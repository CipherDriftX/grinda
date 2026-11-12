-- Money flows.
--
-- Every step that moves money or Shields runs inside one SQL function, so a
-- crash between two writes can't leave a race paid without its days, a balance
-- spent twice, or Shields lost. Edge Functions talk to Whop; these functions
-- keep the books. Each one locks the rows it reads, so two requests from the
-- same person (or two webhooks for the same payment) run one after the other.
--
-- Errors are raised with a short code as the message ('purse_full', ...); the
-- Edge Functions turn them into readable answers.

-- Columns ----------------------------------------------------------------------------------
alter table public.races
  add column checkout_url text,                                                       -- Whop hosted checkout for the card part
  add column card_cents int not null default 0 check (card_cents >= 0),               -- what the card paid
  add column card_refunded_cents int not null default 0 check (card_refunded_cents >= 0),
  add column paid_from_credit_cents int not null default 0 check (paid_from_credit_cents >= 0);
create index races_pending_idx on public.races (created_at) where status = 'pendingPayment';
create index races_settling_idx on public.races (settles_at) where status = 'settling';

alter table public.purses
  add column host_fee_cents int not null default 0 check (host_fee_cents >= 0),
  add column host_paid_from_vault_cents int not null default 0 check (host_paid_from_vault_cents >= 0),
  add column host_checkout_url text;

-- A card dispute (chargeback) stops cash-outs until a person looks at it.
alter table public.profiles add column payouts_frozen_at timestamptz, add column payouts_frozen_reason text;

-- Ledger lines for a race that is now fully paid --------------------------------------------
create function public.book_paid_race(rid uuid, pay_ref text, bonus int)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r races;
begin
  select * into r from races where id = rid;
  if r.purse_id is not null then
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
      values (rid, r.user_id, 'entry', r.stake_cents, r.currency, pay_ref) on conflict do nothing;
    if r.fee_cents + r.host_fee_cents > 0 then
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
        values (rid, r.user_id, 'fee', r.fee_cents + r.host_fee_cents, r.currency, pay_ref) on conflict do nothing;
    end if;
    perform pay_referral(r.user_id, bonus, r.currency);   -- first paid purse entry pays the inviter
  else
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
      values (rid, r.user_id, 'charged', r.stake_cents, r.currency, pay_ref) on conflict do nothing;
  end if;
end $$;

-- Opening a race (solo stake or purse entry) ------------------------------------------------
-- spec: template_id, name, daily_goal, grace_allowed, timezone, days (sorted dates),
-- settles_at, stake_cents, currency, bib_number, shields, purse_id, comeback_of,
-- fee_cents, host_fee_cents, from_credit, from_vault, from_card.
-- Paid fully from balances: live at once. Otherwise it waits for the card.
create function public.open_race(uid uuid, spec jsonb, max_running int, bonus int)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare
  v_id uuid;
  v_purse purses;
  v_days date[] := array(select (jsonb_array_elements_text(spec -> 'days'))::date);
  v_goal int := (spec ->> 'daily_goal')::int;
  v_stake int := (spec ->> 'stake_cents')::int;
  v_fee int := coalesce((spec ->> 'fee_cents')::int, 0);
  v_host int := coalesce((spec ->> 'host_fee_cents')::int, 0);
  v_credit int := coalesce((spec ->> 'from_credit')::int, 0);
  v_vault int := coalesce((spec ->> 'from_vault')::int, 0);
  v_card int := coalesce((spec ->> 'from_card')::int, 0);
  v_shields int := coalesce((spec ->> 'shields')::int, 0);
  v_pid text := spec ->> 'purse_id';
  v_n int;
