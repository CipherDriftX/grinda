-- Comeback refunds get their own ledger line. Enum values must be committed
-- before use, so this runs in its own migration.
alter type ledger_kind add value if not exists 'comeback';
