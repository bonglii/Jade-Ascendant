# Jade Ascendant — Audio Presentation Bible V2.1

Source authority audited before this patch:

- Repository: `bonglii/Jade-Ascendant`
- Branch: `checkpoint/billing-runtime-pass-20260922`
- Commit: `7d82cdb30f8c48d6f3dc96f065d7c3560c02b07b`
- Baseline status: user reported `PERIKSA_GAME.bat` PASS before this V2.1 semantic patch.

## Sonic identity

Jade Ascendant uses one shared language across UI, progression, combat, Pavilion and results:

- **Jade / spiritual:** clean crystal resonance, airy qi tail, restrained high-frequency shimmer.
- **Physical / grounded:** wood, bronze and metal transients so actions have material weight.
- **Cultivation / ritual:** temple-bell and East-Asian musical gestures for milestones rather than generic fantasy sparkles.
- **Combat:** short, readable attacks with variations. Frequent events stay dry and controlled; rare events receive longer ritual tails.

The target is **premium xianxia mobile**, not arcade, cartoon, retro, or generic western-fantasy UI.

## Dynamic hierarchy

| Tier | Events | Mix behavior |
|---|---|---|
| Tactile | tap, tab, back, locked | short, quiet, never dominates music |
| Combat frequent | hit, sword, pickup, chain | short variants + subtle pitch rotation |
| Progression | equip, ascend, level, claim, upgrade | physical transient + jade resonance |
| Prestige | victory, boss spawn/phase/defeat, stage unlock, legendary summon | ritual layer + selective music ducking |
| Negative | locked, defeat | low / dissonant material, no cartoon error beep |

## Active cue mapping

Existing direct gameplay cue names remain API-compatible. V2.1 adds semantic overlays centrally inside `AudioManager` so gameplay/save/Billing files do not need to be rewritten.

- `ui` → soft tactile pair
- `ui_tab` → crisp navigation pair
- `ui_confirm` → confirm + jade accent
- `ui_back` → subdued release / return
- `ui_locked` → disabled cue + restrained metal stop; V2.1 also restores it to the automatic UI cue allowlist
- `pickup` → three jade crystal variations
- `shield` → crystal barrier + metal resonance
- `claim` → success transient + jade resonance + spiritual tail
- `equip` → metal seating + progression tone + blade resonance
- `sword` → two air-cut variants with restrained spiritual ring
- `fire` → three compact Fire Orb cast variants
- `thunder` → three primary lightning variants
- `chain` → three lighter lightning-chain variants
- `hit` → three dry material hit variants
- `hurt` → two non-vocal player impact variants
- `death` → two short non-vocal collapse variants
- `level` → two breakthrough variants
- `victory` → two ceremonial victory variants
- `defeat` → two underworld defeat variants
- `boss_defeat` → two ritual boss-fall variants
- `summon_charge` → two omen-charge variants
- `summon_rare` → two rare reveal variants
- `summon_epic` → two epic reveal variants
- `summon_legendary_omen` → two major omen variants
- `summon_legendary_reveal` → two legendary reveal variants
- `summon_new` → two new-discovery variants
- `summon_duplicate` → two duplicate-transmutation variants
- `upgrade` → permanent Cultivation progression
- `purchase_success` → successful Google Play reward delivery
- `stage_unlock` → authored and routed, reserved for the later stage-unlock ceremony

### V2.1 semantic overlays

These cues layer existing curated V2 material; they do not add another raw third-party pack.

- `revive` → shield resonance + breakthrough rise on top of the established revive claim transient
- `boss_spawn` → ritual charge + low thunder impact
- `boss_phase` → restrained charge + darker thunder pressure on top of the established phase breakthrough transient
- `equipment_ascend` → progression layer paired with EquipmentManager's established material equip transient
- `unequip` → softened equipment release + return gesture
- `achievement_unlock` → short discovery accent paired with the existing toast confirmation

## Central signal ownership

`AudioManager` listens only to presentation-safe signals and does not mutate gameplay state:

- `ProgressionManager.cultivation_upgraded`
- `PavilionManager.purchase_delivery_finished`
- `MonetizationManager.reward_delivery_finished`
- `EquipmentManager.equipment_changed`
- `EquipmentManager.equipment_ascended`
- `AchievementManager.achievement_unlocked`
- runtime `EnemySpawner.boss_spawned_signal`
- runtime Boss `phase_changed`

This keeps reward/save/Billing/combat authority in their existing managers.

## Music contexts — current status

Current V2 runtime mapping remains:

- Home / hub → WAFU `The Ruler I`
- Journey → WAFU `The River I`
- Boss → WAFU `Judgement I`
- Pavilion → WAFU `The Gate I`

This mapping is **not the final chapter-music lock**. WAFU Vol.19 is underworld/dark material and must not become the sonic identity for every realm.

Final music direction remains:

- Chapter 1 — Verdant Qi Valley: natural / jade / spiritual
- Chapter 2 — Crimson Moon Sect: darker / cinnabar / sect tension
- Chapter 3 — Nine Heavens Star Palace: celestial / heavenly / astral

Dedicated Chapter 1 and Chapter 3 source material is still required before chapter-specific BGM orchestration should be implemented. Do not downgrade back to deterministic legacy music merely to create different filenames.

## Runtime rules

1. Frequent cues rotate variants instead of replaying one file.
2. Frequent combat/tactile cues receive very small deterministic pitch variation.
3. Semantic actions suppress the deferred generic button tap, preventing double UI feedback.
4. Normal UI browsing keeps a deliberately quiet tactile cue.
5. `ui_locked` is a first-class automatic cue again.
6. Victory, defeat, boss defeat, stage unlock, purchase success, revive and boss milestones may duck music.
7. Semantic overlays use existing V2 assets as layers instead of shipping duplicate/raw sound-library files.
8. No stock character grunt/voice asset is used; Lin Yue voice direction remains separate.
9. Old `assets/audio/*` files remain rollback assets until device QA and later cleanup pass.

## QA focus for V2.1

- locked interactions actually play `ui_locked` where a clickable locked control exposes that semantic
- rewarded revive reads as spiritual restoration, not a normal reward claim
- boss appearance is clearly announced without drowning the boss-music transition
- boss Phase 2 is audibly distinct from normal player level-up
- equipping and unequipping equipment both produce material feedback
- equipment ascension reads as progression, not just ordinary equip
- achievement unlock sits above a normal UI confirm without becoming a major fanfare
- menus do not become noisy after 2–3 minutes of browsing
- crowded combat remains readable on the Snapdragon 680 baseline
- no behavior, save, reward, Billing or AdMob regression occurs
