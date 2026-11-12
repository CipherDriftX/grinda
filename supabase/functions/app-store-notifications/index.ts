// App Store Server Notifications V2. Apple calls this on every renewal,
// expiry, billing problem, refund or revoke. The body is only a pointer: we
// read the subscription's original transaction id from it, ask the App Store
// Server API for the real status, and store that. A forged notification can't
// grant anything because nothing in it is believed.
// Set this URL in App Store Connect > App > App Information > App Store Server
// Notifications (Version 2), for production and sandbox.
import { admin, HttpError, json } from "../_shared/common.ts";
import { BUNDLE_ID, jwsPayload, proStatus } from "../_shared/appstore.ts";
import { proOwner, savePro } from "../_shared/pro.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  let tx: string;
  try {
    const { signedPayload } = await req.json();
    const note = jwsPayload(signedPayload);
    if (note.data?.bundleId !== BUNDLE_ID) return json({ ok: true, ignored: "other app" });
    if (!note.data?.signedTransactionInfo) return json({ ok: true, ignored: note.notificationType });
    tx = String(jwsPayload(note.data.signedTransactionInfo).originalTransactionId ?? "");
    if (!/^\d{1,20}$/.test(tx)) return json({ ok: true, ignored: "no transaction" });
  } catch {
    return json({ error: "bad body" }, 400);
  }

  try {
    const s = await proStatus(tx);
    if (!s) return json({ ok: true, ignored: "not Pro" }); // a Shield or another product
    const db = admin();
    const uid = await proOwner(db, s);
    if (!uid) return json({ ok: true, ignored: "no account yet" }); // verify-pro links it when the app opens
    return json({ ok: true, ...(await savePro(db, uid, s)) });
  } catch (e) {
    if (e instanceof HttpError && e.status === 409) return json({ ok: true, ignored: "owned by another account" });
    console.error("app-store-notifications", tx, e);
    return json({ error: "failed" }, 500); // Apple retries
  }
});
