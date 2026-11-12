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
