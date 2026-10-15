-- Read-only staging prerequisites. No user IDs, tokens or synthetic watermark.
SELECT
 (SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN
  ('iap_paid_gameplay_v2','iap_paid_commands_v2','iap_paid_runs_v2',
   'iap_play_void_cursor_v1','iap_refund_account_holds_v1','iap_wallet_accounts_v1','iap_wallet_events_v1')) = 7 AS paid_schema_ready,
 CASE WHEN (SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp')
  BETWEEN unixepoch('now')*1000-7200000 AND unixepoch('now')*1000+60000 THEN 1 ELSE 0 END AS refund_monitor_fresh,
 (unixepoch('now')*1000-(SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp'))/1000 AS refund_poll_age_seconds,
 (SELECT COUNT(*) FROM iap_paid_gameplay_v2) AS initialized_paid_accounts,
 (SELECT COUNT(*) FROM iap_paid_runs_v2) AS stored_paid_runs,
 'not_checked' AS device_purchase_evidence;
