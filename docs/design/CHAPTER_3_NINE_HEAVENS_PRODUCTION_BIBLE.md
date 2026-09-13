# Chapter 3 — Nine Heavens Star Palace — Production Bible

Status: GATE C / BOSS PRODUCTION INTEGRATED / ENGINE-SMOKE PENDING

Chapter 3 is the v1.0 content climax after Verdant Qi Valley and Crimson Moon Sect.
It must not be exposed through JourneyManager until dedicated enemy and boss art is integrated and smoke validated.

## Realm identity

Foundation: wuxia discipline elevated into xianxia celestial authority.
Primary materials: dark indigo lacquer, cloud-white stone, restrained star-gold trim, pale ivory silk.
Atmosphere: cloud sea, floating terraces, astronomical arrays, celestial gates, distant palace silhouettes.
Enemy supernatural attack language: amethyst / violet-magenta / pale gold. Do not use player Thunder Talisman cyan/jade.
Environment can use cool blue/periwinkle, but immediate hostile telegraphs must remain unmistakable.

## Five-stage progression

3-1 Cloudsea Star Gate
- First arrival above the mortal cloud layer.
- Broken cloudstone causeways, outer celestial gate, sparse star lanterns.
- Encounter emphasis: disciplined melee + ranged pressure.
- Boss: Cloudsea Gate Warden.

3-2 Astral Mirror Causeway
- Reflective sky bridges and suspended astral mirrors.
- Encounter emphasis: mobile enemies + Starfall Seal hazard.
- Boss: Astral Mirror Daoist.

3-3 Constellation Sword Court
- Celestial sword court built around active constellation arrays.
- Encounter emphasis: formation casters + Heavenly Rift hazard.
- Boss: Constellation Sword Saint.

3-4 Ninefold Heaven Terrace
- High-altitude terraces approaching the inner palace.
- Encounter emphasis: elite pressure + accelerated Starfall Seals.
- Boss: Ninefold Heaven Arbiter.

3-5 Celestial Star Palace
- Inner palace and ascension throne beneath the nine-star canopy.
- Encounter emphasis: full roster, rapid Heavenly Rifts, finale pressure.
- Boss: Star Palace Celestial Sovereign.

## Enemy production roster

The proven enemy_1..enemy_6 and elite_1..elite_2 behavior archetypes may be reused.
Their Chapter 3 presentation must be dedicated; Chapter 1/2 SpriteFrames are not acceptable shipping art.

1. Cloudsea Sword Disciple — disciplined melee jian user.
2. Astral Talisman Seer — ranged star-talisman caster.
3. Skybound Pursuer — fast cloudstep attacker.
4. Constellation Array Adept — formation/area-pressure caster.
5. Voidstar Blade Dancer — mobile assassin silhouette.
6. Heavenly Ward Sentinel — defensive celestial guardian.
Elite 1. Starforged Iron Guardian — heavy armored enforcer.
Elite 2. Ninefold Thunder Oracle — celestial thunder caster; hostile lightning must be violet-gold, never cyan.

## Boss hierarchy

Visual authority:
Cloudsea Gate Warden < Astral Mirror Daoist < Constellation Sword Saint < Ninefold Heaven Arbiter < Star Palace Celestial Sovereign.

Bosses must use adult wuxia/xianxia proportions, strong head/shoulder/weapon silhouette, and restrained celestial ornament.
Do not make them chibi, toy-like, Western angelic fantasy, or simple blue/gold recolors of Chapter 1/2 bosses.
Phase manifestations may add stars, celestial seals, mirror shards, or heaven rings, but aura never owns the collider.

## Hazards

Hazard 5 — Starfall Seal
- readable circular telegraph with star geometry;
- violet-magenta warning line with pale-gold star core;
- one bounded impact event;
- no cyan/jade hostile language.

Hazard 6 — Heavenly Rift
- tighter, faster celestial fracture telegraph;
- amethyst fracture lines with warm gold impact;
- one bounded impact event.

Both preserve TELEGRAPH -> ACTIVE IMPACT -> RECOVERY and remain paused with the scene tree.

## Initial balance anchors — not playtest claims

Chapter 3 assumes Chapter 1/2 progression and equipment, but difficulty should not erase gear value by mirroring gear multipliers one-for-one.
Pressure comes from composition, elite cadence, hazard placement and boss behavior as well as durability.

Boss HP anchors:
- 3-1: 10,500
- 3-2: 12,500
- 3-3: 14,800
- 3-4: 17,400
- 3-5: 20,500

Stage-clear Spirit Stone anchors (first / repeat):
- 3-1: 900 / 400
- 3-2: 1,050 / 450
- 3-3: 1,200 / 500
- 3-4: 1,400 / 600
- 3-5: 1,800 / 750

Stage clear remains economy-only. No direct equipment reward.

## Release gates

Gate A — PASS: production bible + hidden catalog/scenes/environment/hazard scaffold.
Gate B — PASS: dedicated Chapter 3 normal/elite enemy production art and presentation mapping.
Gate C — CANDIDATE: five dedicated boss identities, SpriteFrames, presentation mapping, and Nine Heavens hostile boss VFX theme; awaiting PERIKSA_GAME.
Gate D — register Chapter 3 in JourneyManager + RewardManager; unlock only after Chapter 2-5 clear.
Gate E — one batch PERIKSA_GAME, then targeted runtime visual/combat QA.

Until Gate D, JourneyManager must not register Chapter 3. This prevents incomplete Chapter 3 content from appearing in the shipping flow.
