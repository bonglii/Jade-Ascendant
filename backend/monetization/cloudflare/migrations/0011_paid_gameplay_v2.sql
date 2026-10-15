-- Additive cutover. V1 balances, outcomes and fragments are preserved.
CREATE TABLE IF NOT EXISTS iap_paid_gameplay_v2 (
 owner_key TEXT PRIMARY KEY NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
 revision INTEGER NOT NULL DEFAULT 0 CHECK(revision BETWEEN 0 AND 9007199254740990),
 source_revision INTEGER NOT NULL CHECK(source_revision>=0),
 state_json TEXT NOT NULL CHECK(json_valid(state_json) AND length(state_json) BETWEEN 20 AND 32768),
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS iap_paid_commands_v2 (
 operation_key TEXT PRIMARY KEY NOT NULL CHECK(length(operation_key)=71 AND substr(operation_key,1,7)='paidv2:'),
 owner_key TEXT NOT NULL REFERENCES iap_paid_gameplay_v2(owner_key),
 payload_digest TEXT NOT NULL CHECK(length(payload_digest)=64),
 result_json TEXT NOT NULL CHECK(json_valid(result_json) AND length(result_json) BETWEEN 2 AND 16384),
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_iap_paid_commands_owner_v2 ON iap_paid_commands_v2(owner_key,created_at);
CREATE TRIGGER IF NOT EXISTS freeze_canonical_after_paid_v2 BEFORE UPDATE ON iap_summon_canonical_v1
 WHEN EXISTS(SELECT 1 FROM iap_paid_gameplay_v2 WHERE owner_key=OLD.owner_key)
 BEGIN SELECT RAISE(ABORT,'paid_v2_cutover'); END;
CREATE TRIGGER IF NOT EXISTS freeze_loadout_after_paid_v2 BEFORE UPDATE ON iap_paid_loadouts_v1
 WHEN EXISTS(SELECT 1 FROM iap_paid_gameplay_v2 WHERE owner_key=OLD.owner_key)
 BEGIN SELECT RAISE(ABORT,'paid_v2_cutover'); END;
