# Jade Ascendant — Audio Presentation Bible V2

Base source authority: `checkpoint/billing-runtime-pass-20260922` @ `7f3199a0c7d3f86cb64cb17f425a78a8a28fa6f8`.

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
| Tactile | tap, tab, back | 40–170 ms, quiet, never dominates music |
| Combat frequent | hit, sword, pickup, chain | short variants + subtle pitch rotation |
| Progression | equip, level, claim, upgrade | physical transient + jade resonance |
| Prestige | victory, boss defeat, stage unlock, legendary summon | ritual cue + music ducking |
| Negative | locked, defeat | low / dissonant material, no cartoon error beep |

## Active cue mapping

Existing gameplay cue names remain API-compatible. `AudioManager.play_sfx()` call sites do not need migration.

- `ui` → soft tactile pair
- `ui_tab` → crisp navigation pair
- `ui_confirm` → confirm + jade accent
- `ui_back` → subdued release / return
- `ui_locked` → disabled cue + restrained metal stop
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

Additional semantic cues:

- `upgrade` → connected centrally to permanent Cultivation upgrades.
- `purchase_success` → connected centrally to successful Google Play reward delivery.
- `stage_unlock` → authored and routed, but intentionally reserved for the later stage-unlock ceremony so it does not double-stack with the current Victory cue.

## Music contexts

WAFU Vol.19 is intentionally mapped according to the roles documented by its author:

- Home / hub → `The Ruler I`
- Journey → `The River I`
- Boss → `Judgement I`
- Pavilion → `The Gate I`

All use the supplied seamless-loop versions. Runtime target is `-18.5 dB`, leaving headroom for combat and reward feedback.

## Runtime rules

1. Frequent cues rotate variants instead of replaying one file.
2. Frequent combat/tactile cues receive very small deterministic pitch variation (roughly ±1.4%).
3. Semantic actions suppress the generic deferred button click, preventing double audio.
4. Normal UI browsing is no longer silent; the default tap is deliberately very quiet and short.
5. Victory, defeat, boss defeat, stage unlock and purchase success automatically duck music.
6. No stock character grunts from the sword pack are used; Lin Yue voice direction remains a separate future decision.
7. Permanent Cultivation upgrades and successful purchase delivery receive dedicated semantic cues without screen-local audio duplication.
8. Old `assets/audio/*` files are retained for rollback until device QA passes. They are not referenced by AudioManager V2.

## QA focus

Device QA should specifically check:

- menus do not feel noisy after 2–3 minutes of browsing;
- rapid enemy hits do not become a wall of sound;
- Spirit Sword, Fire Orb and Thunder Talisman remain distinguishable in crowded waves;
- claim reward feels materially stronger than normal button presses;
- Victory / Boss defeat remain readable over music;
- Pavilion Legendary omen and reveal do not clip or stack into harshness;
- music/SFX balance is comfortable on phone speakers at 30%, 60% and 100% device volume.
