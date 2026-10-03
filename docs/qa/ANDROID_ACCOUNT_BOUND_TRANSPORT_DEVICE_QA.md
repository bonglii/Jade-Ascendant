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

## Two-step validation

1. Commit/push the source and harness. GitHub must first prove:
   - Android debug/release AAR separation;
   - debug AAR contains `JadeAccountBoundTransportDebugBridge` and the immutable fixture;
   - release AAR contains neither;
   - PowerShell disposable-workspace audit passes;
   - Godot 4.7.2 parses all device QA resources;
   - all existing exact-SHA regressions stay green.
2. Only after CI is green, use the exact debug AAR artifact produced by that same SHA for physical-device validation. The local harness requires its SHA-256 explicitly and refuses an unbound AAR.

The physical device remains final validation, not the first place obvious harness/source errors are discovered.
