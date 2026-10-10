-- Immutable token fingerprint is the primary key. Never store raw purchase tokens.
CREATE TABLE IF NOT EXISTS iap_purchase_ledger_v1 (
  token_key TEXT PRIMARY KEY NOT NULL CHECK (token_key GLOB 'playtoken:*'),
  record_json TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1)
);
