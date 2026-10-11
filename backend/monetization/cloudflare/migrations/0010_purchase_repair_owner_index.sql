-- SOURCE ONLY. Not applied to remote D1.
-- json_valid guards against preexisting malformed legacy records at index build.
CREATE INDEX IF NOT EXISTS idx_iap_purchase_repair_owner_state_v1
ON iap_purchase_ledger_v1 (
 (CASE WHEN json_valid(record_json) THEN json_extract(record_json,'$.ownerUid') ELSE NULL END),
 (CASE WHEN json_valid(record_json) THEN json_extract(record_json,'$.state') ELSE NULL END),
 token_key
);
