// The app asks the server to look at its Pro subscription: after a purchase,
// at launch, and when StoreKit reports a change. Body { transaction_id } is
// any transaction of the subscription (StoreKit's Transaction.id); with no
// body the server re-checks the subscription it already knows. The answer
// always comes from Apple, never from the phone.
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";
import { proStatus } from "../_shared/appstore.ts";
import { savePro } from "../_shared/pro.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const body = await req.json().catch(() => ({})) as { transaction_id?: string };
  const db = admin();

  const { data: profile } = await db.from("profiles").select("pro_original_tx").eq("id", user.id).maybeSingle();
  if (!profile) throw new HttpError(404, "No profile for this account.");
  const tx = body.transaction_id ?? profile.pro_original_tx;
  if (!tx) return json({ is_pro: false, expires_at: null });
  if (!/^\d{1,20}$/.test(tx)) throw new HttpError(400, "Bad transaction.");

  const s = await proStatus(tx);
  if (!s) {
    // Not a Pro subscription of this app. Only switch Pro off if it was the one on file.
    if (tx === profile.pro_original_tx) await db.from("profiles").update({ is_pro: false, pro_checked_at: new Date().toISOString() }).eq("id", user.id);
    throw new HttpError(404, "We couldn't find a Steppie Pro subscription for that purchase.");
  }
  return json(await savePro(db, user.id, s));
}));
