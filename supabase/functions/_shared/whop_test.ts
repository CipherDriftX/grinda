import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import {
  checkoutBody, createClaimLink, getTransfer, metadata, refundPayment, SignatureError, signStandard, toAmount, toCents, transferToUser,
  verifyStandard, verifyWhopWebhook, WhopError, whopBase,
} from "./whop.ts";

function decode(b64: string): Uint8Array<ArrayBuffer> {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// The published Standard Webhooks test vector (checked against Python's hmac).
const VECTOR = {
  key: decode("MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"),
  id: "msg_p5jXN8AQM9LWM0D4loKWxJek",
  ts: "1614265330",
  body: `{"test": 2432232314}`,
  sig: "g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=",
};

function headers(id: string, ts: string, sig: string) {
  return new Headers({ "webhook-id": id, "webhook-timestamp": ts, "webhook-signature": sig });
}

Deno.test("signs exactly like the Standard Webhooks reference", async () => {
  assertEquals(await signStandard(VECTOR.key, VECTOR.id, VECTOR.ts, VECTOR.body), VECTOR.sig);
});

Deno.test("accepts a good signature, also among rotated ones", async () => {
  const now = Number(VECTOR.ts) * 1000;
  const h = headers(VECTOR.id, VECTOR.ts, `v1,bm90LWl0 v1,${VECTOR.sig}`);
  const { event } = await verifyStandard(VECTOR.body, h, VECTOR.key, now);
  assertEquals((event as unknown as { test: number }).test, 2432232314);
});

Deno.test("rejects a changed body, a wrong version, and an old timestamp", async () => {
  const now = Number(VECTOR.ts) * 1000;
  await assertRejects(() => verifyStandard(VECTOR.body + " ", headers(VECTOR.id, VECTOR.ts, `v1,${VECTOR.sig}`), VECTOR.key, now), SignatureError);
  await assertRejects(() => verifyStandard(VECTOR.body, headers(VECTOR.id, VECTOR.ts, `v2,${VECTOR.sig}`), VECTOR.key, now), SignatureError);
  await assertRejects(() => verifyStandard(VECTOR.body, headers(VECTOR.id, VECTOR.ts, `v1,${VECTOR.sig}`), VECTOR.key, now + 301_000), SignatureError);
  await assertRejects(() => verifyStandard(VECTOR.body, new Headers(), VECTOR.key, now), SignatureError);
});

Deno.test("a Whop secret is used as UTF-8 bytes, ws_ prefix and all", async () => {
  // Expected value computed independently: python hmac(b"ws_test_secret_123", msg, sha256), base64.
  const body = `{"type":"payment.succeeded","data":{"id":"pay_1"}}`;
  const h = headers("msg_1", "1700000000", "v1,EBL/b+YSLJbvtPTmql19QncY6szo3p/SWZpGTemeVpo=");
  const { id, event } = await verifyWhopWebhook(body, h, "ws_test_secret_123", 1700000000_000);
  assertEquals(id, "msg_1");
  assertEquals(event.type, "payment.succeeded");
  await assertRejects(() => verifyWhopWebhook(body, h, "", 1700000000_000), SignatureError);
});

Deno.test("checkout body: exact amount, hidden one-time variant, string metadata", () => {
  const b = checkoutBody({
    accountId: "biz_1", productId: "prod_1", amountCents: 2199, currency: "USD", title: "Lion's Share entry",
    meta: { kind: "purse_entry", race_id: "r1", purse_id: null, bib: 4821 }, redirectUrl: "https://example.com/paid",
  });
  assertEquals(b.variant.initial_price, 21.99);
  assertEquals(b.variant.currency, "usd");
  assertEquals(b.variant.billing_type, "one_time");
  assertEquals(b.variant.visibility, "hidden");
  assertEquals(b.metadata, { kind: "purse_entry", race_id: "r1", bib: "4821" });
  assertEquals(b.redirect_url, "https://example.com/paid");
  assertThrows(() => checkoutBody({ accountId: "biz_1", amountCents: 49, currency: "USD", title: "x", meta: {} }));
});

Deno.test("money converts between cents and Whop decimals without drift", () => {
  assertEquals(toAmount(1), 0.01);
  assertEquals(toAmount(2199), 21.99);
  assertEquals(toCents("21.99"), 2199);
  assertEquals(toCents(0.29), 29);
  assertEquals(toCents(null), 0);
  assertEquals(toCents({ amount: "21.99", currency: "usd", decimals: 2 }), 2199);
  assertEquals(metadata({ a: 1, b: "", c: undefined }), { a: "1" });
});

Deno.test("sandbox unless production is named", () => {
  assertEquals(whopBase(undefined), "https://sandbox-api.whop.com/api/v1");
  assertEquals(whopBase("prod"), "https://sandbox-api.whop.com/api/v1");
  assertEquals(whopBase("production"), "https://api.whop.com/api/v1");
});

Deno.test("API calls: bearer key, pinned version, sandbox base, exact bodies", async () => {
  const calls: { url: string; init: RequestInit }[] = [];
  const realFetch = globalThis.fetch;
  Deno.env.set("WHOP_API_KEY", "key_test");
  Deno.env.set("WHOP_ACCOUNT_ID", "biz_test");
  Deno.env.delete("WHOP_ENVIRONMENT");
  globalThis.fetch = ((url: string, init: RequestInit) => {
    calls.push({ url, init });
    return Promise.resolve(new Response(JSON.stringify({ id: "x_1", status: "processing", claim_url: "https://whop.com/c/1" }), { status: 200 }));
  }) as typeof fetch;
  try {
    await transferToUser({ whopUserId: "user_9", cents: 2150, currency: "USD", key: "co-1", note: "Steppie cash-out", meta: { cashout_id: "co-1" } });
    await createClaimLink(500, new Date("2026-11-19T00:00:00Z"));
    await refundPayment("pay_7", 1000, { reason: "won" });
    await refundPayment("pay_8");
  } finally {
    globalThis.fetch = realFetch;
  }
  const h = calls[0].init.headers as Record<string, string>;
  assertEquals(h.Authorization, "Bearer key_test");
  assertEquals(h["Api-Version-Date"], "2026-11-10-1");
  assertEquals(calls[0].url, "https://sandbox-api.whop.com/api/v1/transfers");
  assertEquals(JSON.parse(calls[0].init.body as string), {
    type: "balance", amount: 21.5, currency: "usd", origin_id: "biz_test", destination_id: "user_9",
    idempotence_key: "co-1", notes: "Steppie cash-out", metadata: { cashout_id: "co-1" },
  });
  assertEquals(JSON.parse(calls[1].init.body as string), {
    type: "claim_link", amount: 5, origin_id: "biz_test", expires_at: "2026-11-19T00:00:00.000Z", redeemable_count: 1,
  });
  assertEquals(calls[2].url, "https://sandbox-api.whop.com/api/v1/payments/pay_7/refund");
  assertEquals(JSON.parse(calls[2].init.body as string), { partial_amount: 10, metadata: { reason: "won" } });
  assertEquals(JSON.parse(calls[3].init.body as string), { metadata: {} });
});

Deno.test("a Whop error keeps its status and body", async () => {
  const realFetch = globalThis.fetch;
  Deno.env.set("WHOP_API_KEY", "key_test");
  globalThis.fetch = (() => Promise.resolve(new Response('{"error":"insufficient balance"}', { status: 422 }))) as typeof fetch;
  try {
    const e = await assertRejects(() => getTransfer("tr_1"), WhopError);
    assertEquals([e.status, e.body], [422, '{"error":"insufficient balance"}']);
  } finally {
    globalThis.fetch = realFetch;
  }
});
