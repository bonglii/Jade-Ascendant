# Unified Pavilion and honest reveal — 2026-10-13

Incremental client patch after `Jade-Ascendant-Gacha-Premium-Polish.patch`. User requested whole-Pavilion cohesion, removal of the cut/pasted altar appearance, hidden equipment identity until the ritual ends, and clear blue Rare/purple Epic/gold Legendary cues. Assets may be generated and used autonomously.

## Composition

A new original ImageGen portrait sanctuary covers the entire Pavilion. Gate and relic share the same environment, with a quiet jade floor continuing through summon controls and meditation. The Home stage draws no separate backdrop, rectangular tint or opaque shell. Existing service cards receive the same jade material as the action bank. Resource bar, meditation behavior, utility navigation and parked features retain their rules. Asset provenance/prompt summary/hash are in `asset_sources.json`.

## Reveal boundary

The old renderer showed equipment at 74% while still playing, and individual formation taps filled the result card before its focused ritual. Both were visible spoilers.

- A pending texture is kept separate from the visible texture. `relic` stays null throughout the entire ritual, including 99%; equipment is promoted only on normal completion or an explicit Skip.
- The seal, qi, gate and rarity clues carry the anticipation. Names, slot, actual ascension stars and duplicate counts appear only on landing, alongside the equipment and impact cue. Landed image/copy ease in together.
- Every manually opened seal, Common through Legendary, uses its rarity ritual. Its underlying card icon/text/tooltip remain sealed until completion. Returning preserves the opened formation. Explicit Reveal All intentionally bypasses the animations.
- Common jade/gray, Rare blue, Epic violet, Legendary gold. Rarity text reinforces color after the initial quiet phase. No five-star Rare is misleadingly recolored gold: actual rarity controls anticipation; ascension affects only the landed flourish.
- Batch intro shows only the highest rarity hint, never its actual equipment. It clears the preview when opening the formation. History is blocked while the reveal overlay is open.
- Reused views clear old result textures before opening. Back cancels presentation only; existing committed economy/save authority is unchanged.

## Verification

Godot 4.7.2: 701 native checks, zero failures; EN/ID and five viewport sizes from 320×568 through landscape. Covers identities/tooltip/texture hidden at 99%, true rarity hints, history guard, all four individual rarities, seal still closed while animating, normal/skip/all/back/reduced-effects flows, actual ten-pull commit and double-tap guard. Restart retains exact committed counters.

Real OpenGL renderer pixel regression: two actual equipment outcomes per rarity, frozen at 99%, have byte-identical rendered stage pixels. After completion their stage pixels differ. Rare/Epic anticipation frames also differ. This checks actual visible pixels, beyond variable state. QA fixtures may report resource cleanup on immediate whole-engine exit; these are distinct from live script errors.

Native screenshots/video inspected for the one continuous Home backdrop, large relic placement, full ten-result formation, and revealed/hidden states. No server deployment, credential changes, rates/prices/pity edits or monetization backend changes. Main/production and parked IAP remain untouched. No GitHub push is claimed here.

## Install

`git apply --check "D:\Godot\tools\Jade-Ascendant-Pavilion-Unified-Reveal.patch"`

`git apply "D:\Godot\tools\Jade-Ascendant-Pavilion-Unified-Reveal.patch"`

Open Godot to import the new background, export Android once, test single and ten pulls on the actual phone. Publish using `backend\player_identity\publish_gacha.cmd`; it uses the explicit Windows PowerShell path and prints the verified GitHub commit link after a successful normal push. Mutable global publisher files are excluded from this incremental patch.
