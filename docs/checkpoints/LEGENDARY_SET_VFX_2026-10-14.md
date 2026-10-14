# Legendary four-piece VFX — 2026-10-14

Scope: client presentation for the four Legendary (5-star rarity) sets. Ascension
stars remain independent; this does not introduce a max-ascension requirement
for existing four-piece passives. Weapon remains independent of the set.

| Set | Actual passive | Visual response |
| --- | --- | --- |
| Nine Heavens | Jade Venom: accepted direct hit applies non-stacking poison | Emerald dragon-vine halo, jade leaves, poison crest; short flare on a confirmed status |
| Solar Meridian | Solar Scorch: accepted direct hit applies non-stacking burn | Amber sun seal, fire-petal orbit, imperial solar crest; short flare on a confirmed status |
| Vermilion Verdict | Already ≤35% HP before direct hit: +12%, boss +6% | Vermilion tribunal seal and converging blade plaques only on an eligible applied hit, including a killing hit |
| Celestial Aegis | After 8 quiet seconds, replenish 1 Qi Shield only if empty | Gold/sapphire cloud seal; six decorative guardians unfold on a real charge increase, compact while charged, fragment on an actual block |

No numerical bonus, status stacking/ticks, cooldown, save schema, acquisition,
inventory, shader on the character, weapon, IAP gate or server endpoint changed.
The six Aegis plaques represent one shield charge, never six charges.

Built-in imagegen authored four transparent component kits. Prompts and source
images are kept under `assets/effects/legendary_sets/`; sources have `.gdignore`.
Runtime uses four 512×512 atlases, sixteen 256px component frames with exact
16px transparent gutters and `AtlasTexture.filter_clip`. Technical packing
only downsamples/pads the complete source cells. No character is baked into VFX.

Animation uses continuous transform and opacity, not discrete pose swaps.
Smoothstep fades, 0.82s formation, 0.70s proc, 0.48s block. Proc refreshes are
rate limited to 0.32s. One VFX node and one foreground layer per player; fixed
guardian/filament/fragment budgets. Only the selected atlas is loaded and
cached. Reduced Effects provides static ornamentation without active bursts.
Pause freezes playback; defeat hides the aura, revive can resume it.

Validation: Godot 4.7.2 import/parser, 90 production scene VFX checks,
105 alpha/hash/packing checks, 40 existing production weapon/report regression
checks all passed. Native compatibility renderer captured 48 demonstration
frames and a Reduced Effects still using production VFX and Lin Yue sprites.
Gallery timing is compressed; it is a controlled render, not a phone playtest.
Android FPS/thermal cost and Windows launchers have not been measured here.

Three modified source blobs verified against remote checkpoint
`8fb3cd328008a9e7fba7f4a0401e407477dc4ba7`; identical to the local Library mirror.
Patch excludes shared LESSONS.md to avoid recurring checkpoint-note conflicts.
GitHub integration write returned 403; no publication is claimed. The package
publisher fetches an explicit tracking ref, checks ancestry and only stages
listed package paths, refuses unrelated staged/outgoing paths, never forces a
push, and verifies the resulting remote SHA before printing its commit URL.

Lessons retained with this feature:
- A generative source grid is not a production atlas. Add and audit exact
  alpha-zero gutters after resampling, and clip filtering per AtlasTexture.
- Derive procs from applied HP loss and pre-hit eligibility, not the HP after
  a hit crosses a threshold. DOT may not retrigger direct-hit ornamentation.
- Aegis set identity is not proof of a shield charge; a real health/block event
  controls shield guardians. No quiet-timer shortcut from cosmetic animation.
- Fetch commit metadata without printing its entire diff or binary content.
