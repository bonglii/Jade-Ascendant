# Ascendant Trials — approved redesign, 2026-10-18

Base: 1a59a9ed0badcaaa21a6a1fe19b00f9dbcb8af40, checkpoint/iap-fasttrack-20261010.

## Delivered

- Daily Disciplines and Eternal Records use two generated temple headers from the approved concept, carved gold/jade frames, existing licensed archive serif and engraved category medallions.
- Daily cards show the real mission description/progress, Spirit Stone reward, Claim/Claimed/Go states. Go opens chapter selection because daily cultivation goals concern run level. Claim All stays outside the scroll area.
- Achievement filters: All, Combat (combat + boss), Journey, Cultivation (cultivation + progression). Filters hide cached cards without deleting them. No fabricated achievement lock gates.
- Completion totals, reward values, daily reset countdown and badges come from the existing managers/local date boundary. No sample preview balances installed.
- Both tabs retain their own trees and scroll regions. Incremental construction, signature-based card refresh and manager-owned duplicate protection remain inherited.
- Narrow cards move their action/reward row beneath the description. Very short screens compact the heading; filters use two columns. Scrollbars remain hidden without disabling scrolling. No moving entrance/font resize after first paint.
- Responsive reparenting exposed duplicate signal connections in MobileTouchPresentationGuard. Existing connections are now reused and OptionButton cancellation is installed once.

## Scope preserved

No reward amounts, quest definitions, achievement targets, save format, gacha, paid wallet, IAP, native Google login, network/DNS routing, backend deployment, export preset, version or signing changes. Existing common wallet and bottom navigation stay in place. New interactive events and public release submission remain separate.

## Validation

357 targeted assertions pass headless and in real desktop OpenGL rendering: exact-once single/bulk daily claims, individual achievement claims, simulated touch swipe claim fence, actual category mapping, cached cards, four viewport sizes, direct achievement entry and rapid tab switching. This is not a new Android hardware test.

All 303 production scripts load with the engine's 41 default-enabled warning categories promoted to errors in the isolated QA project. Production warning settings are unchanged. Native renderer reports only its expected unsupported V-Sync driver warning.

Installer checks cover payload/source integrity, atomic conflict refusal, idempotency, preserving local notes/export settings, and scoped commit/non-force push against a local bare Git fixture. No automatic index.lock removal.

Artwork prompts/provenance: assets/ui/trials/ascendant_v2/asset_sources.json.
Actual desktop captures are included in the delivery ZIP's Review directory; sample QA balances are isolated.
