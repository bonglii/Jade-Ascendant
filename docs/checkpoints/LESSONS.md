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


## 2026-10-18 — Home and Hero visual cohesion

- Control.clip_contents clips only the outer rectangle, not the transparent carved frame aperture. Put painted art/fades in an inset rounded clipping panel and render the frame above it; keep opaque fills inside the frame as well.
- A card child at z_index 90 can render above a sibling modal at 80. Refine notifications belong to the card layer (3); modal overlays stay above the entire card subtree. Check rendered modal stacking, not just node order.
- Selected realm art must use the existing JourneyArtCatalog metadata, cached on chapter change, instead of a constant crop of the Home illustration. Presentation must not change chapter selection or progression.
- Validate actual native renders as well as dimensions. Use isolated save scopes, real renderer snapshots and a small interaction suite for the affected menus. Stop audio before fixture teardown so pending UI sound callbacks do not create false leak reports.

- Distinguish parser-warning cleanup from runtime shutdown diagnostics. The older Home regression emits six RefCounted exit warnings on both the exact baseline and this patch; record that comparison instead of mislabelling them SDK mock leaks or claiming all runtime warnings are fixed.


## 2026-10-18 — Ascendant Trials
- Test layouts against the smallest supported viewport and actual minimum widths, not only the large approved mockup. On narrow screens reflow reward/actions under the description; compact headers and wrap filters before the scroll area becomes unusable.
- UI reparenting exits/re-enters the tree. A touch tracker may forget the node while its signal connections survive. Check existing connections before reconnecting; install OptionButton cancellation once.
- Concrete sibling types (StyleBoxTexture vs StyleBoxFlat, VBoxContainer vs HBoxContainer) still trigger incompatible_ternary even with an ancestor-typed destination. Use explicit branches; validate with all 41 enabled warning categories as errors before packaging.
- Reward fixtures must use the manager's completion API: assigning progress alone does not update completed/unlocked IDs. Keep test setup isolated and verify the real claim authority.


## 2026-10-18 — Jade Dragon Odyssey
- Save a durable source checkpoint before a long feature crosses an environment/session boundary. Generated art survived, but an earlier uncommitted draft did not; recovered source must be tested again rather than inheriting its old pass claims.
- Keep paid dice, wallet debit, revision CAS and operation receipt in the same D1 batch. Retrying one request ID must return the committed result; a stale revision or later write failure must not spend Jade.
- A rewarded SDK callback is not a server grant. Verify Google's exact signed query bytes (including the required leading question mark), consume one nonce and receipt atomically, and enforce server daily caps.
- New event-only equipment must be excluded from both normal summon pools and the pinned paid catalog hash. Update Library/acquisition copy, result damage source and ownership checks together.
- Single-line counters inside an HBox need a natural width. A wrapped progress label with a 1px minimum caused vertical text and pushed monetization controls offscreen; verify native portrait layouts before delivery.
- Defer autoload cross-service signal setup until all autoloads exist. Otherwise the first autoload can miss the ad service and never poll its signed reward.
- Avoid Node signal/property names such as ready/owner in new locals. Run all 41 enabled warnings as errors; a test's own pass line is insufficient if SCRIPT ERROR appears earlier.
- Retain durable operation journals on uncertain transport failures. Clear them only after a verified commit or an explicit non-commit response; account switches must discard in-memory authority before any refresh.

## 2026-10-18 — Gradle bootstrap checksum handling
- Gradle publishes the .sha256 endpoint as application/octet-stream. Casting an Invoke-WebRequest byte-array Content directly to string can produce decimal bytes instead of the hash, falsely rejecting a valid archive. Pin the independently verified 8.13 SHA-256 and hash the actual ZIP before extraction.
- Reuse verified ZIP and existing 8.13 caches, including wrapper caches, before downloading. Download to unique temporary paths and validate each route before extracting. Keep a damaged prior cache for diagnosis.
- Test PowerShell helpers by executing them with a real official archive, paths with spaces, repeated installs and simulated HTML/download failures. Parser-only tests do not detect read-only automatic variable names such as HOME; avoid those names completely.
- When fixing a delivered installer, update its payload and manifest along with the installed source, so its next run accepts the correction and its scoped publisher includes every helper.

## 2026-10-18 — Portable Odyssey continuation
- Resume a source batch from its installed project and a durable scoped manifest. Do not require the original extracted download folder to still exist. Support moved/nested packages and a completely missing package; test all three before delivery.

