# IAP lifecycle and production candidate — 2026-10-16 (+07:00)

Base: checkpoint/iap-fasttrack-20261010 at 78cdc958008bbc98443087364cfcdad68a28c805.

## Passing checkpoint retained

User confirmed Test card. Two verified/credited orders (100 and 14000 Jade), restart/RESTORE still two credits, then balance 10100 after 4000 Jade spent. Four single summons plus four ten-pulls returned 44 outcomes; 400 + 3600 = 4000. These results belong to staging. They are not real-money production evidence. See IAP_DEVICE_CREDIT_EVIDENCE_20261016.md.

## Implemented in this batch

- Added a real SQLite lifecycle integration combining the actual D1 wallet, paid gameplay, immutable run ownership, Play-void reconciliation and verified-ledger repair. Credit is idempotent; another owner cannot claim its grant. Refund after a spend holds only the matched owner, rejects old command/run replay, blocks new spending and repair, and leaves the other account usable. Existing protected SQL and ownership checks passed; no invented refund balance deduction or destructive inventory migration was added.
- Added an optional, bounded second staging tester hash. The original tester remains required and valid; missing optional hash preserves current behavior, malformed optional configuration fails closed, and other accounts remain denied. A separate interactive staging-only helper hashes the second Firebase Authentication UID locally, saves that one optional secret and deploys staging code without migrations. The public game UID/account_ref/email cannot substitute for the Firebase UID. This helper is not executed by the batch installer.
- Prepared an explicit production-candidate native target. It requires release + independent opt-in + gameplay V2 + no sandbox credit + exact production HTTPS URL. Anonymous identities are rejected; Google sign-in remains required. Candidate debug and ordinary release builds remain locked. Existing staging debug build remains available. Client authorization/repair accepts the optional native candidate method, and old AARs without that method fail closed for the candidate route.
- Preserved HTTPS hostname/SNI/certificate checks, encrypted DNS fallback, bounded replies, no redirects and no automatic POST retries. Production host is accepted only by a valid candidate build policy. No Windows or device DNS setting changes.
- Added a separate candidate builder which checks compiled flags, every JNI method, actual Play Integrity provider bytecode, absence of debug App Check in release dependencies, JVM XML results and normalized source hashes. Output remains in .local/production_native_candidate; it never replaces installed addons AARs.
- Added CI candidate compilation/artifact upload and locked Worker dry-run bundling. Existing CI still produces staging-debug plus ordinary locked-release artifacts independently. New policy matrix tests cover debug/target/URL/flag/identity boundaries in both variants.
- Prepared wrangler.production-candidate.toml pointing to the existing production D1 identity and production V2 entrypoint with nodejs_compat. All nine release/payment gates remain false. Existing wrangler.toml is untouched. No remote production deployment or activation is performed.
- Added timestamped read-only lifecycle evidence collection. Diagnosis uses Format-List so refund_monitor does not become a vertical column of letters. Its JSON runtime readiness is explicitly unknown until in-game support, rather than a hardcoded false claim.
- Added a dedicated narrow publishing manifest/publisher and backed-up installer. It prints the actual verified GitHub commit URL after push; no force push, index.lock deletion, unrelated staging or silent conflict overwrite.

## Validation actually executed

- Backend: 441/441 tests passed, including the combined cross-account refund lifecycle, optional second-tester guard and locked production config.
- Godot 4.7.2 headless, isolated user data: paid gameplay 56 checks, server Jade delivery 31, delivery boundaries 15. Total 102 checks, zero failures and no ERROR/SCRIPT ERROR output.
- Production config parsed as TOML; all release gates default false and production/staging database identities remain distinct. Scoped diff whitespace and package payload checks passed.

Not executed locally: Windows PowerShell launcher execution/AST suite, Android/Kotlin compilation, JVM policy tests, Gradle dependency verification, Wrangler dry-run, candidate installation or live Google Play verification. These are prepared in CI; do not call them passing until the published revision finishes successfully. This environment lacks the Android SDK/full JDK build toolchain. Installed AARs and historical build receipts are unchanged and do not prove the new source; wait for CI and verified binary delivery before re-exporting.

## Remaining external evidence — do only the distinct cases

1. **Second account on staging:** sign in with B so Firebase Authentication creates its UID. Configure B using configure_iap_second_tester.cmd; do not replace the primary tester secret. B must not display A's paid balance/gear. A new unfunded B is expected; no new purchase is required. Return to A and confirm its own balance/ownership remain. collect_iap_lifecycle.cmd supports -Label baseline/account-b/back-to-a. This is device staging evidence; production multi-account code is covered separately by fixtures, not claimed live.
2. **Refund an already credited Test card order, last:** capture baseline; refund/revoke one of the existing successful test orders through Play Console. Allow the genuine scheduled scan and Google reporting to catch up, then collect -Label after-refund plus in-game Copy support. Expect a matched void and account_held=1; paid operations/old receipts/runs must be refused after server revalidation. Do not assume balance becomes zero: policy is hold/review. Account hold intentionally blocks further paid tests, so run this after the account-switch checks. No automatic hold release or new purchase is included.
3. **Interrupted consume/response recovery:** native/server fixture coverage exists, but live interrupted-purchase recovery is still unproven. Do not count the already-passed ordinary restart/RESTORE as this case. Use license testing, not an unverified real-money charge.
4. **Release Play Integrity and production handoff:** after successful CI and source-matched release candidate delivery, register/verify the Play app-signing certificate SHA-256 and Android app's Play Integrity configuration in Firebase App Check. A debug token is not release proof. Install through a Play test track and verify release attestation. User controls AAB/version settings. Production needs its own verified schema, secrets/Play permissions, actual fresh refund scan and release gates; staging Test card balances are not migrated into production. Do not enable all payment flags merely because compilation passed.

Official setup references: https://firebase.google.com/docs/app-check/android/play-integrity-provider and https://developer.android.com/google/play/billing/test.

## Unchanged

No existing purchase/summon retest, purchase execution, production mutation, secret read, save migration, account reset, app data clear, version/export setting change, installed native binary replacement or main-branch change. The optional second-tester helper changes staging only when explicitly run with the second UID. The batch installer only applies source and publishes; later CI artifacts still need verified installation.
