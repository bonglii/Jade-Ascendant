# Jade Ascendant — Cloud Save Gate 1: Structural Snapshot Contract

**Basis audit:** user-provided `JADE_CLOUD_SAVE_SOURCE_AUDIT.zip`, received 2026-10-01; compare authority for existing committed files: GitHub `main` `7c9c5e7`. Local source is newer than that commit. The replacement `tests/phase0_smoke.gd` is based **only on the supplied latest local file**, not on GitHub's older smoke script.

**Status:** Candidate format + in-memory validator + regression QA only. This is *not* a cloud-save delivery system. Do not publish a UI claim that gameplay is backed up.

## Source findings (not assumptions)

`SaveManager.SAVE_DOMAINS` contains 9 registered domains: 8 `permanent`, 1 `active_run`. SaveManager has domain-specific schema checks, atomic writes, backup recovery, and `write_save_batch()`. `EquipmentManager.build_equipment_save_data()` can include `active_run_loadout_snapshot`, and `JourneyManager.build_save_data()` includes active-run chapter/stage IDs. A raw copy of those two permanent save files is **not** a permanent-only snapshot. Equipment and inventory must be validated together. `PavilionManager` can commit cross-domain economy transactions; it is excluded from this draft until a trusted receipt/entitlement ledger and conflict policy exist.

## Candidate V1 structure (not sent to Firestore)

```
{
  "snapshot_format_version": 1,
  "owner_uid": "<verified Firebase UID>",
  "revision": 1,
  "saved_at_unix": 1,
  "domain_schema_versions": {
    "achievements": 1, "daily_quests": 1, "equipment": 1,
    "inventory": 1, "journey": 1, "progression": 1
  },
  "domains": {
    "achievements": {"version": 1, "progress": {}, "unlocked": [], "claimed": []},
    "daily_quests": {"version": 1, "date_key": "2026-10-01", "progress": {}, "completed": [], "claimed": []},
    "equipment": {"version": 1, "equipped_item_ids": {"armament": "", "robe": "", "bracer": "", "boots": "", "pendant": ""}},
    "inventory": {"version": 1, "item_counts": {}},
    "journey": {"version": 1, "selected_chapter_id": 1, "selected_stage_id": 1, "active_run_chapter_id": 0, "active_run_stage_id": 0, "unlocked_stage_keys": [], "cleared_stage_keys": []},
    "progression": {"version": 1, "spirit_stone": 0, "vitality_level": 0, "sword_power_level": 0, "swift_qi_level": 0}
  }
}
```

**The sample is synthetic:** it is not derived from the owner's real save and is not evidence that the data is complete or eligible to restore. All six domains must be present and match the SaveManager registry. No partial domain set or partial restore.

## Required defensive checks

- Firebase UID exact match; reject invalid document IDs or malformed metadata, unknown and future schema versions.
- Only the current **six-domain candidate**; reject `pavilion`, `idle_cultivation`, `checkpoint`, and unknown domains. `idle_cultivation` is a permanent economy producer that can affect progression/inventory, so a six-domain snapshot is **not yet a complete cross-device game-state representation**.
- Reject `journey` when `active_run_chapter_id` or `active_run_stage_id` is not `0` (`JourneyManager.NO_ACTIVE_ID`); never include `equipment.active_run_loadout_snapshot`. The future snapshot builder must establish a safe checkpoint-free capture boundary and must not silently erase live run data.
- Validate known inventory item IDs, equipped slot IDs, equipment catalog slot match, inventory ownership for equipped/ascended gear, ascension stars 1–5. Do not attempt to grant or normalize inventory during inspection.
- Reject unexpected per-domain fields, invalid numeric fields (including negative values and string-coerced counters), unsafe integers, unbounded objects, unsupported Godot-only Variants, and oversized JSON payloads. The structural size budget is 256 KiB; this is an intentionally conservative contract limit, not the Firestore service limit.
- Do not trust local progress values or local timestamps as economic proof. Structural checks cannot establish that an item, Spirit Stone, EXP, or entitlement was earned. Any authoritative cross-device currency workflow requires a server-controlled ledger and anti-replay semantics.

## Explicitly **not** implemented

- No network request; no collection/doc creation; no token retrieval; no disk read; no save write; no upload, restore, merging or automatic conflict resolution.
- No server timestamp, compare-and-swap revision, device identity, checksum, cryptographic authenticity, data migration, purchase restore, or claim settlement. The `revision` and `saved_at_unix` fields are merely input fields until checked by a trusted service.
- No changes to published Firestore Security Rules. Current Gate 1 rules allow only account-owned `get` of `jade_cloud_manifests_v1/{uid}`; **all client writes remain denied**. Keep them that way.
- No UI change or new Autoload. Google sign-in and the Android debug read-only probe remain as previously approved.

## QA and integration

`tests/phase0_smoke.gd` contains a permanent `_test_cloud_snapshot_contract()` using **fabricated data in memory only**, checking cross-account, unsupported versions, partial snapshots, excluded domains, active-run spillover, economy type spoofing, inventory/equipment mismatch, and other hostile input. No user file is opened or changed by the new test.

Run the owner's `PERIKSA_GAME.bat` after replacing files. In this environment no complete Godot project or installed Godot binary is available; **Android/runtime PASS cannot be claimed here**. After PASS, inspect the Godot console warnings. Do not commit or push until the user's local smoke/QA has passed and source diff is reviewed. The full local `project.godot` and unrelated Pavilion/export/release changes must remain unchanged by this patch.

## Hard gate to the next implementation

Before enabling even experimental cloud uploads, audit transaction replay, server-authoritative premium currency, a proper capture barrier, version migration, snapshot integrity and authenticated-account switching. Protect local backups **before** any eventual restore and require an explicit selection when local/cloud histories diverge. Firestore cache is not proof of server freshness.