## Release QA17 — 2026-10-23

- Reconcile the actual checkpoint SHA and cross-chat CI first. The nine-feature batch is already71f6753; its older recovery ZIP is not the current source.
- A hidden recovery subtree has no settled visible layout. Test the real expansion, then intrinsic button text, bounds and a first native swipe. Do not weaken the text-fit check or force collection/backup permissions.
- Home now has one contextual primary goal. Test saved-run/recovery priority and real navigation, instead of restoring the obsolete duplicate Continue UI to satisfy stale assertions.
- Queued Hero layout/texture work must stop after page removal, including both sides of awaited frames. Clear its pending flag without rebuilding a detached page.
- Native first-swipe evidence must configure actual mouse-to-touch GUI emulation and dismiss the fixture's unrelated onboarding overlay. A blocked action behind FTUE is not evidence that the underlying card handled a swipe.
- The training actor scene lacks the health child normally supplied by levels. Include the real health dependency before entering the tree, then test every skill/level control. Training must not freeze a paid run, attach mastery-trial health, or update persistent quest/achievement counters.

### Retention/dashboard batch, 2026-10-23
- A browser-local datetime input is not a WIB input. Reuse one strict offset boundary and test multiple process zones, invalid days, year boundaries and the actual form handler. Never shift an already published Unix timestamp.
- A cosmetic redesign can increase page weight if the whole stylesheet is duplicated. Cache a content-versioned presentation-only asset and measure actual HTML bytes; preserve nonce-only page policy.
- Tab-specific scripts previously re-wrapped nav handlers, producing duplicate reads and resetting banner drafts. Keep one lazy/coalesced view loader and test repeated presses plus edit/navigation/reopen.
- Code-level daily availability does not mean Home actually points to it. Test actual completed manager state, the reward operation and a separate restart; production completion sync is deferred and must be awaited by the fixture.
- Library fixtures must compare the full current active catalog, not an old56-item count. Verify every item once while preserving retired snapshots. Metadata fixtures need the current independent native proof as well as the AAR, with target/debug assertions retained.
- Legacy combat fixtures could exit before Dummy audio drains, reporting in-use resources. Use the shared teardown; keep genuine ERROR output fatal instead of disabling the scanner.
- The browser policy rejected the local data-URL composition preview. Do not retry through another browser surface or claim that the redesign was visually validated. Full generated-script DOM tests are behaviour evidence only.

## CI closure and retained local configuration — 2026-10-23

- Compile the evaluated dashboard export, including shared WIB helpers, rather than extracting JavaScript from the raw module template. Validate every inline script and keep missing/invalid scripts fatal. The raw-template regression must reproduce its original parse failure.
- A correctly rejected negative PowerShell preflight leaves LASTEXITCODE=1. After asserting both the valid target and rejected wrong target, explicitly finish the CI step with success; GitHub otherwise forwards the expected failure. Exercise the actual workflow step with the runner exit-code trailer, a broken positive guard, and an incorrectly accepted negative guard.
- Profile sync/deploy share the same backend scope. Preserve the exact local IAP deployment config only under the existing nine-gate/identity/refund contract; never broaden this exemption to shared authentication or runtime code. Prepare backups and merge plans before tracked-file writes. A reviewed empty-side conflict adding only the two required companion autoloads can be resolved narrowly; other settings conflicts remain explicit.
- Owner sync and Profile deployment are already confirmed at version786759a1-e470-4fa5-ba96-1a459a9fe551. CI-only closure does not require repeating installation, migrations, native builds or deployments. Keep author evidence, Windows results, GitHub exact-SHA CI and Android/Play approval separate.

