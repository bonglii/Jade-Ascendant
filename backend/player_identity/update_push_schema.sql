CREATE TABLE IF NOT EXISTS player_update_push_v1 (
 id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, draft_json TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('pending','sending','accepted','rejected','unknown')),
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
 message_id TEXT NOT NULL DEFAULT '', error_code TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS player_update_push_created_v1 ON player_update_push_v1(created_at);
