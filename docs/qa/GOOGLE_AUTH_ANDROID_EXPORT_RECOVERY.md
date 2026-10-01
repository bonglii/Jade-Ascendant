# Jade Ascendant Android Google Authentication export regression — targeted correction

Source authority: main `7c9c5e7`; patch assumes Cloud Save Gate 1 read-only patch was already installed.

Root audit: the committed `project.godot` enabled GooglePlayBilling and AdMob editor plugins but omitted `GodotFirebaseAndroid`. The Firebase addon adds `/root/Firebase` via its editor plugin and exports Android AARs via its `EditorExportPlugin`. Without an enabled plugin, a new Android export may lack Firebase, while an older APK can continue working.

Changes: enable addon in `project.godot`; show existing provider failure reason in the Settings Google account card; adjust permanent Phase0 smoke so it checks the Firebase editor plugin is enabled and allows the Firebase autoload to be added by the editor.

No modification to SaveManager, purchases, Firestore Security Rules, player account/session logic, Cloud Save snapshot logic, native binaries, or local user:// saves.

Android root cause is not yet proven from a device log: if unavailable persists, the new Settings card shows a specific safe reason (Desktop build / native AAR not included / Firebase autoload absent / auth module absent). Inspect the Android export only after reading that reason; do not disable safeguards or clear user data.

Deployment: extract ZIP to D:\Godot\project\; before applying smoke patch run `git apply --check auth_export_smoke.patch`, then `git apply auth_export_smoke.patch`, then delete the patch. Reopen Godot Editor so the editor plugin can register Firebase autoload. Run PERIKSA_GAME.bat and export a fresh Android build from the existing Android Gradle preset. Install over the currently installed app (same package and signing key) without uninstalling or clearing data. No push until Android QA.

QA expectation: Google Account native readiness on Android; sign in/out; Guest; permanent progress preserved; no cloud upload/restore activated.