## Release polish and delivery — 2026-10-24
- A mailbox action queued during the first 1500 ms of a catalog read could wait for the full request timeout. Schedule a bounded yield of read-only background work; never cancel a claim or durable ACK for speed.
- A popup's self_modulate only hides its background. Hide the complete panel until its first stable layout, retain the same target sheet across categories, and reserve the gacha result area before first paint.
- Kill prior result landing tweens and hide identity controls before every summon. Verify pixel secrecy for all four rarities, plus a second summon while the previous landing is unfinished.
- Claim All existed in AchievementManager but the production presenter hid its footer and ignored its handler. Exercise the actual visible presenter, and retain source-authority/idempotency checks.
- A saved test receipt is permanent by design. Use a new isolated user directory for each independent QA run; reuse a directory only for an explicit restart test.
- Test doubles must not collide with newly autoloaded services and silently acquire another node name. Bind the intended fixture explicitly. Keep catalog assertions aligned with event-only and retired equipment without changing production unlock rules.
- Godot get_meta with a null default reports an absent key. Preserve optional hit-source metadata with has_meta and a non-null fallback; scan complete combat logs even if numeric assertions pass.
- Raw WAV/Ogg bytes must never pass through UTF-8/newline normalization in portable installers or sync checks. Hash/copy binary bytes exactly, retain backups and prove replay with a local bare remote.
- Preserve efficient release scope: no new ad quota, speculative SSV grant, IAP gate changes or native rebuild for a GDScript/audio-only batch. New active music/SFX require source/license notices accessible in Credits.

### 2026-10-24 — CI follow-up after published polish
- A restart must execute immediately after its save-producing fixture with the same userdata configuration. Appending an unrelated suite must never change the restart's save directory; do not assume a test is last.
- Dispose active combat scenes and settle exit callbacks before draining QA audio. Retain all runtime error scanning and gameplay/restart assertions. An unreproduced shutdown leak has uncertain resource types; do not label audio decoding or player saves broken without evidence.

### 2026-10-24 — shared chrome and skill identity
- Compare final nav typography as well as rectangles across all five pages. Generic readability enlargement must not resize only non-Sanctuary labels; shared nav labels explicitly own their typography and geometry.
- Artwork files being different does not prove displayed icons are different. The equipped-weapon override was incorrectly applied to both the primary attack and Sword Dao Resonance, including a duplicate resolver in Library. Keep the primary equipment identity and the synergy identity separate through one catalog resolver.
- WIB input conversion does not rewrite dates already published. Repair only an unstarted campaign with no frozen weeks, use database time and a compare-and-swap, retain flags/rewards and preserve the current live rotation. Never clear player progress to fix a schedule.

-2026-10-24: A whole textured dragon mesh can pinch its head during sharp turns. Keep the painted head rigid, bound body curvature and inspect actual compact engine renders; HP tests alone do not prove VFX quality.
-2026-10-24: Standalone SceneTree tests must load weapon scripts after autoload initialization; eager preloads can compile before singleton identifiers exist. Corrected scoped test passes189 checks.

-2026-10-24: Asset batches must be tested in the actual sparse QA-clone topology. Stage only verified manifest paths with git add --sparse; never expand the checkout or stage unrelated files. The local bare publisher simulation caught the missing flag before owner delivery.

###2026-10-24 — independent operational clock
- A SELECT driven by an optional campaign table loses the server clock when the table is empty. Drive the snapshot from a clock row and LEFT JOIN campaigns; test the actual query against an empty real SQLite database. Never substitute device time.
- An empty schedule means NO_CAMPAIGNS, not a failed connection or successful reset. Verify a read-only skip, create no event, run no repair SQL and never print RESET=PASS. Existing/frozen player progress stays unchanged.
- Preserve the preparation command output in the PowerShell failure itself and plan-output.log; a parent subprocess may otherwise hide stdout behind a generic stderr exception.

## Admin Studio refinement — 2026-10-24
- Global function names can shadow browser APIs differently from JSDOM. Rename the mail-history loader away from `history` before using the native History API; verify actual browser navigation and a deep link.
- Feature hashes use `view-` prefixes so they cannot scroll the initial document to an unrelated form ID. Check the actual first compact render, not only DOM existence.
- Standalone admin pages use explicit head/body boundaries; preview injection must retain the full application script and visible data-example label. DOM-only parsing is not browser visual proof.
- Home scroll tests must inspect the effective layout after native input at the new viewport before deciding it overflows. A stale21px range that becomes0 is not a touch regression; also inspect visible child bounds. The390px case exposed a real clipped shortcut row: publish the complete authored stack minimum height before the parent sorts, rather than inventing padding or a custom gesture router. Keep real first-swipe assertions where content overflows and forbid accidental run navigation.
- A compact fixed Hero deck must reserve a usable backpack reader. Put Build Journal in the title row on short screens; keep equipped items pinned and native navigation unchanged.
- Combat smoke fixtures must call the current persistent-courier API and fail promptly on an exception; never add a legacy runtime overload just to satisfy obsolete path-lock tests.
- Save implemented source in durable checkpoints immediately after a stage. A plan-only checkpoint cannot recover changes lost with an author runtime reset.

