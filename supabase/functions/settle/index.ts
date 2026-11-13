// Settle. Runs every 15 minutes (pg_cron), one run at a time.
// 1. Calls off card checkouts left unpaid for an hour: balances and Shields go
//    back. Unpaid public purses go away and their Vault part goes back.
// 2. Settles races whose last day has closed. A flagged or disputed day sends
//    the race to a person instead. Shields cover missed days beyond grace;
//    unused ones go back to the locker. A finished solo stake comes back (the
//    card part refunded to the card, the rest to the Vault); a missed one is
//    kept. A won comeback also returns half of the missed stake.
// 3. Purse entries settle without money; a purse splits once every entry has a
//    result or is under review (split_purse). An entry decided after the split
//    gets its held share, or shares it (pay_reviewed_entry).
// 4. Retries cash-outs Whop hasn't taken yet; checks open transfers and claim links.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { admin, CHECKOUT_TTL_MS, handler, HttpError, json } from "../_shared/common.ts";
import { type Cashout, checkCashout, sendCashout } from "../_shared/payout.ts";
import { getPayment, refundPayment, toCents } from "../_shared/whop.ts";

const LOCK_SECONDS = 600;

Deno.serve(handler(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) throw new HttpError(401, "Nope");
  const db = admin();
  const { data: mine } = await db.rpc("claim_settle", { seconds: LOCK_SECONDS });
  if (!mine) return json({ skipped: "another run is settling" });
  try {
    return json({
      called_off: await callOffUnpaid(db),
      settled: await settleDue(db),
      purses: await splitPurses(db),
      cashouts: await moveCashouts(db),
    });
  } finally {
    await db.rpc("release_settle");
  }
}));

async function callOffUnpaid(db: SupabaseClient) {
  const cutoff = new Date(Date.now() - CHECKOUT_TTL_MS).toISOString();
  const out: string[] = [];
  const { data: races } = await db.from("races").select("id").eq("status", "pendingPayment").lt("created_at", cutoff).limit(200);
  for (const r of races ?? []) {
    const { data: ok } = await db.rpc("cancel_pending", { rid: r.id });
    if (ok) out.push(r.id);
  }
  const { data: purses } = await db.from("purses").select("id").eq("listed", false).is("host_payment_ref", null)
    .gt("host_fee_cents", 0).lt("created_at", cutoff).limit(100);
  for (const p of purses ?? []) {
    const { data: ok } = await db.rpc("cancel_host_purse", { pid: p.id });
    if (ok) out.push(p.id);
  }
  return out;
}

// deno-lint-ignore no-explicit-any
type Race = Record<string, any>;

async function settleDue(db: SupabaseClient) {
  const results: Record<string, string> = {};
  const { data: due } = await db.from("races").select("*").in("status", ["active", "settling"])
    .lte("settles_at", new Date().toISOString()).order("settles_at").limit(200);

  for (const race of (due ?? []) as Race[]) {
    try {
      results[race.id] = await settleOne(db, race);
    } catch (e) {
      console.error("settle", race.id, e);
      results[race.id] = "error, will retry";
    }
  }
  return results;
}

async function settleOne(db: SupabaseClient, race: Race): Promise<string> {
  const { data: days } = await db.from("race_days").select("*").eq("race_id", race.id).order("day");
  if (!days?.length) return "no days";

  if (days.some((d) => d.flagged || d.disputed)) {
    await db.from("races").update({ status: "underReview" }).eq("id", race.id).in("status", ["active", "settling"]);
    return "under review";
  }

  const missed = days.filter((d) => d.steps < d.goal).length;
  const equipped = race.shields_equipped ?? 0;
  const won = missed <= race.grace_allowed + equipped;
  const used = Math.min(Math.max(missed - race.grace_allowed, 0), equipped);
  await db.from("races").update({ status: "settling" }).eq("id", race.id).eq("status", "active");

  if (race.purse_id || race.stake_cents == null) {
    const { data, error } = await db.rpc("settle_race", { rid: race.id, won, used });
    if (error) throw error;
    if (race.purse_id) await db.rpc("pay_reviewed_entry", { rid: race.id }); // only acts if the purse already split
    return `${data}${race.purse_id ? " (purse)" : ""}`;
  }

  let cardBack = 0;
  let comebackCardBack = 0;
  if (won) {
    const onCard = Math.min(race.stake_cents, (race.card_cents ?? 0) - (race.card_refunded_cents ?? 0));
    if (onCard > 0 && race.payment_ref) {
      cardBack = await refundTo(race.payment_ref, (race.card_refunded_cents ?? 0) + onCard, onCard, `stake back: ${race.id}`);
    }
    if (race.comeback_of) {
      const { data: lost } = await db.from("races").select("*").eq("id", race.comeback_of).maybeSingle();
      const half = Math.floor((lost?.stake_cents ?? 0) / 2);
      const onOldCard = Math.min(half, (lost?.card_cents ?? 0) - (lost?.card_refunded_cents ?? 0));
      if (onOldCard > 0 && lost?.payment_ref) {
        comebackCardBack = await refundTo(lost.payment_ref, (lost.card_refunded_cents ?? 0) + onOldCard, onOldCard, `comeback: ${race.id}`);
      }
    }
  }
  const { data, error } = await db.rpc("settle_race", {
    rid: race.id, won, used, card_back: cardBack, comeback_card_back: comebackCardBack,
  });
  if (error) throw error;
  return data as string;
}

/**
 * Refunds `amount` of a payment so its refunded total reaches `target`. Asks
 * Whop first, so a retried run never refunds twice. Returns what is back on
 * the card; 0 means the caller puts the money in the Vault instead (the
 * payment is disputed, too old, or Whop said no).
 */
async function refundTo(paymentId: string, target: number, amount: number, reason: string): Promise<number> {
  const before = await getPayment(paymentId);
  const done = toCents(before.refunded_amount);
  if (done >= target) return amount;
  if (before.refundable === false) return 0;
  try {
    await refundPayment(paymentId, target - done, { reason });
    return amount;
  } catch (e) {
    const after = await getPayment(paymentId).catch(() => null);
    if (after && toCents(after.refunded_amount) >= target) return amount;
    console.error("refund", paymentId, e);
    return 0;
  }
}

async function splitPurses(db: SupabaseClient) {
  const { data: waiting } = await db.from("purses").select("id").is("settled_at", null)
    .lt("starts_on", new Date().toISOString().slice(0, 10)).limit(100);
  const out: unknown[] = [];
  for (const p of waiting ?? []) {
    const { data, error } = await db.rpc("split_purse", { pid: p.id });
    out.push(error ? { purse: p.id, error: error.message } : data);
  }
  return out;
}

async function moveCashouts(db: SupabaseClient) {
  const out: Record<string, string> = {};
  const settledIn = new Date(Date.now() - 2 * 60_000).toISOString(); // leave the live request its own first try
  const { data: open } = await db.from("cashouts").select("*").in("status", ["requested", "processing"])
    .lt("created_at", settledIn).order("created_at").limit(50);
  for (const c of (open ?? []) as Cashout[]) {
    try {
      if (c.status === "requested") {
        const { data: p } = await db.from("profiles").select("whop_user_id").eq("id", c.user_id).maybeSingle();
        out[c.id] = (await sendCashout(db, c, p?.whop_user_id ?? null)).status;
      } else {
        out[c.id] = await checkCashout(db, c);
      }
    } catch (e) {
      console.error("cashout", c.id, e);
      out[c.id] = "error, will retry";
    }
  }
  return out;
}
