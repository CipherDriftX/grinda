// Joins a purse. The entry plus fees come from entry credit first, then the
// Vault, then the card. The race is live at once when balances cover it;
// otherwise it waits for the card payment (stripe-webhook activates it).
import {
  admin, consecutiveDates, handler, hostFee, HttpError, json, localToday, payReferral, requireUser, serviceFee, settleInstant,
  stripe, STRIPE_API_VERSION, stripeCustomer,
} from "../_shared/common.ts";

type Body = {
  purse_id: string;
  timezone: string;
  birth_year?: number | null;
  shields_equipped?: number;
};

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  try {
    new Intl.DateTimeFormat("en-US", { timeZone: body.timezone });
  } catch {
    throw new HttpError(400, "Unknown time zone.");
  }

  const { data: purse } = await db.from("purses").select("*").eq("id", body.purse_id).maybeSingle();
  if (!purse || !purse.listed) throw new HttpError(404, "That purse isn't open.");
  // Open until the first day starts for this walker.
  if (purse.starts_on <= localToday(body.timezone)) throw new HttpError(409, "This purse has already started. A new one opens every week.");

  const { data: profile } = await db.from("profiles").select("*").eq("id", user.id).maybeSingle();
  const birthYear = body.birth_year ?? profile?.birth_year;
  if (!birthYear || new Date().getUTCFullYear() - birthYear < 18) throw new HttpError(403, "Purses are for adults 18 and over.");
  if (purse.pro_only && !profile?.is_pro) throw new HttpError(403, "This purse is for Steppie Pro members.");

  const isPro = !!profile?.is_pro;
  const { count: running } = await db.from("races").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).in("status", ["active", "pendingPayment"]).not("stake_cents", "is", null);
  if ((running ?? 0) >= (isPro ? 5 : 1)) {
    throw new HttpError(409, isPro ? "You're running five already." : "You already have a race running. Steppie Pro lets you run up to five at once.");
  }

  if (purse.cap) {
    const { count: inIt } = await db.from("races").select("id", { count: "exact", head: true })
      .eq("purse_id", purse.id).neq("status", "cancelled");
    if ((inIt ?? 0) >= purse.cap) throw new HttpError(409, "This purse is full.");
  }

  const shields = Math.max(0, Math.min(Math.floor(body.shields_equipped ?? 0), 2));
  if (shields > (profile?.shields ?? 0)) throw new HttpError(400, "Not enough Shields in your locker.");

  const entry = purse.entry_cents as number;
  const fee = serviceFee(entry, isPro);
  const host = hostFee(entry, purse.kind);
  const total = entry + fee + host;

  // Balances: credit first (entry-only money), then the Vault.
  const fromCredit = Math.min(profile?.credit_cents ?? 0, total);
  const fromVault = Math.min(profile?.vault_cents ?? 0, total - fromCredit);
  const fromCard = total - fromCredit - fromVault;
  if (fromCard > 0 && fromCard < 50) throw new HttpError(400, "Add a little to your Vault first; cards need at least 50 cents.");

  const dates = consecutiveDates(purse.starts_on, purse.days);
  const settlesAt = settleInstant(dates[dates.length - 1], body.timezone, 24); // late syncs always land
  const bib = 1000 + Math.floor(Math.random() * 9000);

  const { data: race, error } = await db.from("races").insert({
    user_id: user.id,
    template_id: `purse:${purse.id}`,
    name: purse.name,
    daily_goal: purse.daily_goal,
    grace_allowed: 0,
    timezone: body.timezone,
    start_date: dates[0],
    end_date: dates[dates.length - 1],
    settles_at: settlesAt.toISOString(),
    stake_cents: entry,
    currency: purse.currency,
    capture_method: "automatic",
    status: fromCard > 0 ? "pendingPayment" : "active",
    stake_state: fromCard > 0 ? "none" : "charged",
    bib_number: bib,
    shields_equipped: shields,
    purse_id: purse.id,
    fee_cents: fee,
    host_fee_cents: host,
    paid_from_balance_cents: fromCredit + fromVault,
  }).select().single();
  if (error?.code === "23505") throw new HttpError(409, "You're already in this purse.");
  if (error || !race) throw error ?? new Error("insert failed");

  if (fromCredit + fromVault > 0) {
    const { error: e } = await db.rpc("adjust_balance", { uid: user.id, vault_delta: -fromVault, credit_delta: -fromCredit });
    if (e) {
      await db.from("races").delete().eq("id", race.id);
      throw new HttpError(409, "Your balance changed. Try again.");
    }
  }
  await db.from("race_days").insert(dates.map((day) => ({ race_id: race.id, day, goal: purse.daily_goal })));
  if (shields > 0) await db.from("profiles").update({ shields: (profile?.shields ?? 0) - shields }).eq("id", user.id);

  if (fromCard === 0) {
    await db.from("ledger_entries").insert([
      { race_id: race.id, user_id: user.id, kind: "entry", amount_cents: entry, currency: purse.currency, stripe_ref: `bal_${race.id}` },
      ...(fee + host > 0
        ? [{ race_id: race.id, user_id: user.id, kind: "fee", amount_cents: fee + host, currency: purse.currency, stripe_ref: `bal_${race.id}` }]
        : []),
    ]);
    await payReferral(db, user.id, purse.currency);
    return json({ race_id: race.id, bib_number: bib, payment: null });
  }

  const customerId = await stripeCustomer(db, user.id, profile);
  const intent = await stripe.paymentIntents.create({
    amount: fromCard,
    currency: purse.currency.toLowerCase(),
    customer: customerId,
    payment_method_types: ["card"],
    description: `Steppie purse entry: ${purse.name} (bib ${bib})`,
    statement_descriptor_suffix: "STEPPIE PURSE",
    metadata: { race_id: race.id, user_id: user.id, purse_id: purse.id, kind: "purse_entry" },
  }, { idempotencyKey: `purse-${race.id}` });
  await db.from("races").update({ stripe_payment_intent: intent.id }).eq("id", race.id);
  const key = await stripe.ephemeralKeys.create({ customer: customerId }, { apiVersion: STRIPE_API_VERSION });

  return json({
    race_id: race.id,
    bib_number: bib,
    payment: {
      race_id: race.id,
      bib_number: bib,
      payment_intent_client_secret: intent.client_secret,
      customer_id: customerId,
      ephemeral_key: key.secret,
      publishable_key: Deno.env.get("STRIPE_PUBLISHABLE_KEY"),
      capture_method: "automatic",
    },
  });
}));
