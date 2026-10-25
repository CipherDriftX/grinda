-- Purses: group races where everyone pays the same entry into one purse and
-- every finisher splits all of it. Steppie earns only the fee charged on top
-- ($0.50 + 4%, none for Pro). Hosts of public purses earn 5% on top as well.
-- Also: the Vault (winnings you can cash out), entry credit, invite codes,
-- sync disputes, Paid to Post, and the bench (accounts removed for fake steps).

-- People ------------------------------------------------------------------------------
alter table public.profiles
  add column vault_cents int not null default 0 check (vault_cents >= 0),     -- cash-outable winnings
  add column credit_cents int not null default 0 check (credit_cents >= 0),   -- entry-only credit
  add column invite_code text unique,
  add column invited_by text,
  add column invites_paid int not null default 0,
  add column is_pro boolean not null default false,       -- mirrored from App Store notifications
  add column host_free_month date;                        -- month the free Pro host purse was used

-- Short codes from the name: SAM-4821. Random digits, retried until unique.
create function public.make_invite_code(name text)
returns text language plpgsql volatile set search_path = public as $$
declare head text; c text;
begin
  head := left(upper(regexp_replace(coalesce(name, ''), '[^A-Za-z]', '', 'g')), 5);
  if head = '' then head := 'LION'; end if;
  loop
    c := head || '-' || (1000 + floor(random() * 9000))::int;
    exit when not exists (select 1 from profiles where invite_code = c);
  end loop;
  return c;
end $$;

create function public.profiles_invite_code()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.invite_code is null then new.invite_code := make_invite_code(new.display_name); end if;
  return new;
end $$;

create trigger profiles_invite_code before insert or update on public.profiles
  for each row execute function public.profiles_invite_code();

update public.profiles set invite_code = make_invite_code(display_name) where invite_code is null;

-- Balances only move through this, so two requests can't both spend the same cent.
-- The check constraints above make an overdraft fail the whole call.
create function public.adjust_balance(uid uuid, vault_delta int, credit_delta int)
returns table (vault_cents int, credit_cents int)
language sql volatile security definer set search_path = public as $$
  update profiles p set vault_cents = p.vault_cents + vault_delta, credit_cents = p.credit_cents + credit_delta
  where p.id = uid returning p.vault_cents, p.credit_cents
$$;
revoke all on function public.adjust_balance(uuid, int, int) from public, anon, authenticated;

-- Purses ------------------------------------------------------------------------------
create type purse_kind as enum ('house', 'host', 'crew');

create table public.purses (
  id text primary key,                                   -- 'lions-share-2026-44'
  name text not null check (char_length(name) between 3 and 40),
  tagline text not null default '',
  kind purse_kind not null,
  art text not null default 'lion',
  daily_goal int not null check (daily_goal between 1000 and 50000),
  days int not null check (days between 1 and 30),
  window_start int check (window_start between 0 and 23), -- steps only count inside [start, end)
  window_end int check (window_end between 1 and 24),
  entry_cents int not null check (entry_cents between 500 and 50000),
  currency text not null check (currency in ('EUR', 'USD')),
  starts_on date not null,                               -- each walker's own local calendar days
  sponsor_cents int not null default 0 check (sponsor_cents >= 0),
  host_id uuid references auth.users (id) on delete set null,
  code text unique,
  cap int check (cap between 2 and 100000),
  pro_only boolean not null default false,
  listed boolean not null default true,                  -- false until a public host fee is paid
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  check ((window_start is null) = (window_end is null)),
  check (window_end is null or window_end > window_start)
);
alter table public.purses enable row level security;      -- read through purse_board only

alter table public.races
  add column purse_id text references public.purses (id),
  add column fee_cents int not null default 0,
  add column host_fee_cents int not null default 0,
  add column paid_from_balance_cents int not null default 0, -- returned if the card part fails
  add column payout_cents int,
  add column finishers int,
  add column benched boolean not null default false;         -- removed for fake steps
create unique index races_one_entry_per_purse on public.races (purse_id, user_id)
  where purse_id is not null and status <> 'cancelled';
create index races_purse_idx on public.races (purse_id) where purse_id is not null;

alter table public.race_days
  add column late boolean not null default false,       -- reached the goal from a sync after the day closed
  add column disputed boolean not null default false;   -- a Health screenshot is waiting for a person

-- Money lines without a race (cash-outs, credit, referral bonuses) ----------------------
alter table public.ledger_entries alter column race_id drop not null;
alter table public.ledger_entries add column label text;
create unique index ledger_once_without_race on public.ledger_entries (user_id, kind, stripe_ref) where race_id is null;

