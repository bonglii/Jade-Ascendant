# Combined player-trust release batch

Baseline: published checkpoint `0e3cb1e780a5a45c58fa7e5aa1e4d4715bc6cb08`. User confirmed real-money IAP delivery/restart earlier; do not repeat. Android first progress backup observed at **2026-10-16 16:31:22 UTC** with automatic backups enabled. Cross-device restore was not observed.

## Included

1. Bilingual privacy policy describing actual nine-domain profile backups, profile/mail records, Firebase/Cloudflare service use, server-paid wallet and SDK advertising, local-only support breadcrumbs, deletion and legitimate retention. One reviewed JSON source generates all public/local copies. A canonical HTTPS policy and deletion page are served directly by the existing profile Worker without app sign-in, tracking scripts, a database dependency or a new hosting subscription. Existing GitHub Pages files are updated too, but in-game links use the deployed Worker rather than assuming Pages follows this checkpoint branch.
2. In-game Privacy & Support has a public deletion path and optional email draft. Requests are explicit and support-operated; a draft does not silently send mail or claim an account is already deleted. Public UID is optional and never sufficient proof. The public page works after uninstall and describes removal/limited retention without requiring a new purchase or reinstall.
3. A separate owner-only erasure processor prepares a private plan and defaults to read-only D1 checks. It requires independently verified ownership/request, operator-attested prior Firebase Auth removal and at least a 65-minute existing-token expiry interval. It binds exact production DBs and owner-specific generated SQL; explicit case confirmation is necessary for irreversible removal. It removes profile/current+previous snapshots/mail/read/activity/targeted jobs and server gameplay/loadout/run rows. Shared content, other players, admin credentials and financial/refund ledger records are not rewritten. A failed two-service operation is resumable; it is never claimed globally atomic. It is not run by deploy/export/publish/tests.
4. AdMob privacy transition closes the ad gate immediately, destroys cached ads, cancels retries and fences old callbacks. Failed privacy forms remain closed; delayed UMP entry availability updates in the open Privacy screen. New safe support fields identify SDK/native/consent/loading state. Existing ad amounts/caps, paid wallet authority, Google test/production ID separation and production native AAR/source proofs are preserved. Server AdMob SSV remains unactivated.
5. Source-based Data safety worksheet, deletion runbook and AdMob Console/device handoff. These are prepared actions and documented evidence, not a submitted Console form, legal certificate, verified inbox, serving approval or real native ad/UMP observation.

## Owner delivery

Close Godot, install/publish the package from the authorized checkpoint. The installer backs up scoped originals, refuses conflicting local source before mutation, appends lessons without discarding local notes, verifies unchanged 31-source production AAR provenance, and never deletes Git locks, stages unrelated paths or deploys.

After linked CI passes:

```cmd
backend\player_identity\deploy_player_trust.cmd
backend\player_identity\export_production.cmd
```

Deploy touches **only the existing profile Worker**: no migrations, erasure or IAP deployment. Existing ignored config, Mail Studio assets/passwords, backup flag and cron are preserved. Both public pages are checked over verified TLS using the existing process-only DNS route. Do not submit the URLs in Console until these checks pass. Source does not prove reachability in all countries/ISPs; a stable owned domain can be configured later if needed.

Export one combined release AAB through the existing launcher, with Debug unchecked and an incremented owner-selected version code. Close the launched editor afterward to restore the locked AAR, upload to internal testing and update in place. Do not uninstall/clear player data or repeat passed purchases. The new app surfaces and ad privacy fix require that AAB update; server pages become available after profile deployment.

Read `PLAYER_TRUST_DATA_SAFETY_20261016.md`, `ACCOUNT_ERASURE_RUNBOOK_20261016.md` and `ADMOB_RELEASE_HANDOFF_20261016.md`. Owner actions remaining: monitored inbox/actual request handling, real audience and final SDK inventory, Play data-safety submission, AdMob privacy messages/app readiness/app-ads.txt and one registered-test-device UMP/reward observation. No credentials/account operation is guessed or claimed complete.

## Validation recorded for this delivery

- Profile backend: **91/91** passing, including actual two-account SQLite erasure SQL, foreign-key rollback, idempotent rerun and unchanged financial ledger fixtures.
- Godot: **31/31** trust/ad-callback/UI checks, plus **28/28** existing Settings/backup layout checks. These are isolated fixtures, not a native Android UMP/ad observation. Editor-only SDK mock Nodes are owned/freed by the fixture; the final runs have no script/resource teardown errors.
- Actual PowerShell 7 parser: four launchers pass; unchanged production-native preflight verifies the original candidate and all **31** source inputs. Windows PowerShell 5 parsing/native preflight and repository installer regression are included in the new CI workflow, not claimed locally executed.
- Installer: 37 scoped payload checksums, normal/non-enumerating JSON, corrupted-payload rejection, conflicting-local-source no-mutation, apply and rerun tested. Local notes/export settings survive. Publishing was stubbed in the harness; remote success is never simulated as a published commit.
- Wrangler **4.151.0 dry-run** bundles the complete profile Worker and existing dashboard assets successfully. No live deployment, purchase, message send, Console submission or account erasure was performed.
