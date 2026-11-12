-- Payments move from Stripe to Whop.
--
-- Card money comes in through Whop's hosted checkout (one checkout per entry,
-- stake or host fee, its metadata names the race or purse). Vault money goes
-- out as a Whop balance transfer to the person's Whop account, or as a claim
-- link when they have never paid through Whop.
--
-- Whop's hosted checkout can't place card holds, so new solo stakes are always
-- charged; a finished stake goes back to the Vault. The 'held' and 'released'
-- states stay in the enums only so old rows still read.

-- Races ---------------------------------------------------------------------------------
alter table public.races rename column stripe_payment_intent to payment_ref;  -- Whop payment id, pay_...
alter table public.races add column checkout_id text;                         -- Whop checkout configuration, ch_...
alter table public.races drop column capture_method;

alter type public.stake_state add value if not exists 'returned';             -- finished stake, back in the Vault
alter type public.ledger_kind add value if not exists 'returned';

-- People --------------------------------------------------------------------------------
alter table public.profiles drop column stripe_customer_id;
-- The Whop account that paid most recently. Cash-outs are sent here.
alter table public.profiles add column whop_user_id text;
create index profiles_whop_user_idx on public.profiles (whop_user_id) where whop_user_id is not null;

-- Public host purses pay their listing fee through a checkout too.
alter table public.purses add column host_checkout_id text, add column host_payment_ref text;

-- Ledger --------------------------------------------------------------------------------
-- Every line points at the money movement behind it: a Whop payment (pay_),
-- refund, transfer or claim link, or an internal balance move (bal_, split_, ...).
alter table public.ledger_entries rename column stripe_ref to ref;

drop view public.ledger_view;
create view public.ledger_view with (security_invoker = true) as
  select l.id, l.created_at, coalesce(r.name, l.label, '') as race_name, l.kind, l.amount_cents, l.currency, l.ref, l.user_id
  from public.ledger_entries l left join public.races r on r.id = l.race_id;
grant select on public.ledger_view to authenticated;

-- Webhooks ------------------------------------------------------------------------------
-- Whop delivers each event at least once. The webhook-id is stored first, so a
-- repeat delivery is answered 200 and does nothing.
create table public.whop_events (
  id text primary key,
  type text not null,
  object_id text,
  received_at timestamptz not null default now()
);
alter table public.whop_events enable row level security;   -- service role only

-- Cash-outs -----------------------------------------------------------------------------
alter table public.cashouts drop constraint if exists cashouts_method_check;
alter table public.cashouts drop constraint if exists cashouts_status_check;
alter table public.cashouts drop constraint if exists cashouts_amount_cents_check;
update public.cashouts set method = 'whop' where method in ('bank', 'paypal');
alter table public.cashouts
  add constraint cashouts_method_check check (method in ('whop', 'claim_link')),
  add constraint cashouts_status_check check (status in ('requested', 'processing', 'paid', 'failed')),
  add constraint cashouts_amount_cents_check check (amount_cents > 0),
  add column transfer_id text unique,          -- Whop transfer (or claim link) id
  add column claim_url text,                   -- claim links only: shown to the owner, nobody else
  add column claim_expires_at timestamptz,
  add column tracking_url text,
  add column failure text,
  add column attempts int not null default 0,
  add column reason text not null default 'cashout' check (reason in ('cashout', 'account_closed'));

-- Referrals -----------------------------------------------------------------------------
-- Pays the inviter once, in one statement, so two first entries at the same
-- moment can't both pay or both lose the count.
create function public.pay_referral(invitee uuid, bonus int, cur text)
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare inviter uuid;
begin
  update referrals set bonus_paid_at = now()
    where invitee_id = invitee and bonus_paid_at is null
    returning inviter_id into inviter;
  if inviter is null then return false; end if;
  perform adjust_balance(inviter, bonus, 0);
  update profiles set invites_paid = invites_paid + 1 where id = inviter;
  insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
    values (null, inviter, 'referral', bonus, cur, 'ref_' || invitee, 'Friend joined a purse')
    on conflict do nothing;
  return true;
end $$;
revoke all on function public.pay_referral(uuid, int, text) from public, anon, authenticated;

-- split_purse() wrote to stripe_ref; same function, renamed column.
create or replace function public.split_purse(pid text)
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
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
        values (r.id, r.user_id, 'winnings', r.stake_cents, r.currency, 'split_' || pid) on conflict do nothing;
    end loop;
  else
    share := pot / n;
    extra := pot - share * n;                -- leftover cents go one each to the first finishers
    for r in select * from races where purse_id = pid and status = 'won' and not benched order by created_at loop
      i := i + 1;
      perform adjust_balance(r.user_id, share + case when i <= extra then 1 else 0 end, 0);
      update races set payout_cents = share + case when i <= extra then 1 else 0 end, finishers = n where id = r.id;
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
        values (r.id, r.user_id, 'winnings', share + case when i <= extra then 1 else 0 end, r.currency, 'split_' || pid)
        on conflict do nothing;
    end loop;
    update races set payout_cents = 0, finishers = n where purse_id = pid and status = 'lost';
  end if;

  if p.kind = 'host' and p.host_id is not null then
    select coalesce(sum(host_fee_cents), 0) into host_cut from races where purse_id = pid and status in ('won', 'lost');
    if host_cut > 0 then
      perform adjust_balance(p.host_id, host_cut, 0);
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
        values (null, p.host_id, 'hostFee', host_cut, p.currency, 'host_' || pid, 'Host share: ' || p.name)
        on conflict do nothing;
    end if;
  end if;

  update purses set settled_at = now() where id = pid;
  return jsonb_build_object('purse', pid, 'state', 'split', 'finishers', n, 'pot', pot);
end $$;
