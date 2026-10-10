-- Wallet M1 staging migration. Do not apply remotely until end-to-end wallet
-- cutover (including server-side spend/reconciliation) is implemented and approved.
-- All events use fingerprints/opaque IDs; no raw Play purchase token is stored.
CREATE TABLE IF NOT EXISTS iap_wallet_accounts_v1 (
  owner_key TEXT PRIMARY KEY NOT NULL CHECK (length(owner_key) = 67 AND substr(owner_key, 1, 3) = 'u1:'),
  balance INTEGER NOT NULL DEFAULT 0 CHECK (balance BETWEEN 0 AND 9007199254740991),
  revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0)
);

CREATE TABLE IF NOT EXISTS iap_wallet_events_v1 (
  event_key TEXT PRIMARY KEY NOT NULL,
  owner_key TEXT NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
  event_kind TEXT NOT NULL CHECK (event_kind IN ('play_credit', 'summon_debit')),
  item_key TEXT NOT NULL,
  delta INTEGER NOT NULL CHECK (
    (event_kind = 'play_credit' AND delta > 0) OR
    (event_kind = 'summon_debit' AND delta < 0)
  ),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_iap_wallet_events_owner
  ON iap_wallet_events_v1 (owner_key, created_at);
