# Jade Ascendant — Gate 4.2A native Android bridge BUILD CANDIDATE (NO APP INTEGRATION)

**Source authority audited:** `qa/cloud-save-gate2-ci` at `3ed7fc9fcdb2da54cc7ed5ac2a9d4215293f501c`.
**Status:** New isolated Kotlin/Gradle QA source with a pure decoder regression suite; NOT Android Native PASS until GitHub compile + Android device tests.

## Production constraints kept intact

- No changes to existing `GodotFirebaseAndroid` Auth/Firestore addon, its debug/release AAR, `project.godot`, GoogleAccountManager, gameplay, `SaveManager`, export presets, local release configuration, Firebase deploy, Firestore Rules or Play purchase flow.
- This new source lives under `backend/.gdignore` and cannot be invoked from production GDScript in this pass. NO native AAR is embedded in the delivered ZIP or enabled in Godot. CI-generated AARs are *untrusted QA artifacts* until audited.
- Read-only backend route stays `asia-southeast2/jadeCloudSaveCapabilities`, with `enforceAppCheck: true`. The native entrypoint exposes `requestReadOnlyCapabilities()` with zero arguments: it has no UID, token, price, purchase token, balance, snapshot, generic route, upload, restore, grant or revocation input.
- Native method checks signed-in, non-anonymous user with a linked Google provider. The backend alone validates Firebase Auth context and current sign-in provider. A linked provider is NOT server authorization by itself. Firebase Android Functions SDK attaches Auth and App Check automatically; GDScript never receives tokens.
- Request is explicit/manual. Only limited status codes appear in `capabilitiesResult(success, code)` and no server UID, email, auth token or raw exception is logged. A failed SDK response does not modify gameplay or player saves.
- Debug variant uses Firebase App Check **debug** provider; release variant uses **Play Integrity**. Debug tokens are secrets: register only in a test Firebase project when later authorized. Never log, share, commit or ship them. Release classpath must exclude `firebase-appcheck-debug`.

## Dependency/build trade-off

- Based on the official Godot Android plugin v2 template (AGP 8.13.2, Kotlin 2.2.21, Gradle 8.14.3, Java 17), using `org.godotengine:godot:4.7.2.stable` and Firebase Android BoM 34.19.0.
- **Compatibility risk:** existing `GodotFirebaseAndroid/export_plugin.gd` pins several older Firebase Android libraries, including `firebase-auth:23.2.0`. This isolated bridge resolves its own BoM but that does **not** prove app-level dependency resolution will preserve Google login. Audit the combined export's resolved Gradle graph and Android sign-in regression BEFORE activating the AAR. Do not force a conflicting version in the game silently.
- **Startup-order risk:** initialization in `onMainCreate` is as early as this plugin can act, but plugin load order with the existing Firebase addon must be checked on an actual Android export. `isAppCheckConfigured()` signals *local factory installation only*, not a valid Play Integrity attestation. Always fail closed if initialization fails.
- No Gradle wrapper binary or credentials are included. CI uses an isolated Android SDK/Gradle runner and uploads both debug and release AARs ONLY as QA evidence. The new workflow never exports the game, accesses player data, contacts Firebase production, or performs deployment.

## Mandatory QA / path to 4.2B

1. For the new SHA on QA, inspect BOTH GitHub Actions workflows. Existing Godot 4.7.2 check must still show `JADE_PHASE0_PASS`. New native workflow must show 3/3 Node static tests PASS, four Kotlin decoder tests in both build variants, Android Kotlin build success for both variants, and release runtime dependencies without `firebase-appcheck-debug`.
2. Download compiled AAR artifact and audit class/manifest/dependency metadata before packaging a second isolated Godot integration patch. Do not check in debug token or service account key.
3. After building an Android export from unchanged local source plus approved bridge AAR, perform a focused Android native QA: Google sign in/sign out/Guest regressions; check Android singleton; valid Google account with read-only callable; anonymous and no auth rejected; no App Check attestation yields fail-closed; network failure; account switch in-flight. For true Callable + App Check live QA, a separately approved cost/IAM/deploy plan is required; emulator QA does NOT establish production attestation.
4. Retain server-side disabled capability flags. No Firebase Blaze upgrade, rule change, Firestore write, purchase grant, Cloud Save upload or restore in this gate. No merge to `main` without explicit user approval.

**STOP criteria:** Gradle SDK version collision, broken existing Google Auth, debug App Check provider in release dependency graph, missing App Check initialization, or any mutation method exposed. Resolve instead of bypassing validation.

References:
- https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html
- https://github.com/m4gr3d/Godot-Android-Plugin-Template
- https://firebase.google.com/docs/functions/callable
- https://firebase.google.com/docs/app-check/android/play-integrity-provider
- https://firebase.google.com/docs/app-check/android/debug-provider
