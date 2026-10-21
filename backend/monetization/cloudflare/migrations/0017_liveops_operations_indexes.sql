-- Additive covering indexes for read-only operations and the existing mail retry.
-- No table, balance, campaign, reward or session data is rewritten.
CREATE INDEX IF NOT EXISTS ht_sessions_operations_week_v1 ON ht_sessions(week,owner,status,expires_at);
CREATE INDEX IF NOT EXISTS ht_progress_operations_week_v1 ON ht_progress(week,clears,claimed,bonus);
CREATE INDEX IF NOT EXISTS odyssey_outbox_pending_operations_v1 ON odyssey_outbox(id,event_id,expires_at) WHERE delivered_at=0;
