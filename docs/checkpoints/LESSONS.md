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


### IAP lifecycle and production candidate — 2026-10-16
- Test card credit, ordinary RESTORE, paid summons, interrupted consume, refund and release attestation are distinct evidence. Preserve successful checkpoints and never claim one proves the others.
- A staging allowlist with one UID cannot prove a second allowed account has an independent wallet. Use an optional bounded second tester hash without replacing the first, and keep unexpected accounts denied.
- Enabling a release endpoint in source is not compiled-native evidence. Build a separate candidate, inspect actual flags/JNI/App Check provider, retain source hashes and do not relabel old AAR receipts or install uncompiled binaries.
- A read-only ledger script cannot decide current device gameplay readiness. Report unknown rather than a hardcoded false. Use Format-List for wide account diagnostics to avoid one-letter vertical headers.
- The prepared Worker entrypoint imports node:crypto; its opt-in config needs nodejs_compat. Verify the actual candidate config with a Wrangler dry-run in CI, while keeping every payment gate locked by default.


### Native lifecycle artifact delivery — 2026-10-16
- Check the workflow head SHA, artifact archive digest, every source input, actual BuildConfig/JNI/provider bytecode and JVM XML before installing. The annotated Godot JNI inventory differs from all JVM methods, including private Kotlin helpers; report the annotated inventory only.
- Keep production candidate binaries separate from the installed staging/locked pair. A passing build does not prove Play Integrity on an installed release or authorize enabling payment gates.
- Binary payloads require byte hashes; text payloads use UTF-8 LF normalization. Validate every entry before writing, retain scoped backups, and verify source inventory before replacement.
- Do not embed single-quoted Python code in a single-quoted shell -c argument. Write the helper script and pass structured JSON through stdin; keep signed artifact download URLs out of output.


## 2026-10-16 — Production release and progress recovery

- A successful profile UID and server wallet do not prove that all gameplay progress is cloud-backed. Audit the current permanent registry: mastery increased it to nine domains, while historical closed Firebase contracts still describe eight. Use the explicit current protocol; do not reactivate archived gates or claim lost local-only progress can be recreated.
- Keep accepted real-payment/restart evidence separate from Test card, simulation, refund polling and real-order refund evidence. Do not repeat passed purchases on unrelated code changes.
- Store the reviewed live IAP gates in a named production config and always deploy through the checked release entry point. CLI-only overrides and an ordinary locked release export are not a reproducible release process.
- Bundle diagnostic helpers, check their paths, use the absolute Windows PowerShell executable, and retain verified AAR backup/recovery state before substitution. Text provenance must normalize CRLF on Windows; binary hashes must not. Never delete Git locks automatically.
- Backups are account-bound offline snapshots, never paid currency/equipment authority. Read before writing, compare server revisions, fence account changes and late callbacks, require explicit restore, retain a verified before-image, and replay exact multi-domain journal targets after interruption. A fresh install must not overwrite an existing remote save with defaults.
- Derive release version/code from the selected export preset. Embed them into the exported package and use the same metadata for support and LiveOps headers; a blank application/config/version must not turn into an empty version or a fictitious 1.0.6.
- Log bounded source locations and error kinds only. Never persist raw Firebase/Play tokens, error payloads, captured variables or private identities. An incomplete previous session is not conclusive crash evidence.
- UI fixtures must measure controls in their logical stretched canvas, not compare logical widths to physical window pixels. Check complete label width and touch-release behavior in both languages.
- Windows PowerShell 5 may emit a JSON array as one pipeline object. Never use @(ConvertFrom-Json ...) to count manifest entries; assign the decoded value and explicitly enumerate it. Exercise both enumerating and non-enumerating output before delivery. PowerShell 7 alone is not Windows PowerShell 5 evidence.

## 2026-10-16 — Player trust and ad privacy

- Match disclosures to the live profile/backup and authoritative purchase services. Archived “local-only/no cloud save” wording cannot remain the player-facing policy after those features ship.
- A support email/draft is a deletion request pathway, not completed erasure. Verify account ownership independently; never delete based only on a public UID. Remove Firebase Auth first and allow existing signed ID tokens to expire before purging, otherwise an old session may recreate data.
- Distinguish limited financial/refund/security retention from playable inventory and backups. Remove both backup snapshots, targeted queued mail, loadouts and runs; keep other players/shared content and financial authority intact. Do not turn deployment or release tests into a live destructive deletion.
- Opening ad privacy choices must immediately invalidate cached/pending ads. Fence delayed load callbacks by generation; a stale callback must not re-open advertising after consent changes. Do not claim SDK-earned callbacks are server-side SSV.
- PowerShell 5 manifest counts require explicit enumeration of a decoded JSON variable. Test the repository-owned installer under Windows PowerShell and simulate non-enumerating JSON; PowerShell 7 alone is insufficient evidence.
- Godot editor SDK mocks can allocate before SceneTree exists. Disposable QA must attach orphan mock Nodes to its tree so teardown is clean; do not confuse that fixture leak with a production Android SDK leak.

### Expected subprocess failures in PowerShell CI
- A successful negative test must exit 0 explicitly after checking the expected child failure. Otherwise Windows PowerShell retains the child LASTEXITCODE=1 when the test is called with &, and CI reports failure even after every assertion passes. Validate the caller invocation used by the workflow, not only a fresh powershell -File process.

## 2026-10-18 — Branding delivery

- Inkscape can exit successfully while an embedded PNG referenced with SVG2 href renders blank. Use compatible xlink:href and inspect actual exported pixels, dimensions and transparency.
- SceneTree current_scene is briefly null during a successful deferred scene change. Tests must await the replacement scene before asserting its name.
- Branding installers must merge only logo/splash keys in project.godot and export_presets.cfg; preserve local Android version, signing and release settings. Verify all package/source hashes before writing and retain backups. Never delete a Git lock automatically.

- Branding R2: Android export preset counts and indices differ after editor saves. Discover Android presets by platform, update only existing Android targets, and test single/reindexed presets plus mixed desktop targets. Never require preset.1.options from the build machine.

## 2026-10-18 — Warning cleanup

- Local names owner, name, ready and rotation can shadow Node/Node2D properties or signals. Use account_binding, backup_filename, reward_available and signature_angle; preserve wire-format dictionary keys and property access.
- A float passed to a theme constant expecting int needs an explicit conversion. Keep the previous truncation behavior rather than silently changing rounding/layout.
- Check-only mode does not initialize autoload singletons and can report misleading missing-identifier errors. Compile the full script set inside an isolated project with real autoloads and targeted warnings promoted to errors; never change production warning settings to hide warnings.

- Warning cleanup R2: the supplied LiveOps diff (blob b1326b9) was already an equivalent fix using ready_count and claim_available. Preserve that exact verified variant; accept it as already installed rather than replacing correct local names or relaxing hash checks for unknown edits.


## 2026-10-18 — Complete default warning checks

- Checking only three categories missed five incompatible-ternary warnings. Discover the running engine's default enabled warning categories, promote all of them in an isolated QA configuration, and load all production scripts. Do not disable warnings in the game to obtain a clean result.
- Conditional visual expressions must use consistent numeric types in both branches (0.0/PI and float pixel offsets). Keep the numeric values and visual behavior unchanged.
- Generic lesson publishing must stage the verified append payload rather than searching for a hardcoded section heading from an earlier package. Preserve unrelated local notes in the working tree.
