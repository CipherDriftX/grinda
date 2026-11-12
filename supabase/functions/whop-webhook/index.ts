// Whop webhook. Checks the Standard Webhooks signature, stores the event id
// first (Whop delivers at least once), then books the money:
//   payment.succeeded   a race goes live or a host purse is listed; a payment
//                       nothing can take (race called off, paid twice, short)
//                       is refunded at once
//   dispute.created     cash-outs stop for that person until someone looks
//   transfer.completed  a cash-out is paid
//   transfer.failed     a cash-out failed: the money goes back to the Vault
// Every other event is stored and answered 200. On an error the event is
// forgotten and a 500 goes back, so Whop retries it.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { admin, INVITE_BONUS, json } from "../_shared/common.ts";
import {
  getPayment, refundPayment, SignatureError, toCents, verifyWhopWebhook, type WhopEvent, type WhopPayment,
} from "../_shared/whop.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const raw = await req.text();
  let id: string;
  let event: WhopEvent;
  try {
    ({ id, event } = await verifyWhopWebhook(raw, req.headers, Deno.env.get("WHOP_WEBHOOK_SECRET") ?? ""));
  } catch (e) {
    if (e instanceof SignatureError) return json({ error: e.message }, 401);
    return json({ error: "bad body" }, 400);
  }

  const db = admin();
  const { error: seen } = await db.from("whop_events").insert({ id, type: event.type, object_id: event.data?.id ?? null });
  if (seen?.code === "23505") return json({ ok: true, repeat: true });
  if (seen) return json({ error: "store failed" }, 500);

  try {
    return json({ ok: true, result: await handle(db, event) });
  } catch (e) {
    await db.from("whop_events").delete().eq("id", id);
    console.error(event.type, event.data?.id, e);
    return json({ error: "failed" }, 500);
  }
});

async function handle(db: SupabaseClient, event: WhopEvent): Promise<string> {
  switch (event.type) {
    case "payment.succeeded":
      return await paid(db, event.data as WhopPayment);
    case "dispute.created":
      return await disputed(db, event.data);
    case "transfer.completed":
    case "transfer.failed":
      return await transferDone(db, event.data);
    default:
      return "stored";
  }
}

async function paid(db: SupabaseClient, pay: WhopPayment): Promise<string> {
  const meta = pay.metadata ?? {};
  const cents = toCents(pay.total ?? pay.subtotal);
  const cur = pay.currency ?? "";
  const whopUser = pay.user?.id ?? null;

  let state: string;
  if (meta.kind === "race" && UUID.test(meta.race_id ?? "")) {
    const { data, error } = await db.rpc("confirm_payment", {
      rid: meta.race_id, pay_ref: pay.id, paid: cents, cur, whop_user: whopUser, bonus: INVITE_BONUS,
    });
    if (error) throw error;
    state = data as string;
  } else if (meta.kind === "host" && meta.purse_id) {
    const { data, error } = await db.rpc("confirm_host_payment", { pid: meta.purse_id, pay_ref: pay.id, paid: cents, cur, whop_user: whopUser });
    if (error) throw error;
    state = data as string;
  } else {
    return "not a Steppie payment";
  }

  if (state === "refund" || state === "unknown") {
    await refundOnce(pay.id, state === "unknown" ? "no_such_entry" : "entry_closed");
    return `${state}: refunded`;
  }
  return state;
}

/** Refunds a whole payment unless Whop already shows it refunded (a retried event). */
async function refundOnce(paymentId: string, reason: string) {
  const p = await getPayment(paymentId);
  if (p.refundable === false || toCents(p.refunded_amount) >= toCents(p.total)) return;
  await refundPayment(paymentId, undefined, { reason });
}

// deno-lint-ignore no-explicit-any
async function disputed(db: SupabaseClient, d: any): Promise<string> {
  const payId = d?.payment?.id as string | undefined;
  if (!payId) return "no payment";
  const why = `${d.inquiry ? "inquiry" : "dispute"} ${d.id} (${d.reason ?? "no reason"}) on ${payId}`;
  const { data: race } = await db.from("races").select("user_id").eq("payment_ref", payId).maybeSingle();
  const { data: purse } = race ? { data: null } : await db.from("purses").select("host_id").eq("host_payment_ref", payId).maybeSingle();
  const uid = race?.user_id ?? purse?.host_id;
  if (!uid) return "not a Steppie payment";
  const { error } = await db.rpc("freeze_payouts", { uid, why });
  if (error) throw error;
  return "payouts frozen";
}

// deno-lint-ignore no-explicit-any
async function transferDone(db: SupabaseClient, t: any): Promise<string> {
  const { data: c } = await db.from("cashouts").select("id").eq("transfer_id", t?.id ?? "").maybeSingle();
  const cid = c?.id ?? t?.metadata?.cashout_id;
  if (!cid || !UUID.test(cid)) return "not a Steppie cash-out";
  if (t.status === "succeeded") {
    await db.rpc("cashout_paid", { cid });
    return "cash-out paid";
  }
  if (t.status === "failed") {
    await db.rpc("cashout_failed", { cid, why: t.failure_reason ?? t.failure_code ?? "transfer failed" });
    return "cash-out failed, Vault restored";
  }
  return "cash-out processing";
}
