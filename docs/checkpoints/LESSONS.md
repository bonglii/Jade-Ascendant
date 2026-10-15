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

### Native artifact and CI teardown — 2026-10-15
- A source-level bridge contract is insufficient: install only AARs whose real build receipts match every compile input, archive digest and JVM result. Keep debug staging and release locked distinct.
- Runtime audio release resets background state. Suppress queued semantic SFX after release and cover all success/restart exits; never weaken CI error scanners.
- A crash-recovery fixture must quit immediately after its deliberate partial commit. Drain presentation resources before that boundary, never await after it.
- Public health cannot prove schema, refund freshness or a purchase. Use separate read-only readiness evidence and Android purchase evidence.
- Avoid assuming ripgrep exists on hosted runners. Existing portable grep checks retain the same strict patterns.

### Windows installer path inventory — 2026-10-16
- Do not wrap ConvertFrom-Json pipeline output in an array and assume a flat list on Windows PowerShell 5.1. Assign the decoded JSON directly and enumerate strings into a validated path map.
- Keep Git stderr separate from machine-readable numstat stdout; validate row syntax, duplicate paths and the complete manifest. Report the actual rejected row/path instead of a generic error.
- A Linux patch/tree check does not verify Windows PowerShell execution. Label that limit and retain strict allowlisting rather than bypassing the failing guard.

### Read-only D1 readiness — 2026-10-16
- Remote Wrangler --file uses the ingestion path and asks about database availability even for a SELECT-only file. Use --command for the bounded read-only readiness query. Do not silence the ingestion prompt with --yes.
- CLI help/source review and local SQL tests do not prove remote command behavior. Keep remote deployment/device checks explicitly pending until observed.

### App Check device diagnosis — 2026-10-16
- Debug provider initialization is not token acquisition. APP_CHECK_UNAVAILABLE before native route means no wallet HTTPS request was attempted; do not call it a Worker/DNS failure.
- Do not repeat tag-only logcat filters after empty results: token logging depends on SDK behavior and retained logs. Firebase debug secrets persist in narrowly scoped private SharedPreferences; for a debuggable tester build retrieve only its DEBUG_SECRET to the user's clipboard with explicit missing/ambiguous/permission errors. Never request secret output in chat or dump all preferences.
- Native task failures currently collapse to an App Check status without safe reason codes. Add bounded redacted diagnostics at the next native build rather than guessing registration versus networking.

### Support report truthfulness — 2026-10-16
- Purchased gameplay readiness was hardcoded false in Copy Support after V2 was introduced. Derive readiness from the actual live V2 lease. Legacy wallet read status is a separate path and must not be treated as V2 request status. A DNS route only proves resolver selection, not App Check success, HTTP success or wallet confirmation.

### Shared Firebase key transport receiver — 2026-10-16
- Profile verification preserved the native fetch receiver, but the shared IAP verifier still invoked a detached native function. In a receiver-sensitive workerd runtime this throws before downloading Google's public signing keys and is collapsed into UNAUTHENTICATED.
- Preserve globalThis for both default and injected key fetchers. Add a regression using the default fetch path, real signed Auth/App Check JWTs and a receiver-sensitive fetch mock; injected arrow-only mocks miss this defect.
- Reproduction failed before the fix with InvalidIdentity; after the fix both signature chains must succeed without sending account headers or bodies to key endpoints. Live staging recovery still requires deployment and device evidence.


### Windows migration argument transport — 2026-10-16
- Passing multiline SQL as --command through npx.cmd/cmd.exe can truncate the argument and cause incomplete input even when the SQL file is valid. Strip full-line comments then normalize the reviewed migration to one line before invoking the CLI. Never interpret a failed first migration as a successful deploy.
- Test all 12 normalized migrations against SQLite, rerun idempotently with an existing ledger row, and separately label Windows/remote execution as unverified. Preserve trigger bodies, quoted literals and data.
- Use explicit if errorlevel guards and success/failure exits in launchers. A later check must not proceed after a failed deploy. Capture stderr alongside the failing command when reporting deployment failures.


### Google Play workerd transport — 2026-10-16
- Refund and RTDN fetches still used redirect:error after the shared JWT path was repaired. Actual workerd Request::tryParseRedirect accepts only follow/manual. Audit all related HTTP clients together; Node mocks that accept any redirect value do not validate edge compatibility.
- Reproduce with receiver-sensitive, redirect-restricting fixtures before fixing. Use manual redirect denial and preserve the global receiver for OAuth, purchase verification/consumption, refund and RTDN key requests. Keep all activation gates unchanged.
- Fixed safe status labels must distinguish Play HTTP 401/403/429/5xx and timeouts. Never collapse every failure into a DNS diagnosis or log OAuth tokens, URLs containing purchase tokens, private keys or Google response bodies.


### Recovery empty POST compatibility — 2026-10-16
- A zero-byte POST can have a non-null Request.body stream. Testing only method POST plus Content-Length:0 without an actual empty body missed the Android HTTP representation. Validate actual bytes with bounded time/chunks, and keep non-empty request data rejected.
- The client recovery allowlist omitted fixed native errors such as INVALID_REQUEST, hiding the actual diagnosis as unavailable. Preserve fixed safe labels and add server-side status/stage-only logs without secrets or account payloads.
- Zero recovered receipts must never imply guaranteed restoration of consumed purchases absent from the server ledger. Test replay, zero-ledger behavior and disguised/nonterminating bodies without inventing credits.
