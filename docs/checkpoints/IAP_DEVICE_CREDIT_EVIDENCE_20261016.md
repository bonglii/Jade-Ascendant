# Staging device credit evidence — 2026-10-16 (+07:00), through supplied checkpoint

User-observed device and remote D1 evidence, not a synthetic fixture:
- Initial confirmed wallet balance 0, revision 0; profile and Google identity connected; six Play products loaded.
- Scheduled refund scan succeeded at 02:15:03. Read-only D1 readiness: paid_schema_ready=1, refund_monitor_fresh=1, refund_poll_age_seconds=142.
- Current app successfully completed ledger repair: SERVER_LEDGER_RECONCILED.
- First new purchase: server_balance=100; verified_purchases=1; credited_purchases=1; verified_not_credited=0; voided_purchases=0; account_held=0.
- Second new purchase: server_balance=14100; verified_purchases=2; credited_purchases=2; verified_not_credited=0; voided_purchases=0; account_held=0.
- User confirmed game close/reopen and RESTORE; credited_purchases remained 2. These two tested transactions did not double-credit.
- Earlier failed purchase was refunded, per user; it is closed as a refund, not an outstanding grant to invent.

- Subsequent balance 10100, still two verified and two credited purchases; 4000 Jade spent. Remote receipts show four single pulls (400 Jade), four ten-pulls (3600 Jade), and 44 total outcomes. Costs reconcile exactly. This proves the tested paid-summon path, not every gear action.

Limits:
- User explicitly confirmed Test card. These are license-test transactions, not real-money production approval.
- No new-order refund/revoke-to-hold, second-account isolation, live interrupted-consume replay or release Play Integrity proof was supplied. Existing fixture coverage must not be relabelled device evidence.
- Current exported app still has a hardcoded Purchased gameplay ready=false support field. Source fix is prepared; this field cannot alone decide actual runtime readiness.
- Installed debug bridge targets staging; release target/production gates remain locked. No native production build or production deployment is implied by these results.

Next engineering work: audit the production build/endpoint/identity gates, preserve this passing checkpoint, then close only the remaining distinct lifecycle/device gates. Do not repeat credit/RESTORE tests without a new change or failure. Do not instruct another purchase to prove already-established credits.

Diagnostic presentation: use Format-List rather than an overwide PowerShell Format-Table so refund_monitor does not wrap one letter per line. Formatting-only correction is local until the next published batch.