## Home chapter route and boss notices — 2026-10-24
- Recommendations must not replace stable navigation. Home uses a progression-only decision; Trial/event rewards stay in their own entry points. Keep recovery protection and an independent chapter route beside a real Continue.
- Ornament-safe bounds must include the CTA and eyebrow, not only the large title. Check long EN/ID labels at320,390,648 and720px, with actual claim-ready manager state.
- All combat modals need a higher sibling z-order than boss notices. Stop notice tweens on global pause so reading time is preserved; verify a real Resume click for both pre-warning and arrival, with reduced effects on/off.
- Reuse boss atlas idle art with a clipped square portrait crop inside one cell. Do not stretch a full transparent-gutter frame into a tiny unreadable portrait or use a rectangular crop as a square.
- Match the existing GDScript indentation style when inserting a function. Load the production presenter in the fixture and fail promptly if it is absent; an import scan alone does not compile every scene script.
- Compact achievement toasts need their own bounded typography and viewport clamp. Native notice tests must release scene/audio before exit; resource-in-use errors are not a passing test.
- Catch up the exact prior Studio stage only if still pending, then apply the client delta. Recognize the reviewed parent by all committed file hashes; never infer publication from a chat claim. Preserve a valid local IAP-config exception without staging it, after all nine gates validate.

## Player Comfort — 2026-10-24

- Permanent Hero level and combat run level are different signals. A committed permanent EXP grant must have its own read-only celebration; coalesce multiple gained levels, never replay save loads, and clear pending display on account switch. Preserve the existing run upgrade picker.
- Shared navbar geometry alone does not prove shared appearance: inspect the actual frame/style on all five production menus, including runtime-created Hero.
- Godot's default gray clear color can be exposed between scenes. Keep the boot art on the persistent transition layer until the incoming frame draws; cleanup must belong to that persistent manager, not the outgoing Boot coroutine.
- A similar login header is not proof that the deployed dashboard is stale. Inspect rendered shared navigation or a visible release marker before asserting deployment status. This batch corrected an initial inference after the live DOM proved the new eleven-tool sidebar was present.
- Restore an approved old weapon palette instead of stacking more impact layers on a continuous weapon. One touch cue uses one asset and fixed pitch; BGM selection remains explicit owner choice.
- A warm QA fixture still needs every changed dependency copied and its isolated userdata flag retained when project.godot changes. Missing manager updates / overwritten custom-dir config produced fixture-only failures; both were corrected before claiming runtime PASS. Exit2 is a guard rejection, never a passed test.

- Strict editor import catches inherited member shadowing that plain game execution can permit; use binding_value instead of Node.owner in the new presenter. Check real module exports in dashboard tests rather than assuming every page has a default export.
- A pending Home refresh may run after change_scene detaches the old tree; stop at the shared refresh entry before touching managers or child controls. Cover the resource-grant/menu-to-combat transition, not just static pages.

## 2026-10-24 — complete portable dependency and audio lifecycle checks

The PlayerComfort archive omitted transitive profile_guard.cjs because validation
used publish-only. Include and recursively load every runtime helper before any
publish mutation. Exercise the complete publish + game-sync + retry path with
local project/LESSONS/IAP config and save bytes preserved. Do not rely solely on
syntax checks or publish-only tests. Accept retained local project bytes only
with a completed three-way merge receipt; later unrecorded edits still stop.

AudioStreamPlayer.playing becomes false while stream_paused. Same-track music
routing must accept the currently paused stream as well, preserving its position
and duck envelope. Validate actual playback, loop wrap and background/resume;
matching resource paths alone does not establish continuity. Prepare raw audio
imports before enabling autoload preloads in a clean isolated test project.

## 2026-10-24 — test the first checkout, not a bootstrapped audio fixture

The Chinese music suite imported raw resources before enabling autoloads; this
hid missing committed .ogg.import files. Exact-SHA CI artifact12555831453 showed
both new preloads failed during first autoload parsing and four shared release
jobs stopped at that same root cause. Ship Godot-generated importer sidecars and
copy them into the isolated fixture. Run one strict import with autoloads enabled
from the beginning and verify the shared full-project fixture from an empty cache.
Do not dismiss first-import errors as harmless or turn off the strict error gate.

