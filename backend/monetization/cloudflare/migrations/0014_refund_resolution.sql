-- Audited compensating debit for an owner-reviewed Play refund.
-- Original purchase and wallet events remain immutable. One header INSERT is
-- one atomic SQLite statement: all trigger writes roll back together on error.
CREATE TABLE IF NOT EXISTS iap_refund_resolutions_v1 (
 resolution_key TEXT PRIMARY KEY NOT NULL CHECK(length(resolution_key)=73 AND substr(resolution_key,1,9)='refundv1:'),
 owner_key TEXT NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
 debit_jade INTEGER NOT NULL CHECK(debit_jade BETWEEN 0 AND 9007199254740991),
 balance_before INTEGER NOT NULL CHECK(balance_before BETWEEN 0 AND 9007199254740991),
 balance_after INTEGER NOT NULL CHECK(balance_after=balance_before-debit_jade AND balance_after>=0),
 wallet_revision_before INTEGER NOT NULL CHECK(wallet_revision_before BETWEEN 0 AND 9007199254740989),
 wallet_revision_after INTEGER NOT NULL CHECK(wallet_revision_after=wallet_revision_before+1),
 hold_revision_before INTEGER NOT NULL CHECK(hold_revision_before>=1),
 voids_json TEXT NOT NULL CHECK(json_valid(voids_json) AND json_type(voids_json)='array' AND json_array_length(voids_json) BETWEEN 1 AND 100 AND length(voids_json)<=16384),
 review_reason TEXT NOT NULL CHECK(review_reason='owner_authorized_refund_reconciliation'),
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS iap_refund_settlements_v1 (
 token_key TEXT PRIMARY KEY NOT NULL REFERENCES iap_play_void_events_v1(token_key),
 owner_key TEXT NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),
 resolution_key TEXT NOT NULL REFERENCES iap_refund_resolutions_v1(resolution_key),
 credited_jade INTEGER NOT NULL CHECK(credited_jade BETWEEN 0 AND 9007199254740991),
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS iap_refund_settlements_owner_v1 ON iap_refund_settlements_v1(owner_key);
CREATE TRIGGER IF NOT EXISTS iap_refund_settlement_validate_v1 BEFORE INSERT ON iap_refund_settlements_v1
BEGIN
 SELECT CASE WHEN NOT EXISTS(
  SELECT 1 FROM iap_refund_resolutions_v1 r,json_each(r.voids_json) j
  WHERE r.resolution_key=NEW.resolution_key AND r.owner_key=NEW.owner_key
   AND json_extract(j.value,'$.token_key')=NEW.token_key AND json_extract(j.value,'$.credited_jade')=NEW.credited_jade
 ) THEN RAISE(ABORT,'refund_settlement_not_reviewed') END;
END;
CREATE TRIGGER IF NOT EXISTS iap_refund_resolution_validate_v1 BEFORE INSERT ON iap_refund_resolutions_v1
BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM iap_wallet_accounts_v1 WHERE owner_key=NEW.owner_key AND balance=NEW.balance_before AND revision=NEW.wallet_revision_before) THEN RAISE(ABORT,'refund_wallet_changed') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=NEW.owner_key AND status='held' AND reason='play_voided_purchase' AND revision=NEW.hold_revision_before) THEN RAISE(ABORT,'refund_hold_changed') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp' AND watermark_ms BETWEEN unixepoch('now')*1000-7200000 AND unixepoch('now')*1000+60000) THEN RAISE(ABORT,'refund_monitor_stale') END;
 SELECT CASE WHEN json_array_length(NEW.voids_json)!=(SELECT COUNT(*) FROM iap_play_void_events_v1 v LEFT JOIN iap_refund_settlements_v1 s ON s.token_key=v.token_key WHERE v.owner_key=NEW.owner_key AND s.token_key IS NULL) THEN RAISE(ABORT,'refund_void_set_changed') END;
 SELECT CASE WHEN (SELECT COUNT(DISTINCT json_extract(value,'$.token_key')) FROM json_each(NEW.voids_json))!=json_array_length(NEW.voids_json) THEN RAISE(ABORT,'refund_duplicate_token') END;
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM json_each(NEW.voids_json) j
  LEFT JOIN iap_play_void_events_v1 v ON v.token_key=json_extract(j.value,'$.token_key')
  LEFT JOIN iap_wallet_events_v1 e ON e.event_key='iapv1:'||substr(v.token_key,11)
  LEFT JOIN iap_refund_settlements_v1 s ON s.token_key=v.token_key
  WHERE json_type(j.value)!='object' OR json_type(j.value,'$.token_key')!='text' OR json_type(j.value,'$.credited_jade')!='integer'
   OR v.owner_key IS NULL OR v.owner_key!=NEW.owner_key OR s.token_key IS NOT NULL
   OR (e.event_key IS NOT NULL AND (e.owner_key!=NEW.owner_key OR e.event_kind!='play_credit' OR e.delta<=0))
   OR json_extract(j.value,'$.credited_jade')!=COALESCE(e.delta,0)
 ) THEN RAISE(ABORT,'refund_credit_evidence_changed') END;
 SELECT CASE WHEN NEW.debit_jade!=(SELECT SUM(json_extract(value,'$.credited_jade')) FROM json_each(NEW.voids_json)) THEN RAISE(ABORT,'refund_debit_mismatch') END;
