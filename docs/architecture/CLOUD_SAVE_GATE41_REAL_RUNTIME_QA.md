# Jade Ascendant — Gate 4.1A/B: real SDK loading + isolated Firebase Emulator QA

**Source authority:** `qa/cloud-save-gate2-ci` at `453954f30004d1aa936e24b13016dd38668459b6` (audited 2026-10-01).  **Status of this patch: QA candidate, NOT PASS until a NEW matching-SHA GitHub Actions run has succeeded and its logs have been reviewed.**  This does **not** deploy backend code, write Firestore, upload/restore saves, grant purchases, or change Android runtime.  The existing Gate 4 read-only callable remains the only exposed route.

## What was actually changed

1. Add a **separate Linux CI job** `cloud-backend-runtime`. Existing Windows Godot 4.7.2/`PERIKSA_GAME` job is intentionally unchanged, including its 13 mocked Node boundary tests and smoke evidence artifact.
2. Install the exact direct dependencies already declared by `backend/cloud_save/functions/package.json`: `firebase-functions@7.4.0` and `firebase-admin@14.5.0`. `npm ci --ignore-scripts` must succeed. When no checked-in lockfile exists, CI first generates a candidate `package-lock.json` with `npm install --package-lock-only --ignore-scripts`. It uploads this lockfile as an artifact for review; **reproducible dependency install is NOT PASS until the reviewed lockfile is committed and a subsequent run uses `npm ci` directly**. Do not synthesize a lockfile manually.
3. `real_sdk_loading.test.mjs` imports the **actual** Firebase SDK and production ESM `index.mjs`, checks exact versions, one exported callable, and v2 trigger metadata. This is real module loading, not proof of any server deployment or Auth/App Check attestation.
4. A local, explicitly isolated `demo-jade-cloud-save-gate41` Firebase Auth + Functions emulator configuration and HTTP tests exercise an **actual running onCall route**, using only emulator-issued Firebase Auth tokens. The mock Google IdP credential is explicitly test-only; it is NOT a real Google identity. The test expects non-Google, missing auth, malformed auth, missing App Check header, forged payload, cross-account UID claim, upload/restore/purchase field attempts to fail closed.
5. The emulator job is pinned to Firebase CLI `15.28.2`, runs on Node.js 22, and does not start Firestore Emulator. There is no `.firebaserc`, no real Firebase project ID, no production credential or deploy command. A file-path denylist prevents tracked backend local credentials/caches.

## Scope of evidence, and known emulator limitation

- `GitHub Actions PASS`: package loading and local HTTP integration only after the new run. This does **not** mean an Android device can reach this function.
- `Firebase Emulator PASS`: protocol/identity/payload wiring locally. The Authentication emulator accepts **unsigned mock IdP credentials**; the Functions emulator is **not production App Check attestation**. A test App Check header value is only a local placeholder. This step cannot claim real Firebase Auth/Google OAuth or Play Integrity verification.
- `Android Native PASS`: not addressed. The installed `GodotFirebaseAndroid` wrapper currently exposes Auth and Firestore but not native Functions/App Check; do not add an HTTP workaround that posts client UID/saldo/receipt. Audit native AAR and implementation separately.
- `Full cloud integrity PASS`: not addressed. The six-domain memory snapshot is still incomplete; 8 permanent domains and a server-side verified economy ledger/revision CAS are needed. `checkpoint` remains device-local.
- `Production server PASS`: not addressed. No Firestore Rules/IAM change, Firebase Blaze, deploy, billing, Google Play receipt validation, Cloud Save write or restore.

## Expected new CI proof

Under the same new HEAD, check:

- Existing job `Godot 4.7.2 / PERIKSA_GAME`: retains `JADE_PHASE0_PASS` + total checks.
- New job `Cloud Gate 4.1 / real SDK and emulator (NO DEPLOY)`:
  - `npm ci` success; `real_sdk_loading.test.mjs` reports actual SDK import success.
  - Firebase CLI launches **both** Auth 9099 and Functions 5001 for demo project; test reaches `jadeCloudSaveCapabilities` in `asia-southeast2`.
  - Both emulator-issued Google test identities return only disabled capabilities. Missing/invalid/anonymous/email identity, missing App Check header, forged owner, purchase token, upload and restore requests are rejected with appropriate `HttpsError` codes.
  - No Firebase project credential, service account, environment secret, or player save appears in the log/artifacts.
- Download and audit `jade-cloud-gate41-lock-<run id>`; if clean, add ONLY `backend/cloud_save/functions/package-lock.json` in a subsequent explicitly scoped patch. Verify a subsequent run uses `npm ci` without generating it. Never mark reproducibility PASS from a candidate-only lockfile.

**If the emulator test fails:** do not mark Gate 4.1 PASS or adjust `enforceAppCheck` to bypass it. Review the actual SDK/CLI logs and revise the test/client or emulator integration based on observed behavior, keeping the server fail-closed. A placeholder App Check header must never be used outside the emulator QA.

## Local working-tree / production guardrails

This patch contains only new backend QA files, the added standalone CI job, and this document. It does not replace local `export_presets.cfg`, release configs, `project.godot`, gameplay scripts, plugins or native AARs. Extract under `D:\\Godot\\project\\`; do not reset/clean/merge branches; stage only explicit changed paths after `git status --short`, `git diff --check`, `git diff --cached --check` and `git diff --cached --name-status`. No direct GitHub write or deployment was performed by preparing this patch.

References:
- https://firebase.google.com/docs/functions/local-emulator
- https://firebase.google.com/docs/emulator-suite/connect_functions
- https://firebase.google.com/docs/emulator-suite/connect_auth
- https://firebase.google.com/docs/app-check/cloud-functions
- https://firebase.google.com/docs/functions/callable-reference