A normal owner editor may have generated those sidecars already with another
resource UID. The portable fix backs up and accepts only that UID-only variation
for these two reviewed files; every import parameter/source/cache path must match.
No broad local-file hash bypass. QA failures must print the first actual error,
not trailing import progress; a long-output child-process regression covers this.

## 2026-10-24 — audio approvals must update older release contracts too

Do not retain V3 palette-size, extra impact-family or retired artist/license
assertions after an owner-approved switch to legacy weapon SFX and new Chinese
music. Assert actual context aliases, required cue families, deliberate silence
for the removed per-hit layer, and the currently shipped creator/license instead.
Do not weaken failure detection or change product audio to satisfy an old fixture.

The Odyssey combat/inventory fixture emitted an unrelated upgrade WAV during
bulk ascension. Verbose exit evidence identified upgrade_01.wav / its playback
handle. A longer teardown sleep was not reliable and was reverted. Suppress
unrelated audio before this non-audio fixture performs actions, as the economy
fixture already does. Keep dedicated real audio playback tests enabled and the
strict shared error gate unchanged. Run the previously blocked successor suite,
reuse already-passing checks, and distinguish fixture repair from product changes.

## 2026-10-24 — connection refresh, overlay order and complete recovery

Server loadout revalidation emits equipment_changed for UI/stats. Treat that as
synchronization, not manual equip audio. Scope and restore a reentrant quiet
context; do not suppress refresh signals or globally mute gameplay feedback.

Check shared reward z-order against the actual Profile overlay (300), then
claim a real milestone and dispatch input to its visible reward action. A popup
existing in the tree is insufficient evidence that it is readable or clickable.

Keep all weapon acquisition, cast caps and actual travel/visual extents in one
reach contract. Validate new-edge hits and old per-cast totals together. Never
claim a range buff from selector changes alone.

An analysis-only checkpoint cannot restore unuploaded implementation bytes.
The author runtime reset exposed this gap. Include changed source, exact base,
launcher dependencies and evidence in every durable checkpoint before long QA.

Async admin readiness must refresh after reading=false, not only while rendering
inside an in-flight fetch. Exercise pause/resume, double click and dirty draft
protection through actual browser DOM handlers. Keep page-local fonts consistent
with the shared content-versioned Studio stylesheet.

## 2026-10-24 — connection refresh, overlay order and complete recovery

Server loadout revalidation emits equipment_changed for UI/stats. Treat that as
synchronization, not manual equip audio. Scope and restore a reentrant quiet
context; do not suppress refresh signals or globally mute gameplay feedback.

Check shared reward z-order against the actual Profile overlay (300), then
claim a real milestone and dispatch input to its visible reward action. A popup
existing in the tree is insufficient evidence that it is readable or clickable.

Keep all weapon acquisition, cast caps and actual travel/visual extents in one
reach contract. Validate new-edge hits and old per-cast totals together. Never
claim a range buff from selector changes alone.

An analysis-only checkpoint cannot restore unuploaded implementation bytes.
The author runtime reset exposed this gap. Include changed source, exact base,
launcher dependencies and evidence in every durable checkpoint before long QA.

Async admin readiness must refresh after reading=false, not only while rendering
inside an in-flight fetch. Exercise pause/resume, double click and dirty draft
protection through actual browser DOM handlers. Keep page-local fonts consistent
with the shared content-versioned Studio stylesheet.

## 2026-10-24 — connection refresh, overlay order and complete recovery

Server loadout revalidation emits equipment_changed for UI/stats. Treat that as
synchronization, not manual equip audio. Scope and restore a reentrant quiet
context; do not suppress refresh signals or globally mute gameplay feedback.

Check shared reward z-order against the actual Profile overlay (300), then
claim a real milestone and dispatch input to its visible reward action. A popup
existing in the tree is insufficient evidence that it is readable or clickable.

Keep all weapon acquisition, cast caps and actual travel/visual extents in one
reach contract. Validate new-edge hits and old per-cast totals together. Never
claim a range buff from selector changes alone.

An analysis-only checkpoint cannot restore unuploaded implementation bytes.
The author runtime reset exposed this gap. Include changed source, exact base,
launcher dependencies and evidence in every durable checkpoint before long QA.

