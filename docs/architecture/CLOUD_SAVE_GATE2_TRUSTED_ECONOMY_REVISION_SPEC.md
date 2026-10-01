# Jade Ascendant — Gate 2: Trusted Economy Ledger & Server Revision Contract

**Status: QA-only design / server reference model. NOT a deployed backend.**
**Base:** `qa/cloud-save-gate2-ci` at `9ce1e18c73544c861ac3709bcdc2d4cc3f36971a`.
**Scope:** `tests/cloud_save_server_reference_model.gd` plus isolated regression in `tests/phase0_smoke.gd`. The model is deliberately under `tests/` and never runs in gameplay; the Android export preset excludes `tests/*`. No Firebase credentials, Cloud Functions deployment, Firestore writes, upload, restore or premium grant occurs in this pass.

## Audited source constraints

- `SaveManager` defines **eight permanent** save domains (`pavilion`, `progression`, `journey`, `achievements`, `daily_quests`, `equipment`, `inventory`, `idle_cultivation`) and **one active-run** domain (`checkpoint`). It uses local journal/batch writes; local atomicity does not establish server economic authority.
- `cloud_save_snapshot_contract.gd` currently accepts a **six-domain structural preview only**. It excludes Pavilion and Idle Cultivation, even though rewards, summons, equipment, inventory and progression have cross-domain economic dependencies. A valid draft can never itself authorize upload or restore.
- `PavilionManager` stores at most **1,024** processed grant IDs in `processed_grant_ids`, then evicts the oldest. That local list cannot prevent old purchase-token replay after restore or across devices.
- `PavilionManager.apply_verified_iap_purchase()` accepts a transaction identifier from the caller; naming a method “verified” does not independently verify the Google Play purchase token.
- `saved_at_unix` is a device clock and draft `revision: 1` is a structural placeholder. Neither is a trusted server sequence number.

## Required trusted service boundary

The backend is the **only** party permitted to: (1) validate a purchase with Google Play Developer API; (2) grant premium currency and store an append-only global deduplication key; (3) reconcile refunds, chargebacks, revocations and purchase consumptions; (4) allocate strictly increasing server revisions; and (5) commit or restore authoritative whole-account snapshots.

The Android client may submit authenticated, untrusted proposals (requested operation, expected server revision, account context) but **never** a statement that it has validated its own purchase, currency balance, entitlement, server revision or receipt. UID comes from verified Firebase Auth on the backend, not from a client-provided JSON field. App Check and security rules can complement this boundary but never replace purchase verification or transaction authority.

### Proposed Firestore server-side conceptual schema (NOT DEPLOYED)

| Logical record | Fields / semantics | Trust boundary |
|---|---|---|
| `accounts/{uid}` | `revision: int`, `state_digest`, `economy_status`, `updated_at: serverTimestamp` | Created/modified inside server transaction only |
| `purchase_ledger/{fingerprint}` | Global dedup key derived from verified package/product + Play purchase token; ownership UID; server validation outcome; refund/void status | **Never** client writable/readable; fingerprint is not a raw token |
| `accounts/{uid}/events/{eventId}` | Server-generated event identifier, kind, source verification marker, revision, sanitized product/grant and reconciliation facts | Append-only server-authorized ledger; no client write access |
| `accounts/{uid}/snapshots/{revision}` | Full reconciled permanent-domain state or server-recomputable commitments; schema/version and digest | Server-only, immutable revision; protect backups and restore policy |
| `accounts/{uid}/proposals/{requestId}` (optional) | Untrusted requests, bounded rate/size, authenticated account and expected revision | Must not become entitlements without server validation |

This is a **design sketch**, not a promise that these exact paths are final. Do not create these collections or loosen the current published Firestore Rules yet. Server Admin SDK bypasses Firestore Security Rules: restrict it using IAM and service identity.

## Atomic server transition protocol

1. Authenticate caller server-side. Establish authoritative Firebase UID independently of request payload.
2. For a purchase: consult the Google Play Developer API using a backend credential, verify package name, product ID, purchase-token state == `PURCHASED`, quantity, pending/consumption state, and entitlement eligibility. Do **not** use order ID as the sole dedup key. Only the backend derives a stable ledger key from the verified purchase token and bound product/source.
3. Within **one server-side database transaction**, look up the global ledger entry. If already applied to this UID, return its *existing result* without any second grant; if bound to another UID, reject pending account-reconciliation policy.
4. Read the account revision and compare to the caller's expected revision. If it differs, reject with a conflict response and do not mutate any state. Reserve the dedup key, update the complete reconciled state and increment revision **once** atomically.
5. Commit the event, revised state and globally unique ledger record together. On retries after a lost response, return an idempotent result rather than applying it twice.
6. A refund/chargeback/void is itself an independently identified compensating event, **not a blind local balance subtraction**. Where the currency or item has already been spent, mark account for explicit reconciliation and block further unsafe snapshots. Account deletion, ownership transfer and multi-device merge need separate policy.
7. A cloud snapshot commit is a server CAS operation on a **complete reconciled transaction boundary**; it must reject stale revisions and all attempts to replace an account with an incomplete six-domain candidate. Device-only checkpoints stay local.
8. A safe restore remains a separate gate: create local backup, present explicit player choice, verify server revision and entitlement state, apply a reversible transaction, test rollback and reconcile offline play.

## QA model / negative tests

`tests/cloud_save_server_reference_model.gd` is a **test-only in-memory reference**, not cryptographic authorization. It accepts synthetic, allegedly verified backend facts solely to exercise the proposed invariants. Production code must never import this test module as an authority.

Synthetic tests in `tests/phase0_smoke.gd` cover: foreign/guest UID, incomplete snapshot, currency-inflation proposal, active-run rejection, pending/canceled purchase, zero/negative grants, successful server-fixture grant, delayed response replay, global token ownership, stale CAS across two devices, full vs. partial domain closure, duplicate domain injection, unknown refund, verified refund hold, repeated refund, voided-token replay, blocked writes during unresolved reconciliation, >1,024 ledger events with the earliest still deduped, and no real file or network write. All snapshots and purchase keys are fake QA fixtures.

**There are no production-enabled upload/restore/grant APIs in this pass.** QA PASS means the synthetic protocol invariants are executable; it does not establish that the real backend exists or that purchase verification can run on Firebase Spark.

## Cloud plan and cost boundary

Firebase supports local emulation without a billing upgrade, but **deploying Cloud Functions for Firebase requires the Blaze plan**. This pass does not upgrade the project. Before deploying: agree on cost safeguards/budgets, IAM, service account policy, emulator tests, authorized endpoints, Play Console purchase-verification access, and production security review.

## Official references (checked 2026-10-01)

- Google Play Billing security: https://developer.android.com/google/play/billing/security
- Google Play purchases.products API: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products
- Google Play voided purchases API: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.voidedpurchases
- Firebase Cloud Functions deploy prerequisites: https://firebase.google.com/docs/functions/get-started
- Server libraries and IAM: https://firebase.google.com/docs/firestore/client/libraries
