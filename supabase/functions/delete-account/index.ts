// In-app account deletion (App Store guideline 5.1.1(v)).
//
// Money first, then the account:
// - card checkouts still open are called off (balances come back first);
// - a race that is still running blocks deletion until it settles, because
//   other people's purses depend on it (support can close one by hand);
// - a cash-out on its way blocks deletion until it lands;
// - Vault money is either paid out now ("cash_out") or given up ("give_up");
//   the app asks which. Entry credit is promotional and ends with the account.
// Ledger and cash-out rows stay without the person's id (see the
// keep_money_records migration), so a payout sent here can still finish.
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";
import { type Cashout, sendCashout } from "../_shared/payout.ts";

type Body = { vault?: "cash_out" | "give_up" };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json().catch(() => ({}))) as Body;
  const db = admin();

  const { data: pending } = await db.from("races").select("id").eq("user_id", user.id).eq("status", "pendingPayment");
  for (const r of pending ?? []) await db.rpc("cancel_pending", { rid: r.id });
  const { data: unpaid } = await db.from("purses").select("id").eq("host_id", user.id).eq("listed", false).is("host_payment_ref", null);
  for (const p of unpaid ?? []) await db.rpc("cancel_host_purse", { pid: p.id });

  const { count: running } = await db.from("races").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).in("status", ["active", "settling", "underReview"]);
  if ((running ?? 0) > 0) {
    return json({
      error: `You have ${running} race${running === 1 ? "" : "s"} running. You can delete your account once ${running === 1 ? "it settles" : "they settle"}, and we'll pay out what you win first. To close it sooner, write to support.`,
      code: "races_running",
    }, 409);
  }

  const { count: sending } = await db.from("cashouts").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).in("status", ["requested", "processing"]);
  if ((sending ?? 0) > 0) {
    return json({ error: "A cash-out is on its way. Delete your account once it lands.", code: "cashout_in_flight" }, 409);
  }

  const { data: profile } = await db.from("profiles").select("vault_cents, currency, whop_user_id").eq("id", user.id).maybeSingle();
  const vault = profile?.vault_cents ?? 0;
  let payout: Cashout | null = null;

  if (vault > 0) {
    if (body.vault === "cash_out") {
      const method = profile?.whop_user_id ? "whop" : "claim_link";
      if (method === "claim_link" && (profile?.currency ?? "USD") !== "USD") {
        return json({ error: "We can only send this Vault to a Whop account you've paid with. Write to support and we'll pay it out by hand.", code: "no_payout_path" }, 409);
      }
      const { data: id, error } = await db.rpc("request_cashout", {
        uid: user.id, cents: vault, daily: 2_000_000_000, how: method, why: "account_closed",
      });
      if (error) throw error;
      const { data: row } = await db.from("cashouts").select("*").eq("id", id).single();
      payout = await sendCashout(db, row as Cashout, profile?.whop_user_id ?? null);
      if (payout.status === "requested") {
        return json({ error: "Your Vault payout is queued; Whop didn't answer just now. Delete your account once it lands.", code: "cashout_in_flight" }, 409);
      }
    } else if (body.vault === "give_up") {
      await db.rpc("adjust_balance", { uid: user.id, vault_delta: -vault, credit_delta: 0 });
      await db.from("ledger_entries").insert({
        race_id: null, user_id: user.id, kind: "kept", amount_cents: vault, currency: profile?.currency ?? "USD",
        ref: `close_${user.id}`, label: "Vault given up when the account was deleted",
      });
    } else {
      return json({
        error: "Your Vault still holds money. Cash it out, or say you're giving it up.",
        code: "vault_not_empty",
        vault_cents: vault,
        currency: profile?.currency ?? "USD",
      }, 409);
    }
  }

  const { error } = await db.auth.admin.deleteUser(user.id); // profile, races and days cascade; money rows stay, unnamed
  if (error) throw error;
  return json({
    ok: true,
    // A claim link is the only way to the money once the account is gone: the app shows it now.
    payout: payout ? { status: payout.status, method: payout.method, claim_url: payout.claim_url, amount_cents: payout.amount_cents } : null,
  });
}));
