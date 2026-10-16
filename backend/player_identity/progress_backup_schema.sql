CREATE TABLE IF NOT EXISTS player_progress_backups_v1 (
 owner_binding TEXT PRIMARY KEY NOT NULL CHECK(length(owner_binding)=64),
 revision INTEGER NOT NULL CHECK(revision>=1),
 request_id TEXT NOT NULL CHECK(length(request_id)=32),
 snapshot_json TEXT NOT NULL CHECK(json_valid(snapshot_json) AND length(snapshot_json)<=196608),
 snapshot_hash TEXT NOT NULL CHECK(length(snapshot_hash)=64),
 updated_at INTEGER NOT NULL CHECK(updated_at>0),
 previous_json TEXT CHECK(previous_json IS NULL OR json_valid(previous_json))
);
