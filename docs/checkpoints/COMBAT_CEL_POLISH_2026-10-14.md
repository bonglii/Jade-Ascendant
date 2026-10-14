# Combat cel polish — 2026-10-14

Scope: regular enemy attack presentation, Sword Rain, Yin-Yang Blades, and
confirmed weapon hits. Production checkpoint preimages match remote
`43c779a3012ea19dd294fe4cd76bab62797f34f1` (Legendary set VFX).

## Attack audit and resulting behavior

- Basic melee and runner enemies already use chase/contact and weave/frenzy
  roles with no hexagonal attack marker. Preserve those roles and movement.
- Ranged cultivator keeps single/spread-three/predictive-pair counts. A real
  0.18-second release wind-up now precedes shots; aim/prediction snapshots at
  charge, pause freezes it, death cancels it, cooldown remains unchanged.
  Hand seal follows the cast instead of instantaneous projectile release.
- Qi Caster explosion and Storm Cultivator lightning replace flat inner
  ornaments/impact primitives with carved talisman seal, branching storm cel
  and qi-shard wave. Their existing circular outer warning stays the exact
  danger radius; impact timer/damage are unchanged. Realms IV/V use the same
  bounded renderer instead of stacking old spell stamps. Shared boss ornament
  also uses the new cel renderer; boss mechanics/patterns remain unchanged.
- Assassin keeps real direction lock, dash speed/range, single-hit gate and
  recovery; a directional wind-up cue and painted sweep follow those states.
- Guardian keeps support protection and close-range pulse. The warning now
  shows full real radius throughout wind-up; ornate pulse replaces flat rings.
- Hostile projectile keeps speed/damage/lifetime/collider. A carved talisman
  comet replaces the tiny legacy image when ornament budget is available;
  realm IV/V themes now resolve from their own projectile frames.

## Player skills and hit semantics

- Yin-Yang orbit: 80 → 116 world pixels. Milestones Lv.1/3/5/7: 2/3/4/6
  blades; Lv.7 is 3 Yin + 3 Yang. Reversal: 139.2px orbit, existing 1.5× speed,
  1.25× damage and four-second duration unchanged. Blade collider radius stays
  the actual inherited 10px. Individual per-hit damage stays 8+3×(level−1).
  Shared per-target hit interval remains 0.5 seconds, not one interval per
  blade. Upgrade rebuild preserves orbital phase and initializes new blades
  on the real orbit before their first paint. Old octagonal AuraRing hidden.
- Pending attachment race fixed: rebuilding before the deferred queue flush
  now attaches only the current collection. Stale blade references are never
  handed to native add_child; old physics stops and exit releases blades.
- Sword Rain: new downward carved jian, controlled descent and sapphire
  ground-puncture/shards. Strike count, spread, radius, cooldown and per-hit
  damage unchanged. Full true-radius boundary from first paint. Damage window
  still 0.12s; visual tail lasts 0.26s, with monitoring off after active window.
- RunCombatLedger returns accepted HP loss. Rejected Sword Rain hits no longer
  report successful impact/trigger Tribulation. Final killing blow stays
  counted. Spirit Sword/Fire Orb impact ornaments also require actual HP loss.
- Spirit Sword gets carved jade slash (armament/critical palette retained);
  Fire Orb gets fire-petal bloom. Other sources get distinct slash, fire,
  thunder, twin Yin/Yang, sword puncture, Bagua blossom, binding-knot or pierce
  hit motifs via one fixed 32-entry renderer (12 in Reduced Effects), no
  per-hit particle/timer/node allocation. Set DoT does not retrigger these.
  New hit pool freezes on pause and clears on scene transition.

## Balance evidence

Role: wider orbit controls an outer ring; close enemies require repositioning
or another weapon. The wider artwork does not create invisible full-disc damage.
Costs, acquisition, permanent progression, equipment bonuses and IAP unchanged.

Production-physics fixture, 2s exposure, real ordinary enemy/boss colliders,
no crit/set/progression bonuses; fixture targets stationary or moving slowly.
Not full-run DPS or a phone FPS/thermal measurement:

| Configuration | Six enemies on 116px ring: HP loss / aggregate DPS | Six moving enemies | Six enemies 55px from centre |
| --- | --- | --- | --- |
| Legacy control: Lv.7, manually 5 blades/80px | 0 / 0 | 0 / 0 | 572 / 286 |
| New Lv.1, 2 blades/116px | 112 / 56 | 96 / 48 | 0 / 0 |
| New Lv.7, 6 blades/116px | 624 / 312 | 624 / 312 | 0 / 0 |

Production Boss 1 on outer ring: 104 applied HP loss / 2s = 52 DPS. Existing
shared gate bounds Lv.7 to 26/0.5 = 52 per target per second, before modifiers.
This is a coverage change with a close-range tradeoff, not six independent
damage streams. Attack Speed/permanent stats retain their previous behavior.

## Validation and asset provenance

619 targeted checks passed: 83 alpha/hash/packing, 88 production mechanics,
12 coverage/boss checks, 175 existing damage/report/checkpoint checks, 261
existing skill/attack regression checks. Godot 4.7.2 native compatibility
renderer captured 32 controlled demonstration frames, with no script/shader
errors. Actual Android cost/feel and Windows launcher execution remain device
checks. Only affected checks repeated when failures or fixes required it.

Built-in imagegen: three premium hand-painted component kits, 16 components.
Technical extraction/downsampling/padding only; art remains authored by
imagegen. Sources/prompts retained under assets/effects/combat_cels. Runtime
atlases use 256px frames, exact 16px transparent gutters, clipped filtering.
Cached palettes sample texture/alpha once with vertex tint, preserving gold.
Runtime assets total about 1.2MB compressed PNG; sources excluded from import.

No backend deployment. Patch excludes shared LESSONS.md to avoid recurring
note conflicts. Publisher stages only package paths, verifies checkpoint
ancestry and refuses unrelated staged/outgoing changes; never force pushes.
GitHub write access previously returned 403; no new publication is claimed.

Lessons:
- Read inherited native shape values: the actual default blade circle was
  10px, not an assumed 20px. Tests compare actual production geometry.
- Assert seed phase before awaiting running physics; elapsed physics is not
  a phase-reset defect. Test startup scripts load autoload-dependent classes
  after initialization instead of premature global class resolution.
- Attach current collections rather than deferred stale Node arguments when
  rapid refinement/Continue can rebuild before attachment finishes.
- Shader fragment COLOR already includes the texture; preserve vertex tint
  separately and sample each texture/alpha once to avoid dark doubled alpha.
- Untyped validity checks are required when iterating freed render references;
  inspect error logs even if a render fixture printed PASS/returned zero.
