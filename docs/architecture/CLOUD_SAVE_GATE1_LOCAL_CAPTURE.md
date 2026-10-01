# Jade Ascendant — Gate 1: Local Memory Snapshot Capture (preview only)

**Input authority:** latest owner-provided `JADE_CLOUD_SAVE_SOURCE_AUDIT.zip` (local scripts, 2026-10-01), the subsequently QA-approved `CLOUD_SAVE_GATE1_SNAPSHOT_CONTRACT` and `SNAPSHOT_AUTOLOAD_QA_FIX` replacement, plus the previously approved Firebase lifecycle fix. GitHub `main` `7c9c5e7` remains the last **pushed** baseline; these Cloud Save changes are local and deliberately not committed yet.

## What this adds

`cloud_save_snapshot_capture.gd` is a **non-Autoload, uninvoked RefCounted helper**. `capture_current_account_preview()` is a synchronous in-memory assembly path that obtains an actual, verified Firebase UID from `GoogleAccountManager.get_authenticated_uid()`, reads permanent state directly through existing manager `build_save_data()` methods, and assembles six candidate domains for `CloudSaveSnapshotContract.inspect_draft()`.

- **Achievements:** `AchievementManager.build_save_data()`.
- **Daily Quests:** `DailyQuestManager.build_save_data()`.
- **Equipment:** `EquipmentManager.build_equipment_save_data()`; active-run loadout fields are **rejected**, never silently stripped.
- **Inventory:** copy of `InventoryManager.item_counts` with the registered schema version; the source has no `build_inventory_save_data()` API.
- **Journey:** `JourneyManager.build_save_data()`; both active-run identifiers must equal zero.
- **Progression:** `ProgressionManager.build_progression_save_data()`.

The helper refuses an account that is not authenticated, a pending transaction or blocked save, an active scene transition, active journey run, existing checkpoint, preserved equipment run loadout, or gameplay `player` node. It checks the boundaries and authenticated UID **again** after collecting. The read happens synchronously without `await`, timers, or signals; no automatic capture is triggered.

`SaveManager.read_save_data()` was intentionally **not** used: it may recover corrupt primary saves from `.backup`, which can write to the local disk. This pass must not change primary, backup, or transaction files. The only filesystem access is the **checkpoint file-existence guard** via `SaveManager.has_save_file("checkpoint")`; no save content is opened or changed. No `FileAccess.open()`, `SaveManager.write_save_data()`, `write_save_batch()`, Firestore calls, logging of UID, network I/O, or restoration occurs in the new helper.

## Important limitations (blocking cloud write)

- The returned `draft` contains account UID and gameplay values. **Do not log, display, publish or persist it**. The public synthetic-input API exists only for the isolated in-memory QA; it is not a future cloud security boundary.
- `revision = 1` is a **placeholder** for the structural contract, not a server revision. `saved_at_unix` comes from the device clock and **does not establish freshness**.
- Structural validation is **not evidence that a reward, item, EXP or Spirit Stone was legitimately earned**. It does not stop client forgery. The returned flags are always `upload_allowed = false`, `restore_allowed = false`, `server_verified = false`, `economy_verified = false`.
- The candidate excludes `pavilion`, `idle_cultivation`, and `checkpoint`. Pavilion transactions can touch several domains, and idle cultivation can generate rewards. Therefore **the six-domain candidate is not a complete transferable gameplay state**, even when structurally valid. This pass must never be auto-uploaded or restored.
- There is no save file snapshot consistency/revision barrier spanning external processes. This capture is a read-only examination of the synchronous in-memory manager state, not an authoritative persistent snapshot. Capture must not be invoked while gameplay runs or during transitions.
- Live capture is not attached to any existing UI flow; no additional Autoloads; Android Google Login and Firestore read-only probe behavior are unchanged.

## Regression QA

The existing **permanent** `tests/phase0_smoke.gd` gets an additional synthetic-only suite verifying the new script loads, captures exactly six domains, deep-copies, refuses excluded/economy/checkpoint data and cross-domain mismatch, preserves the original fixture, rejects unsafe identity/timestamps and never marks upload/restore as approved. A desktop call to the live method must refuse capture without Android authentication.

Run `PERIKSA_GAME.bat` locally. If QA passes, additionally check that Google Login / Firestore Read-only remains available on the Android debug build only if the integration is subsequently exposed there. **There is no Android UI or upload to test in this patch.**

Do not change Firestore Security Rules. The current published rules grant account-owned **GET only**, deny all client writes. Do not commit/push until local QA, selective Git review and explicit owner authorization.
