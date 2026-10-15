# Verified native lifecycle delivery — 2026-10-16 (+07:00)

Compiled source: 74a05e1d6444be6e3096928adb6061fda4a708bc.
Commit: https://github.com/bonglii/Jade-Ascendant/commit/74a05e1d6444be6e3096928adb6061fda4a708bc
IAP CI: https://github.com/bonglii/Jade-Ascendant/actions/runs/38799168464

All four workflows on that commit completed successfully: IAP delivery, Premium UI/account readiness, Reward/Refine, and Player Identity/Mail. All four IAP jobs passed: backend tests + locked Worker dry-run, Windows staging/locked native + PowerShell suites, production native candidate, and Godot paid client.

## Delivered changes

- Replace the two installed addon AARs with the actual successful CI outputs: debug targets staging and permits the existing tester credit/gameplay path; ordinary release remains locked at iap-disabled.invalid.
- Update IAP_CLIENT_V2_NATIVE.json with the real archive digest, artifact ID, source hashes, 28 annotated Godot JNI methods, compiled flags and 95 passing JVM tests per variant. All 21 compile inputs match the current source. Do not use historical receipts as evidence for these new binaries.
- Include the production release candidate separately in the tools ZIP, not installed into addons. Its SHA-256 is 5a3679d44a9d756ba8649ea41f20df775eabf26c4260297dba68e3c0c50a071d. The candidate's 31 inputs (including JVM tests), 28 JNI methods, release flags, actual Play Integrity provider bytecode and release dependency graph were checked. Debug App Check is absent from its release dependency graph. Its debug/release JVM suites passed 95 tests each, 190 executions total. This is not proof of release device attestation or real-money approval.
- Add a local-only native verifier reusing the input-inventory functions already tested on Windows CI. It checks installed AAR bytes and all source inputs without probing PC DNS or the phone. The installer invokes it before publishing and refreshes only the two local native rebuild receipts with backed-up, matching CI receipts; those local files are never staged.
- Add a narrow native handoff publisher and package installer with complete preflight hashes, source-input checks, scoped backups, byte hashes for binaries, normalized hashes for text, no silent conflict overwrite, and no lock deletion/force push.
- Extend the existing Windows parser suite to include the new verifier and publisher on the next push. The already-passing Windows CI covers the original five lifecycle launchers; the two new scripts and this new portable installer have not been run on Windows locally.

## Validation scope

On compiled commit 74a05e1: backend 441 tests, all selected Godot CI checks, both native build modes and Windows compatibility/provenance suites succeeded. The two native jobs executed 380 JVM tests in total (95 tests in each of four build/test variants; not 380 unique tests). Binary class files were inspected independently after download, and archive digests matched GitHub's artifact metadata.

This delivery changes binary artifacts, provenance, publishing/verification helpers and documentation. It does not alter the previously passing gameplay/backend implementation. Those suites were not redundantly rerun locally. Complete scoped patch whitespace, payload checksums, before/after compatibility and ZIP integrity are checked while packaging. The new package's Windows execution and post-push CI are still pending; original commit CI is already successful.

## Next external cases, without repeating passed purchases

1. Apply/publish the native handoff. A normal staging/debug export can then contain the new native/source pair. User retains control of version/AAB settings; ordinary release is still locked. Existing Test card purchase/RESTORE/summon results remain accepted. Do not uninstall or clear app data for these checks.
2. Second Google account: sign in B once, get B's Firebase Authentication UID from the console, then use backend/player_identity/configure_iap_second_tester.cmd. It hashes that UID locally, adds only the optional second tester secret and deploys staging Worker code without migrations. Check B cannot see A's paid wallet/gear, and switching back returns A's state. A new B should be unfunded; no new purchase is required. Collect evidence with collect_iap_lifecycle.cmd and Copy support. Do not replace the primary tester secret.
3. Refund/revoke an existing successful Test card order LAST, after account checks. Capture baseline, perform the Play Console action, allow the real cron/reporting update, then collect after-refund. Expect the matched void and account hold; protected paid calls/replays must be refused after revalidation. Policy is hold/review, not a promise that the stored numeric balance becomes zero. This deliberately blocks further paid tests for that account.
4. Interrupted consume/response recovery still needs its own device proof; ordinary restart/RESTORE is already passing and is not that case.
5. Production handoff requires actual release Play Integrity evidence, app-signing SHA-256/Firebase setup, production database/secrets/Play permissions and a genuine fresh production refund scan. Candidate compilation alone does not authorize switching release AARs or enabling payment flags. Staging Test card balance is separate from production.

No production Worker deployment, secret read, payment, save migration, native signing change, export/version change, DNS setting change or main-branch write is part of this delivery.
