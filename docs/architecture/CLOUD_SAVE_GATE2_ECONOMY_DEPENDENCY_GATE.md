# Jade Ascendant — Cloud Save Gate 2: Economy transaction dependencies

**Status:** Source-audited, read-only graph and permanent regression gate. **NOT** production cloud synchronization. No upload, restore, ledger verification, purchase reconciliation, or Firestore write permissions are introduced.

## Source of truth and audit scope

- The source baseline for existing gameplay systems is the user-provided `JADE_CLOUD_SAVE_SOURCE_AUDIT.zip` (2026-10-01) with `scripts/managers`, `scripts/game/ProgressionManager.gd`, `scripts/ui/equipment_manager.gd`, `tests/phase0_smoke.gd`, and `project.godot`. Baseline `main` at last verification: `7c9c5e7`.
- The patch for `cloud_save_snapshot_capture.gd` and `tests/phase0_smoke.gd` builds from the previously delivered `JADE_ASCENDANT_CLOUD_SAVE_GATE1_LOCAL_MEMORY_CAPTURE.zip`, the latest authoritative replacements for these two files in this conversation. Subsequent Android Capture QA only changed `scripts/ui/google_account_card.gd`; Firebase teardown only changed addon `Firebase.gd`.
- Relevant source evidence: `PavilionManager.summon()` batch Pavilion+Inventory; `PavilionManager.acquire_equipment()` batch Progression+Inventory; `PavilionManager` cosmetics batch Progression+Inventory+Pavilion; `EquipmentManager.ascend_item()` batch Equipment+Inventory; `RewardManager.grant_reward()` batch Progression+Inventory plus caller-supplied claims; `IdleCultivationManager.claim_idle_reward()` supplies its own domain to RewardManager; DailyQuestManager and AchievementManager do the same. `LiveOpsManager` supplies Pavilion to RewardManager.

## Why a six-domain structural draft cannot be moved to another device

`CloudSaveSnapshotContract` validates six **candidate** domains (achievements, daily_quests, equipment, inventory, journey, progression). But economic actions use **atomic local batch writes** that cross this boundary:

| Source operation | Locally co-committed domains | Six-domain copy |
|---|---|---|
| Pavilion summon | pavilion, inventory | SPLIT (pavilion omitted) |
| Pavilion currency shop / cosmetics | pavilion, progression, inventory | SPLIT |
| Pavilion daily meditation, LiveOps claims | pavilion, progression, inventory | SPLIT |
| Equipment direct purchase | progression, inventory | both included |
| Equipment ascension | equipment, inventory | both included |
| Offline idle claim | idle_cultivation, progression, inventory | SPLIT (idle omitted) |
| Daily quest reward | daily_quests, progression, inventory | all included |
| Achievement reward | achievements, progression, inventory | all included |
| Generic reward grant | progression, inventory | both included |

Additional transactional paths must be added when identified: this graph is an **audited inventory of known flows**, not a runtime transaction log. `journey` can contain progression and run-selection state; current capture excludes active runs and checkpoint, but Journey is not independently attested by this graph.

## New code and failure behavior

`cloud_save_economy_consistency.gd` is an inert `RefCounted` inspector. `inspect_domains(Array)` accepts only unique, registered **permanent** domain IDs, checks the audited local batch groups, and identifies which groups would be partially transferred. Unknown, duplicate, non-string, or checkpoint domains fail closed. It returns **no player data**, and never opens or changes save files. Its answers deliberately distinguish:

- `valid`: input and audited domain graph are well-formed;
- `transaction_closed`: **only** whether the chosen set contains all members of every **enumerated** group it intersects;
- `missing_dependency_domains`: omitted domains for partially included transaction families;
- `economy_verified = false`, `trusted_ledger_present = false`, `upload_allowed = false`, `restore_allowed = false` **unconditionally**, including if all eight permanent domains are selected.

The existing read-only capture now runs this inspector after the already approved structural validation. It retains the existing `valid = true` six-domain **local structural preview**, but additionally returns `economy_transaction_closed = false` and `economy_missing_domain_dependencies` (Pavilion and Idle Cultivation for current candidate). The preview **still** has `economy_verified = false`, `upload_allowed = false`, and `restore_allowed = false`.

The synthetic-only permanent suite tests split families, the full-eight-domain **closed-but-still-not-transferable** case, malformed domain sets, and the capture's revised report. It does not inspect actual saved currency, call Firebase, or modify runtime managers.

## Additional blockers beyond transaction closure

1. **Client-generated state is not authoritative.** A forged high balance can satisfy both the snapshot structure and this graph. Server must validate receipts/entitlements and issue authoritative revisions.
2. **Local anti-replay is bounded.** `PavilionManager.MAX_PROCESSED_GRANT_IDS = 1024`; the oldest IDs are evicted. This is not a durable, unlimited, cross-device purchase ledger. The method named `apply_verified_iap_purchase` accepts an identifier passed by the client-side adapter: method naming is not proof of independently verified Google Play receipt.
3. **Idle time uses a device-observed clock.** Reconciliation needs explicit rules for offline accrual and device clock rollback, not a snapshot timestamp guess.
4. **A locally atomic batch is not a server-side revision or cloud transaction.** Future upload must bind a complete, allowed state to an authenticated UID, server revision, integrity policy, and conflict strategy.
5. **Equipment and inventory must remain consistent**, and all economic effects of permanent equipment purchases/ascensions must be reconciled with their transaction history.
6. **Current Firestore Rules must remain read-only.** The owned `get` permission on `jade_cloud_manifests_v1/{uid}` does not authorize any write to snapshots or economy ledgers. Do not loosen Rules until a backend design, tests, and security review exist.

## Release gate / next engineering step

- Establish a **server-owned append-only transaction/entitlement model** and precise trusted verification of Google Play purchase tokens (including refunds/revocations/restore on another device). Define claim grant IDs, uniqueness, and replay windows independent of device data.
- Specify whether each permanent domain is server-derived, client-proposed and validated, or device-local only. In particular, inventory, progression, Pavilion, and idle cultivation cannot be considered separable solely because they occupy different save files.
- Introduce an account-linked **server-issued monotonic revision**, compare-and-swap, and documented multi-device conflict handling; never equate the current `revision=1` placeholder or device timestamp with authority.
- Build a reversible local-backup restore transaction and tests before enabling remote restore.

No automatic upload/restore or additional Autoload is introduced in this patch. Do not commit or push until `PERIKSA_GAME` and relevant QA pass on the user's local project and staged diffs are reviewed.
