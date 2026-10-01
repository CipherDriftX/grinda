// Creates a race and the Stripe PaymentIntent for its stake.
// Short races use capture_method=manual (a hold, released on success).
import {
  admin, COMEBACK, handler, HttpError, json, requireUser, scheduleDates, settleInstant, stripe, STRIPE_API_VERSION, TEMPLATES, usesHold,
} from "../_shared/common.ts";

type Body = {
  template_id: string;
  stake_cents: number;
  currency: "EUR" | "USD";
  timezone: string;
  start_date: string; // YYYY-MM-DD, local
  birth_year?: number;
  shields_equipped?: number; // 0...2, taken from the person's locker
  comeback_of?: string | null; // a missed race this is the comeback for
};

const COMEBACK_WINDOW_MS = 72 * 3600_000;

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  let t = TEMPLATES[body.template_id];
  let comebackOf: string | null = null;
  if (body.comeback_of) {
    // One second chance, never a chase: own race, missed, settled in the last 72 h,
    // not itself a comeback, no comeback yet, and a stake at least as big as the miss.
    const { data: lost } = await db.from("races").select("*").eq("id", body.comeback_of).maybeSingle();
    if (!lost || lost.user_id !== user.id || lost.status !== "lost" || !lost.stake_cents) {
      throw new HttpError(400, "That race can't have a comeback.");
    }
    if (lost.comeback_of) throw new HttpError(400, "A comeback can't have a comeback.");
    if (!lost.settled_at || Date.now() - new Date(lost.settled_at).getTime() > COMEBACK_WINDOW_MS) {
      throw new HttpError(400, "The comeback window has closed.");
    }
    const { count: taken } = await db.from("races").select("id", { count: "exact", head: true })
      .eq("comeback_of", lost.id).neq("status", "cancelled");
    if ((taken ?? 0) > 0) throw new HttpError(409, "You already took this comeback.");
    if (body.stake_cents < lost.stake_cents) throw new HttpError(400, "A comeback stake matches the race you missed.");
    if (body.currency !== lost.currency) throw new HttpError(400, "Use the same currency as the race you missed.");
    t = { ...COMEBACK, dailyGoal: lost.daily_goal };
    comebackOf = lost.id;
  }
  if (!t) throw new HttpError(400, "That race isn't on the board anymore.");
  const shields = Math.max(0, Math.min(Math.floor(body.shields_equipped ?? 0), 2));
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

  // Stake tables: Champion (50+) after one finished race, Legend (100+) after three.
  if (body.stake_cents >= 5000) {
    const { count: finished } = await db.from("races").select("id", { count: "exact", head: true })
      .eq("user_id", user.id).eq("status", "won").not("stake_cents", "is", null);
    const need = body.stake_cents >= 10000 ? 3 : 1;
    if ((finished ?? 0) < need) throw new HttpError(403, `That table opens after ${need} finished race${need > 1 ? "s" : ""}.`);
  }
  if (shields > (profile?.shields ?? 0)) throw new HttpError(400, "Not enough Shields in your locker.");

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
    shields_equipped: shields,
    comeback_of: comebackOf,
  }).select().single();
  if (error || !race) throw error ?? new Error("insert failed");

  await db.from("race_days").insert(dates.map((day) => ({ race_id: race.id, day, goal: t.dailyGoal })));

  const intent = await stripe.paymentIntents.create({
    amount: body.stake_cents,
    currency: body.currency.toLowerCase(),
    customer: customerId,
    capture_method: hold ? "manual" : "automatic",
    payment_method_types: ["card"], // includes Apple Pay; holds need card rails
    description: `Steppie stake: ${t.name} (bib ${bib})`,
    statement_descriptor_suffix: "STEPPIE STAKE",
    metadata: { race_id: race.id, user_id: user.id, template_id: t.id },
  }, { idempotencyKey: `stake-${race.id}` });

  await db.from("races").update({ stripe_payment_intent: intent.id }).eq("id", race.id);
  // Shields move from the locker onto the race now; settle() returns the unused ones.
  if (shields > 0) await db.from("profiles").update({ shields: (profile?.shields ?? 0) - shields }).eq("id", user.id);

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
