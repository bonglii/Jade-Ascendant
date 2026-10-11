# Jade Ascendant — RC3 Trusted Progression & Recovery Index (STAGING)

**Source-only, NOT Production RC. NO commit, push, deploy, remote D1 migrations, or enabling purchases.**

Baseline: `checkpoint/iap-fasttrack-20261010` @ `54168ac936acfdde380336687ba307172e168659` + RC2.1 FIX2 installed and its 13 focused backend tests reported PASS by user.

## Implemented

- `0006_trusted_progress_evidence.sql` defines a *future* server-authored trusted-stage evidence store. **No code writes evidence**, no client bootstrap endpoint, and no offline `progression.save` ingestion. Table literals such as `server_verified_gameplay` are NOT enough to prove stage completion; a real trusted issuer must be implemented and security-reviewed before using this in production.
- `/v1/wallet/trusted-progress` independently default-off GET: verifies Firebase UID and App Check, reads canonical progression from primary D1, matches exactly to server evidence including `1-5`, refuses missing/revoked/extra proofs; returns display-only projection. `JADE_TRUSTED_PROGRESSION_READ_ENABLED=false`.
- Paid summon production coordinator now requests `requireTrustedProof:true` and `writeRecoveryIndex:true`. Canonical summon prechecks evidence before RNG and performs a **second server proof count/identity check INSIDE its D1 canonical update CAS**, preventing revoke-to-debit races. Direct `createCanonicalSummonStage(db)` remains backward-compatible for existing source-only tests, but may NEVER be wired as the production coordinator without these options.
- `0007_summon_request_index.sql` stores an account-scoped UUID for committed summons. Canonical coordinator appends the index INSERT to the SAME D1 batch as the debit, canonical state mutation, and immutable outcome. Failure rolls back all steps. The `request_id` itself is not a purchase token.
- `/v1/wallet/summon-recovery-index`: default-off read-only GET with optional numeric `before` cursor. Returns up to 20 committed UUIDs, joined with durable outcomes, from verified Firebase UID only. `JADE_SUMMON_RECOVERY_INDEX_READ_ENABLED=false`. Use existing `/v1/wallet/summon-recovery/<request_id>` for individual immutable results. Older non-indexed results may require original pending IDs; response explicitly marks `indexed_commits_only`.
- Two Godot **display-only** parsers with no runtime cutover, no save or inventory writes and no grant/consume operations.
- 15 focused backend unit scenarios, 5 additional real-repository atomic summon integration scenarios, plus one Godot smoke script. The backend units have passed 15/15 in an isolated Node 22 `node:sqlite` harness with mock verifier module; they still require project-source QA on your Windows workstation. The Godot smoke script has not been locally run by assistant.

## Unresolved production blockers

1. **Trusted gameplay proof issuer** with objective server verifiability, fraud resistance, attestation, safe account provisioning, verified stage unlock transitions, and explicit operator policy. Server evidence is currently **never issued**; this is intentionally fail-closed.
2. Full paid summon native Android request transport, pending request ID durability *before* POST, at-least-once same-ID retries, Firebase account switch isolation, App Check, and recovery queue drain.
3. Paid loadout runtime projection: account-bound and volatile, without `equipment.save`/`inventory.save` copying; snapshot and revoked equipment safety.
4. RTDN/Google Play voided purchase handling, debt/refund/revoke accounting, ownership reconciliation, chargeback cases, entitlement revocation, and fail-closed multi-device QA.
5. Remote D1 `0002`–`0007` migrations pending; backup and rollback plan must be reviewed first.
6. Production security review, backend rate limiting/WAF, actual Play Billing sandbox and physical Android QA (including killed process/account switch/two-device tests).

## Install from CMD

1. Extract `Jade-IAP-RC3-Staging.zip` to `D:\Godot\tools` (outside repo).
2. Run `powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "D:\Godot\tools\Jade-IAP-RC3-Staging\Apply-RC3-Staging.ps1" -Project "D:\Godot\project\jade-ascendant"`.
3. It checks **exact HEAD and branch**, RC2 preimage, all tracked target hashes, payload digests, and flag placement, while allowing unrelated dirty files. It backups four tracked targets and rolls back changes on apply failure. Safe to run again (idempotent). It never executes Git writes/commit, cloud migrations or deploy.

## Focused combined QA on user's real repo (only impacted targets)

```bat
cd /d D:\Godot\project\jade-ascendant\backend\monetization\cloudflare
node --test tests\rc3_recovery_progression.test.mjs tests\rc3_atomic_summon_integration.test.mjs tests\fasttrack_rc_routes.test.mjs tests\summon_canonical_stage.test.mjs tests\summon_recovery_route_m11.test.mjs
cd /d D:\Godot\project\jade-ascendant
"D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hybrid_rc3_recovery_progress_smoke.gd
git diff --check
```

If that Godot path differs, use the actual installed executable. **Do not repeat unchanged RC1/RC2 tests** unnecessarily. Do not enable any IAP/Worker flag. **No GitHub commit URL exists** because no commit was authorized or created.

## Process lessons retained

- Do not shadow native `git.exe` with a PowerShell function called `Git` (FIX1 recursion bug).
- Do not require an unrelated working tree to be clean (FIX2 issue). Check only target conflicts.
- Do not claim a staging test succeeded before it actually ran on the user's real project.
- Never call client progression or platform app integrity proof of completed gameplay.

## Team rules (explicitly agreed 2026-10-10)

1. For every authorized commit, provide the exact GitHub commit URL. **No commit in RC3 staging.**
2. Before any requested polish, classify whether the target is an asset vs. implementation/UI code; inspect the existing asset and only polish the correct layer.
3. Record failures and corrective prevention in each checkpoint/handoff so we do not loop through earlier installer mistakes.
4. Assistant owns routine technical decisions; ask for approval only for safety-critical actions (commit/push, remote migration, production unlock, save mutation).
5. Batch cohesive changes and run impacted tests once, without needless reruns of unchanged PASS suites.
6. Use direct, relaxed peer/developer tone and give clear actionable deliverables.
7. Proactively offer original game-dev ideas rather than blindly executing instructions.

## Product idea for next RC

**Jade Echo Recovery Ledger:** treat every paid summon as a durable server event with UUID before submitting a network request. On app restart, query the bounded index and reconcile immutable outcomes with local *presentation only* until paid entitlement/runtime cutover is approved. This supports cross-device recovery without crediting local saves. A real pre-POST journal/transport is still missing and must be built safely.
