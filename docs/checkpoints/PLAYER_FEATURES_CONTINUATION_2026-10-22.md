# Jade Ascendant — Feature Batch Continuation (2026-10-22)

Base: `ece467fb141ba1c6175cfbb136a8ce4dce9765bf` on `checkpoint/iap-fasttrack-20261010`.
Source: durable Work checkpoint `Jade-Player-Features-Checkpoint.zip` (24 files).
This is source-only and is **not** a production deployment, installed build, GitHub commit or device test.

## Work preserved
All nine previously approved feature integrations from the recovered Work archive are preserved: gear comparison, summon history, three presets, collection target, boss codex, recent run reports, published agenda, training ground and opt-in aggregate dashboard.

## Current-turn changes
1. Subscribe `PlayerCompanion` to `JourneyManager.stage_completed` for successful stage-clear display records. Avoid creating a victory merely when a boss's death signal occurs. Death/revive report logic remains independently journalled and does not grant currency.
2. Add three portable Node.js server contract tests (`companion.test.mjs`).
3. Add isolated Node 22 SQLite/handler QA and static asset/source checks to the continuation package; they are not shipped with the game.
4. Correct the durable CURRENT_WORK pointer so the next step is validation, not a repeat implementation.

## Confirmed local evidence
- Node 22 isolated SQLite and HTTP contract checks: 6/6 PASS (local adapter, not Cloudflare D1).
- Portable Node route and validation tests: 3/3 PASS.
- `companion_schema.sql`: SQLite schema creation PASS.
- Six Work checkpoint `.mjs` files: Node syntax PASS.
- Source safety checks: no direct stage-completion rewards added; no main/production mutation.

## HOLD / required validation
- Full Godot 4.7.2 import and runtime integration: NOT RERUN here; no local Godot binary.
- Real mobile scroll/gesture, journal/preset/arena presentation, save isolation and 0-reward training: NOT DEVICE TESTED.
- Profile D1 migration and Worker deployment: NOT PERFORMED. `companion_schema.sql` must be reviewed and applied to **Profile database only** after approval, never IAP ledger.
- Privacy copy and Data safety: existing public policy does not yet disclose the optional 30-day account-bound gameplay funnel. Align template, docs and release outputs before any live client rollout. Do not publish a contradictory privacy page.
- Base commit has existing red CI workflows; do not represent them as feature-batch passing.

## Known limitation
This ZIP uses source file replacements based on exactly the locked base commit. Before applying, validate clean checkpoint branch and compare actual working tree; do not overwrite any unpushed Work files.

## Continuation pass — QA and client queue hardening

- **9/9 PASS**, Node 22 isolated SQLite/HTTP regression against actual `companion.mjs` and `companion_schema.sql` plus fixture imports for existing authentication/helpers. Covers replay, daily quotas, account isolation, DELETE, schema/FK, aggregation, retention, and public-only agenda. SQLite is not remote Cloudflare D1.
- Fixed optional metric queue: a 20-item `_clean()` limit previously dropped newly appended events after the queue filled; the client now stores at most 100 FIFO and drops oldest only on a genuine offline overflow. Network continues sending at most 20 events per request; local session/event IDs and account-binding checks unchanged.
- Corrected the `SceneTree.scene_changed(scene)` callback adapter so `_scene_changed()` receives no unexpected argument.
- Added `tests/player_features_smoke.gd` for an **isolated** full-project Godot run. It checks data validation, 100-event cap and real practice scene/player/targets while asserting there are no inventory/quest/currency/progress mutations. This test is **NOT EXECUTED** here: no Godot binary nor complete source checkout available.
- Added `PLAYER_FEATURES_PRIVACY_DEPLOY_GATE_2026-10-22.md`: draft privacy text + staging-only migration/release gate. Neither public text nor Data safety is claimed updated.

This does **not** authorize production, main merges, or replacing previously recorded QA evidence. Continue from `CURRENT_WORK.json` and only run test stages not yet proven.
