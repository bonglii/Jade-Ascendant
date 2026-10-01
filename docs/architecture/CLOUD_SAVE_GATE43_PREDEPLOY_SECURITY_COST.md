# Jade Ascendant — Gate 4.3A: Pre-deployment safety / cost gate

**Audited authority:** `bonglii/Jade-Ascendant`, branch `qa/cloud-save-gate2-ci`, commit `cfc55e6313a7156cd468d4c659ee9ef8e8db70e3` (2026-10-02). `main` remains separate. **State: PRE-DEPLOYMENT ONLY.** No Firebase project, deployment, billing upgrade, Cloud Save upload, restore, Firestore Rules update, Play purchase validation or remote player-data operation is performed by this patch.

## What is verified automatically

- `backend/cloud_save/predeploy_gate.json` is an intentionally **blocked** local policy, not a Firebase deployment configuration. No project ID, credentials or billing details belong in it. It authorizes one *read-only* capability function, not save or economy writes.
- `backend/cloud_save/tests/predeploy_gate43.test.mjs` locks one callable export, `asia-southeast2`, `enforceAppCheck: true`, `maxInstances: 1`, zero idle minimum, 256 MiB and 10 seconds. It verifies exact all-false capability response, no caller-provided UID/balance/snapshot/purchase token, pinned Node/Firebase packages, emulator-local-only Firebase config, no deployment commands/production secrets wired in QA workflows, and separation of Android debug vs release App Check providers.
- Both Windows Godot smoke and Linux Firebase SDK/emulator jobs execute this drift test, in addition to their existing suites. All tests use synthetic request contexts. **PASS never means live production Auth, App Check, Firestore Rules, IAM, pricing, real device attestation or genuine Play purchase tokens were verified.**
- `maxInstances` restricts scaling but **is not** a billing cap. Even a read-only function can incur Cloud Run, Cloud Build, Artifact Registry, logging and network charges.

## Manual STOP conditions before the first live read-only deployment

1. **Environment separation and ownership:** Identify the intended **test** Firebase project ID through Firebase Project settings (a project ID is not a secret); verify it matches the Android `google-services.json` being installed. Never commit that private local JSON or a `.firebaserc` binding. Read and confirm the existing production project ID separately to avoid targeting it. Require explicit owner approval for the exact project and only `jadeCloudSaveCapabilities` in `asia-southeast2`. Do not deploy all functions and do not enable database APIs or player uploads.
2. **Billing and costs:** A Firebase project must use **Blaze** to deploy Cloud Functions. User approval is required before any upgrade, linking of a billing account, or paid deployment. Review the Cloud Billing estimate and set alerts at suitable thresholds. **Alerts-only budgets do not stop spending.** Google Cloud documents **spend cap budgets (Preview)** for eligible services including Cloud Run and Cloud Run functions: verify eligibility and exact product coverage in the user's own billing console; caps are not instantaneous and do not eliminate in-flight or unrelated charges. Do not assert a guaranteed zero-cost deployment. Record an explicit monthly maximum accepted by the owner; do not invent an amount.
3. **Service identity and access:** Inspect actual Cloud Functions v2 runtime service-account identity and project IAM. Prefer a dedicated, least-privilege runtime identity, with no Editor/Owner role and **no Firestore/Play Billing privilege for this read-only handler**. Any required deployment-time permissions are separate from runtime permissions. Do not ship or commit service-account JSON keys. Note: existing source does not yet explicitly bind a dedicated service-account ID; **do not deploy until the identity strategy and least privileges are reviewed**.
4. **App Check:** Confirm exact Android package/application registration and proper SHA-256/Play Integrity setup for the *release signing identity*, including Play App Signing where applicable. Android **debug** APK uses `firebase-appcheck-debug` and the release APK uses Play Integrity. A test debug token allows requests without genuine attestation; use only a controlled test Firebase project, keep tokens out of GitHub, screenshots, shared logs and public chat. If the token is disclosed, revoke it. Do not turn off `enforceAppCheck` to make a test green. A successful debug probe does **not** prove release Play Integrity.
5. **Firestore and server authorization:** Read back actual deployed Firestore Rules *from the target Firebase console*. The repository does not contain an authoritative rules file for the live project; source-only QA **cannot establish that production rules are unchanged**. Verify owner-scoped metadata `get` only, deny all client writes, and review service-account IAM separately (Admin SDK bypasses rules). Before economy writes, implement server-side Play Developer API verification, refund handling, durable token dedupe, full eight permanent domains, revision CAS, and reversible restore.
6. **Visibility and rollback:** Confirm access to Cloud Logging/Monitoring, error-rate/latency alerts, cost notifications and a documented manual disable/rollback procedure with an authorized operator. Capture baseline and post-deploy function list to avoid accidental deletions. Avoid logging UID, email, purchase tokens, App Check debug secrets or payloads. Live testing must try signed-in Google, Guest, unknown account, network loss and invalid/missing App Check with sanitized status only.
7. **Explicit gate sign-off:** The owner must approve a specific project/environment, actual spend plan, security setup and the exact deployment command **in a separate step**. `predeploy_gate.json` remains blocked until a newly reviewed change; current CI has no credential or deploy command.

## Why we cannot claim a production PASS yet

The device probe returned `CALLABLE_NOT_FOUND` with a Google session and a working bridge; this confirms Android SDK invocation reached the not-deployed state but not production App Check enforcement. Firebase Emulator QA uses emulated Google and synthetic App Check, not real attestation. The six-domain client draft is structurally useful but incomplete; Pavilion and Idle Cultivation must be reconciled into the **eight permanent domains** before any server snapshot/restore. Payment tokens and premium balance must never be trusted from the device.

## Next gate

After the new SHA passes CI, review the **actual Firebase console** and approval checkpoints above before proposing any live deployment. Do not merge to `main` or include uncommitted `project.godot`, `export_presets.cfg`, release configs, Pavilion VFX, diagnostic scripts or UID files unrelated to this gate. No project deletion, remote rules or billing changes are permitted by this patch.

**Official references (verified 2026-10-02):**
- https://firebase.google.com/docs/functions/get-started
- https://firebase.google.com/docs/functions/manage-functions
- https://firebase.google.com/docs/app-check/cloud-functions
- https://firebase.google.com/docs/app-check/android/play-integrity-provider
- https://firebase.google.com/docs/app-check/android/debug-provider
- https://firebase.google.com/docs/functions/quotas
- https://docs.cloud.google.com/billing/docs/how-to/budgets
- https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps
