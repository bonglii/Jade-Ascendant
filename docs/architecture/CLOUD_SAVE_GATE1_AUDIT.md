# Jade Ascendant — Cloud Save Gate 1 / architecture audit (NO runtime implementation)

Audit source: `bonglii/Jade-Ascendant` `main` at `ea9108e1dc4962a36ba885ae16ecaecbf5490f23` (GitHub fetch, 2026-10-01), plus local Google Login patch family tested by owner. Future commits and local working-tree differences require re-audit. This is **a proposed design**; not a claim that Firebase Cloud Save has been deployed.

## 1. Actual save authority

`SaveManager.SAVE_ARCHITECTURE_VERSION = 1` and domain schema versions currently equal 1. Each manager owns its save payload; `SaveManager` owns shared I/O, staged atomic writes, last valid backup, pending transaction journal and recovery. NEVER bypass owner managers with a direct `FileAccess` cloud restore.

| SaveManager domain | Scope | Concrete path | Owner | Proposed v1 treatment | Reason / dependencies |
| --- | --- | --- | --- | --- | --- |
| `progression` | permanent | `user://progression.save` | ProgressionManager | paired backup/restore with ledger checks | Spirit Stones, cultivation and hero EXP. Reward grants may write with other domains. |
| `journey` | permanent | `user://journey.save` | JourneyManager | paired snapshot | Stage unlock/clear, selected stage, active-run chapter/stage identity. Must not restore inconsistent stage identity. |
| `achievements` | permanent | `user://achievements.save` | AchievementManager | paired snapshot | Progress / unlocked / claimed; never grant a one-time reward twice. |
| `daily_quests` | permanent | `user://daily_quests.save` | DailyQuestManager | paired snapshot, server date policy needed | Date key and reward claim markers must stay consistent. |
| `equipment` | permanent | `user://equipment.save` | EquipmentManager | paired snapshot after inventory validation | Equipped IDs must be owned, valid and compatible. |
| `inventory` | permanent | `user://inventory.save` | InventoryManager | paired snapshot after reward ledger checks | Items/shards include potentially monetized and summon-earned value. |
| `idle_cultivation` | permanent | `user://idle_cultivation.save` | IdleCultivationManager | **do not auto-restore** until clock policy | Unix timestamps, lifetime claims and shard progression are time-sensitive. |
| `pavilion` | permanent | `user://pavilion.save` | PavilionManager | **not client-authoritative**; trusted-economy boundary required | Celestial Jade, Pavilion Seals, pity, summons, billing grant IDs, entitlements, LiveOps claims all coexist here. |
| `checkpoint` | active_run | `user://checkpoint.save` | CheckpointManager | **local-only for v1** | Active-run state is volatile and coupled to runtime timing and stage identity. |

Related files that are **not** `SaveManager` domains: `user://transaction.journal` (SaveManager atomic recovery), Firebase native auth session, `user://google_account_entry.cfg` (legacy entry UI preference, ignored by final boot routing), onboarding/UI configuration, settings, and platform billing SDK state. No direct synchronization of these files in Cloud Save v1.

## 2. Cross-domain integrity hazards from actual source

- `LiveOpsManager` deliberately stores namespaced claim markers inside the **Pavilion** domain (`claimed_milestone_ids`) and grants rewards using `RewardManager` paired with Pavilion snapshot. Restoring `progression` and `inventory` independently of Pavilion risks claim duplication or rollback.
- `PavilionManager` stores `processed_grant_ids` only locally and trims history to `MAX_PROCESSED_GRANT_IDS = 1024`. This is **not** an authoritative all-time purchase ledger.
- `PavilionManager._on_billing_purchase_ready` forwards token directly to `apply_verified_iap_purchase()`, then finalizes through the billing adapter. The audited path has **no trusted backend verification step**. Method name `verified` is not evidence of server verification.
- `SaveManager.write_save_batch()` and pending-journal recovery are valuable local integrity mechanisms, but they do **not** automatically provide multi-device conflict resolution, Firestore atomicity, or purchase provenance.
- Android Firebase Authentication establishes UID/identity only; the existing login code does not upload or download gameplay data.

## 3. Design choice required before implementation

**Recommended split:**

