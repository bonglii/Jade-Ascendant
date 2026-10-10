JADE ASCENDANT
==============

Jade Ascendant is a portrait Android xianxia action game built with Godot 4.7.2.

CURRENT RELEASE IDENTITY
- Package: com.yungdevstudio.jadeascendant
- Version: 1.0.4
- Version code: 4
- Android minSdk: 24
- Android targetSdk: 36
- Architecture: arm64-v8a
- INTERNET permission: enabled
- VIBRATE permission: enabled

CURRENT PRODUCT TRUTH
- Gameplay progress is stored locally on the device.
- Google Sign-In is optional; Guest mode remains available.
- Google Login establishes identity only. It does not back up, download, merge,
  switch, or restore gameplay progress.
- Optional rewarded ads use Google Mobile Ads. Google UMP is used for applicable
  privacy choices.
- Optional Celestial Jade purchases use Google Play Billing on supported Android
  builds.
- The current billing client trusts purchase state/token delivered by Google Play.
  Production server-side purchase-token verification is not integrated yet.
- Production Cloud Save, cloud restore, automatic restore, cloud-wins behavior,
  cloud writes, and server economy writes remain disabled/fail-closed.
- Cloud production activation requires explicit human approval.

CANONICAL CHECK / RELEASE ENTRYPOINTS
- PERIKSA_GAME.bat    : Godot production smoke/check entrypoint.
- PERIKSA_ANDROID.bat : Android/AdMob release preflight.
- SIAPKAN_RILIS.bat   : publisher/release configuration flow.
- BUAT_AAB.bat        : guarded Android AAB release build entrypoint.

SOURCE AUTHORITY
The canonical source is the tracked Git repository at an exact commit SHA.
Old ZIPs, historical handoffs, generated artifacts, APK/AAB files, local caches,
and machine-local build state are not source authority.

See:
- docs/release/CANONICAL_SOURCE.md
- docs/release/PLAYSTORE.md
- docs/release/STORE_LISTING.md
- release/GOOGLE_PLAY_IAP_SETUP.md
- docs/GOOGLE_LOGIN_SETUP.md
- docs/architecture/CLOUD_SAVE_PRODUCTION_APPROVAL_BOUNDARY.md

IAP ARCHITECTURE DECISION - HYBRID NOW, FULL MIGRATION LATER
Decision recorded: 2026-10-10
Status: APPROVED DIRECTION; PRODUCTION IAP STILL LOCKED

CURRENT STRATEGY: OPTION A - HYBRID
- Use Firebase Spark for identity/App Check and Cloudflare Workers Free + D1
  for server-side purchase verification and the paid-currency ledger.
- Preserve offline gameplay, existing local chapter progress and local saves.
- Keep free/earned Celestial Jade distinct from paid Celestial Jade in the
  implementation, even if the storefront UI presents a unified balance.
- All credit, debit, and summon fulfillment involving PAID Celestial Jade
  must be authorized, idempotent, auditable, and recoverable on the server.
- Never treat a local save, claimed chapter completion, client-supplied Jade
  amount, or client-generated reward as trusted server-side proof.
- The exact rules for mixed paid/free currency spending, pity, inventory
  delivery, and cross-device recovery must be designed and tested before IAP
  production activation. Hybrid is NOT permission to skip those safeguards.
- Online connectivity is required for paid-currency transactions. Ordinary
  offline progression should remain playable where currently supported.

CURRENT IMPLEMENTATION CHECKPOINT (AS OF 2026-10-10)
- Cloudflare Worker and D1 are configured; the public authorize route has
  returned HTTP 503 with purchase_backend_disabled while locked.
- Android Cloudflare Native Bridge was built and packaged in a QA AAB.
- Wallet source stages M1-M5 passed 65 local tests. Staged source modules are
  NOT the same as a deployed, fully integrated, production-safe economy.
- Production wallet migrations, credit/debit cutover, trusted progression,
  client wallet synchronization, and Android purchase end-to-end testing
  remain incomplete.
- Keep JADE_IAP_BACKEND_ENABLED=false and
  SECURE_PURCHASE_ACTIVATION_APPROVED=false until explicit approval after
  security review and real-device/Google Play test verification.
- Never commit or upload private service-account JSON, tokens, or keystores.

FUTURE PLAN: OPTION B - FULL SERVER-AUTHORITATIVE MIGRATION
Status: DEFERRED - WAITING FOR SUFFICIENT FUNDING
- Do not begin full migration just to finish the current IAP release.
- Revisit when budget exists for server capacity, operations, monitoring,
  backups, maintenance, and sustainable usage beyond free-tier limits.
- Future scope: server-authoritative full Celestial Jade balance, chapters,
  player progression, inventory/equipment, pity/summon results, cloud saves,
  recovery, and multi-device synchronization.
- Plan a gradual migration with data integrity checks, backups, account
  reconciliation, staged rollout, and a rollback strategy. Never discard or
  silently overwrite players' existing progress.
- Starting this migration requires a new explicit project decision and
  budget approval; it is NOT an automatic consequence of enabling IAP.
