// Stripe webhook: activates races once money is held or paid, and records every
// movement in the ledger. Idempotent: ledger has unique (race_id, kind).
import Stripe from "npm:stripe@17";
import { admin, handler, HttpError, json, stripe } from "../_shared/common.ts";

const cryptoProvider = Stripe.createSubtleCryptoProvider();

Deno.serve(handler(async (req) => {
  const signature = req.headers.get("Stripe-Signature");
  if (!signature) throw new HttpError(400, "Missing signature");
  const raw = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      raw, signature, Deno.env.get("STRIPE_WEBHOOK_SECRET")!, undefined, cryptoProvider,
    );
  } catch {
    throw new HttpError(400, "Bad signature");
  }

  const db = admin();

  async function raceFor(intent: Stripe.PaymentIntent) {
    const id = intent.metadata?.race_id;
    if (!id) return null;
    const { data } = await db.from("races").select("*").eq("id", id).maybeSingle();
    return data;
  }

  async function ledger(race: { id: string; user_id: string; currency: string }, kind: string, amount: number, ref: string) {
    await db.from("ledger_entries").upsert(
      { race_id: race.id, user_id: race.user_id, kind, amount_cents: amount, currency: race.currency, stripe_ref: ref },
      { onConflict: "race_id,kind", ignoreDuplicates: true },
    );
  }

  switch (event.type) {
    // Hold placed (manual capture authorised).
    case "payment_intent.amount_capturable_updated": {
      const pi = event.data.object as Stripe.PaymentIntent;
      const race = await raceFor(pi);
      if (race && race.status === "pendingPayment") {
        await db.from("races").update({ status: "active", stake_state: "held" }).eq("id", race.id);
        await ledger(race, "held", pi.amount_capturable, pi.id);
      }
      break;
    }
    // Paid (automatic capture). A captured hold also lands here; settle() records that as "kept".
    case "payment_intent.succeeded": {
      const pi = event.data.object as Stripe.PaymentIntent;
      const race = await raceFor(pi);
      if (race && race.status === "pendingPayment" && pi.capture_method !== "manual") {
        await db.from("races").update({ status: "active", stake_state: "charged" }).eq("id", race.id);
        await ledger(race, "charged", pi.amount_received, pi.id);
      }
      break;
    }
    case "payment_intent.payment_failed":
    case "payment_intent.canceled": {
      const pi = event.data.object as Stripe.PaymentIntent;
      const race = await raceFor(pi);
      if (race && race.status === "pendingPayment") {
        await db.from("races").update({ status: "cancelled" }).eq("id", race.id);
      }
      break;
    }
    case "charge.refunded": {
      const charge = event.data.object as Stripe.Charge;
      const piId = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id;
      if (!piId) break;
      const { data: race } = await db.from("races").select("*").eq("stripe_payment_intent", piId).maybeSingle();
      // A refund on a missed race is a comeback refund; settle() books it on the comeback race.
      if (race && race.status !== "lost") await ledger(race, "refunded", charge.amount_refunded, piId);
      break;
    }
  }

  return json({ received: true });
}));
