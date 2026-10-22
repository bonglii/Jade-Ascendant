CREATE TABLE IF NOT EXISTS player_gameplay_metrics_v1 (
 owner_binding TEXT NOT NULL REFERENCES player_identities(owner_binding) ON DELETE CASCADE,
 event_id TEXT NOT NULL,
 event_kind TEXT NOT NULL CHECK(event_kind IN ('session_start','tutorial_complete','stage_enter','stage_clear','stage_defeat','stage_leave')),
 chapter INTEGER NOT NULL CHECK(chapter BETWEEN 0 AND 5),
 stage INTEGER NOT NULL CHECK(stage BETWEEN 0 AND 6),
 duration_seconds INTEGER NOT NULL CHECK(duration_seconds BETWEEN 0 AND 86400),
 received_at INTEGER NOT NULL,
 PRIMARY KEY(owner_binding,event_id)
);
CREATE INDEX IF NOT EXISTS player_gameplay_metrics_time_v1 ON player_gameplay_metrics_v1(received_at,event_kind,chapter,stage);
CREATE INDEX IF NOT EXISTS player_gameplay_metrics_owner_time_v1 ON player_gameplay_metrics_v1(owner_binding,received_at);
