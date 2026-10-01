# Gate 4.2C — Android DEBUG-only Native Functions + App Check probe

Source authority: `qa/cloud-save-gate2-ci`, `fb48f994242d7ee6b50e9a7159c57c2d024b8639`.

Files in patch: `scripts/managers/google_account_manager.gd` (additive debug-only injection), `scripts/ui/cloud_native_readonly_qa_card.gd` (new), and this QA note. The original manager was reconstructed byte-for-byte from GitHub before applying the bounded edit; original Git blob SHA was verified as `e8514e752756b8aedbe140c57024528b325c567f`. Does NOT update `project.godot`, native AAR, Firebase configuration, purchase systems, or any save domains.

## Safe device test

1. Keep existing `JadeCloudNativeBridge` Android editor plugin enabled **only locally for QA**, not committed. Export a new **DEBUG APK**, install over the existing application without clearing its data, and keep account/save data intact.
2. In Settings, sign in with Google. A separate debug-only card appears after the Account card. Press `UJI FUNCTIONS / APP CHECK` once and report **only the safe status text from the card**.
3. Check Guest / Sign-Out: probe button must be disabled. Verify local gameplay progression unchanged. For an in-flight sign-out/account change, response must be discarded. For a timeout do not retry until native callback or app restart.
4. Backend `jadeCloudSaveCapabilities` is NOT deployed: `CALLABLE_NOT_FOUND`/unavailable/attestation rejection may occur. These are NOT a successful live-server call. Only `CLOUD_DISABLED_CONFIRMED` represents a valid read-only disabled-capabilities response (not upload/restore PASS).
5. Never send Firebase Auth tokens, App Check debug tokens, UID, email, purchase tokens, logcat snippets containing credentials, or private account data. The Firebase App Check DEBUG SDK may emit a **secret debug token in Logcat** when it initializes; do not publish or register it in production. No backend deployment or billing activation is performed.

## Fail-closed requirements

- UI and native request path require Android DEBUG, a current Google session, and manual tapping.
- Native entrypoint takes **no parameters** and calls only `asia-southeast2/jadeCloudSaveCapabilities` with empty payload; SDK attaches Auth/App Check. No client UID, balances, purchases or snapshots are transmitted.
- Return statuses are allowlisted; asynchronous results are checked against private in-memory UID and session epoch, and account switch/timeout invalidates the result. A late response is never treated as a different request's result.
- Neither this helper nor the existing manager writes local save data, changes Firestore rules, deploys Functions, or enables Cloud Save.
- Godot headless QA and Android APK runtime are separate gates. Do not claim production App Check or Cloud Save capability PASS from the SDK failing against an undeployed callable.
