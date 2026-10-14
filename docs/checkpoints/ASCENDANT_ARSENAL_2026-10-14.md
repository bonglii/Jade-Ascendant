# Ascendant Arsenal — 2026-10-14

User scope: three new four-piece sets, distinct equipped-player auras, bleed/poison head markers, and three armaments with different attacks, artwork, refinement UI and VFX. Existing items, accepted boss art, paid gates and Google login remain unchanged. Runtime/save formats are compatible; the original item IDs retain their values.

## New sets (weapon never completes a set)

| Set | Rarity | Four-piece passive | Appearance / tradeoff |
|---|---|---|---|
| Frost Lotus | Epic | Applied direct hits slow movement20% for0.60s; bosses6%. Strongest-only, independent expiry; no root/attack interruption. | Icy six-petal ground lotus. Control instead of damage-over-time. |
| Vermilion Verdict | Legendary | Direct hits deal12% extra if the target was already at/below35%HP; bosses6%. Never boosts set DoT. | Cinnabar/gold orbiting judgment blades. No benefit during the first65% of a fight. |
| Celestial Aegis | Legendary | After8s without accepted HP damage or a shield block, grants1QiShield charge only if empty. Does not heal/bank charges. | Pearl/gold hexagonal ward. Continue restarts the full wait; no free charge. |

Each set has robe, bracer, boots, pendant. Two/three-piece numerical bonuses remain conservative; the four-piece mechanic requires all four. Partial two/three-piece aura is dimmer; Reduced Effects retains a static identity. Normal/boss slow strengths, refresh overlap, threshold, shield/pause/death/restart rules are intentional.

## Armaments

| Weapon | Rarity | Mechanic / milestones | Cooldown / minimum |
|---|---|---|---|
| Phoenix War Fan | Epic | Separate swept feather lanes. Lv1/3/5/7:3/4/5/7 feathers; Lv5 pierces2targets per feather. Central lane always follows aim. Max2feather hits/enemy/cast. |1.90s /0.90s|
| Void Piercer Spear | Legendary | Snapshot aim line,0.30s visible charge, thrust through8nearest enemies. Lv3/7 widens line; Lv5 adds30%aftershock at0.48s. Moving out dodges both. |2.20s /1.35s|
| Astral Resonance Bell | Legendary | Zone stays at the original cast position. Lv1/3/5/7:2/3/3/4full-disc pulses,75/95/115/135px radius. Max12targets/pulse. Slow15%/0.40s, bosses5%. Outgoing ring is aftermath, not a second collision. |3.00s /2.40s|

Extra tempo below each cooldown floor converts to snapshotted potency, capped5x, using the existing reviewed Chain/Glaive policy. Power, critical hits, permanent weapon levels and four-piece passives follow production damage paths. Resonance empowers at most one eligible critical hit40% per cast (central feather / main thrust / final bell pulse); no recursion.

Eight active new casts maximum, seven feathers/cast maximum,12hit flashes/cast maximum, one shared strongest-slow node/enemy; existing set DoT cap64. No unbounded particles. Aura, UI engraving and status marker drawing add no transient particle nodes. New authored weapon icons are used in combat; orange/ivory, violet/gold and bronze/cyan refinement cards use distinct emblems and descriptions. Bell is drawn near the cast point's feet, preserving face visibility. Head badges distinguish a red blood drop from a green poison vial even with Reduced Effects.

## Actual-hit balance evidence

The following is production **cast geometry** with deterministic10/20/30/40base-damage fixtures, stationary target, no gear/power/crit/resonance. These are per-cast applied HP loss, not measured full-run DPS/clear time or phone FPS.

| Weapon | Lv1 | Lv3 | Lv5 | Lv7 | Tradeoff |
|---|---:|---:|---:|---:|---|
| Fan at100px (one lane intersects) |9|18|27|36|At close range up to two lanes can hit: maximum18/36/54/72. Other lanes serve crowds; target count alone is not solo damage.|
| Spear |22|44|85.8|114.4|Stationary line damage;0.30s windup can be dodged. Lv7 crowd fixture:8targets,16hits including aftershock.|
| Bell within zone |16|48|72|128|Requires exposure for all pulses, stationary zone. Lv7 crowd fixture:12targets,48hits. Leaving the zone misses later damage.|

