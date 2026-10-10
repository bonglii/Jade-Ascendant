-- Wallet M3: staging only. DO NOT migrate remote D1 before authoritative
-- server equipment/progression catalog, server RNG, and client reconciliation.
-- Atomic spend + replayable immutable outcome, keyed by SHA-256(uid, UUID).
CREATE TABLE IF NOT EXISTS iap_summon_outcomes_v1 (
  spend_key TEXT PRIMARY KEY NOT NULL
    CHECK (length(spend_key) = 72 AND substr(spend_key, 1, 8) = 'spendv1:'),
  owner_key TEXT NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
  pull_count INTEGER NOT NULL CHECK (pull_count IN (1, 10)),
  jade_cost INTEGER NOT NULL CHECK (
    (pull_count = 1 AND jade_cost = 100) OR
    (pull_count = 10 AND jade_cost = 900)
  ),
  outcome_json TEXT NOT NULL CHECK (length(outcome_json) BETWEEN 20 AND 16384),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (spend_key) REFERENCES iap_wallet_events_v1(event_key)
);
CREATE INDEX IF NOT EXISTS idx_iap_summon_outcomes_owner
  ON iap_summon_outcomes_v1(owner_key, created_at);
