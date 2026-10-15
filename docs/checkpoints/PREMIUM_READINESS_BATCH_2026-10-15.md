# Premium presentation and account resilience — 2026-10-15

Base: published Home Sanctuary `6719f50d16997592c244fd1366ec942bc5ea5539`. The interrupted environment contained an older snapshot; it was preserved. A separate worktree was recovered from the actual remote. Previous uncommitted batch files were unavailable, so only the missing batch source was reconstructed, then revalidated. Home assets/content and unchanged combat balance were not redesigned again.

## Implemented

- Result frame/background artwork in native SVG: jade victory, crimson defeat. The scroll reader stays inside its frame; actions remain fixed. Short reports use content-dependent height. No-receipt Victory no longer claims a secured reward.
- Removed character-overhead skill/passive selection popup; real shield/healing proc acknowledgements remain.
- One pure catalog icon resolver shared by choices/library/report. Run report snapshots the actual starter armament, including Sword Dao resonance, rather than reading current hub equipment. Existing per-source damage accounting/Continue format retained.
- Increased full-set alpha while retaining accepted geometry, fade, timings, reduced-effects limits, proc conditions and draw count.
- Hero loadout stays fixed above a separate five-column backpack scroller; compact short/landscape layout, larger stars and stronger native rarity rims. Filters update collection only. Dropdown sizing cannot use longest string to force overflow.
- Touch hover and hover-pressed use normal visuals; accumulated drag is remembered even after returning to the press origin. Scrollbar policy is shared across live scrollers without disabling their scrolling axes.
- Settings uses new glass/beveled vector cards and background, adds visual presets and connection retry/support summary. Presets persist device preferences once without resetting audio/language/haptics/damage settings. Support report is allowlisted; no raw Firebase UID, email, tokens, account hash or save data. Cloud Save copy corrected.
- Profile uses normal hostname first (including healthy IPv6 networks), bounded threaded requests, callback nonce correlation, one forced fresh-token retry for 401, same-owner signal deduplication and bounded backoff. TLS/connect/DNS failures may use two fixed encrypted DNS resolvers with original-host certificate/SNI validation, related A/CNAME validation, public IP filtering and capped real TTL. No OS DNS, proxy or VPN modification.
- Mail and Google callbacks reject stale account results. Google timeout reconciles a completed native sign-in before showing a timeout.
- Shared backend verifier uses workerd-compatible manual redirects with explicit rejection, coalesces key fetches, refreshes rotated keys with a per-endpoint limit and rejects malformed JWKS. Cryptographic verification remains mandatory. Profile auth_time uses the supplied verification clock.
- Native App Check can recover from Firebase initialization order, with 2-second throttle and exact project guard. Public Godot JNI surface retained. This is SOURCE ONLY until rebuilt.

## Verification in this executor

Godot 4.7.2 Linux; isolated user-data folders, actual production scenes/scripts. No player save/account data, customer mail, payment or remote DB was used.

| Check | Result |
| --- | --- |
| Hero burst/upgrade, stale actions, save behavior | 734 assertions, PASS |
| Premium UI: 320/390/648 portrait, 896×504 landscape; pinned deck, scroll, dropdowns, settings and result icons | 160 assertions, PASS |
| Profile DNS/UTF-8/owner/401/nonce/TLS/TTL/privacy | 49 assertions, PASS |
| Google delayed callback/link/timeout reconciliation | 10 assertions, PASS |
| Existing profile binding/UID/save regression | 85 assertions, PASS |
| Mail/gifts receipt, owner, replay, retired-content conversion, real restart | 26 + 76 assertions; restart 10 + 6, PASS |
| Run report applied damage/skills/checkpoint/final hit | 175 assertions, PASS |
| Existing legendary set mechanics/visibility lifecycle | 90 assertions, PASS |
| Existing combat skill presentation including removed selection popup + retained proc feedback | 261 assertions, PASS |
| Signed JWT/rotation/redirect/concurrency/forgery, Play verify, purchase credit/refund and profile auth | 61 Node tests, PASS |
| Balance export | PASS, PLAYER_STATE_UNCHANGED, 26 stages / 56 equipment / 32 classic-weapon milestone rows |
| Native render | Real Hero, Settings, Victory and Defeat captured and inspected; isolated fixtures, not phone FPS evidence |
| PowerShell | Five launchers parsed; applier executed with real Linux Git: apply, already-installed, conflict preserves files, branch guard. Windows 5.1 execution not claimed; CI parse job added |

Several inherited standalone Godot tests retain resources at process teardown despite zero assertion failures; they are not proof of a runtime memory leak. The final native fixture explicitly releases audio/scenes. AAR compilation/JVM/JNI and live Android/Play/provider evidence are not included as completed local results. CI workflow results must be checked on the actual published commit.

## Remaining operator actions

- `backend\player_identity\deploy_profile_resilience.cmd`: existing profile worker config, scoped tests, code deployment only; no DB creation/reset/migration.
- `backend\player_identity\build_native_bridge.cmd`: locked build by default; validates both variants/JNI/release locks before replacing AARs. For an explicitly staged debug build, existing `-Target staging -SandboxCredit` option is available; release stays locked. Native dependency download/build needs the user's Android SDK/JDK/network.
- `backend\player_identity\diagnose_connectivity.cmd`: read-only PC/phone clock, package/permissions, DNS/TLS classification; no raw auth log dump or VPN inference.
- IAP staging deployment, Play/Firebase/App Check setup and real sandbox transaction/refund evidence remain separate from the completed client/profile source fixes. No production IAP flags or balances were changed.

Read `GAME_REVIEW_2026-10-15.md` for the full player/developer assessment and correctly scoped economy evidence.

## Lessons included in the portable package

Verify actual workspace HEAD before resuming; do not replace newer files with a restored old snapshot. Preserve a separate worktree. Execute dynamically loaded scenes after import. Replace bounded functions to avoid indentation errors. Test both shrinking/growing viewport sizes, and clip native dropdown/button text to prevent minimum-width overflow. Keep pure shared classes independent of autoload globals; lazy-load dependent test fixtures. Reproduce paused gameplay for result rendering. Distinguish source/native build/live service proof. A sparse patch-validation worktree needs `read-tree` before partial checkout; otherwise its empty index cannot prove whole-tree equality. Old mail fixtures still expected Bell and spendable fragments; active catalog parity and one-time 20-Stone historical-fragment conversion were brought into line with the already accepted runtime, without changing grants or economy. These are also recorded in LESSONS.md in the Git commit; the portable patch deliberately excludes that evolving generic file to avoid the previously reported patch conflicts.
