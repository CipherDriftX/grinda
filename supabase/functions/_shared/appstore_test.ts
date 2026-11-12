import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { appleJWT, jwsPayload, pickPro } from "./appstore.ts";
import { HttpError, proActive } from "./common.ts";

const b64url = (s: string) => btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const jws = (o: unknown) => `e30.${b64url(JSON.stringify(o))}.sig`;
const DAY = 86_400_000;

Deno.test("the App Store token is a valid ES256 JWT for our key", async () => {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----`;
  const env = { APPSTORE_PRIVATE_KEY: pem, APPSTORE_KEY_ID: "KEY123", APPSTORE_ISSUER_ID: "iss-1", APPSTORE_BUNDLE_ID: "com.x.app" };
  const token = await appleJWT((k) => env[k as keyof typeof env], 1_700_000_000_000);
  const [h, p, s] = token.split(".");
  assertEquals(jwsPayload(`x.${h}.y`), { alg: "ES256", kid: "KEY123", typ: "JWT" });
  assertEquals(jwsPayload(token), { iss: "iss-1", iat: 1_700_000_000, exp: 1_700_000_900, aud: "appstoreconnect-v1", bid: "com.x.app" });
  const sig = Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "==".slice(0, (4 - s.length % 4) % 4)), (c) => c.charCodeAt(0));
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, pair.publicKey, sig, new TextEncoder().encode(`${h}.${p}`));
  assertEquals(ok, true);
  await assertRejects(() => appleJWT(() => undefined), HttpError);
});

Deno.test("pickPro: active, grace, expired, revoked, and other products", () => {
  const now = Date.now();
  const last = (status: number, t: Record<string, unknown>, renewal: Record<string, unknown> = {}) => ({
    originalTransactionId: "100", status, signedTransactionInfo: jws({ originalTransactionId: "100", productId: "steppie.pro.yearly", ...t }),
    signedRenewalInfo: jws(renewal),
  });
  const res = (...l: unknown[]) => ({ data: [{ lastTransactions: l }] });

  const a = pickPro(res(last(1, { expiresDate: now + DAY, appAccountToken: "ABC" })))!;
  assertEquals([a.active, a.appAccountToken, a.originalTransactionId], [true, "abc", "100"]);
  // Billing grace: the paid period ended but grace runs on.
  assertEquals(pickPro(res(last(4, { expiresDate: now - DAY }, { gracePeriodExpiresDate: now + DAY })))!.active, true);
  assertEquals(pickPro(res(last(3, { expiresDate: now - DAY })))!.active, false); // billing retry
  assertEquals(pickPro(res(last(2, { expiresDate: now - DAY })))!.active, false);
  assertEquals(pickPro(res(last(5, { expiresDate: now + DAY, revocationDate: now })))!.active, false);
  assertEquals(pickPro(res({ ...last(1, { expiresDate: now + DAY }), signedTransactionInfo: jws({ productId: "steppie.shield.1" }) })), null);
});

Deno.test("Pro counts only while its period runs", () => {
  const now = Date.now();
  assertEquals(proActive({ is_pro: true, pro_expires_at: new Date(now + DAY).toISOString() }, now), true);
  assertEquals(proActive({ is_pro: true, pro_expires_at: new Date(now - 1000).toISOString() }, now), false); // missed expiry notice
  assertEquals(proActive({ is_pro: true, pro_expires_at: null }, now), false);
  assertEquals(proActive({ is_pro: false, pro_expires_at: new Date(now + DAY).toISOString() }, now), false);
  assertEquals(proActive(null), false);
});
