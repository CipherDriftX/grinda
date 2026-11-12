// App Store Server API: the truth about Pro subscriptions and Shield purchases.
// Docs: https://developer.apple.com/documentation/appstoreserverapi
//   GET /inApps/v1/transactions/{transactionId}      one purchase
//   GET /inApps/v1/subscriptions/{anyTransactionId}  every subscription status
// Production first, then sandbox (App Review and TestFlight buy in sandbox).
// Answers come straight from Apple over TLS, so the signed payloads inside are
// read without checking their signature again. Anything sent to us by a phone
// or a notification is only used as a lookup key, never trusted.
import { HttpError } from "./common.ts";

export const BUNDLE_ID = Deno.env.get("APPSTORE_BUNDLE_ID") ?? "com.cipherdriftx.steppie";
export const PRO_IDS = ["steppie.pro.monthly", "steppie.pro.yearly"];
const HOSTS = ["api.storekit.apple.com", "api.storekit-sandbox.apple.com"];

// Subscription status values from Apple.
export const ACTIVE = 1, EXPIRED = 2, BILLING_RETRY = 3, GRACE = 4, REVOKED = 5;

const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));

/** ES256 token for the App Store Server API, signed with the .p8 key. */
export async function appleJWT(env: (k: string) => string | undefined = (k) => Deno.env.get(k), now = Date.now()): Promise<string> {
  const pem = (env("APPSTORE_PRIVATE_KEY") ?? "").replace(/-----[^-]+-----/g, "").replace(/\\n|\s/g, "");
  const keyId = env("APPSTORE_KEY_ID"), issuer = env("APPSTORE_ISSUER_ID");
  if (!pem || !keyId || !issuer) throw new HttpError(503, "App Store keys are not set up on the server.");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const iat = Math.floor(now / 1000);
  const head = `${enc({ alg: "ES256", kid: keyId, typ: "JWT" })}.${enc({
    iss: issuer, iat, exp: iat + 15 * 60, aud: "appstoreconnect-v1", bid: env("APPSTORE_BUNDLE_ID") ?? BUNDLE_ID,
  })}`;
  // WebCrypto signs ECDSA as raw r||s, which is the JWS format.
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(head)));
  return `${head}.${b64url(sig)}`;
}

/** The payload of a JWS, unchecked. Only for answers that came from Apple's own API. */
// deno-lint-ignore no-explicit-any
export function jwsPayload(jws: string): any {
  const part = (jws ?? "").split(".")[1];
  if (!part) throw new Error("not a JWS");
  const b64 = part.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((part.length + 3) % 4);
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))));
}

async function appleGet(path: string) {
  const token = await appleJWT();
  for (const host of HOSTS) {
    const res = await fetch(`https://${host}${path}`, { headers: { Authorization: `Bearer ${token}` } });
    if (res.status === 404) continue;
    if (!res.ok) throw new HttpError(502, "The App Store didn't answer. Your purchase is safe; try again in a minute.");
    return await res.json();
  }
  return null;
}

export type AppleTransaction = {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  appAccountToken?: string;
  expiresDate?: number;
  revocationDate?: number;
};

export async function getTransaction(id: string): Promise<AppleTransaction> {
  const res = await appleGet(`/inApps/v1/transactions/${encodeURIComponent(id)}`);
  if (!res) throw new HttpError(404, "We couldn't find that purchase.");
  return jwsPayload(res.signedTransactionInfo);
}

export type ProStatus = {
  active: boolean;
  originalTransactionId: string;
  appAccountToken: string | null;
  expiresAt: string | null; // when Pro ends, grace period included
  productId: string;
};

/** Pro for any transaction id of the subscription: active in status 1 (active) or 4 (billing grace). */
export async function proStatus(anyTransactionId: string): Promise<ProStatus | null> {
  const res = await appleGet(`/inApps/v1/subscriptions/${encodeURIComponent(anyTransactionId)}`);
  if (!res || res.bundleId !== (Deno.env.get("APPSTORE_BUNDLE_ID") ?? BUNDLE_ID)) return null;
  return pickPro(res);
}

/** Picks the Pro subscription out of a subscription-status answer. Exported for tests. */
// deno-lint-ignore no-explicit-any
export function pickPro(res: any): ProStatus | null {
  let best: ProStatus | null = null;
  for (const group of res?.data ?? []) {
    for (const last of group.lastTransactions ?? []) {
      const t = jwsPayload(last.signedTransactionInfo) as AppleTransaction;
      if (!PRO_IDS.includes(t.productId)) continue;
      const renewal = last.signedRenewalInfo ? jwsPayload(last.signedRenewalInfo) : {};
      const ends = Math.max(t.expiresDate ?? 0, last.status === GRACE ? renewal.gracePeriodExpiresDate ?? 0 : 0);
      const s: ProStatus = {
        active: (last.status === ACTIVE || last.status === GRACE) && !t.revocationDate && ends > Date.now(),
        originalTransactionId: String(last.originalTransactionId ?? t.originalTransactionId),
        appAccountToken: t.appAccountToken ? t.appAccountToken.toLowerCase() : null,
        expiresAt: ends ? new Date(ends).toISOString() : null,
        productId: t.productId,
      };
      if (!best || (s.active && !best.active) || (s.active === best.active && (s.expiresAt ?? "") > (best.expiresAt ?? ""))) best = s;
    }
  }
  return best;
}
