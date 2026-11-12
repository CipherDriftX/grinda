// The money functions, run on a real Postgres (PGlite) with every migration applied.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { PGlite } from "npm:@electric-sql/pglite@0.3.15";
import { freshDb, one, user } from "./harness.ts";

const PURSE = "lions-share-test-usd";

async function purse(db: PGlite, cap: number | null = null, id = PURSE) {
  await db.query(`insert into purses (id, name, kind, daily_goal, days, entry_cents, currency, starts_on, cap)
    values ($1, 'Lion''s Share', 'house', 10000, 3, 2000, 'USD', '2026-11-16', $2)`, [id, cap]);
}

async function fund(db: PGlite, uid: string, vault: number, credit: number, shields = 1) {
  await db.query("update profiles set vault_cents = $2, credit_cents = $3, shields = $4 where id = $1", [uid, vault, credit, shields]);
}

function entry(o: Record<string, unknown> = {}) {
  return {
    template_id: `purse:${PURSE}`, name: "Lion's Share", daily_goal: 10000, grace_allowed: 0, timezone: "America/New_York",
    days: ["2026-11-16", "2026-11-17", "2026-11-18"], settles_at: "2026-11-20T05:00:00Z", stake_cents: 2000,
    currency: "USD", bib_number: 4821, shields: 0, purse_id: PURSE, fee_cents: 130, host_fee_cents: 0,
    from_credit: 0, from_vault: 2130, from_card: 0, ...o,
  };
}

function stake(o: Record<string, unknown> = {}) {
  return entry({ template_id: "sprint-5", name: "5-Day Sprint", purse_id: null, fee_cents: 0, stake_cents: 1000, from_vault: 0, from_card: 1000, ...o });
}

async function open(db: PGlite, uid: string, spec: Record<string, unknown>, maxRunning = 1) {
  return (await one<{ id: string }>(db, "select open_race($1, $2, $3, 500) as id", [uid, JSON.stringify(spec), maxRunning])).id;
}

async function balances(db: PGlite, uid: string) {
  const p = await one<{ vault_cents: number; credit_cents: number; shields: number }>(db,
    "select vault_cents, credit_cents, shields from profiles where id = $1", [uid]);
  return [p.vault_cents, p.credit_cents, p.shields];
}

async function race(db: PGlite, id: string) {
  return await one<{ status: string; stake_state: string; card_cents: number; card_refunded_cents: number; payment_ref: string | null }>(db,
    "select status, stake_state, card_cents, card_refunded_cents, payment_ref from races where id = $1", [id]);
}

async function ledger(db: PGlite, uid: string) {
  const r = await db.query<{ kind: string; amount_cents: number }>(
    "select kind::text, amount_cents from ledger_entries where user_id = $1 order by kind", [uid]);
  return r.rows.map((x) => `${x.kind}:${x.amount_cents}`);
}

Deno.test("a purse entry paid from balances is live at once, with its days and ledger", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await purse(db);
  await fund(db, uid, 2000, 500, 2);
  const id = await open(db, uid, entry({ from_credit: 500, from_vault: 1630, shields: 1 }));
  assertEquals((await race(db, id)).status, "active");
  assertEquals(await balances(db, uid), [370, 0, 1]);
  assertEquals((await one<{ n: number }>(db, "select count(*)::int as n from race_days where race_id = $1", [id])).n, 3);
  assertEquals(await ledger(db, uid), ["entry:2000", "fee:130"]);
  await db.close();
});

Deno.test("money that doesn't add up, or more than the balance, opens nothing", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await purse(db);
  await fund(db, uid, 1000, 0);
  await assertRejects(() => open(db, uid, entry({ from_vault: 2000 })), Error, "bad_split");            // 2000 != 2130
  await assertRejects(() => open(db, uid, entry({ from_vault: 2100, from_card: 30 })), Error, "bad_split"); // card under 50
  await assertRejects(() => open(db, uid, entry()), Error, "vault_cents");                              // overdraft
  await assertRejects(() => open(db, uid, stake({ from_credit: 1000, from_card: 0 })), Error, "bad_split"); // credit is purse-only
  await open(db, uid, stake({ stake_cents: 500, from_card: 500 }), 5);                                    // pins USD
  await assertRejects(() => open(db, uid, stake({ currency: "EUR" }), 5), Error, "wrong_currency");
  assertEquals((await one<{ n: number }>(db, "select count(*)::int as n from races")).n, 1);
  assertEquals(await balances(db, uid), [1000, 0, 1]);
  await db.close();
});

