# Android Account-Bound Transport Device QA

Status: QA-only / Android DEBUG / no production endpoint / no restore apply.

This phase proves the Android-native delivery boundary after the account-bound server transport, E3C-A client contract, and Godot candidate staging contracts are green.

## E3C-B extension

E3C-B reuses the already-locked physical Android DEBUG transport harness rather than introducing an unapproved production endpoint or release-native API.

The required device flow is now:

`debug native immutable fixture -> E3C-A production-shaped client validation -> safe summary -> explicit one-shot internal handoff -> locked isolated candidate stager`

The immutable debug fixture predates E3C-A and contains `qaOnly=true` plus the QA transport code. The disposable device runner may normalize **only those two envelope fields** before E3C-A validation. It must not rewrite owner, revision, digest, domain set, timestamps, or snapshot payload. The original native JSON must never bypass E3C-A and enter the candidate stager directly.

After E3C-A validates the record, the runner checks the payload-free safe status first. Only then may it consume the raw transport through the explicit one-shot internal handoff. A second handoff must fail. The older locked candidate stager receives a QA-envelope copy created only from that validated one-shot handoff.

A successful physical E3C-B run must emit both:

- `JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_E3CB_CONTRACT_PASS`
- `JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_PASS`

Both markers must be bound to the exact tested HEAD.

## What this phase proves

- A class that exists **only in the debug AAR** can expose one zero-argument Godot native method.
- The debug plugin reads one immutable reviewed QA transport fixture packaged in the AAR and verifies its exact SHA-256 before emitting it.
- No caller-controlled owner, revision, digest, token, file path, function name, URL or payload crosses the native method boundary.
- Native bytes must pass the locked E3C-A account-bound read client contract before any candidate staging.
- E3C-A exposes only masked/payload-free metadata before the raw one-shot handoff.
- The raw transport internal handoff can be consumed exactly once and still grants no restore, upload, cloud mutation, or production execution authority.
- Godot validates the full permanent eight-domain snapshot contract before the handoff is adapted to the already-locked QA candidate stager.
- Registered permanent save primaries and known sidecars are fingerprinted before/after and must remain byte-identical.
- The transactional restore engine is never invoked by this QA package.
- Device package ID is isolated with `.transportqa`, build is DEBUG only, and the disposable workspace comes from `git archive` of exact HEAD.

## What this phase does NOT prove

- No production Firebase snapshot endpoint exists or is called.
- No Firebase production deployment happens.
- No real cloud save content is read from production.
- No restore is applied to player saves.
- No cloud-wins, auto restore, upload, purchase verification or economy write is enabled.
- The packaged fixture is not server authority; it is an immutable QA record used only to prove native delivery and client/staging mechanics.
- E3C-B does not approve replacing the packaged release AAR or enabling a production snapshot callable. Those decisions remain in E4.

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
   - the existing Android account-bound device boundary remains green;
   - the new E3C-B source test proves native bytes cannot bypass E3C-A;
   - Android debug/release AAR separation remains intact;
   - both PowerShell harnesses parse;
   - disposable workspace transforms pass;
   - the same staged local-build import path completes with plugins OFF;
   - enabling only the bridge plugin afterward completes a headless plugin smoke;
   - Godot 4.7.2 parses all device QA resources;
   - all existing exact-SHA regressions stay green.
2. Only after CI is green, run the local build harness with the already-verified debug AAR SHA-256, then use the resulting APK for physical-device validation.

The physical device remains final validation, not the first place obvious harness/source errors are discovered.
