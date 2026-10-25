-- Purse money gets its own ledger lines. Enum values must be committed before
-- use, so they go in first, on their own.
alter type ledger_kind add value if not exists 'entry';
alter type ledger_kind add value if not exists 'fee';
alter type ledger_kind add value if not exists 'winnings';
alter type ledger_kind add value if not exists 'cashout';
alter type ledger_kind add value if not exists 'credit';
alter type ledger_kind add value if not exists 'referral';
alter type ledger_kind add value if not exists 'hostFee';
