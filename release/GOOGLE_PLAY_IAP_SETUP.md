# Jade Ascendant — Google Play Billing Setup

Package ID: com.yungdevstudio.jadeascendant
Plugin: official GodotGooglePlayBilling 3.3.0

Active Celestial Jade product mapping (canonical game ID -> Google Play product ID):
- jade_pouch_100 -> jade_pouch_100 — consumable — 100 Celestial Jade
- jade_satchel_550 -> jade_pouch_550 — consumable — 550 Celestial Jade
- jade_casket_1200 -> jade_pouch_1200 — consumable — 1,200 Celestial Jade
- jade_vault_2500 -> jade_pouch_2500 — consumable — 2,500 Celestial Jade
- jade_treasury_6500 -> jade_pouch_6500 — consumable — 6,500 Celestial Jade
- jade_ascendant_14000 -> jade_pouch_14000 — consumable — 14,000 Celestial Jade

The canonical game IDs above remain unchanged in economy/reward/UI/save code.
google_play_billing_provider.gd translates only at the Google Play boundary.

Code-supported but not part of the six active Celestial Jade packs in this pass:
- starter_support_pack — non-consumable — 100 Jade + 3 Pavilion Seals

monthly_jade_blessing is intentionally NOT enabled by this pass.

QA behavior:
- money prices always come from Google Play product details
- PENDING purchases grant nothing
- Jade packs consume only after the game save succeeds
- Starter Support Pack acknowledges only after the game save succeeds
- interrupted purchases remain recoverable through Restore Purchases
- exact purchase-token replay is idempotent and cannot double-grant
- Play product IDs are translated back to canonical game IDs before reward/save logic

Use a Google Play license tester. Google currently allows license testers to
test Billing with debug-signed/sideloaded builds as long as package identity
matches the Play Console app, which is useful while Treasury remains QA-only.

Production hardening:
This pass trusts purchase state/token returned by the Google Play Billing client.
For stronger protection against modified clients before broad commercial launch,
add server-side purchase-token verification with Google Play Developer APIs.