create or replace view public.ledger_view with (security_invoker = true) as
  select l.id, l.created_at, coalesce(r.name, l.label, '') as race_name, l.kind, l.amount_cents, l.currency, l.stripe_ref, l.user_id
  from public.ledger_entries l left join public.races r on r.id = l.race_id;

-- The board ------------------------------------------------------------------------------
-- Everything the app's Purse model needs, in its field order. Crew purses are
-- visible only to their host and entrants (others find them by code).
create function public.purse_visible(p public.purses)
returns boolean language sql stable security definer set search_path = public as $$
  select p.listed and (p.kind <> 'crew' or p.host_id = auth.uid()
    or exists (select 1 from races r where r.purse_id = p.id and r.user_id = auth.uid() and r.status <> 'cancelled'))
$$;

create view public.purse_entry_state with (security_invoker = false) as
  select r.purse_id, r.id as race_id, r.user_id, r.status, r.benched, r.daily_goal, r.timezone,
    (select count(*) from race_days d where d.race_id = r.id
       and d.day < (now() at time zone r.timezone)::date and d.steps < d.goal and not d.disputed) as missed,
    r.shields_equipped,
    coalesce((select d.steps from race_days d where d.race_id = r.id and d.day = (now() at time zone r.timezone)::date), 0) as today_steps,
    extract(hour from now() at time zone r.timezone) as local_hour
  from races r
  where r.purse_id is not null and r.status in ('active', 'settling', 'won', 'lost', 'underReview');
revoke all on public.purse_entry_state from public, anon, authenticated;

create view public.purse_board with (security_invoker = false) as
  with agg as (
    select e.purse_id,
      count(*)::int as entrants,
      count(*) filter (where not e.benched and e.status <> 'lost' and e.missed <= e.shields_equipped)::int as still_in,
      count(*) filter (where not e.benched and e.status <> 'lost' and e.missed <= e.shields_equipped
        and e.today_steps >= e.daily_goal * least(1.0, e.local_hour / 20.0))::int as on_pace,
      count(*) filter (where e.benched)::int as benched
    from purse_entry_state e group by e.purse_id
  ),
  late as (
    select r.purse_id, count(*)::int as n
    from race_days d join races r on r.id = d.race_id
    where r.purse_id is not null and d.late group by r.purse_id
  )
  select p.id, p.name, p.tagline, p.kind, p.art, p.daily_goal, p.days,
    case when p.window_start is null then null
         else jsonb_build_object('start_hour', p.window_start, 'end_hour', p.window_end) end as "window",
    p.entry_cents / 100 as entry_units, p.currency,
    p.starts_on::timestamp at time zone 'UTC' as starts_at,
    coalesce(a.entrants, 0) as entrants, coalesce(a.still_in, 0) as still_in, coalesce(a.on_pace, 0) as on_pace,
    p.sponsor_cents,
    (select split_part(h.display_name, ' ', 1) from profiles h where h.id = p.host_id) as host_name,
    case when p.kind = 'house' then null else p.code end as code,
    p.cap, p.pro_only, coalesce(a.benched, 0) as benched, coalesce(l.n, 0) as late_syncs_back
  from purses p
  left join agg a on a.purse_id = p.id
  left join late l on l.purse_id = p.id
  where public.purse_visible(p)
    and p.starts_on + p.days > (now() - interval '14 days')::date;
grant select on public.purse_board to anon, authenticated;

-- A purse by its code (crew purses you've been sent). purse_board hides crew
-- purses from strangers, so this looks them up directly. Returns one object or null.
create function public.purse_by_code(code text)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'tagline', p.tagline, 'kind', p.kind, 'art', p.art,
    'daily_goal', p.daily_goal, 'days', p.days,
    'window', case when p.window_start is null then null
                   else jsonb_build_object('start_hour', p.window_start, 'end_hour', p.window_end) end,
    'entry_units', p.entry_cents / 100, 'currency', p.currency,
    'starts_at', to_char(p.starts_on, 'YYYY-MM-DD') || 'T00:00:00Z',
    'entrants', (select count(*) from races r where r.purse_id = p.id and r.status in ('active', 'settling', 'won', 'lost', 'underReview')),
    'still_in', 0, 'on_pace', 0, 'sponsor_cents', p.sponsor_cents,
    'host_name', (select split_part(h.display_name, ' ', 1) from profiles h where h.id = p.host_id),
    'code', p.code, 'cap', p.cap, 'pro_only', p.pro_only, 'benched', 0, 'late_syncs_back', 0)
  from purses p
  where p.listed and p.code = upper(trim($1)) and p.starts_on >= (now() at time zone 'UTC')::date - 1
  limit 1
