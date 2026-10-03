# Android Account-Bound Transport Device QA

Status: QA-only / Android DEBUG / no production endpoint / no restore apply.

This phase proves the Android-native delivery boundary after the account-bound server transport and Godot candidate staging contracts are already green.

## What this phase proves

- A class that exists **only in the debug AAR** can expose one zero-argument Godot native method.
- The debug plugin reads one immutable reviewed QA transport fixture packaged in the AAR and verifies its exact SHA-256 before emitting it.
- No caller-controlled owner, revision, digest, token, file path, function name, URL or payload crosses the native method boundary.
- Godot receives the transport JSON through an Android native signal, validates the account-bound envelope again, validates the full permanent eight-domain snapshot contract again, and writes only isolated candidate files.
- Registered permanent save primaries and known sidecars are fingerprinted before/after and must remain byte-identical.
- The transactional restore engine is never invoked by this QA package.
- Device package ID is isolated with `.transportqa`, build is DEBUG only, and the disposable workspace comes from `git archive` of exact HEAD.

## What this phase does NOT prove

- No production Firebase snapshot endpoint exists or is called.
- No Firebase production deployment happens.
- No real cloud save content is read from production.
- No restore is applied to player saves.
- No cloud-wins, auto restore, upload, purchase verification or economy write is enabled.
- The packaged fixture is not server authority; it is an immutable QA record used only to prove native delivery and staging mechanics.

## Build harness ordering is a safety boundary

The physical-device APK must be built with `tools/android_account_bound_transport_device_build_qa.ps1`.

The build harness intentionally separates Godot startup into phases:

1. Create a disposable workspace from `git archive` of exact HEAD.
2. Patch the QA main scene, package ID, stubs and exact HEAD binding while setting `editor_plugins/enabled=PackedStringArray()`.
3. Run the expensive `godot --headless --path . --import` with **all editor plugins disabled**.
4. Only after import succeeds, install the hash-bound debug AAR into the disposable workspace.
5. Enable **only** `res://addons/JadeCloudNativeBridge/plugin.cfg`.
6. Run a second **warm `--import`** with only the bridge plugin enabled. This mirrors the import pass implied by `--export-debug` after the expensive first import is already complete.
7. Export the DEBUG QA APK. The export watcher requires Godot's `[ DONE ] export` marker, then waits for the APK file to become size-stable and verifies it opens as an APK/ZIP containing `AndroidManifest.xml`, a DEX file and an ARM64 native library.
8. After verified export completion, Godot gets a short shutdown grace period. If the APK is already verified but the editor process hangs during shutdown/cleanup, the harness kills that process tree and records `export_shutdown_forced=true` instead of waiting for the full export timeout.

Import, plugin smoke and export each have hard timeouts. An export process is never accepted merely because time elapsed: only a verified completion marker + stable valid APK may use the post-export forced-shutdown path. Any pre-completion timeout or invalid/incomplete APK still fails closed.

The production working tree's `project.godot`, `export_presets.cfg`, locked controlled-transfer stager and locked registered restore implementation are fingerprinted and must remain unchanged.

## Two-step validation

1. Commit/push the source and harness. GitHub must first prove:
   - Android debug/release AAR separation;
   - debug AAR contains `JadeAccountBoundTransportDebugBridge` and the immutable fixture;
   - release AAR contains neither;
   - both PowerShell harnesses parse;
   - disposable workspace transforms pass;
   - the **same staged local-build import path** completes with plugins OFF;
   - enabling only the bridge plugin afterward completes a headless plugin smoke;
   - a synthetic export-watcher self-test proves that a completed, structurally valid APK can be preserved when the child process intentionally hangs only after export completion;
   - Godot 4.7.2 parses all device QA resources;
   - all existing exact-SHA regressions stay green.
2. Only after CI is green, run the local build harness with the verified debug AAR SHA-256, then use the resulting APK for physical-device validation.

The physical device remains final validation, not the first place obvious harness/source errors are discovered.