Async admin readiness must refresh after reading=false, not only while rendering
inside an in-flight fetch. Exercise pause/resume, double click and dirty draft
protection through actual browser DOM handlers. Keep page-local fonts consistent
with the shared content-versioned Studio stylesheet.

## 2026-10-24 — PowerShell5 native stderr must not decide Wrangler success

The Profile deploy script captured Wrangler stderr under ErrorActionPreference=Stop.
Wrangler's non-fatal D1 import warning became NativeCommandError before the exit
code was read, after owner publish and game sync had already succeeded. Both
captured Wrangler calls now collect under a narrowly scoped Continue preference,
record the actual native exit code immediately, and restore Stop in finally.
Keep nonzero exit rejection and the actual Worker Version ID requirement. Save
schema diagnostics before reporting failure. Never silence stderr globally or
skip schema/deployment checks. Windows CI exercises stderr warning+exit0, schema
failure, deploy failure, missing version, successful receipt resume and retry
using isolated native command stubs; it makes no real network/deployment calls.
This script-only correction reuses prior game/GUI/server PASS evidence.

## 2026-10-24 — isolate incidental audio before every non-audio combat fixture

The actual dddaf564 CI artifact showed all74 Arsenal assertions passing before
seven playback resources remained at shutdown. Local success alone had not
excluded the timing-sensitive exit. Apply the existing Odyssey fixture policy
also to Arsenal, Glaive and Compass: stop/drain the startup manager and suppress
incidental SFX before accelerated casts, then drain at exit. Keep production
AudioManager unchanged, real cast damage/boundary assertions intact, dedicated
audio playback tests active and the shared strict Godot-error gate unchanged.
Do not mask cleanup errors or add longer arbitrary shutdown sleeps. Verify the
previously blocked successor suites and repeat the failing fixture with verbose
resource diagnostics. This correction affects tests only; no deploy, native
rebuild or extra AAB. Windows native stderr regression already passed11cases on
the real GitHub runner; do not rework that successful deployment fix.

## 2026-10-24 — final phone composition and visual-only combat changes

Short event markers beside an expanding spacer must reserve measured text width.
A generic wrap pass must respect explicit inline metadata; disable autowrap only
for those markers, not reward descriptions. Exercise the actual LiveOps popup and
native first swipe, accounting for whether that viewport has real scroll overflow.
A fixture mounted outside its actual popup or with the wrong native event stream
can falsely report a gesture failure. Keep the shared mobile scroll policy intact.
Icon-only navigation retains accessible names and identical safe touch targets;
touch tooltips are intentionally suppressed by the shared guard.

Identify a circled effect from source and artwork before replacing it: these
screenshots showed stage hazards, not Compass attacks. Replace prototype runes
with existing painted seals while keeping the exact danger boundary and real
warning/hit behavior. A smaller Compass mesh/head must not shrink collision,
range, cadence, targeting or ledger authority. Derive old spine tests from the
visual length constant instead of hardcoding the retired154px presentation.

Retiring automatic local mail removes its catalog, not historical receipts,
balances or the authenticated server-mail path. Test actual process restart and
both signed Google and Firebase anonymous-guest owner bindings. Do not manufacture
an anonymous unauthenticated reward route or erase existing admin mail.
Keep package install/publish/sync receipts and all transitive sync dependencies
portable; no earlier tools folder is required. A passed author fixture does not
mean owner publish, GitHub CI, AAB export or Android testing occurred.

## 2026-10-24 — controls and Yin Yang final comfort pass

Full-speed joystick output normalizes direction only after the existing deadzone;
keep proportional response as an explicit local option. Fixed mode must leave a
visible base and reject activation away from it. Preserve release, pause, focus
and finger ownership. A live preference reload must use the authored radii, not
multiply the last scaled radii repeatedly. Existing two-argument saves preserve
mode, while Reset Controls explicitly restores the new full-speed default.

Orbit speed used to be constant across all seven Yin Yang levels. When adding
level-based tempo, update existing blades even when an upgrade adds no blade;
otherwise Lv2/4/6 silently retain old speed. Keep sixLv7 blades, hit damage,
Reversal multipliers, real orbit radius, shared0.5s target cooldown and applied
HP-loss ledger. Combat stats must display actual orbit duration rather than the
initial cast cooldown. Test actual moving/stationary physics contacts, inner-gap
safety, all upgrade transitions and temporary Reversal, not just animation counts.

