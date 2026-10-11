# Jade Ascendant — Verified Play purchase repair, source-only

## Why this exists

A Google Play consumable can be verified and consumed by the backend, then fail before its paid wallet credit or canonical summon onboarding is delivered. After consumption, Android's ordinary query of outstanding purchases may no longer return the original token. A replay route that requires the device to supply that token is therefore insufficient for **a durable grant_ready record**.

`POST /v1/iap/recover-verified` repairs only purchases that **already exist in the trusted server ledger in state `grant_ready`**. It derives immutable event IDs, product IDs, and amounts from the ledger, reuses the existing refund-aware wallet credit, and performs idempotent canonical onboarding. The request is an authenticated, bodyless POST using Firebase Auth + App Check. It accepts no token, item, amount, stage clear, wish, or RNG from Android. The response contains counters, not local spendable currency or a grant.

## Exact protection rules

- Requires **both** `JADE_IAP_BACKEND_ENABLED=true` and new `JADE_VERIFIED_PURCHASE_REPAIR_ENABLED=true`; both are OFF/absent by default.
- Worker candidate entrypoint is `src/worker_release_candidate.mjs`. The deployed `wrangler.toml` still points to `src/index.mjs`; no production deployment or flag change.
- 0010 is a **staging-only** functional index on ledger's owner/state. Do not apply migrations remotely before review.
- Validate **every** selected record before any credit. Fail on invalid owner binding, mismatched internal/Play product, grant/key mismatch, corrupt JSON, or unexpected status.
- The real `d1_wallet.mjs` performs idempotent credit under an atomic refund/hold/freshness SQL guard; never implement a second wallet mutation path.
- Canonical onboarding preserves preexisting server progress/pity/inventory; never use local `journey.save`, `pavilion.save`, or `inventory.save` as evidence.
- Maximum 32 verified purchases per request. More requires an audited paging design/support, **not** silent truncation or partial replay.
- A `verified_pending_consume` ledger entry **cannot** be repaired without recovering the original token and re-checking Play consume status; this path explicitly leaves it unresolved. Android Keystore protected recovery of tokens or a strictly audited backend pending-consume repair is still a release blocker.

## Native integration (not yet merged or built)

`VerifiedPurchaseRepairContract.kt` handles only the strict response contract. `patches/native_repair_patch.json` describes the gated new method/signals **after** RC6 native transport is merged. `patches/pavilion_manager_repair_patch.json` describes the account-bound Godot callback. `scripts/ui/paid_summon_surface_rc5.gd` includes a hidden-by-default recovery action. Approval flags stay false in Kotlin and Godot. All three pieces need a reviewed merge into the user's real checkout and an Android build before device QA. These JSON patch rules are reference data, **not auto-executed scripts**.

## Local validation in assistant fixture

- `node --test tests/verified_purchase_repair.test.mjs`: **16/16 PASS** using Node SQLite, real patched wallet module, canonical onboarding, and actual staging D1 schemas with a local test-only signed identity stub. This does not assert Cloudflare Worker or Play live status.
- Kotlin contract source compiles with the existing RC6 test-only `org.json` API stub. This is not Android Gradle/AAR validation.
- Worker full import and Android-Godot linked build **have not yet been run**.

## Next physical release blockers

1. Trusted remote battle result adjudication. Current victory screen writes local progress and is not authoritative. Do not sign arbitrary local victory events.
2. Integrate all candidate Kotlin and Godot code into one Android build, including secure token handling for `verified_pending_consume` recovery; test with actual Play testers on two devices.
3. Real RTDN, Google Play sandbox/voided purchases, remote D1 staging migrations, monitoring and release gates.
4. Confirm release approval before touching main/remote D1/prod Worker or turning on IAP.

No commit, push, deployment or save edits were executed by this archive.
