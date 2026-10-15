WITH records AS (
  SELECT token_key,
    json_extract(CASE WHEN json_valid(record_json) THEN record_json ELSE '{}' END,'$.ownerBinding') AS binding,
    json_extract(CASE WHEN json_valid(record_json) THEN record_json ELSE '{}' END,'$.grantId') AS grant_id,
    json_extract(CASE WHEN json_valid(record_json) THEN record_json ELSE '{}' END,'$.state') AS state
  FROM iap_purchase_ledger_v1
), owners AS (
  SELECT owner_key FROM iap_wallet_accounts_v1
  UNION SELECT 'u1:' || binding FROM records WHERE length(binding)=64 AND binding NOT GLOB '*[^0-9a-f]*'
), per_account AS (
  SELECT o.owner_key, substr(o.owner_key,4,12) AS account_ref,
    CASE WHEN w.owner_key IS NULL THEN 0 ELSE 1 END AS wallet_exists,
    COALESCE(w.balance,0) AS server_balance, COALESCE(w.revision,0) AS wallet_revision,
    (SELECT count(*) FROM records p WHERE 'u1:'||p.binding=o.owner_key AND p.state='grant_ready') AS verified_purchases,
    (SELECT count(*) FROM records p JOIN iap_wallet_events_v1 e ON e.event_key=p.grant_id AND e.owner_key=o.owner_key AND e.event_kind='play_credit'
      WHERE 'u1:'||p.binding=o.owner_key AND p.state='grant_ready') AS credited_purchases,
    (SELECT count(*) FROM records p JOIN iap_play_void_events_v1 v ON v.token_key=p.token_key
      WHERE 'u1:'||p.binding=o.owner_key AND p.state='grant_ready') AS voided_purchases,
    EXISTS(SELECT 1 FROM iap_refund_account_holds_v1 h WHERE h.owner_key=o.owner_key AND h.status='held') AS account_held
  FROM owners o LEFT JOIN iap_wallet_accounts_v1 w ON w.owner_key=o.owner_key
)
SELECT account_ref,wallet_exists,server_balance,wallet_revision,verified_purchases,credited_purchases,
  verified_purchases-credited_purchases AS verified_not_credited,voided_purchases,account_held,
  CASE WHEN (SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp') IS NULL THEN 'missing'
    WHEN (SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp') BETWEEN unixepoch('now')*1000-7200000 AND unixepoch('now')*1000+60000 THEN 'fresh'
    ELSE 'stale' END AS refund_monitor,
  'blocked_inventory_contract_v1' AS purchased_gameplay
FROM per_account ORDER BY account_ref;
