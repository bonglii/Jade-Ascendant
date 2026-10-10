-- STAGING ONLY: Do not apply remotely before a trusted server-side progression
-- verification/import path, canonical equipment catalog and client cutover exist.
-- No account is auto-provisioned. Client save data MUST NOT populate this table.
CREATE TABLE IF NOT EXISTS iap_summon_canonical_v1 (
  owner_key TEXT PRIMARY KEY NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
  revision INTEGER NOT NULL DEFAULT 0 CHECK (revision BETWEEN 0 AND 9007199254740990),
  status TEXT NOT NULL CHECK (status IN ('unprovisioned', 'verified')),
  state_json TEXT NOT NULL CHECK (json_valid(state_json) AND length(state_json) BETWEEN 20 AND 65536),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
