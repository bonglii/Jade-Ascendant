CREATE TABLE IF NOT EXISTS player_announcements (
 id TEXT PRIMARY KEY,
 request_id TEXT NOT NULL UNIQUE,
 fingerprint TEXT NOT NULL,
 title TEXT NOT NULL,
 body TEXT NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('notice','event','maintenance')),
 starts_at INTEGER NOT NULL,
 expires_at INTEGER NOT NULL,
 created_at INTEGER NOT NULL,
 cancelled_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS player_announcements_window ON player_announcements(cancelled_at,expires_at,starts_at);
CREATE TABLE IF NOT EXISTS player_announcement_reads (
 announcement_id TEXT NOT NULL REFERENCES player_announcements(id),
 owner_binding TEXT NOT NULL REFERENCES player_identities(owner_binding),
 read_at INTEGER NOT NULL,
 PRIMARY KEY(announcement_id,owner_binding)
);
