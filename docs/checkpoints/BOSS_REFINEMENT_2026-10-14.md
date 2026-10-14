# Boss Realm I–V aggressive refinement

Base: local Balance Ads4378ea936f83c935736ace67b2708223aa3d1b5e on published Combat9bbc463. User accepted crowded Android combat performance as complete; no phone telemetry/FPS result is invented. Google and IAP remain parked.

## Asset inspection and implementation

Inspected all25 old boss atlases and authored SpriteFrames. Early bosses had tiny blurred bodies and inconsistent silhouette/readability; later boss frames were heavily detailed, while generic transform motion could not substitute for pose changes.

Five original ImageGen atlases replace25 identities across all26 encounters. Each boss has guarded ready, left/right stride and committed attack poses. Sovereign Ascended deliberately retains Sovereign identity and existing phase ward. Built-in imagegen used; a targeted Frostveil cleanup iteration reduced noisy exterior effects. Source prompts/source SHA256/runtime SHA256 are preserved in assets/enemy/refined/asset_sources.json. Technical packing separates alpha components, shares scale across each row and aligns feet at248px in256px cells; no figures redrawn by the packer. Final texture1024x1280 per realm, four columns/five rows, clipped AtlasTexture regions. Runtime PNG hashes validated.

New art is installed after original per-encounter footprint configuration. Idle/walk/action frame aliases preserve the existing boss animation contract; matching left/right facing mirrors the new sprites. Collider transforms/shapes remain independent of silhouettes, capes and weapons. Linear filtering preserves painted detail. Old Chapter1–3 art constants now hold lazy fallback paths rather than preloading16 obsolete atlases. IV/V fallback art is not loaded when refined art exists. Only the active realm atlas is needed in normal gameplay; the QA gallery intentionally loads all five.

## Gameplay problem and resulting behavior

Player boss-target radius is230px, while several boss ranged stop radii are240–300px or greater. Previously, these bosses could stand outside player attack range throughout ranged cooldowns; a stationary player then had no eligible target. Fix the boss pressure behavior, rather than expanding player range or firing into empty space.

All realms share reach-aware movement between casts. Guards and sovereigns close toward melee distance; duelists orbit strongly, ritual keepers use smaller circling movement, and heralds use a wider approach/orbit. Phase2 increases pressure within the existing speed cap. Jade Binding slow still applies. Blocked movement switches orbit side after0.6s; no teleport, disabled collision, new navigation meshes or per-frame group scan. Ranged cast, visual recovery and phase ward are explicit stationary states, so movement does not obscure casting.

Melee now winds up0.216s inside its existing0.45s visual action, then checks actual target/range/phase/liveness before dealing original damage. A real sidestep can dodge. Duplicate direct calls cannot schedule duplicate hits. Pause suspends windup; death/phase/target replacement cancels its impact. Original HP, damage amounts, cooldowns, projectile counts, progression and rewards remain unchanged. Authored IV/V patterns and signature spell ownership remain; this is not a claim of26 wholly new attack kits.

Premium profile/arrival/cast/phase/defeat coverage extends from16 encounters to all26. Body-tight spear/cross/seal/bolt/crown crests identify roles without introducing fake danger rings. Real lightning impact gains a layered branching core and an impact ring inside its true radius; existing bounded hostile effects/reduced mode remain. RealmIV/V fallback projectiles use their correct frost/solar colors.

## Validation

-473 focused checks: all26encounters, both phases, real physics approach from265px into player230px range while cooldowns run, frontline melee pressure, original collider transforms, new frames/atlas bounds/facing, cast/phase/death stop, actual melee windup/pause/dodge/phase/death.
-10 stationary-player checks: production WeaponManager emits a real attack after boss movement closes the old gap in RealmI andV, without player motion; no invented attack while out of range.
-261 current combat/18skill checks, including pause and pending projectile cancellation, shifted volleys and bounded spell effects.
-702 expanded tutorial/premium-combat checks: use real RealmBoss subclass forIV/V, all26profiles/themes, original stats, HUD HP/death contracts, phase/collider stability and reduced effects.
-278 current crowded-query/statistics checks passed.
-Total1724checks, zero failed assertions in accepted final runs. Godot4.7.2 Linux. Existing shutdown ObjectDB/resource warnings remain; no warning-free Android claim.
-Native OpenGL Compatibility render inspected for all25identities across5realms. Four-second gallery video shows production SpriteFrames/presentation in a staged gallery; it is not normal combat footage, a map redesign or proof of HP GPU FPS. Windows launchers reviewed, not executed here.

## Install / publish

Apply Jade-Ascendant-Boss-Realms-Refinement.patch after Balance Ads. Reopen Godot and wait for texture import, then re-export Android. No backend deployment, economy migration, profile wipe or login change.

Publisher backend/player_identity/publish_boss_refinement.cmd scopes this package plus explicitly authorized Balance Ads prerequisites if still pending, protects checkpoint/origin, checks ancestry/unrelated staging/outbound changes, never force pushes, and verifies remote SHA before printing commit URL. Assistant GitHub credentials are unavailable; no remote publication claimed here.

Phone review: check visual size/stride in allrealms, stand still at the old ranged gap and confirm boss approach/autofire, dodge a visible melee swing, review ReducedEffects and phase transitions. Performance acceptance from the user remains recorded separately from this new visual/device review.
