-- RC3 SOURCE ONLY. NEVER apply to remote production without explicit approval.
-- Deliberately NO public/API write route and NO client-save import.
-- Rows require a future independently audited trusted gameplay verifier.
CREATE TABLE IF NOT EXISTS iap_trusted_stage_evidence_v1 (
  owner_key TEXT NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
  stage_key TEXT NOT NULL CHECK (
    length(stage_key) BETWEEN 3 AND 4 AND stage_key GLOB '[1-3]-[1-5]'
  ),
  evidence_key TEXT NOT NULL UNIQUE CHECK (
    length(evidence_key)=72 AND substr(evidence_key,1,8)='stagev1:'
  ),
  origin TEXT NOT NULL CHECK(origin='server_verified_gameplay'),
  status TEXT NOT NULL CHECK(status IN ('verified','revoked')),
  recorded_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (owner_key,stage_key)
);
CREATE INDEX IF NOT EXISTS idx_iap_stage_evidence_owner
  ON iap_trusted_stage_evidence_v1(owner_key,status);
