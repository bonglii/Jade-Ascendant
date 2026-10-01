# Jade Ascendant — Google Login integration / activation checklist

## What this patch actually does

- Adds `GoogleAccountManager` to `project.godot` and inserts an Account card into the *existing Settings screen* at runtime. It does not replace or reorganize any approved UI files.
- Wires `Continue with Google`, native success/failure, restored Firebase login, and `Sign Out` to the Android Firebase Auth plugin API.
- Safe fallback on Windows/editor/iOS or missing Android plugin: Google login stays disabled; guest gameplay continues normally.
- **Does NOT** upload, download, relink, merge, or overwrite local gameplay data. Does NOT activate Cloud Save, purchase verification, or premium entitlement restoration.
- No secrets, server keys, Google OAuth JSON, new currencies, or automatic anonymous Firebase accounts are included.

## Required ONE-TIME setup — by project owner, before Android login can work

1. Keep the existing Android package ID from the checked-in export preset: `com.yungdevstudio.jadeascendant`. If your real current *local* export preset differs, stop and reconcile it first; the Firebase Android package and export package MUST match.
2. Create a Firebase project at https://console.firebase.google.com (the Spark free tier is sufficient for initial Authentication testing).
3. Firebase Project Settings > Your Apps > register an **Android** app with `com.yungdevstudio.jadeascendant` (or your reconciled final package).
4. Add the SHA-1 fingerprint of your **debug keystore**, release keystore, and Google Play **app signing key** as appropriate. Android Play App Signing SHA can differ from the upload keystore. The Google login callback may fail with `DEVELOPER_ERROR` if the package or signing SHA is mismatched.
5. Firebase Authentication > Sign-in method > enable **Google**. Download a **fresh** `google-services.json` *after* setting Google sign-in and the SHA-1 fingerprints so it includes `default_web_client_id`.
6. Install and enable the external **GodotFirebaseAndroid** addon. This patch targets the documented `Firebase.auth` API of **SomniGameStudios/godot-firebase-android v1.1.0**:
   - Source/release: https://github.com/SomniGameStudios/godot-firebase-android/releases/tag/1.1.0
   - From the release archive, install the addon folder as `res://addons/GodotFirebaseAndroid/`.
   - Godot > Project > Project Settings > Plugins > enable `GodotFirebaseAndroid`.
   - The addon should create an autoload named **Firebase**; verify this in the project's Autoload list.
   - This **third-party native addon/AAR is not in the patch ZIP**. Its license, binary source/provenance, and suitability for your Play distribution should be reviewed before release.
   - The inspected v1.1.0 native implementation uses the older `GoogleSignInOptions` API. Google’s current Android guidance uses Credential Manager. Treat this as an integration candidate that MUST pass real device / target SDK 36 QA, not as a guaranteed production-ready identity SDK. If the native sign-in fails or cannot be maintained securely, replace only the native adapter while keeping the game’s account/UI and SaveManager boundaries.
7. Install the Firebase app configuration at **`res://android/build/google-services.json`**, the path expected by the audited GodotFirebaseAndroid v1.1.0 export plugin. Its export plugin checks this path; it **does not** automatically copy the JSON from `res://addons/GodotFirebaseAndroid/`. Create/install the Android Build Template first, then copy your downloaded JSON to `android/build/google-services.json`. Keep the addon-local copy only if needed as an installation source.
   - Do not send this file, service-account JSON, keystores, access tokens, or API credentials into chat.
   - Never distribute a service-account PRIVATE KEY in the client. The ordinary client `google-services.json` is public client configuration rather than an admin secret, but avoid unnecessarily publishing your instance's config outside the built app.
8. Godot > Project > Install Android Build Template (if not installed); Project > Export > Android > Use Gradle Build **ON** (already enabled in the audited GitHub export preset). Verify coexistence with existing Google Play Billing and AdMob/UMP addons. Android min SDK/target SDK, Google services Gradle plugin, dexing, manifest merges, and release R8 need device/export QA.
9. Reopen project after enabling the plugin, then export and install on an Android device with Google Play services. In Jade Ascendant > Settings > Account, use **Continue with Google**.

## Mandatory QA matrix

- **Editor/Desktop:** Settings opens normally, shows Account card, login disabled with an honest Android-only message; gameplay and `SaveManager` untouched.
- **Android without addon/config:** game opens; guest can continue; no fake connected status and no crash.
- **Android with addon:** manual Google Sign-In flow opens, success shows connected account display name. Relaunch: Firebase may restore the auth session. Sign Out changes Account status to guest **without deleting local gameplay save**.
- **Cancel/sign-in fail/airplane mode:** operation resolves as error/timeout, no false login, local gameplay works.
- **Guest with existing Hero / Journey / Pavilion / purchases:** sign in, sign out, reopen, recheck the exact local progress; no save domain changes or silent account-based switching.
- **Devices / signing:** debug, upload/release and Play-distributed build must each use matching registered SHA-1; do not interpret success in a debug APK as proof the release AAB works.
- **UI/scroll:** 648x1152 and 405x860, safe area, swipe over the account button, Account card remains readable, no accidental taps while scrolling.
- **Native integration:** collect Godot log and `adb logcat` if Google returns an error; do not paste ID tokens or email addresses into public logs.

Run `PERIKSA_GAME.bat` and `PERIKSA_ANDROID.bat` locally after extracting. **Neither has been run in this sandbox**; only source/contract checks can be performed here. Android manual login is NOT QA PASS until you test it on device.

## Release blocker: privacy and Data safety

Existing `release/privacy-policy.html` and `release/privacy-policy.template.html` were audited: they currently say that the app does not provide player accounts. That wording **must be updated before shipping an Android build with working Google Login** to disclose Firebase Authentication, which account fields are processed, whether data reaches publisher infrastructure, retention/deletion processes, and appropriate third-party references. Confirm Google Play Data safety disclosures from the exact native SDKs and actual data flows. The policy files are intentionally NOT overwritten by this patch because release files may be newer in the owner's uncommitted working tree. Do not mark this pass RELEASE READY yet.

## Future cloud-save boundary (NOT included)

Keep `SaveManager` and all existing save-domain ownership. Before Cloud Save: design account-link flow, data/snapshot versioning, restore/merge conflict UI, trusted server-side purchase verification, premium currency/transaction ledger, and migration of guest data. Never assume successful Firebase Login means the player data is safely backed up.

## References

- Firebase Android Google sign-in: https://firebase.google.com/docs/auth/android/google-signin
- Firebase Android setup / SHA-1: https://firebase.google.com/docs/android/setup
- Godot Firebase Android addon: https://github.com/SomniGameStudios/godot-firebase-android
- Godot Android Plugin v2: https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html
