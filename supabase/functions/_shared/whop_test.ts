import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import { checkoutBody, metadata, SignatureError, signStandard, toAmount, toCents, verifyStandard, verifyWhopWebhook, whopBase } from "./whop.ts";

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
  assertEquals(metadata({ a: 1, b: "", c: undefined }), { a: "1" });
});

Deno.test("sandbox unless production is named", () => {
  assertEquals(whopBase(undefined), "https://sandbox-api.whop.com/api/v1");
  assertEquals(whopBase("prod"), "https://sandbox-api.whop.com/api/v1");
  assertEquals(whopBase("production"), "https://api.whop.com/api/v1");
});
