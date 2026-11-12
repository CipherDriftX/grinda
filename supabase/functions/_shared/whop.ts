// Whop: entry fees, stakes and host fees are paid through Whop's hosted
// checkout, and Vault cash-outs go out as Whop balance transfers. Plain fetch,
// no SDK, so every call and header is visible here.
//
// Docs: https://docs.whop.com/developer/quickstart.md (checkout + webhook),
// https://docs.whop.com/developer/guides/webhooks.md (signatures),
// https://docs.whop.com/developer/payouts/overview.md (transfers).

/** The API version every request is pinned to, so Whop changes never move under us. */
export const WHOP_API_VERSION = "2026-11-10-1";

export function whopBase(env: string | undefined): string {
  // Sandbox unless production is asked for by name: a missing variable never moves real money.
  return env === "production" ? "https://api.whop.com/api/v1" : "https://sandbox-api.whop.com/api/v1";
}

export class WhopError extends Error {
  constructor(public status: number, public body: string) {
    super(`Whop ${status}: ${body.slice(0, 300)}`);
  }
}

/** One Whop API call. Throws WhopError on any non-2xx answer. */
export async function whop<T>(method: "GET" | "POST" | "PATCH", path: string, body?: unknown): Promise<T> {
  const key = Deno.env.get("WHOP_API_KEY");
  if (!key) throw new Error("WHOP_API_KEY is not set");
  const res = await fetch(`${whopBase(Deno.env.get("WHOP_ENVIRONMENT"))}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${key}`,
      "Api-Version-Date": WHOP_API_VERSION,
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new WhopError(res.status, text);
  return (text ? JSON.parse(text) : {}) as T;
}

/** Whop amounts are decimals in the currency ("10.00"); Steppie counts cents. */
export function toAmount(cents: number): number {
  return Math.round(cents) / 100;
}

export function toCents(amount: number | string | null | undefined): number {
  return Math.round(Number(amount ?? 0) * 100);
}

/** Metadata values must be strings; drop empty ones. */
export function metadata(m: Record<string, string | number | null | undefined>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(m)) if (v !== null && v !== undefined && v !== "") out[k] = String(v);
  return out;
}

export type Checkout = { id: string; purchase_url: string };

/**
 * A one-time checkout for an exact amount. The metadata is copied onto the
 * payment, so the webhook knows which race or purse it pays for.
 */
export function checkoutBody(o: {
  accountId: string;
  productId?: string | null;
  amountCents: number;
  currency: string;
  title: string;
  description?: string;
  meta: Record<string, string | number | null | undefined>;
  redirectUrl?: string | null;
}) {
  if (!Number.isInteger(o.amountCents) || o.amountCents < 50) throw new Error("checkout amount must be at least 50 cents");
  return {
    account_id: o.accountId,
    mode: "payment",
    metadata: metadata(o.meta),
    ...(o.redirectUrl ? { redirect_url: o.redirectUrl } : {}),
    variant: {
      title: o.title.slice(0, 60),
      ...(o.description ? { description: o.description.slice(0, 200) } : {}),
      billing_type: "one_time",
      initial_price: toAmount(o.amountCents),
      currency: o.currency.toLowerCase(),
      visibility: "hidden",
      ...(o.productId ? { product_id: o.productId } : {}),
    },
  };
}

export async function createCheckout(o: Omit<Parameters<typeof checkoutBody>[0], "accountId" | "productId" | "redirectUrl">): Promise<Checkout> {
  const accountId = Deno.env.get("WHOP_ACCOUNT_ID");
  if (!accountId) throw new Error("WHOP_ACCOUNT_ID is not set");
  const c = await whop<Checkout>("POST", "/checkout_configurations", checkoutBody({
    ...o,
    accountId,
    productId: Deno.env.get("WHOP_PRODUCT_ID") || null,
    redirectUrl: Deno.env.get("WHOP_REDIRECT_URL") || null,
  }));
  if (!c.purchase_url) throw new Error("Whop returned a checkout without a purchase_url");
  return c;
}

