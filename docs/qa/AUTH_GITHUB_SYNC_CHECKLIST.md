# Google Login — GitHub source alignment / NO AUTO COMMIT

Audit `main` commit `ea9108e1dc4962a36ba885ae16ecaecbf5490f23` has **none** of the login manager, card, entry UI, or GodotFirebaseAndroid addon. The owner has separately tested all of them locally after applying five successive patches. This packet consolidates the last proven file versions and does NOT claim GitHub is already synchronized.

## What this ZIP actually contains

- Last tested Google auth manager, Settings account card, entry UI/script/prefs, and the **final entry-gate** `boot.gd`.
- Corrected Phase 1 and Phase 2 QA documentation.
- `.gitignore` addition to exclude the addon-local `google-services.json`; `/android/` was already ignored by the pinned main baseline.
- Cloud Save Gate 1 architecture **documentation only**.
- NO `project.godot`, NO native Firebase addon/AAR binaries, NO `google-services.json`, NO APK/AAB, NO signing keys, NO Cloud Save code, NO economy or gameplay changes.

## Safe local staging workflow (Windows CMD from project root)

Stop Godot; first verify the actual branch and every local modification:

```
cd /d "D:\Godot\project\jade-ascendant"
git branch --show-current
git status --short
git diff --check
```

Apply this ZIP **only** if the local Google Login sources still correspond to the previously approved/passed patch chain. It can be skipped for already-identical files: its purpose is to publish an exact canonical set later, not to replace different current local source blindly.

Use path-specific staging after reviewing `git status --short` and `git diff`:

```
git add .gitignore project.godot scripts/system/boot.gd scripts/managers/google_account_manager.gd scripts/managers/google_account_entry_prefs.gd scripts/ui/google_account_card.gd scripts/ui/google_account_entry.gd scenes/ui/google_account_entry.tscn docs/GOOGLE_LOGIN_SETUP.md docs/qa/GOOGLE_LOGIN_ENTRY_FLOW.md docs/qa/AUTH_GITHUB_SYNC_CHECKLIST.md docs/architecture/CLOUD_SAVE_GATE1_AUDIT.md
```

**Native addon is manually installed on owner's machine**, not in this ZIP. Verify LICENSE/binary provenance for v1.1.0 and then selectively stage actual distributable runtime files under `addons/GodotFirebaseAndroid/` while EXCLUDING addon `google-services.json`. Don't commit service account JSON, private keys, user email data, or app-store credentials. Confirm output of `git status --short`, `git diff --cached --stat`, `git diff --cached --check`, `git diff --cached --name-only` and `git check-ignore -v addons/GodotFirebaseAndroid/google-services.json` (should be ignored). `project.godot` must retain **both** manually configured autoloads: `Firebase` and `GoogleAccountManager`, and existing AdMob/Billing autoloads/editor plugins. DO NOT replace `project.godot` from the old Phase 1 ZIP because owner enabled Firebase manually afterward.

Run `PERIKSA_GAME.bat` and Android device QA on the resulting staged working tree; review and reconcile local `export_presets.cfg`, `release/*` and Pavilion script modifications listed in previous handoff rather than staging wholesale. Do not call the build release ready until updated public/in-game Privacy Policy, Data Safety, in-app+web account deletion request, Play App Signing SHA and backend purchase verification have independent QA.

**Do not commit/push yet** without owner approval of final diff/QA. Prior handoff states active branch may be `checkpoint/home-meditation-lab-safety-20260928`, not `main`; after approval use the actual branch context rather than assuming `git push origin main` is correct.
