// Moves Vault money out through Whop, from 5 up to 500 a day. The Vault is
// debited first, in one transaction with the cash-out row and ledger line.
// People who have paid through Whop get a balance transfer to their Whop
// account; everyone else gets a claim link (USD only, since a claim link
// can't name a currency). If Whop is down or short, settle retries for about
// a day, then the money goes back to the Vault.
import { admin, CASHOUT_DAILY, CASHOUT_MIN, handler, HttpError, json, requireUser } from "../_shared/common.ts";
import { type Cashout, sendCashout } from "../_shared/payout.ts";

type Body = { amount_cents: number };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  const amount = Math.floor(body.amount_cents);
  if (!Number.isInteger(amount) || amount < CASHOUT_MIN) throw new HttpError(400, "You can cash out from 5.");

  const { data: profile } = await db.from("profiles").select("currency, whop_user_id, payouts_frozen_at").eq("id", user.id).maybeSingle();
  if (!profile) throw new HttpError(403, "Finish setting up your profile first.");
  if (profile.payouts_frozen_at) {
    throw new HttpError(409, "Cash-outs are paused on your account while we look at a card dispute. Write to support and we'll sort it out.");
  }
  const method = profile.whop_user_id ? "whop" : "claim_link";
  if (method === "claim_link" && (profile.currency ?? "USD") !== "USD") {
    throw new HttpError(409, "Pay one entry by card first, so we know your Whop account. Then cash-outs go straight to it.");
  }

  const { data: id, error } = await db.rpc("request_cashout", { uid: user.id, cents: amount, daily: CASHOUT_DAILY, how: method });
  if (error) {
    const m = error.message ?? "";
    if (m.includes("over_daily")) throw new HttpError(409, "Cash-outs are limited to 500 a day.");
    if (m.includes("payouts_frozen")) throw new HttpError(409, "Cash-outs are paused on your account. Write to support.");
    if (error.code === "23514" || m.includes("vault_cents")) throw new HttpError(409, "That's more than your Vault holds.");
    throw error;
  }

  const { data: row } = await db.from("cashouts").select("*").eq("id", id).single();
  const c = await sendCashout(db, row as Cashout, profile.whop_user_id);
  return json({
    cashout: {
      id: c.id, amount_cents: c.amount_cents, currency: c.currency, method: c.method, status: c.status,
      claim_url: c.claim_url, claim_expires_at: c.claim_expires_at, tracking_url: c.tracking_url,
      // Whop didn't answer yet: the Vault is already debited and we keep trying.
      delayed: c.status === "requested",
    },
  });
}));
