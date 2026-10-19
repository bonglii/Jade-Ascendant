-- Explicit event-promo rollout. Re-running does not move the eligibility cutoff.
CREATE TABLE IF NOT EXISTS odyssey_bonus_config (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1), enabled INTEGER NOT NULL CHECK(enabled IN (0,1)), activated_at INTEGER NOT NULL CHECK(activated_at>0)
);
INSERT OR IGNORE INTO odyssey_bonus_config(singleton,enabled,activated_at) VALUES(1,1,unixepoch('now'));
CREATE TABLE IF NOT EXISTS odyssey_purchase_bonuses (
 event_id TEXT NOT NULL REFERENCES odyssey_events(id), owner TEXT NOT NULL CHECK(length(owner)=64),
 product_id TEXT NOT NULL, credit_event_key TEXT NOT NULL UNIQUE REFERENCES iap_wallet_events_v1(event_key),
 dice INTEGER NOT NULL CHECK(dice BETWEEN 1 AND 16), created_at INTEGER NOT NULL,
 PRIMARY KEY(event_id,owner,product_id),
 FOREIGN KEY(event_id,owner) REFERENCES odyssey_players(event_id,owner)
);
CREATE INDEX IF NOT EXISTS odyssey_purchase_bonus_owner ON odyssey_purchase_bonuses(event_id,owner);
CREATE TRIGGER IF NOT EXISTS odyssey_purchase_bonus_no_update BEFORE UPDATE ON odyssey_purchase_bonuses BEGIN SELECT RAISE(ABORT,'bonus_receipt_immutable'); END;
CREATE TRIGGER IF NOT EXISTS odyssey_purchase_bonus_no_delete BEFORE DELETE ON odyssey_purchase_bonuses BEGIN SELECT RAISE(ABORT,'bonus_receipt_immutable'); END;
