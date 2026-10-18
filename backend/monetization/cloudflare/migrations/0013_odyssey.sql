-- Additive event tables. No existing paid/save/player records are rewritten.
CREATE TABLE IF NOT EXISTS odyssey_events(id TEXT PRIMARY KEY NOT NULL,document TEXT NOT NULL,created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS odyssey_players(event_id TEXT NOT NULL,owner TEXT NOT NULL,state TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),last_request TEXT NOT NULL DEFAULT '',PRIMARY KEY(event_id,owner));
CREATE TABLE IF NOT EXISTS odyssey_actions(event_id TEXT NOT NULL,owner TEXT NOT NULL,request_id TEXT NOT NULL,fingerprint TEXT NOT NULL,response TEXT NOT NULL,created_at INTEGER NOT NULL,PRIMARY KEY(event_id,owner,request_id));
CREATE TABLE IF NOT EXISTS odyssey_ad_intents(id TEXT PRIMARY KEY NOT NULL,event_id TEXT NOT NULL,owner TEXT NOT NULL,created_at INTEGER NOT NULL,expires_at INTEGER NOT NULL,consumed_at INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS odyssey_ad_receipts(transaction_id TEXT PRIMARY KEY NOT NULL,intent_id TEXT UNIQUE NOT NULL REFERENCES odyssey_ad_intents(id),created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS odyssey_outbox(id TEXT PRIMARY KEY NOT NULL,owner TEXT NOT NULL,event_id TEXT NOT NULL,reward TEXT NOT NULL,title TEXT NOT NULL,expires_at INTEGER NOT NULL,delivered_at INTEGER NOT NULL DEFAULT 0);

CREATE INDEX IF NOT EXISTS odyssey_players_owner ON odyssey_players(owner);
