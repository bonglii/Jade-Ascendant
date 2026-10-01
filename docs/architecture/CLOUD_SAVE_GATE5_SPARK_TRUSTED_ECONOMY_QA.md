# Jade Ascendant — Gate 5A / Spark trusted-economy reference QA

**Source authority:** `bonglii/Jade-Ascendant`, `qa/cloud-save-gate2-ci` at `a06042f43ce55587d6439db9f3c7de742eb38915`. **Scope: synthetic Node QA + an isolated, real Firestore Emulator transaction harness. NOT a paid-reward backend, persistent production datastore, Firebase deployment or Play purchase verification PASS.** The Firebase project `jade-ascendant` stays on Spark; `main` and local gameplay/release files remain unchanged.

## Audited, consequential risks in the real game

- `release/GOOGLE_PLAY_IAP_SETUP.md`, `scripts/data/economy_catalog.gd` and `scripts/monetization/google_play_billing_provider.gd` define **six active consumable Celestial Jade packs**, with five non-identical internal-vs-Play identifiers. Server catalog must not derive real-money prices or grants from a player-supplied request.
- The existing `scripts/managers/pavilion_manager.gd` calls `apply_verified_iap_purchase(product_id, purchase_token)` when the local BillingClient says PURCHASED; the name `verified` does **not** mean the Google Play Developer API verified the token on a trusted server. Its persisted `processed_grant_ids` retains at most 1,024 entries. It is not a permanent cross-account replay ledger.
- The current Android Billing provider does **not** set a trusted account-specific `obfuscatedAccountId` before launching a purchase. Accordingly, the Gate 5 policy **requires** an independently computed, backend-owned account binding and will reject legacy/unbound purchases until a reviewed migration/ownership policy and Android Billing integration are developed. DO NOT pass a plain client UID or a client-chosen hash as the trusted binding.
- `starter_support_pack` exists in the catalog but is **not one of the six active Jade packs**; `monthly_jade_blessing` is intentionally disabled. Neither is accepted by the new server allowlist.
- Eight permanent save domains remain incomplete in the six-domain preview. An offline reference ledger cannot authorize upload/restore, premium grants, purchase acknowledgement or consumption.

## New code and tested invariants

| Component | Does | Does NOT |
|---|---|---|
| `src/economy/product_catalog.mjs` | Owns fixed package + exact six Play-to-internal product mappings and fixed Jade rewards; no prices | Accept prices, currencies, quantities or product IDs from caller |
| `src/economy/play_purchase_v2.mjs` | Provides an explicitly injected Google Play `purchases.productsv2.getproductpurchasev2` **GET** reader and strict policy: PURCHASED, matching product and account binding, exactly one item/quantity, no refund, unconsumed, supported acknowledgement, safe test-card gate; hashes token with server-only HMAC secret | Automatically contact Google, use environment credentials, produce client-visible token, grant currency or register a Firebase callable |
| `src/economy/ledger_reference.mjs` | Simulates global replay dedup, same-owner idempotent retries, token ownership conflict, revision CAS, refund tombstones and conservative reconciliation hold | Persist records, run a real distributed transaction, validate a Play void, or become an authority for actual paid purchases |
| `src/economy/firestore_gate5_emulator_model.mjs` | Separate hard-gated demo-only Firestore transaction harness: account revision, global ledger, immutable event and void tombstone committed together | Run against the live Firebase project (guarded by exact env + localhost + demo ID) or operate a production database |
| `tests/gate5_trusted_economy.test.mjs` | Real source drift checks against game catalog, Play ID adapter and release setup + synthetic negative/positive tests; simulated replay of more than 1,024 tokens | Exercise real Google Play OAuth, purchase refunds or actual spend |
| `tests/gate5_firestore_emulator.test.mjs` | Execute actual Firebase Admin SDK `runTransaction` against Firestore Emulator: grant-once, cross-UID replay, stale CAS, concurrent retries, hold/tombstone and fake-client rejection | Exercise production IAM, Play verification or real multi-device save restore |
| `firebase-gate5-emulator.json` + test-only deny-all Rules | Run Firestore only on `127.0.0.1:8080` in a demo project; deny all client reads/writes | Modify published Firestore Rules or start a live service |
| `.github/workflows/cloud-economy-gate5-qa.yml` | Independent Node 22 / Java 21 job: offline contract tests, Gate 4.3 predeploy guard, pinned Admin SDK and real demo-only Firestore Emulator transactions | Access Google/Firebase credentials, deploy or enable a mutation endpoint |

## Explicit stop conditions / production prerequisites

1. **Live Google Play Developer API access:** On a later, separately approved backend, use a dedicated service identity with Play Console rights; provide `getAccessToken()` for OAuth scope `https://www.googleapis.com/auth/androidpublisher`, a real `fetch` implementation and a server-only 256-bit HMAC key. The reader has neither credentials nor implicit fetch in Spark CI.
2. **Verified identity binding:** Derive obfuscated account ID on a trusted boundary, wire it into the actual billing flow before purchase, and define migration policy for earlier purchases lacking that binding. Never rely on the app to assert verified purchase state. Purchases currently in the user's local save must be reconciled without blind replacement.
3. **Durable atomicity:** Replace the simulation with **one actual Firestore server transaction** that reserves global token fingerprint, validates ownership, adjusts all relevant permanent domains, records a ledger event, and advances revision exactly once. Keep history beyond 1,024 transactions, and design HMAC key rotation without losing older dedup keys. A Map is not a cross-process database.
4. **Refund/void and unfinished grants:** Read actual Voided Purchases/RTDN facts server-side; record compensating events and put conflicted accounts into reconciliation hold instead of blindly subtracting spent currency. A product already consumed before its ledger entry exists is **not automatically grantable**; handle manual review/migration separately. Handle finalization (consume/acknowledge), retries, and restore in future gates.
5. **Account/retention:** Decide Google account relinking, account deletion, ledger retention and purchase ownership policy. Verify package name and correct Play Console product definitions before any paid grant.
6. **Cloud Save completeness:** Gate 6 must include eight permanent domains (especially Pavilion and Idle Cultivation) and server-issued revisions. Active run `checkpoint` stays local. Restore must be reversible before enabling write.
7. **Service/runtime safety:** Gate 4.3 remains `PRE_DEPLOYMENT_ONLY`: no Firebase project ID, billing upgrade, Firestore rule update, service-account JSON, hidden deploy, exposed purchase callable or cloud write. Never deploy without project/IAM/App Check/cost review and explicit owner consent.

## Supported Google references (reviewed 2026-10-02)

- ProductPurchaseV2 resource: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2
- ProductPurchaseV2 GET: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2/getproductpurchasev2
- Play Billing security and globally unique purchaseToken: https://developer.android.com/google/play/billing/security
- Voided purchases: https://developers.google.com/android-publisher/voided-purchases

**QA acceptance:** Gate 5A+B passes only if the actual new SHA's Gate 5 CI is green, all 19 synthetic suites **and six real Firestore Emulator suites** pass, and existing Godot/Cloud emulator QA remains green. The Firestore Emulator is in-memory and demonstrates transaction semantics, not durability across deployments; production will need actual IAM, Firestore policies, Play auth and real purchase-token/revocation integration. This **does not** pass Gate 5 production trusted economy, real purchase verification or Firebase/Play integration.
