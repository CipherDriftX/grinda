// A friend's code: entry credit for the new member now, a Vault bonus for the
// friend after the new member's first paid purse entry (see payReferral).
import { admin, handler, HttpError, INVITE_CREDIT, json, requireUser } from "../_shared/common.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const { code: raw } = (await req.json()) as { code: string };
  const code = (raw ?? "").trim().toUpperCase();
  const db = admin();

  if (!/^[A-Z0-9-]{4,16}$/.test(code)) throw new HttpError(400, "That code doesn't look right. Codes look like SAM-4821.");
  const { data: inviter } = await db.from("profiles").select("id").eq("invite_code", code).maybeSingle();
  if (!inviter) throw new HttpError(404, "No one has that code. Check the letters and numbers.");
  if (inviter.id === user.id) throw new HttpError(400, "That's your own code.");

  const { data: me } = await db.from("profiles").select("invited_by,created_at").eq("id", user.id).maybeSingle();
  if (me?.invited_by) throw new HttpError(409, "You've already used a code.");
  // Codes are for new members: within 14 days of joining and before any paid race.
  if (me?.created_at && Date.now() - new Date(me.created_at).getTime() > 14 * 24 * 3600_000) {
    throw new HttpError(409, "Codes work in your first two weeks.");
  }
  const { count: paid } = await db.from("races").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).not("stake_cents", "is", null).neq("status", "cancelled");
  if ((paid ?? 0) > 0) throw new HttpError(409, "Codes are for new members, before their first race.");

  const { error } = await db.from("referrals").insert({ invitee_id: user.id, inviter_id: inviter.id, code });
  if (error) throw new HttpError(409, "You've already used a code.");
  await db.from("profiles").update({ invited_by: code }).eq("id", user.id);
  await db.rpc("adjust_balance", { uid: user.id, vault_delta: 0, credit_delta: INVITE_CREDIT });
  await db.from("ledger_entries").insert({
    race_id: null, user_id: user.id, kind: "credit", amount_cents: INVITE_CREDIT, currency: "USD",
    stripe_ref: `inv_${code}`, label: `Code ${code}`,
  });

  return json({ ok: true });
}));
