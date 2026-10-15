# IAP authentication receiver fix — 2026-10-16

Device evidence: App Check acquisition previously failed; after registering the existing debug token, a Treasury read returned UNAUTHENTICATED and native route doh_primary. No successful wallet response or purchase is claimed.

Concrete defect: shared jwt_verify.loadKeys called detached fetcher(url,...). Profile auth already preserves the global receiver using source.call(globalThis,...). A receiver-sensitive Cloudflare fetch can throw Illegal invocation before Google signing keys are downloaded; the IAP path collapses that into InvalidIdentity/401. Restore fetcher.call(globalThis,...) while retaining fixed JWKS URLs, manual redirects, timeout and cryptographic checks. This is a reproducible defect consistent with the device symptom; only a deployed device retry can establish that it was the sole live cause.

Evidence:
- New default-fetch regression with actual signed Auth and App Check JWTs failed before the fix with InvalidIdentity and passed afterward. It also checks no account request headers/body go to signing-key endpoints.
- Backend 423/423 pass after fix; all player identity/dashboard tests 74/74 pass.
- Additional profile suite exposed two stale expectations of four banner weapons. Assert the exact five supported IDs and preserve selected category behavior; no catalog/gameplay change.
- Isolated Godot runtime loads Settings and checks its support report against actual V2 readiness; PASS with no ERROR output. A prior standalone --check-only attempt could not resolve an autoload singleton; it was replaced by this actual runtime check rather than claimed as a passing parse check.

Other bundled fixes:
- Read-only staging SELECT uses --command instead of the remote SQL-file ingestion path. Never auto-confirm an import for readiness.
- Copy Support derives Purchased gameplay ready from the live V2 lease, replacing hardcoded false. Existing app needs an eventual re-export only for this reporting correction; backend auth recovery does not require a new APK/AAB.
- Profile CI runs all current tests and is triggered by changes to the shared JWT verifier.

No native source, AAR, Play configuration, production lock, game balance or player save change. No deployment or purchase performed here. Latest GitHub CI for this new source is pending publication. Previous 19f8859 IAP/Premium CI passed.

Next: apply/publish, deploy_iap_gameplay_staging.cmd, check_iap_staging_schema.cmd, then open Treasury and collect support. Confirm schema, refund freshness and wallet response before any new checkout. If still rejected, retain error evidence rather than logging out or buying again.
