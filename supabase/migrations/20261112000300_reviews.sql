-- Reviews freeze only the disputed money.
--
-- Before: one entry under review (a Health screenshot waiting for a person, or
-- implausible data) held the whole purse, so every finisher waited on one
-- stranger. Now the purse splits when every entry has a result or is under
-- review: finishers are paid at once and one share per entry under review is
-- held back. When a person decides, that entry gets its share if it finished;
-- if it didn't, its share goes to the finishers.
--
-- A reviewer decides per day (resolve_day). Once no day of a race is waiting,
-- the race goes back to settle, which gives it its result as usual.

alter table public.purses
  add column review_share int,                                   -- what each entry under review gets if it finished
  add column reserve_cents int not null default 0 check (reserve_cents >= 0);

alter table public.race_days add column reviewed_at timestamptz, add column review_note text;

create or replace function public.split_purse(pid text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  p purses;
  pot int; n int; u int; share int; extra int; i int := 0; r record; host_cut int; back_credit int;
begin
  select * into p from purses where id = pid for update;
  if not found then return jsonb_build_object('purse', pid, 'state', 'missing'); end if;
  if p.settled_at is not null then return jsonb_build_object('purse', pid, 'state', 'already'); end if;
  if exists (select 1 from races where purse_id = pid and status in ('pendingPayment', 'active', 'settling')) then
    return jsonb_build_object('purse', pid, 'state', 'waiting');
  end if;

  select coalesce(sum(stake_cents), 0) + p.sponsor_cents into pot
    from races where purse_id = pid and status in ('won', 'lost', 'underReview');
  select count(*) into n from races where purse_id = pid and status = 'won' and not benched;
  select count(*) into u from races where purse_id = pid and status = 'underReview' and not benched;
  if n = 0 and u > 0 then return jsonb_build_object('purse', pid, 'state', 'waiting_review', 'under_review', u); end if;

  if n = 0 then
    -- Nobody finished: every entry goes back where it came from (credit stays credit).
    for r in select * from races where purse_id = pid and status = 'lost' and not benched loop
      back_credit := least(r.paid_from_credit_cents, r.stake_cents);
      perform adjust_balance(r.user_id, r.stake_cents - back_credit, back_credit);
      update races set payout_cents = r.stake_cents, finishers = 0 where id = r.id;
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
        values (r.id, r.user_id, 'refunded', r.stake_cents, r.currency, 'split_' || pid) on conflict do nothing;
    end loop;
  else
    share := pot / (n + u);
    extra := pot - share * (n + u);          -- leftover cents go one each to the first finishers
    for r in select * from races where purse_id = pid and status = 'won' and not benched order by created_at loop
      i := i + 1;
      perform adjust_balance(r.user_id, share + case when i <= extra then 1 else 0 end, 0);
      update races set payout_cents = share + case when i <= extra then 1 else 0 end, finishers = n where id = r.id;
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
        values (r.id, r.user_id, 'winnings', share + case when i <= extra then 1 else 0 end, r.currency, 'split_' || pid)
        on conflict do nothing;
    end loop;
    update races set payout_cents = 0, finishers = n where purse_id = pid and status = 'lost';
    update purses set review_share = share, reserve_cents = share * u + greatest(extra - n, 0) where id = pid;
  end if;

  if p.kind = 'host' and p.host_id is not null then
    select coalesce(sum(host_fee_cents), 0) into host_cut from races where purse_id = pid and status in ('won', 'lost', 'underReview');
    if host_cut > 0 then
      perform adjust_balance(p.host_id, host_cut, 0);
      insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
        values (null, p.host_id, 'hostFee', host_cut, p.currency, 'host_' || pid, 'Host share: ' || p.name)
        on conflict do nothing;
    end if;
  end if;

  update purses set settled_at = now() where id = pid;
  return jsonb_build_object('purse', pid, 'state', 'split', 'finishers', n, 'under_review', u, 'pot', pot);
end $$;

-- An entry that was under review at the split now has its result: pay its held
-- share, or give the share to the finishers. Runs once per entry.
create function public.pay_reviewed_entry(rid uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  r races;
  p purses;
  k int; each int; extra int; amt int; i int := 0; w record; first_winner races;
begin
  select * into r from races where id = rid for update;
  if not found or r.purse_id is null then return 'not a purse entry'; end if;
  select * into p from purses where id = r.purse_id for update;
  if p.settled_at is null or p.review_share is null then return 'not split'; end if;
  if r.payout_cents is not null then return 'already'; end if;
  if r.status not in ('won', 'lost') then return 'no result yet'; end if;

  if r.status = 'won' and not r.benched then
    perform adjust_balance(r.user_id, p.review_share, 0);
    update races set payout_cents = p.review_share, finishers = (select count(*) from races where purse_id = p.id and status = 'won' and not benched)
      where id = rid;
    insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref)
      values (rid, r.user_id, 'winnings', p.review_share, r.currency, 'split_' || p.id) on conflict do nothing;
  else
    update races set payout_cents = 0 where id = rid;
    select count(*) into k from races where purse_id = p.id and status = 'won' and not benched;
    each := p.review_share / k;
    extra := p.review_share - each * k;
    for w in select * from races where purse_id = p.id and status = 'won' and not benched order by created_at loop
      i := i + 1;
      amt := each + (case when i <= extra then 1 else 0 end);   -- a CASE inside IF would end at its THEN
      if amt > 0 then
        perform adjust_balance(w.user_id, amt, 0);
        update races set payout_cents = coalesce(payout_cents, 0) + amt where id = w.id;
        insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
          values (null, w.user_id, 'winnings', amt, w.currency, 'xtra_' || rid, 'Extra share: ' || p.name)
          on conflict do nothing;
      end if;
    end loop;
  end if;
  update purses set reserve_cents = greatest(reserve_cents - p.review_share, 0) where id = p.id;

  -- Last review done: leftover cents go to the first finisher.
  if not exists (select 1 from races where purse_id = p.id and status in ('underReview', 'active', 'settling')) then
    select reserve_cents into extra from purses where id = p.id;
    if extra > 0 then
      select * into first_winner from races where purse_id = p.id and status = 'won' and not benched order by created_at limit 1;
      if found then
        perform adjust_balance(first_winner.user_id, extra, 0);
        update races set payout_cents = coalesce(payout_cents, 0) + extra where id = first_winner.id;
        insert into ledger_entries (race_id, user_id, kind, amount_cents, currency, ref, label)
          values (null, first_winner.user_id, 'winnings', extra, first_winner.currency, 'rest_' || p.id, 'Leftover cents: ' || p.name)
          on conflict do nothing;
      end if;
      update purses set reserve_cents = 0 where id = p.id;
    end if;
  end if;
  return case when r.status = 'won' and not r.benched then 'paid' else 'shared' end;
end $$;

-- A person decides one waiting day.
--   A disputed day (screenshot sent): 'accept' counts the day as walked, 'reject' leaves the synced steps.
--   A flagged day (implausible data): 'accept' keeps the steps, 'reject' takes them away and,
--   in a purse, benches the entry (it keeps no share).
-- When no day of the race is waiting anymore, the race goes back to settle.
create function public.resolve_day(rid uuid, d date, verdict text, note text default null)
returns text language plpgsql volatile security definer set search_path = public as $$
declare r races; x race_days;
begin
  if verdict not in ('accept', 'reject') then raise exception 'bad_verdict'; end if;
  select * into r from races where id = rid for update;
  if not found then raise exception 'no_race'; end if;
  select * into x from race_days where race_id = rid and day = d for update;
  if not found then raise exception 'no_day'; end if;
  if not x.flagged and not x.disputed then return 'nothing waiting'; end if;

  if x.disputed then
    update race_days set disputed = false, steps = case when verdict = 'accept' then greatest(steps, goal) else steps end,
                         reviewed_at = now(), review_note = note
      where race_id = rid and day = d;
    update disputes set status = case when verdict = 'accept' then 'accepted' else 'rejected' end where race_id = rid and day = d;
  end if;
  if x.flagged then
    update race_days set flagged = false, steps = case when verdict = 'accept' then steps else 0 end, reviewed_at = now(), review_note = note
      where race_id = rid and day = d;
    if verdict = 'reject' and r.purse_id is not null then update races set benched = true where id = rid; end if;
  end if;

  if r.status = 'underReview' and not exists (select 1 from race_days where race_id = rid and (flagged or disputed)) then
    update races set status = 'active' where id = rid;   -- settle gives it its result on the next run
    return 'back to settle';
  end if;
  return 'decided';
end $$;

revoke all on function public.pay_reviewed_entry(uuid) from public, anon, authenticated;
revoke all on function public.resolve_day(uuid, date, text, text) from public, anon, authenticated;
