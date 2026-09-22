# Audio Identity V2.1 — QA Report

Source authority audited before this patch:

- Repository: `bonglii/Jade-Ascendant`
- Branch: `checkpoint/billing-runtime-pass-20260922`
- Base commit: `7d82cdb30f8c48d6f3dc96f065d7c3560c02b07b`
- Base commit message: `checkpoint: latest audio presentation v2 local pass`
- User-reported baseline: `PERIKSA_GAME.bat` PASS before V2.1.

## Scope

V2.1 is a deliberately narrow semantic-audio follow-up.

Changed runtime file:

- `scripts/managers/audio_manager.gd`

No gameplay, save, reward, checkpoint, Billing, AdMob, balance, stage, boss-stat, or monetization-provider file is modified by this replacement patch.

The pass:

- restores `ui_locked` to automatic UI routing;
- adds signal-driven rewarded-revive identity;
- adds boss-spawn and boss-phase semantic overlays;
- adds equipment equip/unequip/ascend feedback from existing manager signals;
- adds an achievement-unlock discovery layer;
- keeps all existing V2 audio files and legacy rollback audio untouched;
- reuses existing curated V2 streams as layered semantic combinations, so no new raw third-party audio enters the project.

## Dependency audit completed

Verified against base commit `7d82cdb...`:

- `ProgressionManager.cultivation_upgraded(upgrade_id, new_level)`
- `PavilionManager.purchase_delivery_finished(product_id, success, message)`
- `MonetizationManager.reward_delivery_finished(placement, success, amount, message)`
- `EquipmentManager.equipment_changed(slot_id, item_id)`
- `EquipmentManager.equipment_ascended(item_id, old_star, new_star)`
- `AchievementManager` runtime inherits `achievement_unlocked(achievement_id)`
- level scenes use an `EnemySpawner` exposing `boss_spawned_signal`
- bosses expose `phase_changed(current_phase)`

The established direct calls remain intact, including rewarded revive's existing `claim` transient and boss Phase 2's existing `level` transient. V2.1 adds complementary layers centrally rather than editing gameplay owners.

## Static checks completed in this environment

- replacement file delimiter balance: PASS
- duplicate function-name scan: PASS
- indentation consistency scan: PASS
- composite cue sources all reference cue IDs already present in the V2 `SFX` catalog
- no new preload path was introduced
- no new third-party audio file was introduced
- replacement ZIP contains changed/new files only under top-level `jade-ascendant`

This environment does not contain the user's Windows Godot 4.7.2 executable, so it cannot truthfully claim `PERIKSA_GAME.bat` or Windows/device runtime execution for V2.1.

## Required local verification

Run `PERIKSA_GAME.bat` again after replacing this patch. The previous PASS belongs to base commit `7d82cdb...`, not to V2.1.

Focused runtime sequence:

1. Browse normal buttons, tabs, back, and a clickable locked state.
2. Equip and unequip one item; confirm no duplicate generic tap dominates.
3. Ascend one equipment item; confirm material seat + progression lift.
4. Trigger one achievement unlock if practical.
5. Enter combat and reach Boss spawn; confirm the sting does not mask the boss-music crossfade.
6. Trigger Boss Phase 2; confirm it does not sound like an ordinary player level-up.
7. Die once, use rewarded revive, and confirm the old claim transient is now followed/layered by a spiritual restoration identity.
8. Confirm second death/final defeat, Continue cleanup, Victory, rewards, save, Billing and AdMob behavior remain unchanged.

## Still intentionally open

Chapter-specific final BGM is not locked by V2.1. Current WAFU music remains a transitional V2 mapping. Dedicated natural/jade Chapter 1 and celestial/astral Chapter 3 source material should be curated before changing music orchestration.