END;
CREATE TRIGGER IF NOT EXISTS iap_refund_resolution_apply_v1 AFTER INSERT ON iap_refund_resolutions_v1
BEGIN
 INSERT INTO iap_refund_settlements_v1(token_key,owner_key,resolution_key,credited_jade)
 SELECT json_extract(value,'$.token_key'),NEW.owner_key,NEW.resolution_key,json_extract(value,'$.credited_jade') FROM json_each(NEW.voids_json);
 UPDATE iap_wallet_accounts_v1 SET balance=NEW.balance_after,revision=NEW.wallet_revision_after WHERE owner_key=NEW.owner_key;
 UPDATE iap_refund_account_holds_v1 SET status='released',revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE owner_key=NEW.owner_key;
END;
CREATE TRIGGER IF NOT EXISTS iap_refund_resolution_immutable_update_v1 BEFORE UPDATE ON iap_refund_resolutions_v1 BEGIN SELECT RAISE(ABORT,'refund_audit_immutable'); END;
CREATE TRIGGER IF NOT EXISTS iap_refund_resolution_immutable_delete_v1 BEFORE DELETE ON iap_refund_resolutions_v1 BEGIN SELECT RAISE(ABORT,'refund_audit_immutable'); END;
CREATE TRIGGER IF NOT EXISTS iap_refund_settlement_immutable_update_v1 BEFORE UPDATE ON iap_refund_settlements_v1 BEGIN SELECT RAISE(ABORT,'refund_audit_immutable'); END;
CREATE TRIGGER IF NOT EXISTS iap_refund_settlement_immutable_delete_v1 BEFORE DELETE ON iap_refund_settlements_v1 BEGIN SELECT RAISE(ABORT,'refund_audit_immutable'); END;
-- Old and new refund workers both obey this invariant. A newly discovered void
-- is still unresolved, so it creates a fresh hold. Manual/chargeback holds stay.
CREATE TRIGGER IF NOT EXISTS iap_refund_settled_hold_insert_v1 BEFORE INSERT ON iap_refund_account_holds_v1
WHEN NEW.status='held' AND NEW.reason='play_voided_purchase'
 AND EXISTS(SELECT 1 FROM iap_refund_settlements_v1 WHERE owner_key=NEW.owner_key)
 AND NOT EXISTS(SELECT 1 FROM iap_play_void_events_v1 v LEFT JOIN iap_refund_settlements_v1 s ON s.token_key=v.token_key WHERE v.owner_key=NEW.owner_key AND s.token_key IS NULL)
BEGIN SELECT RAISE(IGNORE); END;
CREATE TRIGGER IF NOT EXISTS iap_refund_settled_hold_update_v1 BEFORE UPDATE ON iap_refund_account_holds_v1
WHEN NEW.status='held' AND NEW.reason='play_voided_purchase' AND OLD.status='released' AND OLD.reason='play_voided_purchase'
 AND EXISTS(SELECT 1 FROM iap_refund_settlements_v1 WHERE owner_key=NEW.owner_key)
 AND NOT EXISTS(SELECT 1 FROM iap_play_void_events_v1 v LEFT JOIN iap_refund_settlements_v1 s ON s.token_key=v.token_key WHERE v.owner_key=NEW.owner_key AND s.token_key IS NULL)
BEGIN SELECT RAISE(IGNORE); END;