Deno.test("the running limit, the purse cap and one entry per purse hold", async () => {
  const db = await freshDb();
  const a = await user(db, "Ava Stone");
  const b = await user(db, "Ben Ray");
  const c = await user(db, "Cy Moss");
  await purse(db, 2);
  for (const u of [a, b, c]) await fund(db, u, 10000, 0);
  await open(db, a, entry());
  await assertRejects(() => open(db, a, stake({ from_card: 0, from_vault: 1000 })), Error, "too_many_running");
  await open(db, a, stake({ from_card: 0, from_vault: 1000 }), 5);                                    // Pro: up to five
  await assertRejects(() => open(db, a, entry(), 5), Error, "races_one_entry_per_purse");
  await open(db, b, entry());
  await assertRejects(() => open(db, c, entry()), Error, "purse_full");
  await db.close();
});

Deno.test("a card entry waits, then the payment makes it live exactly once", async () => {
  const db = await freshDb();
  const inviter = await user(db, "Ava Stone");
  const uid = await user(db, "Ben Ray");
  await db.query("insert into referrals (invitee_id, inviter_id, code) values ($1, $2, 'AVA-1')", [uid, inviter]);
  await purse(db);
  await fund(db, uid, 1000, 500);
  // 2000 entry + 199 card fee = 2199; 500 credit + 1000 Vault + 699 card.
  const id = await open(db, uid, entry({ fee_cents: 199, from_credit: 500, from_vault: 1000, from_card: 699 }));
  assertEquals((await race(db, id)).status, "pendingPayment");
  assertEquals(await ledger(db, uid), []);

  const confirm = (pay: string, cents: number, cur = "usd") =>
    one<{ s: string }>(db, "select confirm_payment($1, $2, $3, $4, 'user_abc', 500) as s", [id, pay, cents, cur]);
  assertEquals((await confirm("pay_1", 699)).s, "active");
  assertEquals((await confirm("pay_1", 699)).s, "already");
  assertEquals((await confirm("pay_2", 699)).s, "refund");          // a second payment for the same race
  const r = await race(db, id);
  assertEquals([r.status, r.card_cents, r.payment_ref], ["active", 699, "pay_1"]);
  assertEquals(await ledger(db, uid), ["entry:2000", "fee:199"]);
  assertEquals((await one<{ w: string }>(db, "select whop_user_id as w from profiles where id = $1", [uid])).w, "user_abc");
  assertEquals((await balances(db, inviter))[0], 500);                // referral paid on the first paid entry
  await db.close();
});

Deno.test("a short or wrong-currency payment calls the race off and gets refunded", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await purse(db);
  await fund(db, uid, 1000, 500, 2);
  const id = await open(db, uid, entry({ fee_cents: 199, from_credit: 500, from_vault: 1000, from_card: 699, shields: 2 }));
  assertEquals(await balances(db, uid), [0, 0, 0]);
  assertEquals((await one<{ s: string }>(db, "select confirm_payment($1, 'pay_1', 600, 'usd', null, 500) as s", [id])).s, "refund");
  assertEquals((await race(db, id)).status, "cancelled");
  assertEquals(await balances(db, uid), [1000, 500, 2]);              // credit stays credit, Shields come back
  assertEquals((await one<{ s: string }>(db, "select confirm_payment($1, 'pay_2', 699, 'eur', null, 500) as s", [id])).s, "refund");
  assertEquals((await one<{ s: string }>(db, "select confirm_payment(gen_random_uuid(), 'pay_3', 699, 'usd', null, 500) as s")).s, "unknown");
  await db.close();
});

Deno.test("calling off a pending race twice gives back once", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await purse(db);
  await fund(db, uid, 1000, 0);
  const id = await open(db, uid, entry({ fee_cents: 199, from_vault: 1000, from_card: 1199 }));
  const c1 = await one<{ ok: boolean }>(db, "select cancel_pending($1) as ok", [id]);
  const c2 = await one<{ ok: boolean }>(db, "select cancel_pending($1) as ok", [id]);
  assertEquals([c1.ok, c2.ok], [true, false]);
  assertEquals(await balances(db, uid), [1000, 0, 1]);
  await open(db, uid, entry({ fee_cents: 199, from_vault: 1000, from_card: 1199 }));   // can join again after
  await db.close();
});

