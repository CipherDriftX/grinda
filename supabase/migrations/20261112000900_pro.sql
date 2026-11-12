-- Steppie Pro, known to the server.
--
-- Before: profiles.is_pro said "mirrored from App Store notifications" but
-- nothing wrote it, so the server charged Pro members full fees and let them
-- run one race. Now verify-pro (the app, after a purchase or at launch) and
-- app-store-notifications (Apple, on every renewal, expiry or refund) ask the
-- App Store Server API and store the answer here. Pro counts only while
-- pro_expires_at is in the future, so a missed expiry notice can't keep it on.

alter table public.profiles
  add column pro_original_tx text unique,   -- the subscription this account owns
  add column pro_expires_at timestamptz,    -- end of the paid period, billing grace included
  add column pro_checked_at timestamptz;

-- Shields bought in the App Store: the grant and the count change together,
-- so two purchases at once can't lose one.
create function public.grant_shields(uid uuid, tx text, product text, qty int)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  insert into shield_grants (transaction_id, user_id, product_id, quantity) values (tx, uid, product, qty)
    on conflict (transaction_id) do nothing;
  if found then
    update profiles set shields = least(99, shields + qty) where id = uid returning shields into n;
  else
    select shields into n from profiles where id = uid;
  end if;
  return n;
end $$;
revoke all on function public.grant_shields(uuid, text, text, int) from public, anon, authenticated;
