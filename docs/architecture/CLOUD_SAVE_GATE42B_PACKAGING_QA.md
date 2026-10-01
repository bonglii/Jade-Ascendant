# Gate 4.2B — Android bridge package candidate (DISABLED by default)

**Source authority:** `qa/cloud-save-gate2-ci` commit `95b2ef42efcab588fd20268750576d7bb4bcd965`.
**Prerequisite:** Native build run `36889884706` and Godot/backend run `36889901882` PASS.

This patch packages BOTH inspected AAR variants from the exact GitHub Actions build artifact; hashes are asserted in Node QA. Android manifests contain `org.godotengine.plugin.v2.JadeCloudNativeBridge`, Kotlin bridge and App Check classes exist in both AARs, and the release bytecode references `PlayIntegrityAppCheckProviderFactory` rather than the debug provider. No credentials, provider token, or data are bundled.

**Do not enable the new editor plugin yet.** `project.godot` is intentionally NOT changed; installing these files cannot replace the existing Android Firebase provider or activate the new bridge. The existing Firebase Auth AARs, Google Account manager, SaveManager, purchase code, Firestore Rules, and production configuration are untouched.

Export metadata pins the exact BoM 34.19.0 versions used to build native source:
- firebase-auth:24.2.0 (existing addon pins auth:23.2.0)
- firebase-functions:22.1.1
- firebase-appcheck-playintegrity:19.4.1 (release)
- firebase-appcheck-debug:19.4.1 (debug only)

Official BoM mapping: https://firebase.google.com/support/release-notes/android (September 09, 2026).

The updated isolated CI performs a preliminary Gradle conflict-resolution simulation using the exact existing Firebase addon Maven declarations and proposed new plugin pins; it asserts that the legacy Auth pin is promoted to 24.2.0 and checks no debug provider is selected in the release graph. This **does not establish real app package compatibility or Google Sign-In functional compatibility**. Neither can be marked PASS without an Android game export and device checks. CI also checks both packaged AAR manifests and the release provider bytecode. Its artifact is only QA evidence.

Next after this patch's CI PASS:
1. Enable new plugin from Project > Project Settings > Plugins on a QA working copy; check `project.godot` enabling entry and Android Gradle build. NO silent Firebase config changes.
2. Verify real Android sign-in/out, Guest, Firebase state, plugin singleton and a strictly manual callable attempt. No live callable success is expected without an approved backend deployment. Do not register App Check debug tokens outside a test project.
3. If integrated app-level Gradle, R8, Play Integrity, or login fails, DISABLE the new plugin and fix the mismatch; do not tamper with local saves.
4. The backend callable remains server-enforced read-only, all mutation flags false. No player upload, restore, grants, Firebase deploy, or merge to main.
