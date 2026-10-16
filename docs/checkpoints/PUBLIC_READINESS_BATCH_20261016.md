# Public readiness batch — 2026-10-16

Owner scope: combine production export/deploy reliability, permanent-progress recovery and release diagnostics. Public store release, policy review and production AdMob validation remain separate. Main is unchanged.

## Fixed

1. Production configuration is now durable in `backend/monetization/cloudflare/wrangler.production-live.toml`. Its nine gates reproduce the already accepted production deployment. The original locked candidate/default configurations and legacy retired write routes stay locked. `deploy_public_readiness.cmd` validates the exact existing IAP target, all 15 tables and an actual recent refund observation before deploying; it never invents a watermark, changes credentials or reruns purchase tests.
2. `export_production.cmd` is now repository-owned and self-contained. The original CI production AAR is parked at `release/native`, with its original provenance and 31 source-input hashes checked before use. The editor session temporarily swaps only the release AAR; a verified original copy and durable recovery marker support exact restoration. Debug/staging AAR, source/native receipts, signing/version/export presets and saves are preserved. Use `recover_production_export.cmd` after interruption, with Godot closed. `-VerifyOnly` checks binaries/source without editor, network or substitution.
3. A new profile-service archive covers all **nine** current permanent domains, including cultivation mastery and weapon stars/levels. Historical Firebase gate-era eight-domain contracts remain archived and disabled; they are not reused as live recovery. The archive is untrusted offline progress, never evidence for IAP wallet credits, paid inventory, server progression or refunds. The IAP service remains authoritative for paid state.
4. Settings has compact Save/Restore/Check controls. First save is explicit; automatic updates then run at most every five minutes while safely in menus. New installs only read existing backups and cannot automatically overwrite them. Account changes cancel pending requests and fence old callbacks/actions. A device's progress already bound to another account cannot be uploaded into the new account.
5. Server revisions, idempotency IDs and a per-account write cooldown prevent lost-response replay and stale two-device overwrites. The profile D1 holds one latest snapshot and one previous snapshot; payloads and depth are bounded. Authentication is verified Google Firebase identity, with no client owner selector. Profile/mail/UID records and IAP databases are not imported or replaced.
6. Restore is explicit replacement, with an owned verified local before-image (three retained copies) and the existing SaveManager durable multi-domain journal. Active runs/checkpoints, uncertain transactions, unsupported snapshots and wrong accounts stop restoration. Successful restore closes the game to reload every manager consistently. A committed interrupted restore replays exact target values, never additive currency grants. Fresh startup must use the same Google account to read that account's cloud backup. No feature can recreate progress lost before its first successful archive.
7. An editor export hook embeds the selected Android preset version/name and version/code, actual native target/hash, source commit and build time. It does not change version/signing settings. Copy support uses these fields; missing metadata is explicitly `unreported`, never blank or the stale 1.0.6 configuration. Checkout readiness and paid snapshot state are separate from funded gameplay readiness.
8. Local bounded error breadcrumbs capture source basename, line and error kind only. No error messages, rationale, captured variables, backtraces, UID/email, token or save payload are logged by this feature. Previous session phase is informational, not proof of a crash. This is local support diagnostics, not remote Crashlytics or fleet crash-free statistics.

## Deploy and export once

After installing/publishing the package from the authorized checkpoint:

```cmd
backend\player_identity\deploy_public_readiness.cmd
backend\player_identity\export_production.cmd
```

The first command uses the existing ignored profile deployment config and credentials, creates only `player_progress_backups_v1` idempotently in the existing profile D1, preserves a config backup, enables the progress flag there, and deploys the two explicit services. It preserves existing Mail Studio assets, password, UID and secrets. It requires a recent successful production refund scan; failure stops before any Worker deployment. No Firebase Functions deployment or billing-plan upgrade is involved.

In the launched editor, export Android release with Export With Debug unchecked. Owner controls the AAB/version/signing settings. Close Godot after export so the original release AAR is restored. Upload through Play internal testing. There is no reason to buy Jade again for this batch.

On the updated app, Settings → Cloud backup → Save once from a safe menu. An existing cloud save is never silently chosen over local progress. Reinstall/device-transfer recovery requires a previously successful backup; it does not retroactively recover old local-only files. Check the displayed saved timestamp and account before restoring. Restore explicitly replaces the nine offline domains and closes the app; reopen afterward. Paid wallet and paid equipment reload independently from the IAP service.

## Evidence and remaining scope

`release/public_release_acceptance.json` records actual user-reported real-payment delivery and restart persistence separately from simulations. No amount/order identity was supplied for the real transaction, so those fields are not invented. The successful production Test card credit was 100 Jade. Do not repeat accepted billing tests merely because this package adds recovery/diagnostics.

Local validation is recorded in the delivery report; CI has a new three-job workflow for backend archives, actual Windows launcher parsing/preflight and isolated Godot restore/UI/export-hook fixtures. Source tests and simulated journal interruption are not a phone reinstall, real production backup transfer or live refunded-order proof. Production deployment and the updated AAB remain owner-run because credentials/signing live on the Windows machine.

Still outside this batch: final Privacy Policy/Data safety/account-deletion review; production AdMob consent/reward validation; store publication. Never claim public release approval just because real-money IAP passed.

## Local verification for this delivery

- Existing IAP backend: 441/441 passing; profile backend including new archive/contracts: 84/84 passing.
- Godot isolated recovery/save checks: 33/33; mobile Settings layout/actions: 28/28 across three sizes and English/Indonesian.
- Actual Android export-pack hook: selected preset version/code, source revision and production native target verified. This is not an APK build.
- The three repository launchers and package installer pass the actual PowerShell 7 parser. Offline native/source preflight also passes in PowerShell 7 on Linux. Windows PowerShell 5 remains covered by CI, not claimed as locally executed.
- The package installer was exercised against an isolated repository: conflicting local source stops before mutation; apply and rerun preserve local lessons and export settings. The publisher was stubbed in that harness; no remote push/deploy was simulated as success.
- Original CI candidate binary and all 31 normalized source inputs match provenance. No native recompilation, purchase, live deployment or phone recovery performed in this batch.
