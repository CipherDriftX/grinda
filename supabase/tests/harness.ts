// Runs every migration in supabase/migrations against an in-memory Postgres 17
// (PGlite), with small stand-ins for what Supabase provides: the auth schema,
// storage buckets and pg_cron. Lets the money SQL be tested without Docker.
import { PGlite } from "npm:@electric-sql/pglite@0.3.15";

const STUBS = `
create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean);
create schema cron;
create table cron.job (jobid serial primary key, jobname text unique, schedule text, command text);
create function cron.schedule(name text, sched text, cmd text) returns bigint language sql as $$
  insert into cron.job (jobname, schedule, command) values (name, sched, cmd)
  on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command returning jobid $$;
create function cron.unschedule(name text) returns boolean language sql as $$
  delete from cron.job where jobname = name returning true $$;
create schema net;
create function net.http_post(url text, headers jsonb default '{}', body jsonb default '{}') returns bigint language sql as $$ select 1::bigint $$;
create schema vault;
create table vault.decrypted_secrets (name text primary key, decrypted_secret text);
`;

export async function freshDb(): Promise<PGlite> {
  const db = new PGlite();
  await db.exec(STUBS);
  const dir = new URL("../migrations/", import.meta.url);
  const files = [...Deno.readDirSync(dir)].map((f) => f.name).filter((n) => n.endsWith(".sql")).sort();
  for (const name of files) {
    const sql = Deno.readTextFileSync(new URL(name, dir))
      .replace(/^\s*create extension[^;]*;/gim, "-- (extension provided by the harness)");
    try {
      await db.exec(sql);
    } catch (e) {
      throw new Error(`${name}: ${(e as Error).message}`);
    }
  }
  return db;
}

/** Makes a user with a profile and returns its id. */
export async function user(db: PGlite, name = "Sam Walker", birthYear = 1990): Promise<string> {
  const { rows } = await db.query<{ id: string }>("insert into auth.users default values returning id");
  const id = rows[0].id;
  await db.query("insert into public.profiles (id, display_name, birth_year) values ($1, $2, $3)", [id, name, birthYear]);
  return id;
}

export async function one<T>(db: PGlite, sql: string, params: unknown[] = []): Promise<T> {
  const { rows } = await db.query<T>(sql, params);
  return rows[0];
}
