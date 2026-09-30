# Jade Ascendant — Realm IV boss pass / working standards

Date: 2026-09-30. Engine target: Godot 4.7.2 / portrait mobile. Source of truth for the **new** boss scripts and TRES atlas contracts: the already QA-passed Gate B delivery; full local source may be ahead of GitHub `main`.

## Production policy

- Never change Chapter 1–3 boss gameplay, shared Journey/Reward/Checkpoint save fields, or Chapter 5 assets while polishing Chapter 4 boss presentation.
- Keep the existing `boss_1.gd` contract: max HP, contact damage, phase gate, health_changed, phase_changed, boss_defeated, CombatFeedback, audio context, defeat reward, and collisions.
- Sprite frames must remain 4×4 × 128px, transparent RGBA PNG; do not alter the existing 30 named animations or `SpriteFrames` mappings as part of a sprite-only pass.
- Distinct role silhouettes for **each** boss, not five tinted copies of the same guardian. Stage-specific silhouette grammar:
  - 4-1 Frostveil Pathkeeper: lean ice-gate warrior + paired obelisk banners.
  - 4-2 Shattered Mirror Abbot: tall monk + asymmetrical fragmented mirror halo.
  - 4-3 Lotus of Still Waters: light female lotus priestess + sculpted petal crown.
  - 4-4 Tollkeeper of the Deep: wide golem + hanging bell, iron chains, bronze accents.
  - 4-5 Frostbound Sovereign: imperial gold/jade ice crown + dragon-mantle wings.
- Exactly one boss per active encounter. Aura and entrance embellishment must stay *body-bound*, not read as a dangerous AoE; only telegraph geometry indicates an actual damage area.
- Maintain hit/safe-zone code byte-identically when doing VFX-only changes. A bright effect outside hit geometry is a misleading warning. For Frostveil patterns, draw ornamental ticks *inside* the established danger lanes, rings or spokes.
- Prefer one body aura redraw at no more than ~12Hz; with Reduced Effects switch to ≤4Hz. Avoid particles that grow with wave/enemy count.
- Phase 2 signature must be visible deterministically instead of wholly relying on RNG. Preserve the existing 6-active-telegraph cap, durations, damage, pause and collision systems.

## What this package actually changes

1. Replaces **five** Chapter-IV boss atlas PNGs based on the already-generated Frostveil concept source art with new boss-only ceremonial details and lightweight action-frame variants. **This is not independently hand-keyframed animation.** Several base character figures come from the project's prior approved concept work; the boss composition and accessory silhouettes are a production step, not final bespoke figure painting.
2. Replaces `realm_boss.gd` (shared Realm IV/V adapter) with Chapter-IV-only draw/presentation logic; Chapter V remains on its existing scale and behavior. Phase II's first available ranged action uses the boss's own `boss_signature` once, then returns to the normal random pool.
3. Replaces `realm_boss_telegraph.gd` with low-cost overlays for Frostveil boss attack shapes only; no collision tests, range, damage, or stage-hazard visuals are changed.

## Testing gates — DO NOT claim LOCK prematurely

1. Run `PERIKSA_GAME.bat`; parser errors, bad resources, smoke regressions, warnings -> fix before visual signoff.
2. Spawn each of 4-1..4-5 in a playable debug build. Validate `boss_name`, correct unique art, facing L/R, melee/walk/ranged animation, footprint, death signal exactly once, reward exactly once.
3. On 4-2 and 4-5 watch first Phase II ranged cast: `mirror_cross` / `frost_crown` must appear after the invulnerability ward, with the correct safe gaps and no phantom damage.
4. On 4-3 and 4-4 verify lotus/bell body effects do not imply an additional damage zone. Verify the registered hit point within a telegraph is also inside the visible colored region.
5. Inspect 405×860 phone window at full wave density. If boss detail dissolves, raise *subject contrast* or repaint source silhouettes, not add more glow. Check low-FX preference, FPS, boss movement across camera edges.
6. Screenshot `4-1` and `4-5` during Phase I and Phase II, plus one close-up of 4-2/3/4. Do not call the source art final until runtime screenshot shows it matches Chapters 2/3; hand-keyframed true melee/cast/phase pose animation remains a separate quality gate.

## Reusable lessons for Realm V and beyond

- Begin at previously approved combat screen scale, **not** concept art at 1024px. In the first attempt, the subject art was accidentally thumbnail-downscaled twice: the sprites looked small despite elaborate outlines. Always validate the crop/alpha bounds and visual occupancy in a 128px frame and then at the 405×860 viewport scale.
- Attractive ring ornaments cannot compensate for a tiny figure. Art's hierarchy should be: readable character shape, strong costume/weapon, phase silhouette, finally small particle/rune detail.
- Each encounter needs a distinct signature shape tied to real hit geometry. Trigger it predictably once in Phase II; avoid adding undefined skills or multiplying projectile damage just for spectacle.
- Only reuse mechanics and technical atlas contracts across realms. Realm themes and visual characters must have distinct art identity. Reusing approved concept figures is a temporary production foundation, and should not be misrepresented as fresh, independently drawn boss designs.
- Save work with separate PASS gates: source/static -> Godot/`PERIKSA_GAME` -> runtime combat -> mobile readability/performance -> release quality LOCK.