Reviewed unchanged baseline from Combat Fairness: GlaiveLv7 twins at180px applied120damage/6hits in a stationary fixture. Spear doesn't need a return catch; Bell covers a nearby disc; Fan covers separated lanes. None is intended to dominate every situation. Boss range remains230px; normal reach320px from cast origin. Bell radius is smaller and stays placed when the player moves.

Separate actual-arena integration ran the production PlayerStats, permanent weapon-level multiplier, equipment bonuses, critical rolls, real enemy scene, refinement UI, manager dispatch, cooldown floors/potency ceiling and report buckets. Those damage observations include critical RNG and modifiers; do not compare them as normalized deterministic DPS. No existing item was buffed or nerfed to force these roles.

## Acquisition and server compatibility

- Expanded inventory57items (previous42). All15new entries enter their rarity pools after clear1-5. Four-piece sets and independent weapons persist via existing save/loadout IDs.
- First-copy forge:90shards/Epic armor (360full set),180/Legendary armor (720full set),90Fan,220Spear/Bell. New entries use1-5 forge/shop metadata. Owned-item forge prohibition is unchanged: stars require identical duplicates, not generic shards. Weapon level caps10/20/30/40/50 at1–5stars; run refinement still1–7.
- Rates/costs/pity unchanged: default60%Common,29%Rare,9%Epic,2%Legendary. Epic Fan/Frost use normal Epic pool; Legendary Spear/Bell and armor can be selected in existing Wish/dashboard Legendary rate-up controls. More items dilute untargeted rarity pools; no promise of an Epic fixed-target guarantee.
- Production default offline sampler, seed14102026,1000campaigns for each fixed Legendary target, fresh pity, all57items. Spear mean first42.069pulls, five209.135, median211,p95=280; Bell first43.281,five210.757,median208,p95=286. Both hard upper bound495for five copies. See JSON for complete scope. No live rates/ad availability or guaranteed calendar-day claim.
- Dashboard mail catalog/icons include all15. New clients send `X-Jade-Ascendant-Arsenal: v1`. Older clients hide incompatible mail before reservation; direct claim returns409 without creating a receipt. New Legendary banner targets are withheld from unsupported clients; mixed banners retain compatible entries. No player/mail schema migration, admin reset, database replacement or credential rotation.
- `deploy_ascendant_arsenal.cmd`: validates current backend tests/config, builds icons, deploys Worker+assets only using the existing local config. It does not execute D1SQL.

## Validation

Godot4.7.2 Linux, isolated profiles. Fixed60fps simulation is not a phone frame-time measurement. Native OpenGL renderer inspected actual imported artwork and HERO popups at320×568,390×844,648×1152,896×504; all15new item details remain bounded/scrollable. Preview gameplay is a stopped arena fixture with real sprites/cast/aura drawing; bleed/poison states are positioned deliberately to inspect badges.

3379 completed checks/cases: new mechanics66; actual integration60; native presentation142; acquisition2041(includes2000seeded campaigns); three separate-process checkpoint write/resume pairs33; existing HERO progression143, skills261, Pavilion picker127, Chain59, Glaive66, combat fairness84, run report175+restart4; backend63; shipped PNG/audio audit55. No assertion failures or SCRIPT ERROR lines in final evidence. Existing shutdown ObjectDB/resource cleanup diagnostics remain. Device playtesting of this new content batch and authenticated remote deployment were not performed here; no claim of publication, phone FPS or release readiness.

## Preventive notes

- Feather counts alone hid a Lv3-to-Lv5 solo damage inversion. Measured each milestone, separated off-axis lanes and retained an intentional two-hit close-range cap.
- Source atlases are not guaranteed exact quadrant boundaries. Inspect real tassel bounds before extraction; retain source art, record regions, check padding and inspect final game icons.
- Expanded HERO had a hardcoded `/42` total. Collection counts now derive from catalog size, with a57item presentation assertion.
- Keep GDScript indentation consistent and replace dictionary fields instead of duplicating keys. A PASS marker with SCRIPT ERROR lines does not qualify as a pass. Isolated SceneTree fixtures load autoload-dependent scripts after initialization and satisfy player observer fields.
