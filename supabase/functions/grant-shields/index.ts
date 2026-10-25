// Credits Steppie Shields bought in the App Store. The app sends the StoreKit
// transaction id; we look it up with Apple (App Store Server API), check it is
// ours, a Shield product, bought by this account (appAccountToken = user id),
// and not refunded. One grant per transaction id.
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
import { admin, handler, HttpError, json, requireUser } from "../_shared/common.ts";

const PRODUCTS: Record<string, number> = { "steppie.shield.1": 1, "steppie.shield.3": 3 };
const BUNDLE_ID = Deno.env.get("APPSTORE_BUNDLE_ID") ?? "com.cipherdriftx.steppie";

async function appleJWT(): Promise<string> {
  const pem = (Deno.env.get("APPSTORE_PRIVATE_KEY") ?? "").replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  return await create(
    { alg: "ES256", kid: Deno.env.get("APPSTORE_KEY_ID")!, typ: "JWT" },
    { iss: Deno.env.get("APPSTORE_ISSUER_ID")!, iat: getNumericDate(0), exp: getNumericDate(15 * 60), aud: "appstoreconnect-v1", bid: BUNDLE_ID },
    key,
  );
}

async function lookup(id: string) {
  const token = await appleJWT();
  for (const host of ["api.storekit.itunes.apple.com", "api.storekit-sandbox.itunes.apple.com"]) {
    const res = await fetch(`https://${host}/inApps/v1/transactions/${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 404) continue;
    if (!res.ok) throw new HttpError(502, "The App Store didn't answer. Your purchase is safe; try again in a minute.");
    const { signedTransactionInfo } = await res.json();
    // Response came straight from Apple over TLS; the payload is the middle JWS segment.
    const payload = signedTransactionInfo.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(payload));
  }
  throw new HttpError(404, "We couldn't find that purchase.");
}

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await requireUser(req);
  const { transaction_id } = (await req.json()) as { transaction_id: string };
  if (!transaction_id || !/^\d+$/.test(transaction_id)) throw new HttpError(400, "Bad transaction.");
  const db = admin();

  const t = await lookup(transaction_id);
  const qty = PRODUCTS[t.productId];
  if (t.bundleId !== BUNDLE_ID || !qty) throw new HttpError(400, "That isn't a Shield.");
  if (t.revocationDate) throw new HttpError(400, "That purchase was refunded.");
  if (t.appAccountToken && t.appAccountToken.toLowerCase() !== user.id.toLowerCase()) {
    throw new HttpError(403, "That purchase belongs to another account.");
  }

  const { error } = await db.from("shield_grants").insert({
    transaction_id, user_id: user.id, product_id: t.productId, quantity: qty,
  });
  const { data: profile } = await db.from("profiles").select("shields").eq("id", user.id).maybeSingle();
  if (!error) {
    await db.from("profiles").upsert({ id: user.id, shields: Math.min((profile?.shields ?? 0) + qty, 99) });
    return json({ shields: Math.min((profile?.shields ?? 0) + qty, 99) });
  }
  // Already granted (duplicate transaction id): report the current count.
  return json({ shields: profile?.shields ?? 0 });
}));
