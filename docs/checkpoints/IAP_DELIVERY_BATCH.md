# IAP delivery audit and stabilization

Base: verified GitHub c5f8580b88596d5ea54f029a5dfe6011e839a7bd.
This is NOT a declaration of production-ready IAP or recovery of a particular order.
No remote service was deployed and no payment was started.

## Confirmed blockers
The native M14 receipt credits a server wallet, but the shipping summon uses the
local wallet. Backend paid canonical inventory permits only one owned copy per ID
and converts duplicates to rarity fragments. The game now keeps identical copies
for ascension, separate weapon levels, and removed refinement fragments. The
pinned paid catalog has 40 items; current active game catalog has 56 (16 missing
from paid catalog; exact IDs in IAP_CATALOG_AUDIT.json). Paid runtime/entitlement
cutover is still locked. Do not enable it by flipping flags or adding server balance
to local Jade. That would not fulfill the purchase correctly.

New checkout is now blocked in both UI and PavilionManager until paid delivery can
actually fulfill the current game contract. Existing server/Play purchase recovery
is deliberately still available. No purchased currency is deleted or duplicated.
The next fulfillment work must preserve actual existing server outcomes/ownership,
use counted copies and compatible catalog/upgrade rules, then integrate signed
runtime entitlements; it cannot assume an empty database. Actual staging ledger
read is needed first to determine the reported order and existing migration state.
This remaining fulfillment work is NOT implemented or activated by this package.

## Implemented
- Native IAP uses a shared OkHttp HTTPS transport for the six fixed native routes.
  Fixed bootstrapped encrypted DNS providers first, then validated system DNS.
  Service URL/hostname/SNI and platform certificate verification stay intact;
  redirects and implicit POST retries are disabled; bodies/responses/time are bounded.
  No raw service-IP URL, permissive trust manager or TLS bypass. Resolver requests
  contain only the service DNS name, never Auth/App Check/purchase tokens.
- M14 purchase verification has a 45-second operation fence; late callbacks cannot
  complete another purchase or clear its busy flag. Signed wallet read/repair also
  has a bound. One 401 may refresh Auth AND obtain a fresh limited-use App Check
  token, then retry the same logical operation. A 403 is not treated as expired auth.
- Ledger recovery no longer depends on a live Play Billing provider. This covers
  consumed purchases absent from the Play active-purchase query. Timeout updates UI;
  spam coalesces and old account/request callbacks remain rejected.
- Treasury shows precise server-ledger recovery results, timeout guidance and
  CHECKOUT PAUSED. Support copy adds fixed stages, native DNS route and a 12-character
  hash prefix to correlate operator diagnosis, never raw account UID or Play token.
- Both AARs rebuilt and verified; Godot export dependencies updated together with
  native dependencies. New provenance checks all 17 source/config inputs rather
  than only the main Kotlin file. Text hashes normalize CRLF, binary hashes do not.
- New CI checks backend boundaries plus real Windows PowerShell publisher/provenance
  tests after publishing. CI has not been run here; Linux fixtures are labelled.

## Required read-only evidence
After applying, from CMD in project root:
backend\player_identity\diagnose_iap_delivery.cmd

This reads ONLY configured staging DB c7c9841f-cbd3-4563-b13f-21ed90d45120 through
Wrangler's existing user login; no deploy, migration, credit, debit or repair is
executed by that command. It reports all staging accounts using only hash prefixes,
verified/credited/not-credited counts, balance, voids/holds and refund-monitor age.
No token, raw UID, grant ID, service-account key or password is selected/output.
Result goes to ignored .local/iap_delivery/diagnosis-latest.json. Empty rows are NOT
proof that Play checkout did not occur; wrong environment/account and unverified
purchase states still need investigation. Missing schema/query failure is reported,
never interpreted as zero purchases. Do not paste secrets; the displayed table is
sufficient. This read has NOT been performed against the user's remote DB here.

## Unchanged / limits
Version/internal test 1.0.7, export presets, gameplay saves, economy balances,
production flags and backend data unchanged. Production/release checkout stays
locked. Existing staging recovery configuration has not been deployed here.
No refund freshness cursor, stage victory or server entitlement is fabricated.
Google native sign-in UI/provider DNS still belongs to Firebase/Google; this IAP DNS
change is not a claim to fix every Google network or every ISP. No Android device
TLS, latency, purchase recovery or AAB test performed in this environment.

## Validation
- Godot isolated real manager boundaries: 15 new assertions + 31 existing ledger
  delivery + 36 billing recovery + 21 Google callbacks + 54 profile = 157 passed.
- Native debug/release: see exact current counts/hashes in IAP_DELIVERY_NATIVE.json.
  Added real HTTPS fixture tests cover trusted/untrusted/wrong-host certificates,
  redirect credential isolation, no hidden POST retry, bounds and empty repair body.
- Actual SQLite diagnosis + existing credit/refund/repair/tester guards: 48 tests pass.
- Operator CLI decoder tested normal and non-enumerating JSON behavior, no live CLI
  auth or remote DB call. Provenance covers full input set and CRLF sensitivity.
- Publisher/installer tests use isolated Git repositories, not production remotes.
- Existing Gradle/Kotlin warnings remain; passing assertions are not a zero-warning,
  live order recovery or phone performance claim. Re-export is needed to install
  new native transport/dependencies, but the read-only ledger diagnosis needs no APK.

## Lessons / prevention
A checkout result or credited server wallet is not usable delivery. Audit the
actual game inventory and duplicate/upgrade contract before enabling paid spending.
Do not rebuild only Kotlin source without matching the shipped AAR and export
runtime dependencies. A successful health GET does not prove signed native POST.
Keep timeout/retry/request/account scopes explicit and never retry a purchase as a
new order. Diagnose real ledger/hold/refund states before changing business gates.
Use full Windows PowerShell path from CMD; test non-enumerating JSON arrays and
preserve active Git index locks. Version setup remains the user's task.

## Publishing
backend\player_identity\publish_iap_delivery.cmd
Only the authorized checkpoint branch; FETCH_HEAD ancestry, cumulative allowlist,
whitespace and remote SHA verified. No force-push or main writes. GitHub URL may
only be claimed after successful push and SHA match.
