# Refund checkout and notification recovery — 2026-10-19

Reviewed case: public UID JAWS7KV53DRW, account reference 775dc6968aae. Device version 1.0.13, source ed59025d52982ea27333b3f16256abbd9e0300a5. Production release is enabled; refund monitor fresh; account held for play_voided_purchase. Google void at 2026-10-16 14:05 UTC, reason 6/source 1. The matching jade_pouch_100 credit is 100 and wallet before repair is 100.

Prepared outcome: append a 100-Jade refund settlement, wallet 100 -> 0, wallet revision +1, hold released. No new purchase, grant, refund of real money, save reset, gate change, native rebuild, Worker deployment or push notification. Account recovery has NOT been executed in this preparation environment.

Database invariant: one header INSERT fires validated settlement/debit/release triggers in one atomic SQLite statement. CAS checks include wallet/hold revisions, all unresolved voids, exact original credits and fresh refund monitor. Audit rows are immutable; replay is idempotent. Resolved old voids cannot re-hold an account; a new unresolved void or manual/chargeback review still can. A separate audit ledger records the compensating debit without rewriting original wallet events.

Client: preserve ACCOUNT_HELD and other safe native statuses; retry held reads at 60 seconds; show REFUND REVIEW, VERIFYING WALLET or CONNECT TO BUY accurately; support output adds Paid transport stage. Notification JNI detection fix and its lessons are included. Monetary security gates and pending purchase journals are preserved.

Validation already performed: 15 SQLite/Node cases covering debit-once, rollback, concurrent wallet/hold/void changes, insufficient balance, stale monitor, wrong evidence, immutable audit, cron replay, new refund and isolated operator rerun. Wrangler 4.151.0/workerd local executed the migration, JSON-bearing INSERT through Node argv, replay and old cron upsert: wallet 0/revision 2/released/one audit. No remote queries or deployment were used in those tests. Godot paid-status test passed; the final package status, treasury message/button and notification tests passed before packaging and are run again before publication on the project PC.

Run only Jade-Refund-Checkout-Notifications-Fix\apply_and_publish.cmd to resume this batch. It validates the existing native candidate, installs with backups, tests, publishes the checkpoint, applies/validates the D1 schema, settles this exact case once, opens the production export editor and checks the AAB. It stops on source, account or evidence changes. It accepts the original notification batch or the separate JNI fix. Do not rerun the older package manifest after installing this batch.

Actual GitHub commit, remote settlement, release AAB and Play-device checks remain pending until the Windows launcher completes.
