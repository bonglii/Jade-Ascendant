-- RC7 SOURCE ONLY. NEVER APPLY TO REMOTE WITHOUT APPROVAL.
-- Raw Google Play purchase tokens, order IDs, Firebase UIDs and credentials
-- MUST NEVER be stored in these tables. Token fingerprint is SHA-256 only.
CREATE TABLE IF NOT EXISTS iap_play_void_events_v1 (
  token_key TEXT PRIMARY KEY NOT NULL CHECK (length(token_key) = 74 AND substr(token_key, 1, 10) = 'playtoken:'),
  owner_key TEXT REFERENCES iap_wallet_accounts_v1(owner_key),
  voided_time_ms INTEGER NOT NULL CHECK (voided_time_ms > 0),
  voided_reason INTEGER NOT NULL CHECK (voided_reason BETWEEN 0 AND 8),
  voided_source INTEGER NOT NULL CHECK (voided_source BETWEEN 0 AND 2),
  recorded_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_iap_play_void_unmatched_v1
  ON iap_play_void_events_v1 (owner_key, recorded_at);
CREATE TABLE IF NOT EXISTS iap_play_void_cursor_v1 (
  cursor_name TEXT PRIMARY KEY NOT NULL CHECK (cursor_name = 'voided_inapp'),
  watermark_ms INTEGER NOT NULL CHECK (watermark_ms > 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
