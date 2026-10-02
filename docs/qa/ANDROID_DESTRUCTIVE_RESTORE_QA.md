# Android Destructive Restore QA

Status: **DEVICE REWORK**. The sixth physical-device run from `19afe1f` proved the foreground relaunch fix through cases 1-5 and entered case 6 (`interrupted_recovery_rollback`). The first recovery interruption succeeded: the durable runner state advanced to `final_recover` with zero failures and the expected recovery-discard sidecar plus active intent/commit marker and intact vault. The second Android relaunch then produced a live sleeping QA process and an Activity display event but no fresh Godot native startup marker. This is treated as a controller/process-lifecycle stall, not a restore-engine failure. The controller now requires proof that the old PID is fully gone after `am force-stop`, then requires a new PID, foreground/resumed ownership, and fresh Godot runtime evidence before the test may continue. A Java-side/Activity-only launch is retried once and otherwise fails closed quickly instead of consuming the suite timeout.


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

No destructive restore case started. The original arming model depended on custom `ProjectSettings` values in the exported APK but did not identify which runtime predicate failed. The first hotfix removed those custom settings as an authority and added the disposable export feature plus exact HEAD binding. The second attempt exposed the Android runtime predicate issue and moved the runner, startup bootstrap, and disposable restore activation patch to `OS.get_name() == "Android"`. The third attempt then reported `NOT_ANDROID_RUNTIME:Windows`, which proved the QA main scene was being executed by the Windows Godot build process itself. Root cause: the build helper invoked `--install-android-build-template` as a standalone command after replacing the disposable project's main scene. Godot documents that flag for use together with `--export-release` or `--export-debug`. The helper now combines template installation and `--export-debug` in one host process and rejects any Android QA runtime marker emitted during host-side import/export. The fourth attempt then produced `JadeAscendant-RestoreQA-5866e47.apk`, but no `android-restore-device-qa-build.json` or device summary was written and ADB never started. The final host line was `WARNING: Scan thread aborted...`. This isolated a PowerShell native-process capture problem: Godot stderr was merged into the pipeline while `$ErrorActionPreference = 'Stop'`. The launcher now captures native stdout/stderr to files with native error promotion disabled, preserves the real process exit code, removes stale same-head APK/build-report evidence before export, and proceeds to ADB only after a fresh APK passes those checks.

The fifth run, from `a42f03b`, proved the native-capture fix and ADB path: the exact-head APK built, the device runner armed, and cases 1-4 completed through real `am force-stop` process restarts. On the restart after case 5's `after_all_domains` fault, the QA PID remained alive with no fatal/runtime/script error, but Android reported the QA task paused and invisible while another application was `topResumedActivity`. This isolates the remaining issue to controller relaunch/foreground behavior rather than the transactional restore engine. The controller no longer uses `monkey`; it resolves the launcher activity, uses explicit `am start -W -n`, and verifies foreground/resumed ownership before the test can continue.

The sixth run, from `19afe1f`, verified that explicit foreground relaunch works reliably through case 5. Case 6 intentionally interrupted restart-driven rollback at `inventory`, advanced the persistent runner state to `final_recover`, and left the expected `inventory.save.restore.recovery.discard` artifact while the active transaction retained `intent.bin`, `commit_started.marker`, and an intact ready vault. On the next controller restart, Android reported the QA Activity displayed and kept a live process, but the new process emitted no Godot engine or QA bootstrap/runner log lines. The controller had only waited a fixed 550 ms after `am force-stop`; it did not prove the previous process had actually disappeared, and foreground Activity state alone was therefore insufficient evidence of a healthy Godot relaunch. The controller now polls `pidof` until the old PID is gone, rejects premature respawn, launches explicitly, requires a different PID, requires foreground/resumed ownership, and also requires per-PID logcat evidence that the Godot runtime started.

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

The controller installs only the `.restoreqa` package. It resolves the package's launcher activity, clears logcat, launches with explicit `adb shell am start -W -n`, and verifies through Android `dumpsys` that the QA package is actually foreground/resumed. After every exact `JADE_ANDROID_RESTORE_FORCE_STOP` marker it captures the current PID, performs `adb shell am force-stop`, and polls `pidof` until that PID is gone before any relaunch is allowed. The next launch must obtain a fresh PID, own foreground/resumed state, and emit per-PID Godot runtime evidence (`Godot Engine v4.7.2` or a QA runtime marker). An Activity-only launch without native Godot startup is retried once and then fails closed. A PASS marker is rejected if its embedded HEAD does not exactly match the committed HEAD used to build the APK.

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
