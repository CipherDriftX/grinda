// Creates a race and the Stripe PaymentIntent for its stake.
// Short races use capture_method=manual (a hold, released on success).
import {
  admin, handler, HttpError, json, requireUser, scheduleDates, settleInstant, stripe, STRIPE_API_VERSION, TEMPLATES, usesHold,
} from "../_shared/common.ts";

type Body = {
  template_id: string;
  stake_cents: number;
  currency: "EUR" | "USD";
  timezone: string;
  start_date: string; // YYYY-MM-DD, local
  birth_year?: number;
};

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  const t = TEMPLATES[body.template_id];
  if (!t) throw new HttpError(400, "That race isn't on the board anymore.");
  if (!Number.isInteger(body.stake_cents) || body.stake_cents < 500 || body.stake_cents > 50000) {
    throw new HttpError(400, "Stakes run from 5 to 500.");
  }
  if (!["EUR", "USD"].includes(body.currency)) throw new HttpError(400, "Unsupported currency.");
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: body.timezone });
  } catch {
    throw new HttpError(400, "Unknown time zone.");
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(body.start_date)) throw new HttpError(400, "Bad start date.");

  // Profile + age gate (18+ for money).
  const { data: profile } = await db.from("profiles").select("*").eq("id", user.id).maybeSingle();
  const birthYear = body.birth_year ?? profile?.birth_year;
  if (!birthYear || new Date().getUTCFullYear() - birthYear < 18) {
    throw new HttpError(403, "Staked races are for adults 18 and over.");
  }

  // One staked race at a time on the free tier (Pro is checked client-side via StoreKit and
  // mirrored server-side by App Store Server Notifications in a later version).
  const { count } = await db.from("races").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).in("status", ["active", "pendingPayment"]).not("stake_cents", "is", null);
  if ((count ?? 0) >= 3) throw new HttpError(409, "You already have the maximum number of races running.");

  // Stripe customer.
  let customerId = profile?.stripe_customer_id as string | undefined;
  if (!customerId) {
    const customer = await stripe.customers.create({ metadata: { user_id: user.id } });
    customerId = customer.id;
  }
  await db.from("profiles").upsert({ id: user.id, birth_year: birthYear, stripe_customer_id: customerId });

  const dates = scheduleDates(t, body.start_date);
  const hold = usesHold(t);
  const settlesAt = settleInstant(dates[dates.length - 1], body.timezone);
  const bib = 1000 + Math.floor(Math.random() * 9000);

  const { data: race, error } = await db.from("races").insert({
    user_id: user.id,
    template_id: t.id,
    name: t.name,
    daily_goal: t.dailyGoal,
    grace_allowed: t.graceDays,
    timezone: body.timezone,
    start_date: dates[0],
    end_date: dates[dates.length - 1],
    settles_at: settlesAt.toISOString(),
    stake_cents: body.stake_cents,
    currency: body.currency,
    capture_method: hold ? "manual" : "automatic",
    status: "pendingPayment",
    stake_state: "none",
    bib_number: bib,
  }).select().single();
  if (error || !race) throw error ?? new Error("insert failed");

  await db.from("race_days").insert(dates.map((day) => ({ race_id: race.id, day, goal: t.dailyGoal })));

  const intent = await stripe.paymentIntents.create({
    amount: body.stake_cents,
    currency: body.currency.toLowerCase(),
    customer: customerId,
    capture_method: hold ? "manual" : "automatic",
    payment_method_types: ["card"], // includes Apple Pay; holds need card rails
    description: `Grinda stake: ${t.name} (bib ${bib})`,
    statement_descriptor_suffix: "GRINDA STAKE",
    metadata: { race_id: race.id, user_id: user.id, template_id: t.id },
  }, { idempotencyKey: `stake-${race.id}` });

  await db.from("races").update({ stripe_payment_intent: intent.id }).eq("id", race.id);

  const key = await stripe.ephemeralKeys.create({ customer: customerId }, { apiVersion: STRIPE_API_VERSION });

  return json({
    race_id: race.id,
    bib_number: bib,
    payment_intent_client_secret: intent.client_secret,
    customer_id: customerId,
    ephemeral_key: key.secret,
    publishable_key: Deno.env.get("STRIPE_PUBLISHABLE_KEY"),
    capture_method: hold ? "manual" : "automatic",
  });
}));
