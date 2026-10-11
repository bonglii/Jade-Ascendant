-- STAGING ONLY. Never run against remote production without approval.
-- A trusted Play void/refund ingestion job (NOT a device HTTP endpoint) must
-- author this state. No tokens, user save data, or PII are stored in this table.
CREATE TABLE IF NOT EXISTS iap_refund_account_holds_v1 (
  owner_key TEXT PRIMARY KEY NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
  status TEXT NOT NULL CHECK (status IN ('held', 'released')),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  reason TEXT NOT NULL CHECK (reason IN ('play_voided_purchase', 'chargeback_review', 'manual_review')),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