begin
  -- Balances, Shields and the race limit are all read under this lock.
  perform 1 from profiles where id = uid for update;
  if not found then raise exception 'no_profile'; end if;

  if v_credit < 0 or v_vault < 0 or v_card < 0 or v_fee < 0 or v_host < 0
     or v_credit + v_vault + v_card <> v_stake + v_fee + v_host
     or (v_card > 0 and v_card < 50)
     or (v_pid is null and v_credit > 0)          -- entry credit is for purses only, so it never turns into cash
     or v_shields not between 0 and 2
     or coalesce(array_length(v_days, 1), 0) = 0 then
    raise exception 'bad_split';
  end if;

  select count(*) into v_n from races
    where user_id = uid and status in ('pendingPayment', 'active', 'settling') and stake_cents is not null;
  if v_n >= max_running then raise exception 'too_many_running'; end if;

  if v_pid is not null then
    select * into v_purse from purses where id = v_pid for update;   -- joins queue per purse, so the cap holds
    if not found then raise exception 'no_purse'; end if;
    if v_purse.cap is not null then
      select count(*) into v_n from races where purse_id = v_pid and status <> 'cancelled';
      if v_n >= v_purse.cap then raise exception 'purse_full'; end if;
    end if;
  end if;

  insert into races (user_id, template_id, name, daily_goal, grace_allowed, timezone, start_date, end_date, settles_at,
                     stake_cents, currency, status, stake_state, bib_number, shields_equipped, comeback_of, purse_id,
                     fee_cents, host_fee_cents, paid_from_balance_cents, paid_from_credit_cents)
  values (uid, spec ->> 'template_id', spec ->> 'name', v_goal, coalesce((spec ->> 'grace_allowed')::int, 0),
          spec ->> 'timezone', v_days[1], v_days[array_length(v_days, 1)], (spec ->> 'settles_at')::timestamptz,
          v_stake, spec ->> 'currency',
          (case when v_card > 0 then 'pendingPayment' else 'active' end)::race_status,
          (case when v_card > 0 then 'none' else 'charged' end)::stake_state,
          (spec ->> 'bib_number')::int, v_shields, (spec ->> 'comeback_of')::uuid, v_pid,
          v_fee, v_host, v_credit + v_vault, v_credit)
  returning id into v_id;

  insert into race_days (race_id, day, goal) select v_id, d, v_goal from unnest(v_days) as d;

  if v_credit + v_vault > 0 then perform adjust_balance(uid, -v_vault, -v_credit); end if;   -- an overdraft fails the check constraint
  if v_shields > 0 then
    update profiles set shields = shields - v_shields where id = uid and shields >= v_shields;
    if not found then raise exception 'no_shields'; end if;
  end if;

  if v_card = 0 then perform book_paid_race(v_id, 'bal_' || v_id, bonus); end if;
  return v_id;
end $$;

-- A race waiting for its card is called off: balances and Shields go back exactly
-- where they came from (entry credit stays entry credit).
create function public.cancel_pending(rid uuid)
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare r races;
begin
  select * into r from races where id = rid for update;
  if not found or r.status <> 'pendingPayment' then return false; end if;
  update races set status = 'cancelled', checkout_url = null where id = rid;
  if r.paid_from_balance_cents > 0 then
    perform adjust_balance(r.user_id, r.paid_from_balance_cents - r.paid_from_credit_cents, r.paid_from_credit_cents);
  end if;
  if r.shields_equipped > 0 then
    update profiles set shields = least(99, shields + r.shields_equipped) where id = r.user_id;
  end if;
  return true;
end $$;

-- A card payment arrived for a race. Returns:
--   'active'  the race is live now;
--   'already' this payment was booked before (a repeat webhook);
--   'refund'  the race can't take it (called off, already paid, wrong amount): refund the payment;
--   'unknown' no such race: refund the payment.
create function public.confirm_payment(rid uuid, pay_ref text, paid int, cur text, whop_user text, bonus int)
returns text language plpgsql volatile security definer set search_path = public as $$
declare r races; v_due int;
begin
  select * into r from races where id = rid for update;
  if not found then return 'unknown'; end if;
  if r.payment_ref = pay_ref then return 'already'; end if;
  if r.status <> 'pendingPayment' then return 'refund'; end if;
  v_due := r.stake_cents + r.fee_cents + r.host_fee_cents - r.paid_from_balance_cents;
  if upper(cur) <> r.currency or paid < v_due then
    perform cancel_pending(rid);
    return 'refund';
  end if;
  update races set status = 'active', stake_state = 'charged', payment_ref = pay_ref, card_cents = v_due, checkout_url = null
    where id = rid;
  if coalesce(whop_user, '') <> '' then update profiles set whop_user_id = whop_user where id = r.user_id; end if;
  perform book_paid_race(rid, pay_ref, bonus);
  return 'active';