A. **Local gameplay authority** continues unchanged. Device works offline and its atomic transaction/recovery protects the working save.
B. **Account-bound progress backup** must be an explicit, versioned snapshot with a consistent multi-domain `snapshot_id`, `created_at`, `client_build`, per-domain schema metadata, payload checksums, and a known source device. Protect with Firebase Authentication UID and server-side access controls. A client checksum detects corruption, **not** dishonest edits.
C. **Trusted economy** (verified Play purchases, premiums, paid entitlements, and reward grants that affect them) requires a **server-side idempotent ledger**. A full client-writable raw Pavilion/Inventory blob must never be treated as trusted proof of currency or purchases.
D. **Active run stays on device.** Cross-device checkpoint transfer is a distinct later phase.
E. **First account-link / conflict**: pause gameplay writes and show explicit options only after both snapshots validated. Never silently replace progress or sum currencies across devices. An incompatible, missing, corrupt, or future-version cloud snapshot must not destroy a healthy local one.

Potential implementation sequence:
1. Define a narrow `CloudSaveContract` serialization adapter over existing owner-manager `snapshot`/load methods after per-domain API audit; do not add a second owner for gameplay files.
2. Build local-only dry-run export/import validation in a disposable sandbox. Reconcile cross-domain claims and backward-compatible schema migrations without actual Firebase traffic.
3. Build signed-in **cloud metadata and backup read** with strict UID rules; confirm Firestore-vs-Storage capabilities of the *actual installed native plugin* before writing any Firebase API calls.
4. Add server-side write validation and trusted billing ledger before enabling a cloud restore of economy-bearing domains.
5. Enable explicit backup/restore with revisions (optimistic concurrency), restore preview, automatic local backup, and all-or-nothing commit.
6. Enable limited background sync only after offline queue, collision, sign-out, account switch, dual-device concurrent writes, and interrupted upload tests PASS.

## 4. Proposed data model (contract sketch, not deployed)

`users/{firebase_uid}/save_slots/main` metadata: `schema_version`, `snapshot_id`, `revision`, `updated_at_server`, `build_version`, `device_install_id` (random non-identifying install-scoped ID), `payload_location`, `payload_checksum`, domain-schema map, and compatibility flags. Keep secrets, OAuth tokens, emails, and account passwords **out of gameplay snapshots**. Store large blob in account-restricted Storage only if connector/plugin supports securely audited operations; Firestore document limit and costs must be checked. This is a proposal and can change after SDK review.

`users/{firebase_uid}/economy_ledger/{transaction_id}`: backend-only write; token verified against Google Play; database idempotency across devices and >1024 historical transactions; server-sourced balance/entitlements. Server timestamps and ownership constraints required.

Do not derive `firebase_uid` from a user-entered text field; server verifies Firebase ID token. Client reads its own account using real authenticated SDK context. Firestore rules must deny unauthenticated cross-account reads/writes; sensitive economy writes remain server-only.

## 5. Minimum acceptance tests before claiming Cloud Save PASS

- Existing Guest save and imported legacy save; old app version; schema future version; missing/corrupt domain; stale backups and `transaction.journal` present.
- New device with same UID; two devices with divergent progress; simultaneous writes with revision conflict; account A to B switch; logout while sync pending; Android force-stop mid-commit; airplane mode; outage/retry/reinstall.
- Currency/consumable grant once; rewarded-ad event once; Seven-Day and mail claim once; one-time IAP once; refund/reversal; multi-device replay after local processed IDs rotate.
- Restore staging writes only through managers and SaveManager, preserving previous local backup; no phantom stage clears or dangling equipped items.
- Never put ID tokens/transaction tokens/personal profile fields in logs, cloud snapshot debug dumps, Git or QA artifacts.

## 6. Gate / owner approval

This document is Gate 1 **analysis + proposed contract**. Cloud Save is **not active**, billing backend is **not built**, and release privacy/account deletion requirements remain outstanding. Approval of this architecture plus installed Firebase module API audit are prerequisites to runtime implementation.

Source: `scripts/managers/save_manager.gd`, `scripts/managers/pavilion_manager.gd`, `scripts/managers/live_ops_manager.gd`, `scripts/monetization/google_play_billing_provider.gd`, `scripts/managers/reward_manager.gd`, `scripts/managers/checkpoint_manager.gd` on the pinned GitHub revision. Official Firebase rules: https://firebase.google.com/docs/firestore/security/rules-conditions ; Google Play account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
