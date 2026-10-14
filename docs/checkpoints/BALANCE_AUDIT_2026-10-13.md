# Balance audit checkpoint — 2026-10-13

Read-only runtime export of 25 stages, 42 equipment, 8 sets, 32 weapon milestone rows and 1000 default-rate fixed-target gacha campaigns passed. Owner progression/equipment/inventory/pavilion snapshots remain unchanged; RNG seed/state restored. Isolated QA profile required by tests/balance_audit_export.gd.

Historical correction (2026-10-14): actual level_1 player starts with HP100 through its scene override; HP10 was the script fallback. The earlier export missed Chapter 1 stage 6; the current export covers all 26 encounters.

Confirmed priorities: skill offer generator is uniform; full daily completion may require 3 runs; fragment no longer feeds stars and first-copy forge rejects owned items; DOT application shares a 64-instance gameplay cap and halves boss damage; Chain/Glaive enforce distinct cooldown floors.

Default-rate simulation (full pool; target Glaive; seed13102026): first target mean41.904 pulls; five copies mean208.539/median209/P95 282/max observed397. Legendary pity50 is not target guarantee50: off-target natural Legendary resets rarity pity and activates Wish Fate. With fixed valid target, one target worst99 and five copies worst495 from fresh pity. No live-banner probability claim.

No gameplay tuning, migrations, assets or monetization activation. Full player-facing audit and raw data are delivered separately. Proposed next batch: onboarding HP experiment, owned-skill bias, integrated level-up presentation, then EXP magnet/economy clarity. Google skipped; crowd phone profiling pending.
