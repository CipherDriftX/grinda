-- One settle run at a time. Settle calls Whop (refunds, transfers) between
-- database writes, so two overlapping runs could both act on the same race.
-- A run claims the lock for a few minutes; a crashed run's lock simply expires.
create table public.settle_lock (
  id int primary key default 1 check (id = 1),
  locked_until timestamptz
);
insert into public.settle_lock (id) values (1);
alter table public.settle_lock enable row level security;   -- service role only

create function public.claim_settle(seconds int)
returns boolean language plpgsql volatile security definer set search_path = public as $$
begin
  update settle_lock set locked_until = now() + make_interval(secs => seconds)
    where id = 1 and (locked_until is null or locked_until < now());
  return found;
end $$;

create function public.release_settle()
returns void language sql volatile security definer set search_path = public as $$
  update settle_lock set locked_until = null where id = 1
$$;

revoke all on function public.claim_settle(int) from public, anon, authenticated;
revoke all on function public.release_settle() from public, anon, authenticated;
