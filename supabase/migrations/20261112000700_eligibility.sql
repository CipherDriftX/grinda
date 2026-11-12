-- Who may put money in, and from where.
--
-- Paid contests are legal in some places and not others, and the minimum age
-- is 18 in most places but higher in a few. The rules live in two settings on
-- the Edge Functions (BLOCKED_REGIONS, AGE_RULES) so a lawyer's list can change
-- them without a release. These columns hold what the person told us:
--   country  ISO 3166-1 alpha-2, e.g. US, DE
--   region   ISO 3166-2, e.g. US-AZ; required for countries that set rules per state
--   birth_date  the full date, so an 18th birthday is exact (birth_year stays for old apps)
-- Living somewhere blocked never stops a cash-out: money already in the Vault always goes home.

alter table public.profiles
  add column country text check (country ~ '^[A-Z]{2}$'),
  add column region text check (region ~ '^[A-Z]{2}-[A-Z0-9]{1,3}$'),
  add column birth_date date check (birth_date between '1900-01-01' and '2100-01-01'),
  add column place_set_at timestamptz;