$$;
grant execute on function public.purse_by_code(text) to authenticated;

-- Live board for one purse: today's steps, first name + initial, never more.
create function public.purse_runners(purse_id text)
returns table (rank int, name text, steps int, state text, is_me boolean)
language sql stable security definer set search_path = public as $$
  with e as (
    select s.*, coalesce(split_part(pr.display_name, ' ', 1), 'Walker')
             || coalesce(' ' || nullif(left(split_part(pr.display_name, ' ', 2), 1), '') || '.', '') as who,
      case
        when s.status = 'won' then 'finished'
        when s.benched or s.status = 'lost' or s.missed > s.shields_equipped then 'out'
        when s.today_steps >= s.daily_goal * least(1.0, s.local_hour / 20.0) then 'onPace'
        else 'behind' end as st
    from purse_entry_state s left join profiles pr on pr.id = s.user_id
    where s.purse_id = purse_runners.purse_id
  ),
  ranked as (
    select (row_number() over (order by (e.st = 'out'), e.today_steps desc))::int as rank,
      e.who as name, e.today_steps::int as steps, e.st as state, e.user_id = auth.uid() as is_me
    from e
  )
  select * from ranked where rank <= 100 or is_me order by rank
$$;
grant execute on function public.purse_runners(text) to authenticated;

-- Who got paid lately. Public, first names only.
create view public.payout_feed with (security_invoker = false) as
  select coalesce(split_part(pr.display_name, ' ', 1), 'A walker') as name, p.name as purse_name,
    r.payout_cents as amount_cents, r.payout_cents - r.stake_cents as profit_cents, r.currency,
    date_trunc('second', r.settled_at) as paid_at
  from races r join purses p on p.id = r.purse_id left join profiles pr on pr.id = r.user_id
  where r.payout_cents > 0 and p.kind <> 'crew'
  order by r.settled_at desc limit 50;
grant select on public.payout_feed to anon, authenticated;

-- Accounts removed for fake steps. A count, never names.
create view public.bench_total with (security_invoker = false) as
  select count(distinct user_id)::int as benched from races where benched;
grant select on public.bench_total to anon, authenticated;

-- Splitting -----------------------------------------------------------------------------
-- Runs once every entry in the purse has settled. Finishers split 100% of the
-- entries plus any sponsor money, cent for cent. If nobody finishes, every
-- entry goes back to its owner's Vault. Hosts get their 5% at the same time.
create function public.split_purse(pid text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  p purses;
  pot int; n int; share int; extra int; i int := 0; r record; host_cut int;
begin
  select * into p from purses where id = pid for update;
  if p.settled_at is not null then return jsonb_build_object('purse', pid, 'state', 'already'); end if;
  if exists (select 1 from races where purse_id = pid and status in ('pendingPayment', 'active', 'settling', 'underReview')) then
    return jsonb_build_object('purse', pid, 'state', 'waiting');
  end if;

  select coalesce(sum(stake_cents), 0) + p.sponsor_cents into pot from races where purse_id = pid and status in ('won', 'lost');
  select count(*) into n from races where purse_id = pid and status = 'won' and not benched;

  if n = 0 then
    for r in select * from races where purse_id = pid and status = 'lost' and not benched loop
      perform adjust_balance(r.user_id, r.stake_cents, 0);
      update races set payout_cents = r.stake_cents, finishers = 0 where id = r.id;
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, stripe_ref)
        values (r.id, r.user_id, 'winnings', r.stake_cents, r.currency, 'split_' || pid) on conflict do nothing;
    end loop;
  else
    share := pot / n;
    extra := pot - share * n;                -- leftover cents go one each to the first finishers
    for r in select * from races where purse_id = pid and status = 'won' and not benched order by created_at loop
      i := i + 1;
      perform adjust_balance(r.user_id, share + case when i <= extra then 1 else 0 end, 0);
      update races set payout_cents = share + case when i <= extra then 1 else 0 end, finishers = n where id = r.id;
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, stripe_ref)
        values (r.id, r.user_id, 'winnings', share + case when i <= extra then 1 else 0 end, r.currency, 'split_' || pid)
        on conflict do nothing;
    end loop;
    update races set payout_cents = 0, finishers = n where purse_id = pid and status = 'lost';
  end if;

  if p.kind = 'host' and p.host_id is not null then
    select coalesce(sum(host_fee_cents), 0) into host_cut from races where purse_id = pid and status in ('won', 'lost');
    if host_cut > 0 then
      perform adjust_balance(p.host_id, host_cut, 0);
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, stripe_ref, label)
        values (null, p.host_id, 'hostFee', host_cut, p.currency, 'host_' || pid, 'Host share: ' || p.name)
        on conflict do nothing;
    end if;
  end if;

  update purses set settled_at = now() where id = pid;
  return jsonb_build_object('purse', pid, 'state', 'split', 'finishers', n, 'pot', pot);
