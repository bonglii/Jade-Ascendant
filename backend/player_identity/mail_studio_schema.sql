CREATE TABLE IF NOT EXISTS mail_admin_account (
 id INTEGER PRIMARY KEY CHECK(id=1), username TEXT NOT NULL,
 password_salt TEXT NOT NULL,password_hash TEXT NOT NULL,
 totp_sealed TEXT NOT NULL,last_step INTEGER NOT NULL DEFAULT -1,
 revision TEXT NOT NULL,created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS mail_admin_recovery (
 code_hash TEXT PRIMARY KEY NOT NULL,used_at INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS mail_archives (
 mail_id TEXT PRIMARY KEY REFERENCES mail_campaigns(id),archived_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS mail_drafts (
 id TEXT PRIMARY KEY,draft_json TEXT NOT NULL,updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS mail_jobs (
 id TEXT PRIMARY KEY,request_id TEXT UNIQUE NOT NULL,fingerprint TEXT NOT NULL,
 draft_json TEXT NOT NULL,run_at INTEGER NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('scheduled','sent','cancelled','failed')),
 created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,
 campaign_id TEXT NOT NULL DEFAULT '',error_code TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS mail_job_due ON mail_jobs(state,run_at);
CREATE TABLE IF NOT EXISTS mail_player_activity (
 owner_binding TEXT PRIMARY KEY REFERENCES player_identities(owner_binding),
 last_seen INTEGER NOT NULL,client_version TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS mail_admin_audit (
 id TEXT PRIMARY KEY,action TEXT NOT NULL,detail_json TEXT NOT NULL,created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS mail_claim_resolution (
 mail_id TEXT NOT NULL,owner_binding TEXT NOT NULL,reason TEXT NOT NULL,resolved_at INTEGER NOT NULL,
 PRIMARY KEY(mail_id,owner_binding),
 FOREIGN KEY(mail_id,owner_binding) REFERENCES mail_claims(mail_id,owner_binding)
);
