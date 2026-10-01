// Settles races whose last day closed more than 3 hours ago. Runs every 15 min (pg_cron).
// Won: release the hold or refund in full. Lost: capture the hold or keep the charge.
// Shields cover missed days beyond grace; unused ones go back to the locker.
// A won comeback also refunds half of the missed race's stake.
import { admin, handler, HttpError, json, stripe } from "../_shared/common.ts";

const HOLD_SAFETY_MS = 6.5 * 24 * 3600_000; // Stripe card authorisations expire after ~7 days

Deno.serve(handler(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) throw new HttpError(401, "Nope");
  const db = admin();
  const results: Record<string, string> = {};

  // 1. Safety net: never let a hold expire. Capture it and treat the race as charged (refund on win).
  const { data: aging } = await db.from("races").select("*")
    .eq("status", "active").eq("stake_state", "held")
    .lt("created_at", new Date(Date.now() - HOLD_SAFETY_MS).toISOString());
  for (const race of aging ?? []) {
    await stripe.paymentIntents.capture(race.stripe_payment_intent, {}, { idempotencyKey: `safety-capture-${race.id}` });
    await db.from("races").update({ stake_state: "charged" }).eq("id", race.id);
    results[race.id] = "hold converted to charge (will refund on finish)";
  }

  // 2. Settle due races.
  const { data: due } = await db.from("races").select("*")
    .eq("status", "active").lte("settles_at", new Date().toISOString()).limit(200);

  for (const race of due ?? []) {
    const { data: days } = await db.from("race_days").select("*").eq("race_id", race.id).order("day");
    if (!days) continue;

    if (days.some((d) => d.flagged)) {
      await db.from("races").update({ status: "underReview" }).eq("id", race.id);
      results[race.id] = "under review";
      continue;
    }

    const missed = days.filter((d) => d.steps < d.goal).length;
    const equipped = race.shields_equipped ?? 0;
    const won = missed <= race.grace_allowed + equipped;
    const used = Math.min(Math.max(missed - race.grace_allowed, 0), equipped);
    if (equipped > 0) {
      const { data: prof } = await db.from("profiles").select("shields").eq("id", race.user_id).maybeSingle();
      await db.from("profiles").update({ shields: (prof?.shields ?? 0) + (equipped - used) }).eq("id", race.user_id);
      await db.from("races").update({ shields_used: used }).eq("id", race.id);
    }
    const pi = race.stripe_payment_intent as string | null;
    const base = { race_id: race.id, user_id: race.user_id, currency: race.currency, amount_cents: race.stake_cents, stripe_ref: pi ?? "" };

    await db.from("races").update({ status: "settling" }).eq("id", race.id);

    if (!pi || race.stake_cents == null) {
      await db.from("races").update({ status: won ? "won" : "lost", settled_at: new Date().toISOString() }).eq("id", race.id);
      continue;
    }

    if (won) {
      if (race.stake_state === "held") {
        await stripe.paymentIntents.cancel(pi, {}, { idempotencyKey: `release-${race.id}` });
        await db.from("ledger_entries").upsert({ ...base, kind: "released" }, { onConflict: "race_id,kind", ignoreDuplicates: true });
        await db.from("races").update({ status: "won", stake_state: "released", settled_at: new Date().toISOString() }).eq("id", race.id);
      } else {
        await stripe.refunds.create({ payment_intent: pi }, { idempotencyKey: `refund-${race.id}` });
        await db.from("ledger_entries").upsert({ ...base, kind: "refunded" }, { onConflict: "race_id,kind", ignoreDuplicates: true });
        await db.from("races").update({ status: "won", stake_state: "refunded", settled_at: new Date().toISOString() }).eq("id", race.id);
      }
      if (race.comeback_of) await comebackRefund(db, race);
      results[race.id] = "won";
    } else {
      if (race.stake_state === "held") {
        await stripe.paymentIntents.capture(pi, {}, { idempotencyKey: `capture-${race.id}` });
      }
      await db.from("ledger_entries").upsert({ ...base, kind: "kept" }, { onConflict: "race_id,kind", ignoreDuplicates: true });
      await db.from("races").update({ status: "lost", stake_state: "kept", settled_at: new Date().toISOString() }).eq("id", race.id);
      results[race.id] = "lost";
    }
  }

  return json({ settled: results });
}));

// Half of the missed race's stake goes back to the card it came from.
// deno-lint-ignore no-explicit-any
async function comebackRefund(db: any, race: any) {
  const { data: lost } = await db.from("races").select("*").eq("id", race.comeback_of).maybeSingle();
  if (!lost?.stripe_payment_intent || !lost.stake_cents) return;
  const amount = Math.floor(lost.stake_cents / 2);
  await stripe.refunds.create({ payment_intent: lost.stripe_payment_intent, amount, metadata: { kind: "comeback", race_id: race.id } },
    { idempotencyKey: `comeback-${race.id}` });
  await db.from("ledger_entries").upsert({
    race_id: race.id, user_id: race.user_id, kind: "comeback", amount_cents: amount, currency: lost.currency,
    stripe_ref: lost.stripe_payment_intent,
  }, { onConflict: "race_id,kind", ignoreDuplicates: true });
}

