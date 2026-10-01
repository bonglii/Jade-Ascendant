# Jade Ascendant — Google Login entry flow / actual checkpoint

Authority: GitHub `bonglii/Jade-Ascendant`, `main` at `ea9108e1dc4962a36ba885ae16ecaecbf5490f23` **plus** the five ZIP patches applied and manually tested by the owner on desktop/Android in this conversation. GitHub main by itself does not yet contain the Google Login sources at the time of this audit.

## Runtime behavior after the final entry-gate hotfix

1. Boot invokes `GoogleAccountManager.refresh_provider()` and inspects `get_account_snapshot()["signed_in"]`.
2. Signed-in Android Firebase user goes straight to `res://scenes/ui/main_menu.tscn` via existing Celestial Gate.
3. Guest / signed-out player sees `res://scenes/ui/google_account_entry.tscn` **on each fresh game launch**. This was intentionally changed by the final `boot.gd` hotfix after a stale local flag prevented the prompt from returning on sign-out.
4. `Play as Guest` enters Home and does **not** touch gameplay save files. Google success also enters Home; Settings > Account still controls Sign Out.
5. `google_account_entry_prefs.gd` and `user://google_account_entry.cfg` still exist, but **are not used to bypass the login screen by the final `boot.gd`**. Do not reintroduce that gate by taking `boot.gd` from the older Phase 2 ZIP.
6. Cloud Save, account-based switching of local save, server purchase verification, and account deletion remain out of scope.

## Provenance, required file order

- Original Google Login Phase 1: `Jade_Ascendant_Google_Login_Phase1.zip`.
- Manager hotfix: `JADE_ASCENDANT_GOOGLE_LOGIN_SCENE_CHANGED_HOTFIX.zip`.
- Settings account-card hotfix: `JADE_ASCENDANT_GOOGLE_LOGIN_READY_SHADOW_HOTFIX.zip`.
- Login entry UI: `JADE_ASCENDANT_GOOGLE_LOGIN_ENTRY_PHASE2.zip`.
- **Final source of truth for boot**: `JADE_ASCENDANT_GOOGLE_LOGIN_ENTRY_GATE_HOTFIX.zip`.

The Gate 0 consolidation ZIP applies precisely these final versions, not the earlier `boot.gd`, `google_account_manager.gd`, or `google_account_card.gd`.

## Device QA already reported by owner

- Google account chooser, Sign In, Sign Out, restored session: PASS on an Android device.
- After the final hotfix, signed-out/Guest launch entry flow: owner reports PASS.
- Entry scene appearance on Windows/editor: separately reported (guest selection works).

## QA remaining before GitHub push/release

- Run `PERIKSA_GAME.bat` against the actual final combined local tree.
- Run Android export/deploy smoke with installed GodotFirebaseAndroid v1.1.0 and Gradle `android/build/google-services.json`.
- Verify email/account never appears in publicly shared QA logs.
- `git status --short`, `git diff --check`, `git diff --cached --check`, staged review, then user-approved commit/push only.
- Verify Google Login in a **Play App Signing** build separately; debug keystore alone is insufficient.
- Update all published Privacy Policy variants and in-game Privacy & Support. Google Play account deletion requirements require a discoverable in-app and web request path before public release.
