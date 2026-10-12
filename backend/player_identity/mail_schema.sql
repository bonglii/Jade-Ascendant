CREATE TABLE IF NOT EXISTS mail_campaigns (
 id TEXT PRIMARY KEY NOT NULL, request_id TEXT UNIQUE NOT NULL,
 fingerprint TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
 sender TEXT NOT NULL, reward_json TEXT NOT NULL,
 audience TEXT NOT NULL CHECK(audience IN ('uid','all')), target_uid TEXT NOT NULL,
 created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
 published_at INTEGER NOT NULL DEFAULT 0, cancelled_at INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS mail_recipients (
 mail_id TEXT NOT NULL REFERENCES mail_campaigns(id),
 owner_binding TEXT NOT NULL REFERENCES player_identities(owner_binding),
 delivered_at INTEGER NOT NULL DEFAULT 0, read_at INTEGER NOT NULL DEFAULT 0,
 deleted_at INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY(mail_id,owner_binding)
);
CREATE INDEX IF NOT EXISTS mail_owner ON mail_recipients(owner_binding,mail_id);
CREATE TABLE IF NOT EXISTS mail_claims (
 mail_id TEXT NOT NULL, owner_binding TEXT NOT NULL,
 installation_id TEXT NOT NULL, receipt_id TEXT UNIQUE NOT NULL,
 reward_json TEXT NOT NULL, reserved_at INTEGER NOT NULL, acknowledged_at INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY(mail_id,owner_binding),
 FOREIGN KEY(mail_id,owner_binding) REFERENCES mail_recipients(mail_id,owner_binding)
);
CREATE TABLE IF NOT EXISTS mail_admin_attempts (
 bucket TEXT PRIMARY KEY NOT NULL, window_at INTEGER NOT NULL, attempts INTEGER NOT NULL
);
