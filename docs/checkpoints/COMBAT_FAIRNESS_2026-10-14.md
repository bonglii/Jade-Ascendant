# Combat fairness and starter scaling — 2026-10-14

Base: published checkpoint 83d87360a584778237bc7d2ababf26caff61c335. This follows the accepted Boss 2D Cels package; boss art and the earlier menu work remain complete.

## Result

- Player HP damage or a real Qi Shield block starts 0.30s shared protection. Repeated contact/projectile/hazard calls within the window do not cause additional HP events or consume more shield charges. Guard is reserved before callbacks, uses the pause-aware physics clock, is not serialized, and resets on rewarded revive. Existing revive protection remains authoritative. The player's existing hurt tint lasts through the guard; no new VFX nodes/assets.
- Chain/Glaive retain actual minimum cooldowns 1.25s/1.75s. Extra tempo that cannot shorten those casts instead multiplies snapshotted attack potency by actual/requested cooldown, with a defensive 5x ceiling. Requested cooldown includes Attack Speed and existing equipment cooldown reductions. At ordinary tempo their damage remains unchanged. Power/crit/permanent weapon-level modifiers continue through the original paths; timers and checkpoint weapon identities remain stable.
- Glaive endpoint now overshoots the aimed position by16px, within the24px sweep/spin radius. Removed the120px minimum flight distance which previously caused close targets to miss spin. Maximum flight range remains bounded. Stationary targets at40/80/180/230px receive outbound, spin and return; moving out of the snapshotted path can dodge later phases.
- Bleed/poison/burn can adopt a stronger direct hit's tick damage while active. Weaker hits cannot downgrade it. Remaining tick count, age, clock, non-stacking policy,64-status cap, half damage against bosses and DOT recursion guard remain. No extra status instances or duration extension.
- Skill Book, refinement cards and equipment/set descriptions disclose tempo potency, shield grace and stronger-hit DOT behavior.
- The user-approved new-equipment balance gate is included in AGENTS.md. The prior read-only exporter correction for inherited scene boss properties is included; it changes audit reliability, not gameplay stats.

## Evidence

Godot4.7.2 Linux, isolated QA profiles; fixed60FPS simulation without real-time sync. Targeted regression:1216 checks, zero assertion failures or SCRIPT ERROR lines. Existing ObjectDB/resource cleanup warnings remain at shutdown.

| Suite | Checks |
|---|---:|
| combat_fairness_smoke |84|
| combat_skill_polish_smoke |261|
| returning_glaive_smoke |66|
| jade_binding_chain_smoke |59|
| hero_equipment_progression_smoke |125|
| cultivation_mastery_smoke |65|
| returning_glaive_restart_smoke |5|
| jade_binding_restart_smoke |5|
| crowd_performance_smoke |278|
| skill_refinement_level_up_smoke |268|

The new suite exercises simultaneous damage/shields, expiry, pause, death/revive, real contact and real boss windup/dodge, actual tempo-snapshotted casts, target movement and stronger/weaker/recursive DOT across all3 offensive sets on normal/boss targets. Existing tests for independent armor hits and four distinct trial hits advance protection time between hits; trial still fails on four accepted damage events. Glaive sweep/return fixtures follow the corrected endpoint instead of retaining old positions.

Selective before/after probe reused the completed audit and retested only the3 starter paths,6 solo casts,3 clusters,9 cooldown readings,4 contact patterns and1 DOT interaction. No repeated full42-item audit,1000-campaign gacha simulation or asset generation.

| Probe | Before | After |
|---|---:|---:|
| HP100, ten same-frame contact calls at10damage |0HP|90HP|
| GlaiveLv1, one cast at180px, no modifiers |18damage /2hits|21damage /3hits|
| GlaiveLv7, twins, one cast at180px, no modifiers |104damage /4hits|120damage /6hits|
| ChainLv7, ordinary tempo, one primary target |72damage|72damage|
| SwordLv7, ordinary tempo, one primary target |80damage|80damage|
| Boss bleed from first3damage then15damage |0.12/tick|0.60/tick|

At stat cooldown factor0.2 and no gear, Chain potency is3.472x at1.25s actual cooldown; Glaive4.167x at1.75s. The gain is in hit strength, not extra simultaneous casts. These are stationary-target fixture values, not measured full-run DPS, clear times or phone FPS.

## Scope and remaining work

No boss HP, item prices, acquisition rates/pity, weapon level costs, idle tiers, assets, paid wallet/IAP gates, Google login or backend deployment changed. Save schemas remain unchanged. Manual legacy Windows release gate and live Android playtest were not run in this executor; the listed targeted suites are the completed validation.

Next batch: weapon level cost/value, idle progression beyond16clears and acquisition cadence. Boss HP tuning follows representative run-duration measurements with the new combat behavior, not a blanket HP nerf.

## Lessons and prevention

- Deliberate cast floors must not erase promised Attack Speed growth. Keep bounded cast counts and account for lost tempo in potency; derive both from the same requested cooldown and snapshot at launch.
- Compare overshoot/minimum flight distance to the real hit radius at close, normal and maximum range. Effects alone are not proof that a phase damages its intended target.
- A stronger-hit DOT refresh changes potency only. Do not reset age/clock/ticks, recurse on DOT damage or create a second status.
- QA actor fixtures registered in the player group must satisfy observer contracts (level/experience/next-level fields). A PASS marker with SCRIPT ERROR lines is not a valid pass; fix the fixture and scan logs.
- Derive isolated profile prefixes from the test's own guard. Test separate damage events after grace expiry, while retaining dedicated assertions for simultaneous hits and pause.
- Resolve inherited scene properties by instantiating authored scenes off-tree. Flat SceneState traversal can omit inherited boss_scene and silently substitute zero fallback damage.
- Keep shared backlog/LESSONS out of transport patches to avoid known user-side conflicts; include dedicated checkpoint notes instead.

## Install / publish

Apply Jade-Ascendant-Combat-Fairness.patch after the accepted Boss2D Cels package, reopen Godot for script import, then re-export Android. No backend deployment is needed.

backend\player_identity\publish_combat_fairness.cmd uses native Windows PowerShell, ExecutionPolicy Bypass, explicit fetchspec, authorized branch/origin, scoped staging, ancestry/outbound checks, no force push and remote-SHA verification before printing the real GitHub commit URL.
