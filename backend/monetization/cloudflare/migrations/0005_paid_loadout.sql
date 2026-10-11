-- SOURCE-ONLY / REMOTE MIGRATION PROHIBITED until trusted progression,
-- paid entitlement/runtime cutover, refund and two-device QA are approved.
-- Paid slots are deliberately separate from offline equipment.save and
-- from iap_summon_canonical_v1.inventory ownership.
CREATE TABLE IF NOT EXISTS iap_paid_loadouts_v1 (
  owner_key TEXT PRIMARY KEY NOT NULL
    REFERENCES iap_summon_canonical_v1(owner_key),
  revision INTEGER NOT NULL DEFAULT 0 CHECK(revision BETWEEN 0 AND 9007199254740990),
  slots_json TEXT NOT NULL CHECK(json_valid(slots_json) AND length(slots_json) BETWEEN 20 AND 1024),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS iap_paid_loadout_ops_v1 (
  operation_key TEXT PRIMARY KEY NOT NULL CHECK(length(operation_key) = 74 AND substr(operation_key,1,10) = 'loadoutv1:'),
  owner_key TEXT NOT NULL REFERENCES iap_paid_loadouts_v1(owner_key),
  payload_digest TEXT NOT NULL CHECK(length(payload_digest) = 64),
  committed_revision INTEGER NOT NULL CHECK(committed_revision BETWEEN 1 AND 9007199254740990),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_iap_paid_loadout_ops_owner ON iap_paid_loadout_ops_v1(owner_key, created_at);
