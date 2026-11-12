// Joins a purse. The entry plus fees come from entry credit first, then the
// Vault, then a Whop checkout for the rest. Paid from balances, the race is
// live at once; otherwise the app opens the checkout and whop-webhook makes
// the race live when the payment lands. An unpaid checkout is called off
// after an hour (settle) or when the person closes it (cancel-checkout).
import {
  admin, consecutiveDates, handler, HttpError, INVITE_BONUS, json, localToday, maxRunning, moneyError, quoteEntry, requireUser,
  settleInstant,
} from "../_shared/common.ts";
import { createCheckout } from "../_shared/whop.ts";

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
  if (!profile) throw new HttpError(403, "Finish setting up your profile first.");
  const birthYear = body.birth_year ?? profile.birth_year;
  if (!birthYear || new Date().getUTCFullYear() - birthYear < 18) throw new HttpError(403, "Purses are for adults 18 and over.");
  if (!profile.birth_year) await db.from("profiles").update({ birth_year: birthYear }).eq("id", user.id);
  if (purse.pro_only && !profile.is_pro) throw new HttpError(403, "This purse is for Steppie Pro members.");
  const isPro = !!profile.is_pro;

  // A checkout already open for this purse: hand back the same one, so a second
  // tap never makes a second payment.
  const { data: pending } = await db.from("races").select("id, bib_number, checkout_id, checkout_url")
    .eq("purse_id", purse.id).eq("user_id", user.id).eq("status", "pendingPayment").maybeSingle();
  if (pending?.checkout_url) {
    return json({ race_id: pending.id, bib_number: pending.bib_number, checkout: { id: pending.checkout_id, url: pending.checkout_url } });
  }
  if (pending) await db.rpc("cancel_pending", { rid: pending.id }); // its checkout never got made

  const shields = Math.max(0, Math.min(Math.floor(body.shields_equipped ?? 0), 2));
  const q = quoteEntry(purse.entry_cents, purse.kind, isPro, profile.credit_cents ?? 0, profile.vault_cents ?? 0);
  const dates = consecutiveDates(purse.starts_on, purse.days);
  const bib = 1000 + Math.floor(Math.random() * 9000);

  const { data: raceId, error } = await db.rpc("open_race", {
    uid: user.id,
    spec: {
      template_id: `purse:${purse.id}`, name: purse.name, daily_goal: purse.daily_goal, grace_allowed: 0,
      timezone: body.timezone, days: dates,
      settles_at: settleInstant(dates[dates.length - 1], body.timezone, 24).toISOString(), // late syncs always land
      stake_cents: q.entry, currency: purse.currency, bib_number: bib, shields, purse_id: purse.id,
      fee_cents: q.fee, host_fee_cents: q.host, from_credit: q.fromCredit, from_vault: q.fromVault, from_card: q.fromCard,
    },
    max_running: maxRunning(isPro),
    bonus: INVITE_BONUS,
  });
  if (error) throw moneyError(error, isPro);

  if (q.fromCard === 0) return json({ race_id: raceId, bib_number: bib, checkout: null });

  let checkout;
  try {
    checkout = await createCheckout({
      amountCents: q.fromCard,
      currency: purse.currency,
      title: `${purse.name} entry`,
      description: `Bib ${bib}. Entry ${cents(q.entry)} into the purse, fee ${cents(q.fee + q.host)}` +
        (q.fromCredit + q.fromVault > 0 ? `, ${cents(q.fromCredit + q.fromVault)} already paid from your balance.` : "."),
      meta: { kind: "race", race_id: raceId, user_id: user.id, purse_id: purse.id },
    });
  } catch (e) {
    await db.rpc("cancel_pending", { rid: raceId });
    console.error("checkout", e);
    throw new HttpError(502, "Card payments are down for a moment. Nothing was charged; try again soon.");
  }
  await db.from("races").update({ checkout_id: checkout.id, checkout_url: checkout.purchase_url }).eq("id", raceId);
  return json({ race_id: raceId, bib_number: bib, checkout: { id: checkout.id, url: checkout.purchase_url } });
}));

function cents(c: number): string {
  return (c / 100).toFixed(2);
}
