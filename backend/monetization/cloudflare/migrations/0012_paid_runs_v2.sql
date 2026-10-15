-- Immutable server selection; checkpoints contain only the account-bound run ID.
CREATE TABLE IF NOT EXISTS iap_paid_runs_v2 (
 owner_key TEXT NOT NULL REFERENCES iap_paid_gameplay_v2(owner_key),
 run_id TEXT NOT NULL CHECK(length(run_id)=36),
 loadout_json TEXT NOT NULL CHECK(json_valid(loadout_json) AND length(loadout_json) BETWEEN 20 AND 4096),
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(owner_key,run_id)
);
CREATE TRIGGER IF NOT EXISTS immutable_paid_run_v2 BEFORE UPDATE ON iap_paid_runs_v2
 BEGIN SELECT RAISE(ABORT,'immutable_paid_run'); END;
