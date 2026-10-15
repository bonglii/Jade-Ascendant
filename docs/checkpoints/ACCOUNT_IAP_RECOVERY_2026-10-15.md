# Account, profile transport and IAP recovery — 15 Oktober 2026

Base: UI reliability follow-up `3037142ba72c5c3c9b3e1216db69bb2615767dcd`. This is a delta for the project with both preceding Premium Readiness and UI Reliability patches installed. Existing Home, Hero, combat and artwork are retained. Remote checkpoint inspected read-only before this batch: `6719f50d16997592c244fd1366ec942bc5ea5539`; local packages after it have not been published by this session.

## Changed / player impact

| Area | Concrete change |
| --- | --- |
| Google session | On return from the native account activity, reconcile a completed login/link/logout against the actual native session after 250 ms. No second sign-in is launched. A completed native login need not wait for the 35-second fallback timer. This does not shorten Google/network work that has not completed. |
| Logout and account callbacks | A timeout cannot mistake an existing signed-in user for successful logout. Anonymous-to-Google link reconciliation requires the original UID and a non-anonymous result. Stale signed-out events, stale logout success and unrelated sign-in failure cannot clear/cancel a current native session or logout. |
| Profile backoff | Repeated auth signals respect the existing retry wait instead of restarting failed requests. An explicit Retry still bypasses the wait. Settings reports remaining retry seconds. |
| Profile address failover | After a failed registration POST or health transport attempt, try the next validated address before asking encrypted DNS again. Address lists and automatic cycles remain bounded. Existing original-host TLS/SNI verification, fixed HTTPS resolvers, real TTL and token-owner/nonce checks remain. No OS DNS/proxy/VPN changes. |
| Play product query | Coalesce concurrent requests. Retry transient read failures up to five times with delay 1/2/4/8/16 seconds, and expose timeout instead of waiting indefinitely. Manual refresh/foreground starts a fresh cycle. Configuration errors do not start an automatic retry loop. The installed Billing AAR already enables native auto-reconnection; the game retries its read-only API operation without a second `startConnection`. |
| Play restoration | Serialize queries, coalesce repeated status/configuration requests, retain the request owner, discard stale-owner results and stop a batch if a callback changes owner. A failure is no longer reported as a successful empty ownership snapshot. Pending receipts do not reach purchase verification. |
| Checkout | A second tap cannot launch another Play checkout while one is active. Late checkout completion after a different account is selected is rejected by the provider. Client still never consumes, acknowledges or grants currency. |
| Support report | Settings Copy Support now adds Google/native/busy/elapsed state, purchase identity readiness, Billing stage/product count/authority/recovery-wait state and profile retry delay. It selects fields explicitly; account name/email, private UID, hashes and purchase tokens are excluded. Existing public UID is retained. |
| Native build evidence | Existing build launcher records the AAR hash and the main bridge Kotlin source hash after both variants compile, JVM tests and JNI checks pass. Readiness can detect an unrebuilt main bridge. Receipts live in the already ignored `.local/native_bridge_receipts/`; they prove only that named bridge source/artifact pairing on the PC, not all inputs, the installed APK or live App Check. A rollback removes advisory receipts. |
| Read-only operator check | `check_account_iap.cmd` checks source locks, AAR hashes/build receipts, public health response semantics, selected phone package/permissions and tightly allowlisted QA lines. It does not dump raw logs, select between multiple phones silently, infer VPN, deploy, change DNS or buy anything. |

## Important native callback limitation

The third-party Billing callback contains no request ID. A timed-out restore is therefore quarantined until its late callback drains; a new owner's query cannot borrow that completion. The game reports this state as `Recovery waiting=true`. If the native callback never arrives, restart the game before retrying recovery. This conservative behavior avoids falsely associating an old result with a new account. Server-side purchase owner/replay checks remain authoritative. A future native request-ID API would be needed to remove that limitation safely.

## Unchanged

- Artwork, main menu/Hero layout, weapon/equipment stats and mechanics, loot, gacha odds, prices, rewards and balance.
- Save schema, local progress, identity format, public UID, account merging and Cloud Save. No real player save or account was accessed.
- Production purchase activation, paid summon/write gates, native transport approval, release endpoint and staging allowlist. No flags were enabled.
- Both installed AARs, APK/AAB, Google/Firebase/Play console configuration and remote Worker/D1 data. Native Kotlin is unchanged in this batch; the prior App Check source fix still needs a verified rebuild to reach the phone.
- Backend authentication, Play verification, credit/replay/refund and database implementation. Their existing contracts were exercised, not rewritten.

