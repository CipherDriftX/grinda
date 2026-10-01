-- Steppie: shields, comeback races, stake tables, weekly Grit leagues.
-- Design rule: nothing here changes whether money comes back. That depends only
-- on the steps walked, the grace days, and the shields the person chose to equip.

-- Rename the settlement job ------------------------------------------------------
select cron.unschedule('grinda-settle') where exists (select 1 from cron.job where jobname = 'grinda-settle');

select cron.schedule(
  'steppie-settle',
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

-- People ----------------------------------------------------------------------------
create type league as enum ('bronze', 'silver', 'gold', 'sapphire', 'diamond');

alter table public.profiles
  add column display_name text check (char_length(display_name) <= 40),
  add column shields int not null default 1 check (shields between 0 and 99),   -- one free Shield to start
  add column league league not null default 'bronze';

-- Shields bought in the App Store. One row per transaction makes grants idempotent.
create table public.shield_grants (
  transaction_id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null,
  quantity int not null check (quantity between 1 and 10),
  created_at timestamptz not null default now()
);
alter table public.shield_grants enable row level security;
create policy "own grants" on public.shield_grants for select using (auth.uid() = user_id);

-- Races -----------------------------------------------------------------------------
alter table public.races
  add column shields_equipped int not null default 0 check (shields_equipped between 0 and 2),
  add column shields_used int not null default 0 check (shields_used between 0 and 2),
  add column comeback_of uuid references public.races (id);

-- A missed race gets at most one comeback.
create unique index races_one_comeback on public.races (comeback_of) where comeback_of is not null and status <> 'cancelled';


-- Leagues ----------------------------------------------------------------------------
-- Grit: one point per 100 steps on race days, times the stake table's multiplier.
create function public.grit_multiplier(stake_cents int)
returns numeric language sql immutable as $$
  select case
    when stake_cents is null then 1.0
    when stake_cents < 1000 then 1.5
    when stake_cents < 2000 then 2.0
    when stake_cents < 5000 then 2.5
    when stake_cents < 10000 then 3.0
    else 4.0 end
$$;

create view public.week_grit with (security_invoker = false) as
  select r.user_id, round(sum(d.steps / 100.0 * public.grit_multiplier(r.stake_cents)))::int as grit
  from public.race_days d join public.races r on r.id = d.race_id
  where d.day >= date_trunc('week', now())::date and r.status in ('active', 'settling', 'won', 'lost')
  group by r.user_id;
revoke all on public.week_grit from public, anon, authenticated;

-- The caller's league table: up to 30 walkers in the same league, names shortened.
create function public.league_board()
returns table (rank int, name text, grit int, is_me boolean)
language sql stable security definer set search_path = public as $$
  with me as (select league from profiles where id = auth.uid()),
  board as (
    select p.id, coalesce(split_part(p.display_name, ' ', 1), 'Walker') as first, coalesce(g.grit, 0) as grit
    from profiles p left join week_grit g on g.user_id = p.id
    where p.league = (select league from me) and (g.grit > 0 or p.id = auth.uid())
    order by coalesce(g.grit, 0) desc limit 30
  )
  select (row_number() over (order by grit desc))::int, first, grit, id = auth.uid() from board
$$;
revoke all on function public.league_board() from public, anon;
grant execute on function public.league_board() to authenticated;

-- Monday rollover: top 7 with Grit move up, bottom 5 move down (never below bronze).
create function public.roll_leagues()
returns void language plpgsql security definer set search_path = public as $$
declare l league;
begin
  for l in select unnest(enum_range(null::league)) loop
    with ranked as (
      select p.id, coalesce(g.grit, 0) as grit,
             row_number() over (order by coalesce(g.grit, 0) desc) as up,
             row_number() over (order by coalesce(g.grit, 0) asc) as down
      from profiles p left join week_grit g on g.user_id = p.id where p.league = l
    )
    update profiles p set league = case
        when r.up <= 7 and r.grit > 0 and l <> 'diamond' then (enum_range(l, null))[2]
        when r.down <= 5 and l <> 'bronze' then (enum_range(null, l))[array_length(enum_range(null, l), 1) - 1]
        else p.league end
    from ranked r where r.id = p.id;
  end loop;
end $$;
revoke all on function public.roll_leagues() from public, anon, authenticated;

select cron.schedule('steppie-leagues', '55 23 * * 0', $$ select public.roll_leagues(); $$);

-- Public stats: comeback refunds count as money returned ------------------------------
create or replace function public.public_stats(cur text)
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
                          where kind in ('released', 'refunded', 'comeback') and currency = cur),
    'kept_cents',       (select coalesce(sum(amount_cents), 0) from ledger_entries
                          where kind = 'kept' and currency = cur)
                        - (select coalesce(sum(amount_cents), 0) from ledger_entries
                          where kind = 'comeback' and currency = cur),
    'currency',         cur,
    'weight_lost_kg_opt_in', (select coalesce(sum(weight_lost_kg), 0) from profiles where share_weight_in_stats)
  );
$$;
revoke all on function public.public_stats(text) from public, anon, authenticated;
