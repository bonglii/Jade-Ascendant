# Delivery and Home motion recovery

Scope: bug fixes and the supplied animated Home background. Version, export presets,
Play internal-track configuration, save migration, economy and production activation
are intentionally unchanged. No remote deployment or real purchase was performed.

## Confirmed integration gap
M14 purchase receipts credit the server wallet, while get_celestial_jade reads the
local wallet. The old success message claimed reward delivery even though paid
spending/runtime cutover remain locked. This package exposes a separately verified
purchased balance and labels tester credit accurately. It does not fabricate a local
credit or claim the user's transaction has been recovered. Usable purchased spending
is still incomplete and is a release blocker, not a DNS fix.

Correlated request IDs, captured account binding, revision validation, coalescing,
45/46-second deadlines and account reset prevent stale responses showing another
account's balance. Already-verified ledger repair supports purchases no longer in
Play's active purchase query. Pending approval releases the recovery UI; checkout
also requires native billing readiness. Support copy includes only allowlisted stage
and balance metadata, no tokens, purchase order or raw account identifiers.

Optional tester backend config: backend/monetization/cloudflare/wrangler.wallet-recovery.toml
adds wallet read and verified-ledger repair to the same staging worker/database. It
retains the signed Firebase/App Check tester gate and all paid spending locks. It has
NOT been deployed. Existing staging config and production config remain unchanged.
Other accounts are intentionally rejected by the tester gate; a healthy /health does
not prove account registration, billing, App Check or delivery.

## Animated Home
Uses the user-supplied Lin Yue video, converted to a silent local 540x960, 20fps
Theora loop with a short seam blend. A matching poster remains until decoding starts.
Resources load lazily; reduce-effects, backgrounding, hidden Home and known overlays
pause playback. Leaving Home releases the player. Click targets and UI layout stay
intact. Phone decoder cost and actual visual loop require device verification.

## DNS limits
Profile has its existing validated encrypted-DNS fallback with original hostname/TLS.
Native IAP HTTPS still uses Android DNS. No TLS bypass, IP pinning, global DNS change
or blanket cross-provider guarantee was introduced. Stage guards and payment
activation cannot be diagnosed from DNS alone.

## Workflow / lessons
Always trace checkout -> verification -> server ledger -> visible usable balance.
A purchase receipt or edited Kotlin source alone does not prove on-device delivery
or an updated AAR. Do not turn pending Play approvals into success. Correlate late
callbacks and reset account state. Texture minimum size can break small portrait
layouts; ignore intrinsic poster size and test multiple aspect ratios. Never repeat
an entire old batch when targeted regression covers the changed boundaries.

Publish from CMD after applying this package:
backend\player_identity\publish_delivery_motion.cmd
The publisher verifies FETCH_HEAD, checks only authorized cumulative paths, refuses
force-push/main/unrelated staging, and prints a GitHub URL only after remote SHA match.

## Validation on 2026-10-15
- Godot 4.7.2 actual manager/ledger view: 31 assertions, passed.
- Motion lifecycle / four aspect ratios: 15 assertions, passed.
- Native OpenGL render with real Theora decode, progress, overlay pause/resume and
  leaving Home: 6 assertions, passed; actual frames captured and inspected.
- Existing Home navigation: 193 assertions; Billing recovery: 36; Google callback:
  21; Profile resilience: 54; all passed using isolated QA save locations.
- Backend read / verified repair / purchase credit / preconsume: 62 tests, passed.
- Staging tester guard and optional config: 3 tests, passed.
- Android debug and release: 66 JVM tests each, zero failures; both AARs rebuilt.
  JNI verifier checks 20 methods per AAR and locked release constants. Source and
  binary hashes are in DELIVERY_MOTION_NATIVE.json. Phone integration is unverified.
- Home/native render tests emit shutdown resource/ObjectDB warnings while assertions
  pass. They are recorded; this is not a zero-warning or phone performance claim.
- Existing Kotlin unchecked-cast/type warnings remain in unchanged contract files.
- No confirmed recovery of the user's actual Play test order; server logs and the
  signed installed app still need to prove that boundary. No purchase was started.

The shipped debug AAR targets staging tester credit. Release AAR keeps production
checkout locked. Exporting a release AAB does not automatically activate purchases.
