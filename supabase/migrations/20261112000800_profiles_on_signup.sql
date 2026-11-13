-- Every account gets a profile row the moment it is created.
--
-- Before: nothing created profiles. The app only read its row, so a new
-- account had none and every paid action answered "Finish setting up your
-- profile first". Now a trigger on auth.users makes the row (name from Sign in
-- with Apple when it was shared), and accounts made before this get theirs here.

create function public.create_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
    values (new.id, nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')), 40), ''))
    on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.create_profile();

insert into public.profiles (id) select id from auth.users on conflict (id) do nothing;

-- An account made without a name gets a LION-1234 code. When the name arrives
-- (the app saves it right after sign-up), the code follows the name, as long
-- as nobody has joined with the old one.
create or replace function public.profiles_invite_code()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.invite_code is null then
    new.invite_code := make_invite_code(new.display_name);
  elsif tg_op = 'UPDATE' and old.display_name is null and new.display_name is not null
        and new.invite_code = old.invite_code and old.invite_code like 'LION-%'
        and not exists (select 1 from referrals where inviter_id = new.id) then
    new.invite_code := make_invite_code(new.display_name);
  end if;
  return new;
end $$;