/** Refunds all of a payment, or `cents` of it. */
export function refundPayment(paymentId: string, cents?: number, meta: Record<string, string> = {}) {
  return whop<{ id: string }>("POST", `/payments/${paymentId}/refund`, {
    ...(cents !== undefined ? { partial_amount: toAmount(cents) } : {}),
    metadata: meta,
  });
}

export type Transfer = {
  id: string;
  status: "processing" | "succeeded" | "failed";
  failure_reason?: string | null;
  tracking_url?: string;
};

/**
 * Moves money from Steppie's Whop balance to a person's Whop balance. The
 * idempotence key makes a retry return the same transfer instead of paying twice.
 */
export function transferToUser(o: { whopUserId: string; cents: number; currency: string; key: string; note: string; meta: Record<string, string> }) {
  const accountId = Deno.env.get("WHOP_ACCOUNT_ID");
  if (!accountId) throw new Error("WHOP_ACCOUNT_ID is not set");
  return whop<Transfer>("POST", "/transfers", {
    type: "balance",
    amount: toAmount(o.cents),
    currency: o.currency.toLowerCase(),
    origin_id: accountId,
    destination_id: o.whopUserId,
    idempotence_key: o.key,
    notes: o.note.slice(0, 100),
    metadata: o.meta,
  });
}

// Webhooks ------------------------------------------------------------------------------
// Whop follows Standard Webhooks: HMAC-SHA256 over "{webhook-id}.{webhook-timestamp}.{body}",
// base64, sent as "v1,<sig>" (several may be space-separated during key rotation).
// The key is the UTF-8 bytes of the whole `ws_...` secret, as Whop's own SDK derives it.

const TOLERANCE_S = 300;

export class SignatureError extends Error {}

function b64(bytes: ArrayBuffer): string {
  let s = "";
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s);
}

function sameString(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function signStandard(keyBytes: Uint8Array<ArrayBuffer>, id: string, ts: string, raw: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${ts}.${raw}`));
  return b64(mac);
}

/** Checks a Standard Webhooks signature with raw key bytes; returns the parsed body. */
export async function verifyStandard(raw: string, headers: Headers, keyBytes: Uint8Array<ArrayBuffer>, nowMs = Date.now()) {
  const id = headers.get("webhook-id");
  const ts = headers.get("webhook-timestamp");
  const sigs = headers.get("webhook-signature");
  if (!id || !ts || !sigs) throw new SignatureError("missing webhook headers");
  const t = Number(ts);
  if (!Number.isFinite(t) || Math.abs(nowMs / 1000 - t) > TOLERANCE_S) throw new SignatureError("timestamp out of range");
  const expected = await signStandard(keyBytes, id, ts, raw);
  const ok = sigs.split(" ").some((part) => {
    const [version, sig] = part.split(",", 2);
    return version === "v1" && !!sig && sameString(sig, expected);
  });
  if (!ok) throw new SignatureError("bad signature");
  return { id, event: JSON.parse(raw) as WhopEvent };
}

export async function verifyWhopWebhook(raw: string, headers: Headers, secret: string, nowMs = Date.now()) {
  if (!secret) throw new SignatureError("WHOP_WEBHOOK_SECRET is not set");
  return await verifyStandard(raw, headers, new TextEncoder().encode(secret), nowMs);
}

export type WhopPayment = {
  id: string;
  status: string;
  substatus?: string;
  total?: number | string | null;
  subtotal?: number | string | null;
  currency?: string;
  metadata?: Record<string, string> | null;
  user?: { id: string } | null;
  refunded_amount?: number | string | null;
  checkout_configuration_id?: string | null;
};

export type WhopEvent = {
  id?: string;
  type: string;
  // deno-lint-ignore no-explicit-any
  data: any;
};