end $$;

-- Host purses -------------------------------------------------------------------------------
-- spec: id, name, tagline, kind, art, daily_goal, days, entry_cents, currency, starts_on,
-- code, cap, fee_cents, from_vault, from_card, free_month (the Pro free month, or null).
create function public.open_host_purse(uid uuid, spec jsonb, max_hosted int)
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  v_id text := spec ->> 'id';
  v_fee int := coalesce((spec ->> 'fee_cents')::int, 0);
  v_vault int := coalesce((spec ->> 'from_vault')::int, 0);
  v_card int := coalesce((spec ->> 'from_card')::int, 0);
  v_month date := (spec ->> 'free_month')::date;
  v_n int;
begin
  perform 1 from profiles where id = uid for update;
  if not found then raise exception 'no_profile'; end if;
  if v_vault < 0 or v_card < 0 or v_vault + v_card <> v_fee or (v_card > 0 and v_card < 50) then raise exception 'bad_split'; end if;

  select count(*) into v_n from purses where host_id = uid and settled_at is null;
  if v_n >= max_hosted then raise exception 'too_many_hosted'; end if;

  if v_month is not null then
    update profiles set host_free_month = v_month where id = uid and host_free_month is distinct from v_month;
    if not found then raise exception 'free_month_used'; end if;
  end if;

  insert into purses (id, name, tagline, kind, art, daily_goal, days, entry_cents, currency, starts_on, host_id, code, cap,
                      listed, host_fee_cents, host_paid_from_vault_cents)
  values (v_id, spec ->> 'name', spec ->> 'tagline', (spec ->> 'kind')::purse_kind, spec ->> 'art',
          (spec ->> 'daily_goal')::int, (spec ->> 'days')::int, (spec ->> 'entry_cents')::int, spec ->> 'currency',
          (spec ->> 'starts_on')::date, uid, spec ->> 'code', (spec ->> 'cap')::int, v_card = 0, v_fee, v_vault);

  if v_vault > 0 then perform adjust_balance(uid, -v_vault, 0); end if;
  if v_card = 0 and v_fee > 0 then
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
      values (null, uid, 'fee', v_fee, spec ->> 'currency', 'host_' || v_id, 'Hosting ' || (spec ->> 'name'));
  end if;
  return v_id;
end $$;

-- An unpaid public purse is called off: the Vault part goes back, the purse goes away.
create function public.cancel_host_purse(pid text)
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare p purses;
begin
  select * into p from purses where id = pid for update;
  if not found or p.listed or p.host_payment_ref is not null then return false; end if;
  if exists (select 1 from races where purse_id = pid) then return false; end if;
  if p.host_paid_from_vault_cents > 0 then perform adjust_balance(p.host_id, p.host_paid_from_vault_cents, 0); end if;
  delete from purses where id = pid;
  return true;
end $$;

