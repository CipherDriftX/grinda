-- Cash-outs.
--
-- Money leaves the Vault in one transaction with its cash-out row and ledger
-- line, before Whop is called. Whop then pays it as a balance transfer to the
-- person's Whop account, or as a claim link when we have no account to send
-- to. If Whop says no, cashout_failed() puts the money back in the Vault.
-- The cash-out id is the transfer's idempotence key, so a retry never pays twice.

create function public.request_cashout(uid uuid, cents int, daily int, how text, why text default 'cashout')
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare
  p profiles;
  v_today int;
  v_id uuid;
begin
  select * into p from profiles where id = uid for update;
  if not found then raise exception 'no_profile'; end if;
  if p.payouts_frozen_at is not null and why = 'cashout' then raise exception 'payouts_frozen'; end if;
  if cents <= 0 then raise exception 'bad_amount'; end if;
  if why = 'cashout' then
    select coalesce(sum(amount_cents), 0) into v_today from cashouts
      where user_id = uid and status <> 'failed' and created_at > now() - interval '24 hours';
    if v_today + cents > daily then raise exception 'over_daily'; end if;
  end if;
  perform adjust_balance(uid, -cents, 0);   -- more than the Vault fails the check constraint
  insert into cashouts (user_id, amount_cents, currency, method, status, reason)
    values (uid, cents, coalesce(p.currency, 'USD'), how, 'requested', why)
    returning id into v_id;
  insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
    values (null, uid, 'cashout', cents, coalesce(p.currency, 'USD'), 'co_' || v_id,
            case when why = 'account_closed' then 'Account closed: Vault paid out' else 'Cash-out' end);
  return v_id;
end $$;

create function public.cashout_paid(cid uuid)
returns boolean language plpgsql volatile security definer set search_path = public as $$
begin
  update cashouts set status = 'paid', paid_at = coalesce(paid_at, now()), failure = null
    where id = cid and status in ('requested', 'processing');
  return found;
end $$;

-- Whop refused or the claim link expired unclaimed: the money goes back to the Vault.
create function public.cashout_failed(cid uuid, why text)
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare c cashouts;
begin
  select * into c from cashouts where id = cid for update;
  if not found or c.status not in ('requested', 'processing') then return false; end if;
  update cashouts set status = 'failed', failure = left(why, 300) where id = cid;
  if exists (select 1 from profiles where id = c.user_id) then
    perform adjust_balance(c.user_id, c.amount_cents, 0);
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
      values (null, c.user_id, 'refunded', c.amount_cents, c.currency, 'cof_' || cid, 'Cash-out failed: back in your Vault')
      on conflict do nothing;
  end if;
  return true;
end $$;

-- Cash-outs that still need a call to Whop (first try failed, or a claim link to check).
create index cashouts_open_idx on public.cashouts (created_at) where status in ('requested', 'processing');

revoke all on function public.request_cashout(uuid, int, int, text, text) from public, anon, authenticated;
revoke all on function public.cashout_paid(uuid) from public, anon, authenticated;
revoke all on function public.cashout_failed(uuid, text) from public, anon, authenticated;