## Validation in executor

- Godot 4.7.2 actual account manager callbacks: 21 assertions PASS. Includes delayed/mismatched callbacks, timeout reconciliation, same-owner linking, logout and application resume.
- Godot profile recovery: 54 assertions PASS. Existing DNS/TLS/token/401/nonce/privacy cases plus signal-burst backoff and validated-address failover.
- Godot Play provider: 36 assertions PASS. Fake Play boundary exercises actual provider code: finite retries, timeout, query coalescing, owner switch/draining, pending/cancel, checkout double tap, reentrant owner switch, support privacy and no client finalization/balance mutation. No real purchase was made.
- Existing profile identity/UID/save regression: 85 assertions PASS.
- Node signed Auth/App Check, profile auth, Play gateway, pre-consume readiness, purchase credit/replay, refund, staging tester guard and verified repair: 89 tests PASS. Real cryptographic signatures with fixture keys; fake external Play/DB boundaries as specified by the tests. No live purchase/refund proof.
- Readiness launcher executed under PowerShell 7 with mocked HTTPS/ADB: health semantics, missing SDK/build receipt, source lock checks, timeout and log privacy PASS. Windows 5.1 execution on the user's machine is not claimed.
- PowerShell parse, strict patch apply/reverse/tree match and ZIP CRC are recorded in the package validation manifest. CI adds the new runtime test to the existing account workflow, with native compilation and Windows parse jobs retained. CI has not run on an unpublished local commit.

## Pending / external evidence

1. Apply patch and re-export the Android client. The UI/client fixes need no Worker deployment.
2. Rebuild the previous App Check native change with `backend\player_identity\build_native_bridge.cmd` if it has not already been rebuilt. Default/release remain locked. Explicit existing staging option: `build_native_bridge.cmd -Target staging -SandboxCredit`, for the tester debug build only. That command compiles/tests/JNI-checks both variants before replacing AARs; re-export after it.
3. Public `/health` probes from this executor were unavailable; that result does not diagnose the phone/provider or prove a Worker outage. Run `backend\player_identity\check_account_iap.cmd` on the laptop, and use Settings Copy Support from the actual app.
4. Play Console internal test/license tester, correct signing fingerprint, App Check token success, tester allowlist, staged backend configuration/refund monitor and real purchased/pending/cancel/restart/replay/refund behavior require the user's authenticated environment and phone. This session has no Windows SDK/device, Play/Firebase/Cloudflare credentials or live transaction evidence. No remote deployment was attempted.
5. Production IAP is not ready merely because all source tests pass or the Treasury opens. No purchase activation or production-readiness claim is made.

## Publication and installation safety

GitHub read access works; write access previously returned 403 and Git HTTPS lacks credentials. This batch is committed locally and delivered as a strict patch. `publish_account_iap.cmd` publishes the approved cumulative paths of the preceding two packages plus this delta on `checkpoint/iap-fasttrack-20261010`. It verifies the remote SHA before printing the commit URL, rejects unrelated staged/outgoing files and never force-pushes. Main is untouched. The ZIP applier recognizes an installed patch and refuses conflicts without partial application. Evolving generic AGENTS/LESSONS docs are excluded from the portable patch; relevant lessons are included below.

## Lessons retained

- Inspect shipped AAR behavior, not just GDScript, before adding reconnect logic: an auto-reconnecting BillingClient must not get a competing manual connection loop.
- A nonempty native session is not proof that logout or same-owner linking completed. Reconcile each requested operation explicitly.
- Do not treat an uncorrelated timed-out callback as a response for the next account. Drain/quarantine it and retain backend owner checks.
- Auth signal bursts must not defeat backoff; successful HTTP health is not proof of authorized registration or a successful purchase.
- Build success, main-source/artifact receipt, installed APK, real App Check and actual Play/refund evidence are separate results. Report each honestly.
- Test fixtures must respect production cleanup: a link timeout clears its source UID; reset it explicitly before testing the pure same-owner acceptance case. Avoid fixture property names that collide with Node signals.

Primary reference checked against the installed AAR: https://developer.android.com/google/play/billing/integrate (auto-service-reconnection uses a read API call; do not restart a second connection in onBillingServiceDisconnected). Firebase session/ID-token reference: https://firebase.google.com/docs/auth/admin/verify-id-tokens . No library version upgrade was made.
