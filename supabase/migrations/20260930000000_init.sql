-- Grinda schema: races, day records, money ledger, public stats.
-- All writes happen in Edge Functions with the service role; clients only read their own rows.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- People ---------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  birth_year int check (birth_year between 1900 and 2100),
  stripe_customer_id text unique,
  weight_lost_kg numeric(5,1),           -- opt-in, self-reported, for public stats
  share_weight_in_stats boolean not null default false
);

-- Races ----------------------------------------------------------------------

create type race_status as enum ('pendingPayment', 'active', 'settling', 'won', 'lost', 'underReview', 'cancelled');
create type stake_state as enum ('none', 'held', 'charged', 'released', 'refunded', 'kept');

create table public.races (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  template_id text not null,
  name text not null,
  daily_goal int not null check (daily_goal between 1000 and 50000),
  grace_allowed int not null default 0,
  timezone text not null,
  start_date date not null,
  end_date date not null,
  settles_at timestamptz not null,            -- end of last day (local) + 3 h
  stake_cents int check (stake_cents between 500 and 50000),
  currency text check (currency in ('EUR', 'USD')),
  capture_method text check (capture_method in ('manual', 'automatic')),
  stripe_payment_intent text unique,
  status race_status not null default 'pendingPayment',
  stake_state stake_state not null default 'none',
  bib_number int not null,
  created_at timestamptz not null default now(),
  settled_at timestamptz
);
create index races_user_idx on public.races (user_id, created_at desc);
create index races_due_idx on public.races (settles_at) where status = 'active';

create table public.race_days (
  race_id uuid not null references public.races (id) on delete cascade,
  day date not null,
  goal int not null,
  steps int not null default 0,
  hourly int[] not null default '{}',
  flagged boolean not null default false,      -- implausible data: human review, never auto-fail
  submitted_at timestamptz,
  primary key (race_id, day)
);

-- Money ----------------------------------------------------------------------

create type ledger_kind as enum ('held', 'charged', 'released', 'refunded', 'kept');

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  race_id uuid not null references public.races (id) on delete cascade,
  kind ledger_kind not null,
  amount_cents int not null,
  currency text not null,
  stripe_ref text not null,
  created_at timestamptz not null default now(),
  unique (race_id, kind)                       -- idempotent webhook handling
);
create index ledger_user_idx on public.ledger_entries (user_id, created_at desc);

create view public.ledger_view with (security_invoker = true) as
  select l.id, l.created_at, r.name as race_name, l.kind, l.amount_cents, l.currency, l.stripe_ref, l.user_id
  from public.ledger_entries l join public.races r on r.id = l.race_id;

-- Row Level Security -----------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.races enable row level security;
alter table public.race_days enable row level security;
alter table public.ledger_entries enable row level security;

create policy "own profile" on public.profiles for select using (auth.uid() = id);
create policy "own races" on public.races for select using (auth.uid() = user_id);
create policy "own race days" on public.race_days for select
  using (exists (select 1 from public.races r where r.id = race_id and r.user_id = auth.uid()));
create policy "own ledger" on public.ledger_entries for select using (auth.uid() = user_id);

-- Public statistics (for the app, the website, X and Discord) ------------------
-- Aggregates only, per currency for money. No row-level data ever leaves through this function.

create function public.public_stats(cur text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'walkers',          (select count(distinct user_id) from races where status <> 'cancelled'),
    'steps_walked',     (select coalesce(sum(d.steps), 0) from race_days d join races r on r.id = d.race_id
                          where r.status <> 'cancelled'),
    'km_walked',        (select round(coalesce(sum(d.steps), 0) * 0.00076, 1) from race_days d
                          join races r on r.id = d.race_id where r.status <> 'cancelled'),
    'races_finished',   (select count(*) from races where status = 'won'),
    'completion_rate',  (select coalesce(round(count(*) filter (where status = 'won')::numeric
                          / nullif(count(*) filter (where status in ('won', 'lost')), 0), 4), 0) from races),
    'returned_cents',   (select coalesce(sum(amount_cents), 0) from ledger_entries
                          where kind in ('released', 'refunded') and currency = cur),
    'kept_cents',       (select coalesce(sum(amount_cents), 0) from ledger_entries
                          where kind = 'kept' and currency = cur),
    'currency',         cur,
    'weight_lost_kg_opt_in', (select coalesce(sum(weight_lost_kg), 0) from profiles where share_weight_in_stats)
  );
$$;

revoke all on function public.public_stats(text) from public, anon, authenticated;

-- Settlement schedule ------------------------------------------------------------
-- Calls the settle function every 15 minutes. Set these once per project:
--   select vault.create_secret('https://<project>.supabase.co', 'project_url');
--   select vault.create_secret('<CRON_SECRET>', 'cron_secret');

select cron.schedule(
  'grinda-settle',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/settle',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
