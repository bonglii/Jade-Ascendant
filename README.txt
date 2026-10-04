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
