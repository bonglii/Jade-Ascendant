# Jade Ascendant — Google Play Billing & Secure Treasury Contract

Package ID: com.yungdevstudio.jadeascendant
Billing plugin: official GodotGooglePlayBilling 3.3.0
Secure callable region: asia-southeast2

## Active Celestial Jade products

Canonical game ID -> Google Play product ID:

- jade_pouch_100 -> jade_pouch_100 — consumable — 100 Celestial Jade
- jade_satchel_550 -> jade_pouch_550 — consumable — 550 Celestial Jade
- jade_casket_1200 -> jade_pouch_1200 — consumable — 1,200 Celestial Jade
- jade_vault_2500 -> jade_pouch_2500 — consumable — 2,500 Celestial Jade
- jade_treasury_6500 -> jade_pouch_6500 — consumable — 6,500 Celestial Jade
- jade_ascendant_14000 -> jade_pouch_14000 — consumable — 14,000 Celestial Jade

Canonical game IDs stay unchanged in economy, UI and save code.
`google_play_billing_provider.gd` translates only at the Google Play boundary.

Code-supported but NOT active Treasury products:
- starter_support_pack
- monthly_jade_blessing

## Treasury production contract

The Treasury is presentation-only. It may display the six active Celestial Jade
packs and localized Google Play product details, but it never decides a money
price, validates a purchase token, consumes/acknowledges a Play purchase, or
mints paid currency.

Money prices must come from live Google Play product details. Treasury refuses
to start checkout when a positive Play price and formatted localized price are
not available.

Secure purchase flow:

1. Google Play Billing opens checkout with the Firebase account binding as the
   obfuscated account ID.
2. A PURCHASED token is forwarded transiently to
   `JadeMonetizationNativeBridge`; it is not persisted in GDScript/save state.
3. The native bridge calls fixed callable `jadeAuthorizePurchase` with exactly
   `{ purchase_token }`. Firebase Auth and App Check are required.
4. Server authority verifies package, product, purchase state and account
   binding against Google Play, creates/repairs the durable ledger, and consumes
   the consumable before exposing a client grant.
5. Only canonical `grant_ready` data reaches PavilionManager:
   `purchase_contract_version`, `state`, `grant_id`, `internal_product_id`,
   `celestial_jade`.
6. PavilionManager revalidates that grant and atomically saves Celestial Jade
   with exact grant-id replay protection.

The client does NOT consume, acknowledge, finalize or invent paid purchases.

## Recovery contract

Restore/recovery queries Google Play again instead of storing a local raw-token
queue. M2 serializes one secure authority request at a time. If multiple
recoverable purchases are returned, later purchases are recovered by a fresh
Play rescan after the current grant succeeds.

Server ledger states make retries idempotent. A consume failure exposes no grant;
a retry can resume `verified_pending_consume`. A grant already in `grant_ready`
replays the same stable canonical grant without consuming twice.

Treasury treats delivery success and failure as terminal for the current UI
transaction so the storefront cannot remain stuck in a permanent busy state.

## Current production activation boundary

M3 defines and tests the Treasury production contract; it does NOT activate
commercial checkout.

Current locked state remains fail-closed:
- `SECURE_PURCHASE_ACTIVATION_APPROVED = false`
- secure callable runtime/deployment is not approved
- production Google Play API credentials/access are not approved
- persistent production ledger is not approved
- monetization native bridge AAR is not integrated into the shipping project
- `project.godot` does not enable `JadeMonetizationNativeBridge`
- checkout and purchase recovery remain disabled
- Cloud Save remains unchanged and is not purchase authority

Production activation belongs to later monetization release gates and requires
explicit approval plus the already-defined secure runtime prerequisites.

## M5 monetization release gates

M5 does not activate paid checkout. It converts the remaining monetization
release requirements into an executable CI gate so a future release cannot
silently bypass the locked security boundaries.

Current lane status:

- Rewarded ads code gate: **PASS**. M4 locked production IDs, UMP consent
  fail-closed behavior, bounded consent/load retries, privacy options, and
  SDK-callback-only reward authority. External closed-testing and policy
  validation are still required before broad release.
- Paid purchase security-contract gate: **PASS**. The server-authoritative
  purchase flow, recovery, Treasury contract, and replay protection are locked.
- Paid purchase production gate: **BLOCKED**. Production deployment,
  credentials, Google Play Developer API access, persistent ledger runtime,
  shipping `JadeMonetizationNativeBridge` integration, and explicit activation
  approval are not present.
- Full monetization release gate: **BLOCKED** while the paid purchase production
  gate remains blocked.

The release gate must stay exact-SHA CI enforced. Enabling commercial checkout
requires a separate explicit approval change after the missing production
prerequisites have been supplied and validated; M5 itself does not change
`SECURE_PURCHASE_ACTIVATION_APPROVED`, `project.godot`, backend deployment, or
Cloud Save.

## M6 exact-SHA CI and final monetization lock

M6 closes the monetization engineering phase without activating blocked paid
purchase production. Every required CI job explicitly checks out
`${{ github.sha }}` and verifies repository `HEAD == GITHUB_SHA` before QA.

Final lock status after the M6 commit's own exact-SHA CI is green:
- Monetization engineering/security lock: **FINAL**
- Rewarded ads code gate: **PASS**; external closed-testing/policy validation remains required
- Paid purchase security-contract gate: **PASS**
- Paid purchase production gate: **BLOCKED**
- Full commercial monetization release gate: **BLOCKED**

M6 does not deploy Firebase, add production credentials, integrate the
monetization bridge AAR into the shipping project, enable paid checkout, modify
runtime monetization logic, or give Cloud Save purchase authority.
