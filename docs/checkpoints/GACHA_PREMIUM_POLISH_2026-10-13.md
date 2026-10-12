# Celestial Pavilion premium polish — 2026-10-13

User approved aggressive native polish and new assets after reviewing the selector crop and ten sealed results. This is incremental to Gacha Sanctum R2 (all-or-nothing patch). Protected main/production and parked IAP features remain excluded.

## Native changes

- Three new ImageGen production assets: ancient celestial jade/gold gate, transparent ceremonial seal, and one transparent qi dragon. Original game PNGs are untouched. Artwork provenance, roles, hashes and prompt summaries are in `assets/ui/pavilion/sanctum_premium/asset_sources.json`. Assets were generated using the built-in ImageGen tool, inspected, copied into the project and rendered natively before delivery.
- Home altar uses the new architecture, larger actual equipment icons with slot captions, selected-target trim, and one quiet dark action bank for guarantee/cost/ad controls. Shader-free native drawing preserves aspect ratio; the old flattened altar and baked rectangular dragon are removed from this renderer.
- Ritual phases: silence/seal → qi charge → gate opening → impact → eased equipment landing and copy. Common/Rare/Epic/Legendary sequences are 1.05/1.8/2.8/4.1 seconds. The camera eases into the gate; Legendary adds dragon awakening, split seams, gold rays and one restrained impact veil. Audio is triggered once at the actual reveal cue, including skips. Reduced effects bypass motion and flash immediately.
- Legendary results and actual five-star equipment opened from the ten-result formation get a dedicated focus cinematic, then return to the same formation and opened-state without rerolls or extra rewards. Reveal All bypasses ten repeated cinematics. Reopening a revealed relik is presentation-only.
- Batch results are two columns/five rows for ten pulls. Row height follows available space; narrow/short views scroll while Continue stays pinned. Remove empty metadata rows; use themed backdrop, the new seal, actual gear icons, names, rarity, actual ascension stars and actual duplicate shard counts.
- Rarity and ascension are not conflated: a new Legendary can still display one filled star plus four empty stars. A five-star Rare can receive the premium visual but still shows its actual Rare label. No acquisition rules, rates, pity, prices, ascension, rewarded policy or grants are changed.
- Existing verified rewarded bridge remains the free-one-pull route (one Seal). Provider unavailability/cooldown/limits remain truthful; no fake ad completion or new ad backend.

## Popup error and editor warnings

- `idle_cultivation_presenter_premium._fit_modal_to_content` previously checked references only before two frame waits. Closing during a wait cleared the body; the resumed function called `get_combined_minimum_size` on null. Capture all four target nodes, then validate identity/liveness/queued-deletion state after each frame. Stale callbacks cannot resize a new popup.
- Rename local/argument shadowing in billing runtime status, cache validation, mail reward owner binding and identity readiness. Rename the nested mail-load variable; make elapsed-time truncation explicit through float division and int conversion. The daily offer signal is externally emitted; retain it with only its specific unused-signal warning annotated. Billing/auth behavior and all backend monetization code stay unchanged.

## Verification

- Native Godot 4.7.2 QA: 501 checks across English/Indonesian and 320×568, 390×844, 540×960, 648×1152, 896×504. Covers four rarity sequences, duplicate values, viewport bounds, two-column formation, focused reveal/return, back, all/skip, reduced effects, real committed ten pull, double tap, star/rarity separation and natural completion.
- Modal lifetime stress: 62 checks, zero failures: close at either waited frame, reopen twenty times, old fit leaves new target untouched, valid target still fits, detach during fit, no resource grants.
- Server mail gifts: 60 checks, zero failures; actual Jade/Seal/gear grants, duplicate conversion, replay idempotence and save failure handling. One pre-existing shutdown resource cleanup report exists in that fixture; no script error in the tested behavior.
- Identity/mail Node suite: 40 tests, zero failures. Restart retains exact committed summon counters.
- Native QA/renderer fixtures may report existing resource cleanup warnings when quitting the entire engine; these are distinct from the fixed live popup script exception. Do not claim the whole project is warning-free.
- Native compatibility renderer captures home, Legendary/five-star landing, sealed/open 2×5 and narrow layout. Fixture stars/balances are explicitly QA data, not a production grant. Live Android ad completion is not exercised here.
- Binary patch check/apply uses a temporary index against R2 and verifies every final blob. Existing `publish_paths.json` and base publisher are excluded to avoid the previously observed context conflict.

## Install and publish

Apply only after R2:

`git apply --check "D:\Godot\tools\Jade-Ascendant-Gacha-Premium-Polish.patch"`

`git apply "D:\Godot\tools\Jade-Ascendant-Gacha-Premium-Polish.patch"`

Open Godot to import the three PNG assets, then export Android once. Client-only: no Worker deployment or password reset.

`backend\player_identity\publish_gacha.cmd` uses explicit Windows PowerShell, stages reviewed sources/assets on the authorized checkpoint branch, performs checks, pushes without force and prints the real verified GitHub commit URL. No new remote commit is claimed by this deliverable.
