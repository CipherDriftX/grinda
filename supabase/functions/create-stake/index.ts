// Creates a solo staked race. The stake comes from the Vault first, then a
// Whop checkout for the rest. A finished stake comes back (card part refunded
// to the card, Vault part to the Vault); a missed one is kept.
import {
  admin, COMEBACK, handler, HttpError, INVITE_BONUS, json, maxRunning, moneyError, quoteStake, requireUser, scheduleDates,
  settleInstant, startAllowed, TEMPLATES,
} from "../_shared/common.ts";
import { createCheckout } from "../_shared/whop.ts";

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
    // not itself a comeback, and a stake at least as big as the miss. The unique
    // index races_one_comeback stops a second one.
    const { data: lost } = await db.from("races").select("*").eq("id", body.comeback_of).maybeSingle();
    if (!lost || lost.user_id !== user.id || lost.status !== "lost" || !lost.stake_cents || lost.purse_id) {
      throw new HttpError(400, "That race can't have a comeback.");
    }
    if (lost.comeback_of) throw new HttpError(400, "A comeback can't have a comeback.");
    if (!lost.settled_at || Date.now() - new Date(lost.settled_at).getTime() > COMEBACK_WINDOW_MS) {
      throw new HttpError(400, "The comeback window has closed.");
    }
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
  if (!/^\d{4}-\d{2}-\d{2}$/.test(body.start_date) || !startAllowed(body.start_date, body.timezone)) {
    throw new HttpError(400, "A race starts today or tomorrow.");
  }

  const { data: profile } = await db.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (!profile) throw new HttpError(403, "Finish setting up your profile first.");
  const birthYear = body.birth_year ?? profile.birth_year;
  if (!birthYear || new Date().getUTCFullYear() - birthYear < 18) {
    throw new HttpError(403, "Staked races are for adults 18 and over.");
  }
  if (!profile.birth_year) await db.from("profiles").update({ birth_year: birthYear }).eq("id", user.id);
  const isPro = !!profile.is_pro;

  // Stake tables: Champion (50+) after one finished race, Legend (100+) after three.
  if (body.stake_cents >= 5000) {
    const { count: finished } = await db.from("races").select("id", { count: "exact", head: true })
      .eq("user_id", user.id).eq("status", "won").not("stake_cents", "is", null);
    const need = body.stake_cents >= 10000 ? 3 : 1;
    if ((finished ?? 0) < need) throw new HttpError(403, `That table opens after ${need} finished race${need > 1 ? "s" : ""}.`);
  }

  const dates = scheduleDates(t, body.start_date);
  const bib = 1000 + Math.floor(Math.random() * 9000);
  const { fromVault, fromCard } = quoteStake(body.stake_cents, profile.vault_cents ?? 0);

  const { data: raceId, error } = await db.rpc("open_race", {
    uid: user.id,
    spec: {
      template_id: t.id, name: t.name, daily_goal: t.dailyGoal, grace_allowed: t.graceDays, timezone: body.timezone,
      days: dates, settles_at: settleInstant(dates[dates.length - 1], body.timezone).toISOString(),
      stake_cents: body.stake_cents, currency: body.currency, bib_number: bib, shields, purse_id: null, comeback_of: comebackOf,
      fee_cents: 0, host_fee_cents: 0, from_credit: 0, from_vault: fromVault, from_card: fromCard,
    },
    max_running: maxRunning(isPro),
    bonus: INVITE_BONUS,
  });
  if (error?.message?.includes("races_one_comeback")) throw new HttpError(409, "You already took this comeback.");
  if (error) throw moneyError(error, isPro);

  if (fromCard === 0) return json({ race_id: raceId, bib_number: bib, checkout: null });

  let checkout;
  try {
    checkout = await createCheckout({
      amountCents: fromCard,
      currency: body.currency,
      title: `${t.name} stake`,
      description: `Bib ${bib}. Finish and your stake comes back; miss and Steppie keeps it.`,
      meta: { kind: "race", race_id: raceId, user_id: user.id },
    });
  } catch (e) {
    await db.rpc("cancel_pending", { rid: raceId });
    console.error("checkout", e);
    throw new HttpError(502, "Card payments are down for a moment. Nothing was charged; try again soon.");
  }
  await db.from("races").update({ checkout_id: checkout.id, checkout_url: checkout.purchase_url }).eq("id", raceId);
  return json({ race_id: raceId, bib_number: bib, checkout: { id: checkout.id, url: checkout.purchase_url } });
}));