end $$;
revoke all on function public.split_purse(text) from public, anon, authenticated;

-- House purses for next week, opened every Sunday: the seven weekly ones from
-- the app's catalog. Seasonal ones (Walktober Finale, Winter Mane) are added by hand.
create function public.open_house_purses(week_start date)
returns void language sql volatile security definer set search_path = public as $$
  insert into purses (id, name, tagline, kind, art, daily_goal, days, window_start, window_end, entry_cents, currency, starts_on, pro_only)
  select s.slug || '-' || to_char(week_start, 'IYYY-IW') || '-' || lower(c.cur), s.name, s.tagline, 'house', s.art,
         s.goal, s.days, s.ws, s.we, s.entry * 100, c.cur, week_start + s.offs, false
  from (values
    ('lions-share', 'Lion''s Share', 'The flagship. Ten thousand a day, split with every finisher.', 'lion', 10000, 7, null::int, null::int, 20, 0),
    ('dawn-patrol', 'Dawn Patrol', 'Get it done before the coffee kicks in.', 'sunrise', 3000, 5, 6, 9, 10, 0),
    ('one-and-done', 'One and Done', 'One big day. Twenty thousand steps, then you get paid.', 'bolt', 20000, 1, null, null, 10, 5),
    ('fresh-paws', 'Fresh Paws', 'Your first purse. Small entry, friendly goal.', 'paw', 6000, 3, null, null, 5, 0),
    ('night-shift', 'Night Shift', 'The evening walk, worth money. Steps after 8 pm.', 'moon', 4000, 5, 20, 23, 10, 0),
    ('the-gauntlet', 'The Gauntlet', 'Fifteen thousand, ten days straight. Few finish. They split a lot.', 'flame', 15000, 10, null, null, 50, 0),
    ('golden-mane', 'Golden Mane', 'The big table. Twelve thousand a day for fifteen days.', 'crown', 12000, 15, null, null, 250, 0)
  ) as s(slug, name, tagline, art, goal, days, ws, we, entry, offs)
  cross join (values ('USD'), ('EUR')) as c(cur)
  on conflict (id) do nothing
$$;
revoke all on function public.open_house_purses(date) from public, anon, authenticated;

select cron.schedule('steppie-house-purses', '0 12 * * 0',
  $$ select public.open_house_purses((date_trunc('week', now()) + interval '8 days')::date); $$);

-- Vault, disputes, posts, referrals -----------------------------------------------------
create table public.cashouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  amount_cents int not null check (amount_cents between 2500 and 50000),
  currency text not null,
  method text not null check (method in ('bank', 'paypal')),
  status text not null default 'requested' check (status in ('requested', 'paid', 'failed')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
alter table public.cashouts enable row level security;
create policy "own cashouts" on public.cashouts for select using (auth.uid() = user_id);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  race_id uuid not null references public.races (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  note text check (char_length(note) <= 500),
  image_path text,
  status text not null default 'open' check (status in ('open', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  unique (race_id, day)
);
alter table public.disputes enable row level security;
create policy "own disputes" on public.disputes for select using (auth.uid() = user_id);

create table public.post_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  url text not null unique check (char_length(url) <= 500),
  platform text not null,
  status text not null default 'submitted' check (status in ('submitted', 'approved', 'rejected', 'paid')),
  views int,
  paid_cents int check (paid_cents between 0 and 60000),
  created_at timestamptz not null default now()
);
alter table public.post_submissions enable row level security;
create policy "own posts" on public.post_submissions for select using (auth.uid() = user_id);

create table public.referrals (
  invitee_id uuid primary key references auth.users (id) on delete cascade,
  inviter_id uuid not null references auth.users (id) on delete cascade,
  code text not null,
  credited_at timestamptz not null default now(),
  bonus_paid_at timestamptz,
  check (invitee_id <> inviter_id)
);
alter table public.referrals enable row level security;

insert into storage.buckets (id, name, public) values ('disputes', 'disputes', false) on conflict do nothing;
