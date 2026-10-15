# Lessons and preventive actions

- Local commits are not published GitHub checkpoints. Verify remote publication before presenting a commit link; label patch-only delivery clearly when integration permissions deny writes.
- A random local profile UID is not a server account. Expose the scope in the UI, register identity against a verified Firebase token, and let a database uniqueness constraint allocate the authoritative public UID.
- Do not polish blindly. Inspect existing bitmap/vector assets, atlas boundaries, scene layers, shader ownership, and actual renders before choosing changes.
- Godot's `_input` is a virtual method: do not reuse that name for a LineEdit variable. Use `_name_input` and load the real scene in QA.
- Test fixtures must use actual node names (`ProfileGoogleAccountCard`) and indentation consistent with the fixture. Investigate fixture errors separately from product errors.
- A missing primary save with rollback/staging artifacts is not a fresh installation. Preserve evidence and avoid minting replacement identity.

- Markdown hard-break spaces caused an avoidable whitespace warning in the first UI patch. Strip trailing spaces in deliverables and check the complete publish range, not only the latest diff.
- Godot parses JSON numbers as floats. Validate protocol version numerically while retaining integer schema versions in binary saves; test real JSON parsing rather than only hand-written dictionaries.
- Do not assume a discussed follow-up patch has been applied. The first server-UID patch depended on Short UID and failed on the original Batch 3 files. Deliver a consolidated variant from the prior base, validate its entire resulting tree, and chain deployment after successful patch application so missing-script errors do not repeat.
- Check HTTP transport result and status before parsing a response body. Empty error responses triggered Godot JSON engine diagnostics in the first server client. Use JSON.parse with a checked result for malformed successful responses, expose fixed safe failure codes, and regression-test network, HTTP, empty, and malformed bodies.
- A timeout code does not establish an authentication failure. Measure the deployed route before choosing a fix. The first registration client used a 12-second total budget and frame-polled HTTP; use bounded mobile headroom, threaded transport, and an explicit User-Agent, and keep the authentication boundary unchanged. Live health availability still does not prove authenticated Android registration.
- Increasing transport headroom did not resolve the phone timeout. Browser health success is not equivalent to game-engine GET or authenticated POST success. Capture the engine's last DNS/TCP-TLS/request/body stage and run a bounded credential-free same-engine health probe before choosing another transport/backend change.
- The phone probe established that both GET and POST stalled in connect_tls, before the HTTP request phase. Stop changing UID allocation, JSON, or token handling for that evidence. Address socket routing with DNS-derived IPv4 while preserving the original TLS hostname/SNI and Host header; test certificate rejection rather than relaxing TLS checks. IPv6 remains a hypothesis until the route change succeeds on the phone.

- IAP V2 CI setup: `android-actions/setup-android@v3` defaults to the obsolete `tools` package. The real a5fff4d run failed before Kotlin compilation. Set `packages: platform-tools` explicitly, retain SDK 36, and inspect the failed step before changing game/network/auth code.
- Cross-device paid state must not flow through existing local spend getters or checkpoint serializers. Keep explicit local balance/slot/star reads, and verify paid run data through the current account and expiring server snapshot.
- Autoload order matters: EquipmentManager initializes before PavilionManager. Resolve an optional runtime service through the scene root instead of assuming the later singleton is ready.
- Deferred UI callbacks can receive an object freed before typed parameter conversion. Pass WeakRef through the deferred boundary and validate before casting; do not remove touch/scroll protections to hide the error.
- Godot --script SceneTree tests compile before the project's autoload identifiers are available. Resolve manager nodes from root inside run() after startup; do not use global autoload identifiers in the test entry script.
- A PowerShell test that intentionally exercises a failing native Git command must return an explicit successful exit after all assertions pass. Otherwise GitHub's wrapper inherits the expected negative test's LASTEXITCODE=1 and reports a false failure. Never remove the negative assertion to make CI green.
- Paid snapshot has 15 explicit protocol keys. A manually counted 16-field guard rejected even valid authenticated snapshots. Derive the count from the named field list, compare it with native/fixture keys, and retain a positive real-JSON contract case before relying on negative cases.
- `Skin` is a native Godot class; do not reuse it for a UI script constant. Use feature-specific names such as ArmoryFrame, and load the actual panel in QA. A run-time script error in a coroutine must not waste the entire external timeout: the paid QA harness now has its own short watchdog.
- When local tool downloads are blocked, retain the exact CI Godot engine as an artifact before test execution. It enables matching local reproduction after the next successful tool download and reduces repeated user publish cycles; until then, label source corrections as awaiting execution.

### Canonical numeric fields in durable paid commands — 2026-10-15
- Godot JSON parses numbers as floats. Dictionary equality distinguishes nested
  float/int values even when scalar numeric comparisons agree. A first-response
  receipt could fail the journal equality check after the original int command.
- Validate the exact command schema first; canonicalize only bounded numeric
  fields (revision and pull count) on read, persistence and dispatch. Never coerce
  unvalidated strings/bools. Exercise initial-response retirement as well as replay.
- Reproduce with the exact CI engine artifact before delivering another patch.
  Run every affected client check, including existing separate-process modes;
  collect all failures in CI rather than stopping before later checks execute.

### Paid run recovery and complete CI evidence — 2026-10-15
- Resolve server run selection before constructing the player. A local run ID is
  a reference, never ownership proof; recheck account, live ownership and refunds.
- New-run preflight must read next-run earned levels directly and bound them by
  verified stars, rather than a getter that can still reflect the previous scene.
- A missing/removed run needs a durable cancellation receipt so a bad checkpoint
  does not trap the entire account behind an unretirable pending command.
- Do not assume rg exists on hosted runners. Use provisioned/base tools and retain
  all runtime logs; aggregate failures so later suites are not hidden.
- Stop scene-polled audio context before QA teardown and allow the mixer to drain.
  Otherwise a passing suite can recreate playback and fail on leaked exit resources.
- New manager integration uses runtime root lookups to avoid adding autoload compile
  dependencies. Run Godot checks sequentially per isolated project/import cache.
- Warm gameplay resources explicitly when testing gate/receipt semantics; disclose
  that cold threaded-load behavior/device latency is a separate test boundary.
- Persistent fixture dictionary keys must be String, using ["item_id"] writes.
  Dot insertion into an empty Dictionary can create StringName keys that strict
  save validation correctly rejects; never weaken the save validator to accept it.
