// A friend's code: entry credit for the new member now, a Vault bonus for the
// friend after the new member's first purse entry paid with at least that much
// of their own money (see book_paid_race). redeem_invite() checks and books it
// all in one transaction.
import { admin, handler, HttpError, INVITE_CREDIT, json, requireUser } from "../_shared/common.ts";

const ERRORS: Record<string, [number, string]> = {
  no_such_code: [404, "No one has that code. Check the letters and numbers."],
  own_code: [400, "That's your own code."],
  already_used: [409, "You've already used a code."],
  too_late: [409, "Codes work in your first two weeks."],
  not_new: [409, "Codes are for new members, before their first race."],
  wrong_currency: [409, "Your Steppie balance is in another currency."],
  no_profile: [403, "Finish setting up your profile first."],
};

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const { code: raw, currency } = (await req.json()) as { code: string; currency?: string };
  const code = (raw ?? "").trim().toUpperCase();
  if (!/^[A-Z0-9-]{4,16}$/.test(code)) throw new HttpError(400, "That code doesn't look right. Codes look like SAM-4821.");
  const db = admin();

  // The credit is in the person's currency: the one their balance already uses,
  // else the one their phone uses.
  const { data: me } = await db.from("profiles").select("currency").eq("id", user.id).maybeSingle();
  const cur = me?.currency ?? (currency === "EUR" ? "EUR" : "USD");

  const { error } = await db.rpc("redeem_invite", { uid: user.id, invite: code, credit: INVITE_CREDIT, cur });
  if (error) {
    const hit = Object.keys(ERRORS).find((k) => error.message?.includes(k));
    if (hit) throw new HttpError(...ERRORS[hit]);
    if (error.code === "23505") throw new HttpError(409, "You've already used a code.");
    throw error;
  }
  return json({ ok: true, credit_cents: INVITE_CREDIT, currency: cur });
}));
