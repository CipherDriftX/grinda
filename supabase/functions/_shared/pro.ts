// Stores a Pro answer from Apple on the account that owns the subscription.
// Ownership: the appAccountToken Apple holds (the Steppie account id the app
// passed at purchase) wins. Without one, the first account to show the
// subscription keeps it, so one subscription can't unlock Pro on many accounts.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./common.ts";
import type { ProStatus } from "./appstore.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** Which account a subscription belongs to: the token's account, else the one that claimed it. */
export async function proOwner(db: SupabaseClient, s: ProStatus): Promise<string | null> {
  if (s.appAccountToken && UUID.test(s.appAccountToken)) {
    const { data } = await db.from("profiles").select("id").eq("id", s.appAccountToken).maybeSingle();
    if (data) return data.id;
  }
  const { data } = await db.from("profiles").select("id").eq("pro_original_tx", s.originalTransactionId).maybeSingle();
  return data?.id ?? null;
}

/** Writes the answer to `uid`. Throws 409 when the subscription is someone else's. */
export async function savePro(db: SupabaseClient, uid: string, s: ProStatus) {
  if (s.appAccountToken && UUID.test(s.appAccountToken) && s.appAccountToken !== uid) {
    throw new HttpError(409, "This subscription was bought on another Steppie account. Sign in with that account to use it.");
  }
  const { data: holder } = await db.from("profiles").select("id").eq("pro_original_tx", s.originalTransactionId).maybeSingle();
  if (holder && holder.id !== uid) {
    if (s.appAccountToken !== uid) {
      throw new HttpError(409, "This subscription is linked to another Steppie account. Sign in with that account to use it.");
    }
    // Apple says it's ours: take it back from the account that claimed it first.
    await db.from("profiles").update({ pro_original_tx: null, is_pro: false, pro_expires_at: null }).eq("id", holder.id);
  }
  const { error } = await db.from("profiles").update({
    is_pro: s.active,
    pro_original_tx: s.originalTransactionId,
    pro_expires_at: s.expiresAt,
    pro_checked_at: new Date().toISOString(),
  }).eq("id", uid);
  if (error) throw error;
  return { is_pro: s.active, expires_at: s.expiresAt };
}
