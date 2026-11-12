import { assertEquals } from "jsr:@std/assert@1";
import { freshDb, one, user } from "./harness.ts";

Deno.test("every migration applies on a fresh database", async () => {
  const db = await freshDb();
  const jobs = await db.query<{ jobname: string }>("select jobname from cron.job order by jobname");
  assertEquals(jobs.rows.map((r) => r.jobname).includes("steppie-settle"), true);
  await db.close();
});

Deno.test("a new profile gets an invite code and empty balances", async () => {
  const db = await freshDb();
  const id = await user(db, "Sam Walker");
  const p = await one<{ invite_code: string; vault_cents: number; credit_cents: number }>(db,
    "select invite_code, vault_cents, credit_cents from profiles where id = $1", [id]);
  assertEquals(p.invite_code.startsWith("SAM"), true);
  assertEquals([p.vault_cents, p.credit_cents], [0, 0]);
  await db.close();
});

Deno.test("a referral bonus pays once, even when asked twice", async () => {
  const db = await freshDb();
  const inviter = await user(db, "Ava Stone");
  const invitee = await user(db, "Ben Ray");
  await db.query("insert into referrals (invitee_id, inviter_id, code) values ($1, $2, 'AVA-1234')", [invitee, inviter]);
  const first = await one<{ pay_referral: boolean }>(db, "select pay_referral($1, 500, 'USD')", [invitee]);
  const second = await one<{ pay_referral: boolean }>(db, "select pay_referral($1, 500, 'USD')", [invitee]);
  assertEquals([first.pay_referral, second.pay_referral], [true, false]);
  const p = await one<{ vault_cents: number; invites_paid: number }>(db, "select vault_cents, invites_paid from profiles where id = $1", [inviter]);
  assertEquals([p.vault_cents, p.invites_paid], [500, 1]);
  const lines = await one<{ n: number }>(db, "select count(*)::int as n from ledger_entries where user_id = $1 and kind = 'referral'", [inviter]);
  assertEquals(lines.n, 1);
  await db.close();
});

Deno.test("ledger_view shows the payment reference as ref", async () => {
  const db = await freshDb();
  const id = await user(db);
  await db.query(`insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
    values (null, $1, 'credit', 500, 'USD', 'inv_X', 'Code X')`, [id]);
  const row = await one<{ ref: string; race_name: string }>(db, "select ref, race_name from ledger_view where user_id = $1", [id]);
  assertEquals([row.ref, row.race_name], ["inv_X", "Code X"]);
  await db.close();
});

Deno.test("no stored function or view still names a Stripe column", async () => {
  const db = await freshDb();
  const fns = await db.query(`select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosrc ~* 'stripe|capture_method'`);
  const views = await db.query(`select viewname from pg_views where schemaname = 'public' and definition ~* 'stripe'`);
  assertEquals([fns.rows, views.rows], [[], []]);
  await db.close();
});
