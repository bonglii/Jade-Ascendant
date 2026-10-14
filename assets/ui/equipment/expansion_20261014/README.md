# Ascendant Arsenal artwork — 2026-10-14

Original art generated specifically for this content batch with the imagegen skill. Sources are retained in `sources/` with `.gdignore`; they are not runtime/export assets. Each image is transparent, hand-painted 2D wuxia/xianxia inventory art with gold engraving and readable silhouettes. No text, logos, item-card UI or backdrop is baked into icons.

- Frost Lotus: icy turquoise/pale gold lotus robe, matching bracers, boots and pendant.
- Vermilion Verdict: cinnabar/gold phoenix-shaped robe, bracers, boots and pendant.
- Celestial Aegis: indigo/champagne gold, pearl-jade hexagonal ward robe, bracers, boots and pendant.
- Phoenix War Fan: open cinnabar phoenix fan with gold ribs, jade core and tassel.
- Void Piercer Spear: silver/violet spear, indigo shaft, gold collar and purple ribbon; both tips visible.
- Astral Resonance Bell: bronze ritual bell with constellations, jade core, short suspension knot and visible clapper.

The set source atlases have four isolated objects. Actual object bounds, including ribbons beyond quadrant boundaries, were inspected before technical atlas extraction. `packing.json` records source regions. Exported items have 16-pixel minimum icon padding (256px armor icons; 512px weapons with24px padding). Packing/resampling preserves the painted object; it does not recolor or redesign it. No adjacent armor piece is left in another icon. See the actual-icon gallery and Godot presentation evidence.

Combat geometry/aura/status badges use bounded Godot drawing and retain Reduced Effects support. These are runtime VFX, not replacement item artwork. Three original DSP sound cues are in `assets/audio/arsenal_20261014/`, routed through the existing SFX mixer.
