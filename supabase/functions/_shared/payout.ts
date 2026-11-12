// Sends one cash-out through Whop and records what happened. Used by
// cash-out (first try), settle (retries and claim-link checks) and
// delete-account (closing payout).
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { createClaimLink, getClaimLink, getTransfer, transferToUser, WhopError } from "./whop.ts";

/** About a day of retries at settle's 15-minute beat before the money goes back to the Vault. */
export const MAX_ATTEMPTS = 96;
/** How long a claim link stays open before its money comes back. */
export const CLAIM_DAYS = 7;

export type Cashout = {
  id: string;
  user_id: string;
  amount_cents: number;
  currency: string;
  method: "whop" | "claim_link";
  status: "requested" | "processing" | "paid" | "failed";
  transfer_id: string | null;
  claim_url: string | null;
  claim_expires_at: string | null;
  tracking_url: string | null;
  attempts: number;
  failure: string | null;
};

/** Makes the Whop call for a cash-out that has none yet (status 'requested'). */
export async function sendCashout(db: SupabaseClient, c: Cashout, whopUserId: string | null): Promise<Cashout> {
  const attempts = c.attempts + 1;
  await db.from("cashouts").update({ attempts }).eq("id", c.id);
  try {
    if (c.method === "whop") {
      if (!whopUserId) throw new Error("no Whop account to send to");
      const t = await transferToUser({
        whopUserId, cents: c.amount_cents, currency: c.currency, key: c.id, note: "Steppie cash-out",
        meta: { cashout_id: c.id, user_id: c.user_id },
      });
      await db.from("cashouts").update({ transfer_id: t.id, tracking_url: t.tracking_url ?? null, status: "processing", failure: null })
        .eq("id", c.id);
      if (t.status === "succeeded") await db.rpc("cashout_paid", { cid: c.id });
      if (t.status === "failed") await db.rpc("cashout_failed", { cid: c.id, why: t.failure_reason ?? t.failure_code ?? "transfer failed" });
    } else {
      const expires = new Date(Date.now() + CLAIM_DAYS * 24 * 3600_000);
      const link = await createClaimLink(c.amount_cents, expires);
      await db.from("cashouts").update({
        transfer_id: link.id, claim_url: link.claim_url, claim_expires_at: link.expires_at ?? expires.toISOString(),
        status: "processing", failure: null,
      }).eq("id", c.id);
    }
  } catch (e) {
    const why = e instanceof WhopError ? e.message : String(e);
    console.error("cashout", c.id, why);
    await db.from("cashouts").update({ failure: why.slice(0, 300) }).eq("id", c.id);
    if (attempts >= MAX_ATTEMPTS) await db.rpc("cashout_failed", { cid: c.id, why });
  }
  const { data } = await db.from("cashouts").select("*").eq("id", c.id).single();
  return data as Cashout;
}

/** Checks a cash-out Whop is still working on: a transfer settling, or a claim link waiting. */
export async function checkCashout(db: SupabaseClient, c: Cashout): Promise<string> {
  if (!c.transfer_id) return "no transfer";
  if (c.method === "whop") {
    const t = await getTransfer(c.transfer_id);
    if (t.status === "succeeded") await db.rpc("cashout_paid", { cid: c.id });
    if (t.status === "failed") await db.rpc("cashout_failed", { cid: c.id, why: t.failure_reason ?? t.failure_code ?? "transfer failed" });
    return t.status;
  }
  const link = await getClaimLink(c.transfer_id);
  if (link.redeemed_count >= 1) {
    await db.rpc("cashout_paid", { cid: c.id });
    return "claimed";
  }
  const expiry = link.expires_at ?? c.claim_expires_at;
  if (!link.claimable && expiry && new Date(expiry).getTime() < Date.now()) {
    await db.rpc("cashout_failed", { cid: c.id, why: "claim link expired unclaimed" });
    return "expired";
  }
  return "waiting";
}
