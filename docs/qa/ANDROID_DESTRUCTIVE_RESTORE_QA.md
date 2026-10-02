# Android Destructive Restore QA

Status: **DEVICE REWORK**. Two physical-device attempts have failed closed before destructive case 1. The second attempt proved the exported APK reached the QA runner but `OS.has_feature("android")` returned false on this runtime, so Android platform detection is being moved to `OS.get_name() == "Android"`. Re-run is required after this guard hotfix passes CI.

This gate validates Android process lifecycle behavior for Jade Ascendant's already CI-proven registered-path transactional restore. It does **not** enable production cloud restore, upload, automatic sync, or Firebase writes.

## Safety model

The tracked production project remains disconnected from this harness:

- `tests/*` is excluded by the production Android export preset.
- `project.godot` does not reference the QA scene or QA bootstrap.
- `scripts/managers/cloud_registered_path_restore_qa.gd` remains editor-only in tracked source.
- `tools/android_restore_device_qa.ps1` creates a disposable project from **`git archive HEAD`**, never from the working tree.
- Only inside that temporary archive, the tool:
  - selects the Android QA scene as main scene;
  - injects a startup write barrier immediately after `SaveManager`;
  - adds the disposable export feature `jade_android_restore_qa`;
  - requires `OS.get_name() == "Android"` + Android **debug** + that export feature + the exact QA main scene before destructive code can run;
  - binds the runner to the exact 40-character `git HEAD` embedded only in the disposable workspace;
  - exports a package with the `.restoreqa` suffix;
  - redirects Firebase, Google account, and monetization autoload names to an offline stub;
  - disables editor/export plugins;
  - includes `tests/android/*` in the QA APK.
- The temporary archive is deleted after audit/build.
- The normal Jade Ascendant package and its `user://` data are not installed over or opened by this test.

## First physical-device attempt

The first `BuildRun` attempt failed closed before case 1 with:

```text
JADE_ANDROID_RESTORE_DEVICE_FAIL | case=bootstrap | step=unknown | note=QA package is not correctly armed
```

No destructive restore case started. The original arming model depended on custom `ProjectSettings` values in the exported APK but did not identify which runtime predicate failed. The first hotfix removed those custom settings as an authority and added the disposable export feature plus exact HEAD binding. The second device attempt then failed closed with `NOT_ANDROID`, proving `OS.has_feature("android")` is not reliable for this exported runtime. The next guard uses `OS.get_name() == "Android"` consistently in the runner, startup bootstrap, and disposable restore activation patch while retaining debug-build, export-feature, QA-main-scene, isolated-package, and exact-HEAD requirements.

## Device cases

The QA application runs ten deterministic cases using the eight exact permanent paths from `SaveManager`:

1. Apply → Android force-stop → restart → rollback.
2. Apply → Android force-stop → restart → confirmation.
3. Force-stop after primary is moved to restore rollback storage.
4. Force-stop after candidate promotion on a middle domain.
5. Force-stop after all domain replacements but before terminal decision.
6. Force-stop during restart-driven whole-account rollback, then recover again.
7. Force-stop during explicit manual rollback, then recover again.
8. Restart under a foreign owner and verify fail-closed account binding before the correct owner resolves it.
9. Corrupt a candidate and verify no registered primary mutation occurs.
10. Create an active checkpoint and verify restore preimage preparation is blocked.

Every destructive boundary must retain existing `.backup` sidecars and must converge to either all-preimage or all-candidate state—never a mixed eight-domain state.

## Running after CI PASS

From PowerShell or CMD on a Windows development machine with Godot 4.7.2 export templates, Android SDK Platform Tools, and one connected debug-enabled Android device:

```powershell
powershell -ExecutionPolicy Bypass -File tools/android_restore_device_qa.ps1 -Action BuildRun
```

Optional explicit paths/device:

```powershell
powershell -ExecutionPolicy Bypass -File tools/android_restore_device_qa.ps1 -Action BuildRun -GodotPath "C:\path\Godot_v4.7.2-stable_win64_console.exe" -DeviceSerial "SERIAL"
```

The controller installs only the `.restoreqa` package. It clears logcat, launches the QA app, waits for exact `JADE_ANDROID_RESTORE_FORCE_STOP` markers, performs `adb shell am force-stop`, relaunches the app, and continues until PASS or FAIL. A PASS marker is rejected if its embedded HEAD does not exactly match the committed HEAD used to build the APK.

## PASS evidence

A device PASS requires both files:

- `artifacts/android-restore-device-qa.log`
- `artifacts/android-restore-device-qa-summary.json`

The summary must contain `"status": "PASS"` and the log must contain:

```text
JADE_ANDROID_RESTORE_DEVICE_PASS
```

CI cannot satisfy this gate because the CI workflow deliberately performs **NO APK / NO DEVICE** execution.

## What remains locked after this gate

Even after device PASS, production Firebase-to-local transfer remains locked until a separate controlled-cloud-transfer phase wires a validated account-bound snapshot into candidate files and requires an explicit restore decision. Automatic cloud-wins behavior remains prohibited.
