# Chapter 5 — Solar Nirvana Boss Visual Production Pass

## Source authority and limits

This is an incremental patch based on the approved Chapter 4 boss script, and the Gate B Realm 5 atlas contracts, **not** a replacement for any of the user’s unpushed manager, UI or save work. Only five existing PNG atlases and `scripts/enemy/realm_boss.gd` are replaced. Existing `SpriteFrames.tres` are untouched: each sheet is 512×512 (four by four 128px cells) and preserves thirty animation names, all 16 atlas regions, and the same boss scenes.

## Five visual identities

- 5-1 Ember Stair Sentinel: first-sun ceremonial guard, gate pennants, sunblade.
- 5-2 Crucible Forge King: heavy smelting armor, forge hammer, bronze crucible shoulder silhouette.
- 5-3 Ashwing Matriarch: organic feathered phoenix wings and luminous crown.
- 5-4 Eclipse Ritual Hierophant: black sun/eclipse disc and ritual staff.
- 5-5 Primordial Sun Sovereign: imperial sun canopy, gilded phoenix mantle and nine solar spokes.

Figures use transformed/repainted previously generated project character silhouettes, with new theme-specific ornamentation. **Not** independently hand-painted keyframes. Sprite motion is limited to the inherited 16 cells and should be reviewed on device. Do not mark animation quality LOCK from static art alone.

## Runtime behavioral scope

`realm_boss.gd` adds Realm 5-only art scale and body-bound, non-damaging solar aura (reduced-effects aware). Phase II signature attack is selected as the first available ranged special once, honoring the global limit of six active Realm boss hazards. No HP, actual hitboxes, damage, warning radius, rewards, save schema, death signals, route unlock or Stage Select APIs are changed. Chapter 4 keeps its approved art source and body aura; its existing combat functions remain unchanged.

## Known polish debt — explicitly NOT covered

1. **Chapter IV/V enemy attack effects are still visually flat.** Audit actual spawned VFX and improve depth/readability in the next pass, matching collision and hit timing.
2. **Lightning visuals in Chapters IV/V still feel like prototype effects.** Distinguish stage hazard, boss signature, and the normal enemy lightning while preserving exact impact geometry, anticipation and accessibility.
3. Chapter 5 boss per-frame movement and hit-feedback may need later animation quality work if device QA reports stiffness.
4. Balance (HP, DPS, hit frequency) must be measured through real fights; static QA is insufficient.

## QA flow

1. Run `PERIKSA_GAME.bat` after extracting changed/new files into `D:\Godot\project\jade-ascendant`.
2. Test 5-1 and 5-5 before testing the middle bosses. Capture boss entrance/Phase I/Phase II, including the first signature attack.
3. Verify HP, rewards, checkpoint Continue, boss death and unlock behave identically.
4. Verify enemy/attacks remain readable on 405×860 debug and Android phone. Do not mistake purely ornamental body auras for hit radius indicators.
5. Only after user PASS, prioritize the above FX backlog. Preserve all approved Chapter 4 and Realm 5 art during that pass.

**Status**: Static QA only. Runtime Godot smoke and visual approval still pending.