-- The card part of a host fee arrived. Same answers as confirm_payment ('listed' when it worked).
create function public.confirm_host_payment(pid text, pay_ref text, paid int, cur text, whop_user text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare p purses; v_due int;
begin
  select * into p from purses where id = pid for update;
  if not found then return 'unknown'; end if;
  if p.host_payment_ref = pay_ref then return 'already'; end if;
  if p.listed or p.host_payment_ref is not null then return 'refund'; end if;
  v_due := p.host_fee_cents - p.host_paid_from_vault_cents;
  if upper(cur) <> p.currency or paid < v_due then
    perform cancel_host_purse(pid);
    return 'refund';
  end if;
  update purses set listed = true, host_payment_ref = pay_ref, host_checkout_url = null where id = pid;
  if coalesce(whop_user, '') <> '' then update profiles set whop_user_id = whop_user where id = p.host_id; end if;
  insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
    values (null, p.host_id, 'fee', p.host_fee_cents, p.currency, 'host_' || pid, 'Hosting ' || p.name)
    on conflict do nothing;
  return 'listed';
end $$;

-- Settling one race ---------------------------------------------------------------------------
-- Unused Shields go back to the locker. Purse entries only get their result here
-- (split_purse pays them). A solo stake that finished comes back: `card_back` was
-- already refunded to the card by the caller, the rest goes to the Vault. A won
-- comeback also returns half of the missed stake (`comeback_card_back` of it to
-- the card already). Runs once per race; a second call answers 'already'.
create function public.settle_race(rid uuid, won boolean, used int, card_back int default 0, comeback_card_back int default 0)
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  r races;
  lost races;
  v_vault int;
  v_half int;
begin
  select * into r from races where id = rid for update;
  if not found or r.status not in ('active', 'settling') then return 'already'; end if;
  if used < 0 or used > r.shields_equipped then raise exception 'bad_shields'; end if;

  if r.shields_equipped - used > 0 then
    update profiles set shields = least(99, shields + r.shields_equipped - used) where id = r.user_id;
  end if;
  update races set status = (case when won then 'won' else 'lost' end)::race_status, shields_used = used, settled_at = now()
    where id = rid;

  if r.purse_id is not null or r.stake_cents is null then return case when won then 'won' else 'lost' end; end if;

  if not won then
    update races set stake_state = 'kept' where id = rid;
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
      values (rid, r.user_id, 'kept', r.stake_cents, r.currency, coalesce(r.payment_ref, 'bal_' || rid)) on conflict do nothing;
    return 'lost';
  end if;

  if card_back < 0 or card_back > least(r.stake_cents, r.card_cents - r.card_refunded_cents) then raise exception 'bad_refund'; end if;
  v_vault := r.stake_cents - card_back;
  update races set stake_state = (case when v_vault = 0 then 'refunded' else 'returned' end)::stake_state,
                   card_refunded_cents = card_refunded_cents + card_back
    where id = rid;
  if card_back > 0 then
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
      values (rid, r.user_id, 'refunded', card_back, r.currency, r.payment_ref) on conflict do nothing;
  end if;
  if v_vault > 0 then
    perform adjust_balance(r.user_id, v_vault, 0);
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
      values (rid, r.user_id, 'returned', v_vault, r.currency, 'ret_' || rid) on conflict do nothing;
  end if;

  if r.comeback_of is not null then
    select * into lost from races where id = r.comeback_of for update;
    v_half := coalesce(lost.stake_cents, 0) / 2;
    if v_half > 0 then
      if comeback_card_back < 0 or comeback_card_back > least(v_half, lost.card_cents - lost.card_refunded_cents) then
        raise exception 'bad_refund';
      end if;
      update races set card_refunded_cents = card_refunded_cents + comeback_card_back where id = lost.id;
      if v_half - comeback_card_back > 0 then perform adjust_balance(r.user_id, v_half - comeback_card_back, 0); end if;
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
        values (rid, r.user_id, 'comeback', v_half, lost.currency, coalesce(lost.payment_ref, 'ret_' || lost.id)) on conflict do nothing;
    end if;
  end if;
  return 'won';
end $$;

-- A card dispute: no cash-outs until a person has looked.
create function public.freeze_payouts(uid uuid, why text)
returns void language sql volatile security definer set search_path = public as $$
  update profiles set payouts_frozen_at = coalesce(payouts_frozen_at, now()), payouts_frozen_reason = why where id = uid
$$;

revoke all on function public.book_paid_race(uuid, text, int) from public, anon, authenticated;
revoke all on function public.open_race(uuid, jsonb, int, int) from public, anon, authenticated;
revoke all on function public.cancel_pending(uuid) from public, anon, authenticated;
revoke all on function public.confirm_payment(uuid, text, int, text, text, int) from public, anon, authenticated;
revoke all on function public.open_host_purse(uuid, jsonb, int) from public, anon, authenticated;
revoke all on function public.cancel_host_purse(text) from public, anon, authenticated;
revoke all on function public.confirm_host_payment(text, text, int, text, text) from public, anon, authenticated;
revoke all on function public.settle_race(uuid, boolean, int, int, int) from public, anon, authenticated;
revoke all on function public.freeze_payouts(uuid, text) from public, anon, authenticated;
