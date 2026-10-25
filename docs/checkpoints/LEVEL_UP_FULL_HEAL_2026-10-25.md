# Universal combat level-up recovery — 25 October 2026

Base: `106448c4768ef79460de777c55f1b0c5e0c7b7ef`, the owner-published Home/dragon batch.

- Each earned combat level restores HP to the **current maximum** through the normal PlayerHealth.heal signal before level observers and the existing skill choice. No item, ad, Jade or option is required. The existing congratulations subtitle briefly explains recovery; no additional popup/SFX is added.
- Same-frame surplus EXP waits behind the existing skill-choice panel. Each pending level then consumes its own threshold and heals once after the previous choice. No choice is replaced or skipped.
- Below-threshold/zero EXP and ordinary skill upgrades do not trigger this recovery. Wounded checkpoint loads/Continue preserve saved HP; dead players cannot be revived by late EXP.
- Actual hit/lost-HP history remains intact for reports and no-hit achievements. Blood Qi and other recovery between levels retain their existing behavior. Max HP, enemy damage, prices, EXP thresholds, gear IDs/stars and save schemas are unchanged.
- The old small gear-specific level-up heal is superseded by the universal rule. Preserve legacy data keys for compatibility and all other equipment stats; correct the two item descriptions, historical set-tier copy and Profile row rather than inventing another shield/buff.

Validation:20 real-scene checks plus4 separate-process Continue/death checks pass; all358 production scripts compile under six strict warning categories with16 boundary checks. Existing failed Home caption regression now passes949 checks, and native recovery/first-swipes pass129 checks. These fixtures are not Android testing.

## Prior CI correction included

Exact106448c logs show three red workflows from two old expectations: `ui_reliability_followup_smoke.gd` expected the former long primary caption, and `release_ui_layout_smoke.gd` expected OPEN SETTINGS instead of the approved REVIEW SAVE display. Their semantic actions were unchanged. Update the literals while retaining fit, target, recovery, saved-stage and native-swipe assertions. This corrects a missed test update from the preceding delivery; no checks are disabled.

The prior launcher correctly stopped before Profile policy deployment because CI was red. A read-only check still found the old policy. This portable launcher checks exact public pages again **after new exact-SHA CI passes**: if already current, it skips deployment; only an actual content mismatch completes the existing Profile-only policy deploy. A transport failure stops for diagnosis instead of triggering an unnecessary deploy. No IAP Worker, schema, event activation, notification campaign or native rebuild is part of this addition.

Run `D:\Godot\tools\Jade-Level-Up-Full-Heal\apply_and_publish.cmd`. It publishes the real commit URL, preserves/syncs the game, waits CI and completes any pending policy stage. Then use the established production exporter for **one new client AAB** and briefly check an injured character crossing an EXP threshold before proceeding to Play Console. Owner install/push/CI/deploy/export/device status remain distinct receipts.
