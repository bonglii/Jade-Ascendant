-- RC3 SOURCE ONLY. Never migrate remote production without approval.
-- Lost request_id recovery: server-owned account-scoped UUID index.
-- New records MUST be inserted in SAME D1 batch as summon debit+outcome.
-- No token, client balance, item grant or private account identifiers stored.
CREATE TABLE IF NOT EXISTS iap_summon_request_index_v1 (
  event_sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  spend_key TEXT NOT NULL UNIQUE REFERENCES iap_summon_outcomes_v1(spend_key),
  owner_key TEXT NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
  request_id TEXT NOT NULL CHECK(length(request_id)=36),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(owner_key,request_id)
);
CREATE INDEX IF NOT EXISTS idx_iap_summon_request_index_owner
  ON iap_summon_request_index_v1(owner_key,event_sequence DESC);
