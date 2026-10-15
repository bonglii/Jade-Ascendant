# Native staging candidate — 2026-10-15

Supersedes earlier pending-native statements in IAP_CLIENT_V2_STATUS.md and IAP_PAID_RUN_RECOVERY.md.

## Changed
- Install actual debug/release AARs from GitHub run 38751119455, commit 92b822ab5680f67d54da4b199eb4a3bde667466e. All 20 normalized native inputs match; SHA256 and JVM XML evidence are retained in IAP_CLIENT_V2_NATIVE.json. Debug is staging; release remains disabled. Both variants passed 91 JVM tests each.
- Fix test audio shutdown across affected suites. Stop deferred SFX after audio release; preserve immediate crash-exit semantics by draining audio before writing the partial transaction. Strict CI error scanners remain enabled.
- Remove remaining ripgrep dependency from three QA workflows.
- Advertise staging paid-run protocol version and add a read-only staging schema/refund freshness check. Health is code/config disclosure, not proof of database readiness or a device purchase.

## Validation and limits
- Backend: 422/422 passed locally on this source.
- Published run's native and Windows jobs succeeded. All Godot assertions passed, but the overall run failed resource cleanup at exit. This batch repairs cleanup; its next full GitHub CI run is still required. Do not describe the prior run as green.
- Five affected Godot suites previously passed after the cleanup fix: Hero 141, report 175, combat 261, player binding 85, mail 26, with no error output.
- Additional recovery/reward/home results are recorded in the delivered package logs. These are isolated fixtures, not Android purchase evidence.
- No Worker deployment, real purchase, Play Console change, release unlock, main merge, save migration or export/version change was performed.

## Next staging gate
After publishing and checking CI:
1. backend\player_identity\deploy_iap_gameplay_staging.cmd
2. backend\player_identity\check_iap_staging_schema.cmd
3. backend\player_identity\check_account_iap.cmd

Expected prerequisites: paid_schema_ready=1, refund_monitor_fresh=1, IAP_STAGING_PAID_RUN_CONTRACT=1. Missing schema is a failed prerequisite. If the refund cursor is stale, diagnose the real scheduled monitor; never seed a fake cursor. The SQL check does not expose player IDs or purchase tokens and does not modify data. Its Windows launcher and remote execution have not been exercised here.

Then prove purchase/consume/credit, restart recovery, account isolation and refund handling using the matching staging debug export on an Android tester device. Release AAR is deliberately locked and is not a production money-ready export. Production enablement remains a separate gate after device evidence.
