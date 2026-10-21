-- Additive weekly challenge data. Existing player, payment and event ledgers unchanged.
CREATE TABLE IF NOT EXISTS ht_campaigns(id TEXT PRIMARY KEY, document TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS ht_weeks(id TEXT PRIMARY KEY, campaign TEXT NOT NULL, document TEXT NOT NULL, starts_at INTEGER NOT NULL, ends_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS ht_sessions(id TEXT PRIMARY KEY, owner TEXT NOT NULL, week TEXT NOT NULL REFERENCES ht_weeks(id), tier INTEGER NOT NULL CHECK(tier BETWEEN 1 AND 3), started_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, status TEXT NOT NULL CHECK(status IN ('running','won','failed','abandoned')), report TEXT);
CREATE UNIQUE INDEX IF NOT EXISTS ht_one_active ON ht_sessions(owner) WHERE status='running';
CREATE TABLE IF NOT EXISTS ht_progress(owner TEXT NOT NULL, week TEXT NOT NULL REFERENCES ht_weeks(id), tier INTEGER NOT NULL CHECK(tier BETWEEN 1 AND 3), clears INTEGER NOT NULL DEFAULT 0, best_ms INTEGER NOT NULL DEFAULT 0, survivor INTEGER NOT NULL DEFAULT 0, untouched INTEGER NOT NULL DEFAULT 0, claimed INTEGER NOT NULL DEFAULT 0, bonus INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(owner,week,tier));
CREATE TABLE IF NOT EXISTS ht_actions(owner TEXT NOT NULL, request_id TEXT NOT NULL, fingerprint TEXT NOT NULL, response TEXT NOT NULL, PRIMARY KEY(owner,request_id));
CREATE TABLE IF NOT EXISTS ht_ads(id TEXT PRIMARY KEY, owner TEXT NOT NULL, week TEXT NOT NULL, tier INTEGER NOT NULL, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, consumed_at INTEGER NOT NULL DEFAULT 0, transaction_id TEXT UNIQUE, UNIQUE(owner,week,tier));
CREATE UNIQUE INDEX IF NOT EXISTS ht_ad_per_tier ON ht_ads(owner,week,tier) WHERE consumed_at>0;
CREATE TABLE IF NOT EXISTS ht_purchase_bonus(event_key TEXT PRIMARY KEY, owner TEXT NOT NULL, week TEXT NOT NULL, created_at INTEGER NOT NULL, UNIQUE(owner,week));
CREATE TABLE IF NOT EXISTS ht_audit(id INTEGER PRIMARY KEY AUTOINCREMENT, campaign TEXT NOT NULL, action TEXT NOT NULL, document TEXT NOT NULL, created_at INTEGER NOT NULL);

CREATE TABLE IF NOT EXISTS ht_seal_spends(operation_key TEXT PRIMARY KEY, owner TEXT NOT NULL, available_after INTEGER NOT NULL CHECK(available_after>=0), created_at INTEGER NOT NULL);