Deno.test("host purse: Vault first, card for the rest, listed once paid, called off cleanly", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await fund(db, uid, 1000, 0);
  const spec = (id: string, o: Record<string, unknown> = {}) => JSON.stringify({
    id, name: "Morning Crew", tagline: "Hosted by Sam.", kind: "host", art: "megaphone", daily_goal: 10000, days: 7,
    entry_cents: 1000, currency: "USD", starts_on: "2026-11-20", code: `MORN-${id.slice(-2)}`, cap: null,
    fee_cents: 2500, from_vault: 1000, from_card: 1500, ...o,
  });
  await one(db, "select open_host_purse($1, $2, 3)", [uid, spec("member-a1")]);
  assertEquals((await one<{ listed: boolean }>(db, "select listed from purses where id = 'member-a1'")).listed, false);
  assertEquals((await balances(db, uid))[0], 0);
  const ok = await one<{ s: string }>(db, "select confirm_host_payment('member-a1', 'pay_h', 1500, 'usd', 'user_h') as s");
  assertEquals(ok.s, "listed");
  assertEquals((await one<{ listed: boolean }>(db, "select listed from purses where id = 'member-a1'")).listed, true);
  assertEquals(await ledger(db, uid), ["fee:2500"]);

  await fund(db, uid, 1000, 0);
  await one(db, "select open_host_purse($1, $2, 3)", [uid, spec("member-b2")]);
  assertEquals((await one<{ ok: boolean }>(db, "select cancel_host_purse('member-b2') as ok")).ok, true);
  assertEquals((await balances(db, uid))[0], 1000);
  assertEquals((await one<{ n: number }>(db, "select count(*)::int as n from purses where id = 'member-b2'")).n, 0);
  assertEquals((await one<{ s: string }>(db, "select confirm_host_payment('member-b2', 'pay_x', 1500, 'usd', null) as s")).s, "unknown");

  // Pro's free purse: once a month.
  await one(db, "select open_host_purse($1, $2, 3)", [uid, spec("member-c3", { fee_cents: 0, from_vault: 0, from_card: 0, free_month: "2026-11-01" })]);
  await assertRejects(() => one(db, "select open_host_purse($1, $2, 3)", [uid, spec("member-d4", { fee_cents: 0, from_vault: 0, from_card: 0, free_month: "2026-11-01" })]), Error, "free_month_used");
  await assertRejects(() => one(db, "select open_host_purse($1, $2, 2)", [uid, spec("member-e5", { from_vault: 0, from_card: 2500 })]), Error, "too_many_hosted");
  await db.close();
});

Deno.test("solo stake: a finish returns the card part to the card and the rest to the Vault", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await fund(db, uid, 400, 0, 2);
  const id = await open(db, uid, stake({ from_vault: 400, from_card: 600, shields: 2 }));
  await one(db, "select confirm_payment($1, 'pay_s', 600, 'USD', null, 500)", [id]);
  await assertRejects(() => one(db, "select settle_race($1, true, 1, 700, 0)", [id]), Error, "bad_refund");   // more than the card paid
  assertEquals((await one<{ s: string }>(db, "select settle_race($1, true, 1, 600, 0) as s", [id])).s, "won");
  assertEquals((await one<{ s: string }>(db, "select settle_race($1, true, 1, 600, 0) as s", [id])).s, "already");
  const r = await race(db, id);
  assertEquals([r.status, r.stake_state, r.card_refunded_cents], ["won", "returned", 600]);
  assertEquals(await balances(db, uid), [400, 0, 1]);                // 400 back to the Vault, one Shield back
  assertEquals(await ledger(db, uid), ["charged:1000", "refunded:600", "returned:400"]);
  await db.close();
});

Deno.test("solo stake: a miss keeps the stake; a won comeback returns half of it", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await fund(db, uid, 0, 0, 0);
  const lostId = await open(db, uid, stake({ stake_cents: 2000, from_card: 2000 }));
  await one(db, "select confirm_payment($1, 'pay_l', 2000, 'USD', null, 500)", [lostId]);
  assertEquals((await one<{ s: string }>(db, "select settle_race($1, false, 0) as s", [lostId])).s, "lost");
  assertEquals((await race(db, lostId)).stake_state, "kept");

  const cb = await open(db, uid, stake({ template_id: "comeback", stake_cents: 2000, from_card: 2000, comeback_of: lostId }));
  await one(db, "select confirm_payment($1, 'pay_c', 2000, 'USD', null, 500)", [cb]);
  // Comeback stake back to its card; 600 of the 1000 half back to the old card, 400 to the Vault.
  await one(db, "select settle_race($1, true, 0, 2000, 600)", [cb]);
  assertEquals((await race(db, cb)).stake_state, "refunded");
  assertEquals((await race(db, lostId)).card_refunded_cents, 600);
  assertEquals((await balances(db, uid))[0], 400);
  assertEquals(await ledger(db, uid), ["charged:2000", "charged:2000", "comeback:1000", "kept:2000", "refunded:2000"]);
  await db.close();
});

Deno.test("purse entries only get their result from settle_race; Shields come back", async () => {
  const db = await freshDb();
  const uid = await user(db);
  await purse(db);
  await fund(db, uid, 2130, 0, 2);
  const id = await open(db, uid, entry({ shields: 2 }));
  await one(db, "select settle_race($1, true, 1)", [id]);
  const r = await race(db, id);
  assertEquals([r.status, r.stake_state], ["won", "charged"]);
  assertEquals(await balances(db, uid), [0, 0, 1]);
  await db.close();
});
