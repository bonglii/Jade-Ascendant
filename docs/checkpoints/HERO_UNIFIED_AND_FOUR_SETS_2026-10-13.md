# HERO unified page and equipment progression — 2026-10-13

Patch base tree: `ed747644d68af7eecf3592c9c6895951d4b3fa8d` (after the 40-equipment art refresh).

## HERO

One actual native Godot page: generated scenic banner with existing Lin Yue, five equipped slots, compact 4-piece resonance summary, shared device-safe wallet and five-tab navigation, five-column mixed equipment/material backpack. Slot/type filter, rarity/name/star sort and search remain available. Short taps open a scrollable contextual item sheet; swipes browse. Item details show core stat additions, rarity, stars, signature, set requirements, duplicate count and weapon level. Two existing special-weapon demo previews remain available. Stats and item sheets stay above navigation; Android Back dismisses a sheet before leaving HERO. Native review covers 320×568, 390×844, 648×1152 and landscape.

Banner original PNG, prompt and SHA provenance: assets/ui/hero/imperial_v4. Import bounded to 1024 px with mipmaps. Existing generated equipment art and image-backed rarity/primary button skins are reused. No visual mockup image is used as the functional interface.

## Four-piece sets

Only robe, bracer, pendant and boots are counted. All 10 armaments are standalone, including the two new weapons. Every family completes at 4/4 regardless of selected weapon.

Set classification is explicit: Verdant Common; Mistbound, Moon-Seal and Jade Bastion Rare; Crimson and Stillwater Epic; Nine Heavens and Solar Legendary. Common/Rare set effects only grant Max HP (Common 2 HP per equipped piece from two pieces; Rare 3 HP per piece from two). Individual item stats and signatures remain defined by their existing catalog.

Epic/Legendary retain their existing 2/3/4 tier stats and receive an additional four-piece passive:

- Crimson: Bleeding, 3 one-second ticks, 8% of applied hit damage each.
- Nine Heavens: Jade Venom poison, 4 one-second ticks, 6% each.
- Stillwater: Armor, 8% incoming damage reduction after Iron Body.
- Solar: Burn, 3 one-second ticks, 9% each.

DOT never stacks or refreshes while active, cannot recursively trigger DOT or critical/resonance procs, respects pause/death, has half damage against bosses, uses real enemy damage authority and caps at 64 active statuses. Reduced Effects hides decorations without suppressing damage. Existing five-piece effects no longer apply. These are starting values for the later balance audit, not a claim that all weapons/economy have been rebalanced.

## Duplicates and permanent weapon levels

Every identical duplicate stays in the inventory count from summons, mail and other grants. One extra identical copy raises its own item by one star, preserving the owned/equipped original. Max is 5 stars. Other IDs/rarities and generic fragments cannot pay this cost. Existing stars, shards and claims remain intact; historical converted duplicates cannot be reconstructed from a shared shard balance.

Weapon permanent level is independent of run refinement Lv.1–7. Star 1/2/3/4/5 caps permanent level at 10/20/30/40/50. Starts at Lv.1. +1% weapon attack damage per additional level, applied to actual old armament, chain and glaive attack paths, not unrelated run arts. Upgrade to next level costs 20 × next-level Spirit Stones. Rarity never changes through leveling/stars. Equipment and currency changes commit atomically through existing save journal with reentrant/read-only guards.

Additive weapon_levels inside equipment.save v1 and frozen active-run loadout. Legacy saves/snapshots default to Lv.1. Checkpoint keeps old equipped IDs/stars/weapon levels; hub modifications affect next run. No backend schema, auth, mail receipts, summon rates/pity/Fate, production/IAP enablement or advertising changes.

## Verification

1,318 passing assertions/tests: 125 HERO/progression/status/UI checks; 6 checks after real separate-process restart and actual Continue; 59 chain; 66 glaive; 67 banner; 62 mail; 180 equipment-art; 701 actual gacha reveal checks across EN/ID and five viewports; 52 Node server tests. Includes real ten-pull duplicate grant, replay prevention, actual armor damage with Iron Body, actual level-scaled sword projectile, pause-aware statuses and real checkpoint restoration.

Native screenshots reviewed for overview, weapon detail, set detail and small viewport, plus actual poison effect in the level. Existing shutdown ObjectDB/resource warnings persist in QA; no whole-engine warning-free claim. Physical Android touch/GPU/device review still occurs after export on the developer laptop.

Binary patch whitespace/apply checked against base and diverged shared lessons/publishers. Old publishers/shared lessons/unrelated mirror-edge PNG changes excluded. Dedicated publish_hero_rework.cmd uses absolute System32 PowerShell, Node preflight and normal checkpoint push with verified GitHub SHA URL. GitHub writes unavailable here; no remote commit claimed.

## Windows

Apply after Equipment-Art-Refresh patch; open Godot to import, then export/install Android. Client-side update: no Worker deployment or database migration needed. Publish using backend\player_identity\publish_hero_rework.cmd.
