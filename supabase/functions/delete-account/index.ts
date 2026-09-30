// In-app account deletion (App Store guideline 5.1.1(v)).
// Live races are unwound in the person's favour: holds released, charges refunded.
import { admin, handler, HttpError, json, requireUser, stripe } from "../_shared/common.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const db = admin();

  const { data: live } = await db.from("races").select("*").eq("user_id", user.id)
    .in("status", ["pendingPayment", "active", "settling", "underReview"]);

  for (const race of live ?? []) {
    const pi = race.stripe_payment_intent as string | null;
    if (!pi) continue;
    if (race.stake_state === "held" || race.status === "pendingPayment") {
      await stripe.paymentIntents.cancel(pi, {}, { idempotencyKey: `delete-release-${race.id}` }).catch(() => {});
    } else if (race.stake_state === "charged") {
      await stripe.refunds.create({ payment_intent: pi }, { idempotencyKey: `delete-refund-${race.id}` });
    }
  }

  const { data: profile } = await db.from("profiles").select("stripe_customer_id").eq("id", user.id).maybeSingle();
  if (profile?.stripe_customer_id) await stripe.customers.del(profile.stripe_customer_id).catch(() => {});

  const { error } = await db.auth.admin.deleteUser(user.id); // cascades to all tables
  if (error) throw error;
  return json({ ok: true });
}));
