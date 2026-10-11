# Jade Ascendant IAP — RC5 paid summon UI + refund lock (2026-10-10)

## Real player-facing work

- A separate paid summon CTA (1/10 pulls) is now hooked into the **actual locked Pavilion scene** and talks to the RC4 `PavilionManager.request_paid_summon_rc4` transport. It never substitutes the current local summon buttons. The new CTA is **not visible while `HYBRID_PAID_SUMMON_WRITE_APPROVED=false`**, as required by the pre-release production lock.
- A committed server outcome shows item names and authoritative paid-wallet balance. This is **display only**; the equipment is not duplicated into local save files, and the local pity/inventory remains untouched.
- A dedicated "recover pending" action resubmits the same previously journaled request ID, not a second request, after a lost response. It cannot be used for another Firebase account.

## Refund hold work

- New `0008_refund_account_holds.sql` stores only a server account-key, hold state, revision and reason, **not raw purchase tokens**. Source-only; do not run production migration.
- `refund_account_guard_rc5.mjs` checks held status via a primary D1 read and adds a second **transactional D1 UPDATE guard**; a new hold can prevent an in-flight summon debit from committing.
- Production paid summon factory in RC5 is configured with `requireNoRefundHold:true`, while old source-only stage unit cases remain backward-compatible by default.
- Separate `JADE_REFUND_RECONCILIATION_READY = "false"` prevents this paid-summon route opening before a verified Google Play void/refund ingestion service is ready.
- **Important:** THIS PATCH DOES NOT IMPLEMENT trusted Play voided-purchase ingestion. Operators must never mark `JADE_REFUND_RECONCILIATION_READY=true` just because this table/guard exists. Actual refund reversal, debt accounting, Play RTDN verification and ownership revocation are NOT READY.

## Verified locally by assistant

- `node --test tests/refund_account_guard_rc5.test.mjs`: 6/6 PASS using the isolated Node 22 SQLite harness.
- Checked JS syntax via `node --check` and basic package integrity.
- **NOT claimed:** Godot build, Android Gradle compile, combined repo integration tests, mobile sandbox purchases, live D1 migrations, server trust issuer, refund ingestion, or full production.

## Source merge policy

- `Apply-RC5-StageOnly.ps1` assumes RC3 + RC4 have been installed locally. The existing route-test fixture is adjusted for the new production gate, so prior positive contract assertions keep testing the route rather than stopping at the new gate. It **does not** commit, push, deploy or migrate; it refuses branch/HEAD mismatch, detects conflicting target sources, retains unrelated working-tree changes, and backs up changed targets before writing.
- This is part of a **future single integration batch**, not a request to run a new QA cycle immediately. Do not run the patch until that complete batch is requested.
- All IAP and Android purchase gates stay OFF; `main` is unchanged.

## Actual remaining release blockers

1. Server-verifiable gameplay progress issuance and account onboarding: no trusted win attestation exists yet; never import offline stage clears as paid eligibility.
2. Verified Google Play refund/void ingestion plus negative-liability/debt policy; refund holds do nothing unless genuinely issued by trusted server ingestion.
3. Paid loadout native transport + volatile account-bound runtime application with revocation across account switches and active-run checkpoints.
4. Rebuild native Android `.aar`, wire Google Play purchase/summon screens, and run a **single combined** Play internal-test transaction/crash/account-switch/second-device QA after safety gates are ready.
5. Review remote D1 migrations `0002–0008`, backup/rollback and staged Worker deploy; explicit user approval before any production traffic or IAP activation.

## Developer error log / no repeat

- Earlier PowerShell `Git` function accidentally shadowed `git.exe` and recursively overflowed; all new scripts use `git.exe` directly.
- Earlier installer unnecessarily demanded a globally clean worktree; RC5 only checks files it patches and preserves unrelated local work.
- Earlier answers confused module QA PASS with production readiness; source work and actual on-device results are reported separately.
- Earlier work handed off PS1/QA after tiny steps; source modules now accumulate until meaningful vertical-slice QA.

No GitHub commit URL exists: commit/push was not authorized and was not performed.