Mount joystick input fixtures in the real screen-space CanvasLayer. A temporary
Control attached to the world canvas inherits the Camera2D transform and yields
false deadzone/multi-touch failures; diagnose the actual transformed coordinates
before modifying production input. Test Settings' first swipe directly on the new
OptionButton in both languages. An empty label hint must not reserve a blank row.
Retain previous unchanged batch evidence. Author fixtures and verified package
installation are separate from owner publish, exact-SHA CI, AAB and Android tests.

## Event operations — 2026-10-25

- Orbit tests must derive real production radius; preserve actual collision and damage assertions when a range upgrade lands. Drain fixture audio instead of masking engine errors.
- Scope event dashboard CSS to its own main content. Never override shared nav typography; keep login hidden until an actual expired session is confirmed. Network uncertainty offers retry.
- A calendar endpoint needs a test through the production router, not just its service function. Shared dashboard reads coalesce; a successful save queues one fresh read without replacing the draft.
- Put cross-event schedule exclusion inside the SQL write, including the initially empty-table race. Use trusted database time and compare-and-swap documents; never rewrite frozen player weeks.
- Event OFF blocks new actions but preserves earned outboxes, paid recovery and valid previously issued signed ad intents. Paused receipt delivery must not mint daily allowances.
- Foreground prewarming is read-only while a durable action/ad intent is pending. Do not replay mutations just because a shorter refresh interval elapsed.
- A mock-root UI test is not a production-autoload fixture. Verify actual event popup closure and button stability with the real clients; do not change production contracts to satisfy unrelated mock managers.
- Save source and completed evidence durably before long packaging work. Resume from exact artifacts and receipts, not assumed previous tool folders.

### Release warning follow-up — 2026-10-25

- Make intentional integer truncation explicit at clock/atlas/milestone boundaries; preserve the original positive-integer result instead of suppressing the warning. Keep ternary branches the same numeric type.
- Avoid built-in names seed/exp, the existing context method name, and same-scope captions declarations. Initialize both optional Compass targets to null before selection.
- Compile all production scripts under the six reported warning categories as errors. Use Script.can_instantiate after loading; forcing reload of scripts with live autoload instances creates an invalid audit. A zero process exit alone is not proof: the shared gate must also reject every SCRIPT ERROR/ERROR line.
- Welcome toast remains a preview pending user design approval. Proposed rule: nickname from the game profile, first successful connection only once per process launch; no reconnect/app-resume repeats or connection sound.

## Approved welcome toast — 2026-10-25

- Keep the once-only flag in a persistent process-lifetime node, not menu/account/reconnect handlers or a saved preference. Attach to the existing identity manager; do not add an unnecessary project autoload. Require acknowledged server identity, connected status and the actual game nickname.
- Delay behind loading/modals and background focus; respect safe area/reduced effects. Decorations ignore every mouse/touch event; test a real GUI tap to the underlying button. No connection sound, full-screen shade, server request or save flag is needed.
- Profile smoke still expected eight permanent domains from the old migration era. Pin the actual existing nine-domain registry including cultivation_mastery; do not modify saves to satisfy an obsolete assertion. Drain fixture audio before and after non-audio tests rather than ignoring engine exit errors.
- Recheck remote HEAD before preparing delivery. Event Operations landed as bdf602f with all21Actions successful; stack this client-only addition on that commit and do not republish/deploy the old batch.

## Gear / summon / account clarity — 2026-10-25

- A paid-wallet background read is not a spend. Do not use a blanket busy flag to disable independent local summons. Actual submitted or journalled mutations still serialize economy actions.
- A tap during a fresh verified read may retain one unsent UI intent only. Validate the latest account, balance, lease and save state after the read; then use the unchanged authoritative submit/journal path. Cancel unsent intent on account/verification/navigation changes; never create a charge from a stale tap or swallow a real pending receipt.
- Preserve the approved gear progression: permanent levels for weapons, identical-duplicate star ascension for all equipment. Explain armor/accessory star-only progression near the top of the popup instead of inventing additional stats/costs.
- Distinguish installation-local progress, Google-owned backup, display nickname and server account UID/wallet. Backup isolation alone does not implement automatic full local-save switching between accounts.
- Avoid built-in identifiers for helper FUNCTIONS as well as variables: a new test helper named seed resolved to Godot's global seed() despite its intended signature. Rename it and let the strict error gate catch parsing failures before any package is delivered.
