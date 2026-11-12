-- Invites.
--
-- redeem_invite() does the whole redemption in one transaction: one code per
-- person, only in their first two weeks and before any paid race, credit in
-- their own currency (which this pins), one ledger line.
--
-- The inviter's bonus is Vault money (cashable), so it now needs the friend to
-- put in their own money: a purse entry paid at least INVITE_BONUS from card or
-- Vault. Before, a fresh account could join with its free credit plus a
-- 70-cent card top-up and earn the inviter 5 in cash.

create function public.redeem_invite(uid uuid, invite text, credit int, cur text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  me profiles;
  inviter uuid;
begin
  perform lock_money(uid, cur);
  select * into me from profiles where id = uid;
  select id into inviter from profiles where invite_code = invite;
  if inviter is null then raise exception 'no_such_code'; end if;
  if inviter = uid then raise exception 'own_code'; end if;
  if me.invited_by is not null then raise exception 'already_used'; end if;
  if me.created_at < now() - interval '14 days' then raise exception 'too_late'; end if;
  if exists (select 1 from races where user_id = uid and stake_cents is not null and status <> 'cancelled') then
    raise exception 'not_new';
  end if;
  insert into referrals (invitee_id, inviter_id, code) values (uid, inviter, invite);
  update profiles set invited_by = invite where id = uid;
  perform adjust_balance(uid, 0, credit);
  insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
    values (null, uid, 'credit', credit, cur, 'inv_' || invite, 'Code ' || invite);
  return 'ok';
end $$;
revoke all on function public.redeem_invite(uuid, text, int, text) from public, anon, authenticated;

create or replace function public.book_paid_race(rid uuid, pay_ref text, bonus int)
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
    -- The inviter's cash bonus needs the friend's own money in, not free credit.
    if r.stake_cents + r.fee_cents + r.host_fee_cents - r.paid_from_credit_cents >= bonus then
      perform pay_referral(r.user_id, bonus, r.currency);
    end if;
  else
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
      values (rid, r.user_id, 'charged', r.stake_cents, r.currency, pay_ref) on conflict do nothing;
  end if;
end $$;
