// Moves Vault money out: bank or PayPal, from $25, up to $500 a day. The
// balance is taken now; the payout itself is sent by the payouts run (and
// marked paid), so a failed transfer goes back to the Vault.
import { admin, CASHOUT_DAILY, CASHOUT_MIN, handler, HttpError, json, requireUser } from "../_shared/common.ts";

type Body = { amount_cents: number; method: "bank" | "paypal" };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = (await req.json()) as Body;
  const db = admin();

  const amount = Math.floor(body.amount_cents);
  if (!Number.isInteger(amount) || amount < CASHOUT_MIN) throw new HttpError(400, "You can cash out from 25.");
  if (!["bank", "paypal"].includes(body.method)) throw new HttpError(400, "Pick bank or PayPal.");

  const since = new Date(Date.now() - 24 * 3600_000).toISOString();
  const { data: recent } = await db.from("cashouts").select("amount_cents").eq("user_id", user.id)
    .neq("status", "failed").gte("created_at", since);
  const today = (recent ?? []).reduce((a, r) => a + (r.amount_cents as number), 0);
  if (today + amount > CASHOUT_DAILY) throw new HttpError(409, "Cash-outs are limited to 500 a day.");

  const { data: profile } = await db.from("profiles").select("vault_cents").eq("id", user.id).maybeSingle();
  if ((profile?.vault_cents ?? 0) < amount) throw new HttpError(409, "That's more than your Vault holds.");

  const { error } = await db.rpc("adjust_balance", { uid: user.id, vault_delta: -amount, credit_delta: 0 });
  if (error) throw new HttpError(409, "Your balance changed. Try again.");

  const { data: row } = await db.from("cashouts").insert({
    user_id: user.id, amount_cents: amount, currency: await currencyFor(db, user.id), method: body.method,
  }).select().single();
  await db.from("ledger_entries").insert({
    race_id: null, user_id: user.id, kind: "cashout", amount_cents: amount, currency: row?.currency ?? "USD",
    stripe_ref: `co_${row?.id}`, label: body.method === "bank" ? "Bank account" : "PayPal",
  });

  return json({ ok: true });
}));

// deno-lint-ignore no-explicit-any
async function currencyFor(db: any, userId: string): Promise<string> {
  const { data } = await db.from("races").select("currency").eq("user_id", userId).not("currency", "is", null)
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  return data?.currency ?? "USD";
}
