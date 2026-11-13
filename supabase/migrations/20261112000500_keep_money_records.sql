-- Money records outlive the account. Deleting an account used to cascade into
-- the ledger and cash-outs, erasing the record of money paid in and out. Now
-- those rows stay, with the person's id cleared, so the books still add up and
-- a cash-out sent at deletion can finish. Nothing in them names the person.
alter table public.ledger_entries alter column user_id drop not null;
alter table public.ledger_entries drop constraint ledger_entries_user_id_fkey,
  add constraint ledger_entries_user_id_fkey foreign key (user_id) references auth.users (id) on delete set null;
alter table public.ledger_entries drop constraint ledger_entries_race_id_fkey,
  add constraint ledger_entries_race_id_fkey foreign key (race_id) references public.races (id) on delete set null;

alter table public.cashouts alter column user_id drop not null;
alter table public.cashouts drop constraint cashouts_user_id_fkey,
  add constraint cashouts_user_id_fkey foreign key (user_id) references auth.users (id) on delete set null;
