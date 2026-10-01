# Jade Ascendant — Gate 4: Trusted Backend Boundary (PRE-DEPLOYMENT)

**Base:** GitHub `qa/cloud-save-gate2-ci` at `6975d30f161f7c8f9877905f20937d0b0c657ef7`.
**Status:** Node 22 read-only Cloud Functions v2 entrypoint scaffold + executable synthetic security QA. **NO Firebase deployment, backend purchase verification, writes, save upload, restore, IAP payout or rules changes.**

## Dependency audit and source-of-truth

- Android Firebase plugin already supplies client-side Auth and read-only Firestore manifest inspection. `GoogleAccountManager` reports live non-anonymous identity but is **not** a trusted server verifier.
- `cloud_save_snapshot_contract.gd` validates a **six-domain** in-memory candidate, and Gate 2 established that such a candidate is **not** economically transaction-closed. Gate 3 creates SHA-256 structural diagnostics, not a signature.
- `tests/cloud_save_server_reference_model.gd` represents desired ledger/CAS invariants; it cannot verify real purchase tokens or allocate a real revision.
- Active Billing packs in `release/GOOGLE_PLAY_IAP_SETUP.md`: canonical game ID differs from Play product ID for 550/1,200/2,500/6,500/14,000 Jade packs. Future verification must consult an independently defined server-side allowlist, not accept claimed product IDs or price from the client.
- Existing Firestore rules allow only the authenticated owner to **get** a metadata document. All writes stay denied. No new Firestore collection is created or queried in this pass.
- Audited tracked Android `export_presets.cfg` uses `all_resources` with a narrow non-resource `include_filter` (`release/publisher_info.cfg`). The new `backend/.gdignore` prevents editor indexing of server sources. The user's **local** `export_presets.cfg` has unrelated uncommitted changes, so actual Android package membership must be reverified separately before release. Do NOT stage/overwrite the local export preset for this gate.

## Implementation and trust boundary

| Source | Responsibility | Never does |
|---|---|---|
| `backend/cloud_save/functions/src/read_only_policy.mjs` | Validate *Firebase callable-runtime provided* identity, reject non-Google/anonymous sessions, reject ALL client payload fields, answer fixed read-only capabilities | Accept client UID, balances, purchase tokens, revision or arbitrary snapshot |
| `backend/cloud_save/functions/src/callable_factory.mjs` | Register exactly one callable, enforce App Check, map known policy failures to sanitized `HttpsError` codes | Register upload/restore/purchase/ledger or invoke Admin SDK |
| `backend/cloud_save/functions/index.mjs` | Actual Firebase v2 callable entrypoint for a later separate deployment step | Configure project, deploy automatically, read or write Firestore |
| `backend/cloud_save/functions/package.json` | Declare Node.js 22 and pinned Firebase Functions/Admin SDK dependencies (not installed; Admin not imported) | Install dependencies in this pass |
| `backend/.gdignore` | Keep backend files out of Godot editor indexing | Guarantee arbitrary custom Android export filters omit them; release packaging still requires verification |
| `backend/cloud_save/tests/*.test.mjs` | Unit tests for pure boundary logic and mocked callable registration | Claim a genuine Firebase Auth/App Check/Play receipt integration test |
| `.github/workflows/godot-smoke-qa.yml` | Install Node 22, run backend tests **before** existing Godot 4.7.2 smoke | Deploy infrastructure or load production credentials |

Callable entrypoint **requires App Check** (`enforceAppCheck: true`) and uses authenticated Firebase `request.auth` as its identity authority, not `request.data`. The Google provider/identity claims are inspected, but no credential is verified by our pure-policy unit test: Firebase Functions must supply genuinely authenticated context after deployment. The handler returns no UID, token, player payload, cloud data, timestamp, or economic assertion.

Only `jadeCloudSaveCapabilities` is exported as a callable. The return value says `cloud_write_enabled=false`, `cloud_restore_enabled=false`, `purchase_verification_enabled=false`, `economy_verified=false`, `server_revision_verified=false`, and `server_freshness_verified=false`. The explicit `rejectCloudMutation` guard has no deployed entrypoint and always throws.

**Important:** This is **not** an actual deployed backend. The helper `createCallableHandlers` uses dependency injection to allow tests to exercise the route wiring without Firebase credentials or an npm install. Firebase SDK *module loading*, real Firebase Auth claims, enforced App Check, and network operation are **not** tested by this step. A future isolated emulator + dependency-install QA pass must prove those separately.

## QA coverage / negative cases

- No authenticated context; malformed UID; missing identity claims; anonymous/password/custom login; non-Google account.
- Client attempts to submit `uid`, `owner_uid`, revision, snapshot, checkpoint, currency, premium grant, purchased flag, entitlement list, or purchase token — all rejected including claimed same-owner UID.
- Non-object inputs, null, arrays, prototype-inherited data and proto-key injection are rejected; only empty plain record accepted.
- Handler exposes only one read-only callable; uses App Check enforcement, limited instances, Jakarta region; sanitizes errors via Firebase `HttpsError`.
- Response cannot be mutated by a caller to change flags in subsequent calls; fail-closed mutation guard always rejects.
- Tests use **fake identity claims** and operate without player files, Firebase network, or Google Play APIs.

## Before ANY Cloud Save deployment / monetization writes

1. Audit compatibility of GodotFirebaseAndroid 1.1.0 with callable Functions and App Check. Existing plugin does not establish that an authenticated callable can be invoked; it may require a controlled native adapter change. Do not try calling this from current gameplay yet.
2. Add explicit Firebase project configuration, pinned lockfile, isolated Emulator Suite setup, an authenticated integration test with valid and denied user sessions, App Check verification, cost controls, monitoring/IAM and a deployment review. Never add service-account keys to repository.
3. Implement independent Google Play Developer API purchase-token verification, complete product allowlist, refund/void reconciliation, and a durable global deduplication ledger **before any paid reward** is granted by a server.
4. Implement complete **eight-domain** reconciled account state, server-issued monotonic revisions and CAS, backups, account deletion and offline conflict policy. Do not move the six-domain preview across devices.
5. Implement user-consented, reversible local restore with backup and rollback QA; adjust Firestore access only after a security review. Keep guest/local progress unchanged.

Cloud Functions deployment requires the Firebase Blaze plan; this patch does **not** request, enable or bill it. App Check reduces abuse but is not purchase/ledger authorization. The current published Firestore read-only Rules remain untouched.

Official references: https://firebase.google.com/docs/functions/callable ; https://firebase.google.com/docs/app-check/cloud-functions ; https://firebase.google.com/docs/functions/get-started ; https://developer.android.com/google/play/billing/security .

**Delivery:** ZIP contains only the changed/new paths under `jade-ascendant/`. Extract into `D:\Godot\project\` while on `qa/cloud-save-gate2-ci`. Stage only explicit paths, audit `git diff --cached --check` and the staged list, then commit/push only to QA. Green GitHub Actions proves Node boundary tests and existing Godot smoke; it does NOT prove deployed Firebase or Android runtime.
