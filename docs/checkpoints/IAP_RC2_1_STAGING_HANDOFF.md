# Jade Ascendant — IAP FastTrack RC2.1 (STAGING ONLY)

Baseline branch: `checkpoint/iap-fasttrack-20261010`
Baseline commit: `54168ac936acfdde380336687ba307172e168659`
Source handoff: `docs/checkpoints/IAP_FASTTRACK_2026-10-10.md`

**This patch is local, uncommitted, source-only. It is NOT an IAP production release, not an approval to migrate D1, and not a request to enable flags.**

## Work in this batch

- Adds server-pinned equipment-slot mapping for all 40 equipment IDs, with fail-closed catalog parity check at module import.
- Adds an independent signed-Firebase-UID paid loadout read/write staging endpoint at `/v1/wallet/paid-loadout`.
- Adds a separately stored paid loadout that is **not** stored in `user://equipment.save`, `user://inventory.save`, or the existing canonical summon inventory.
- Validates current server-owned paid inventory before accepting item IDs; rejects wrong slot, unknown item, unowned item, and cross-account data.
- Requires `expected_loadout_revision`, `expected_entitlement_revision`, and UUIDv4 `request_id`; D1 optimistic CAS guards canonical revision, current ownership, and loadout revision in ONE atomic batch. Retries are deduplicated by owner+request_id and payload hash.
- Adds source-only migration `0005_paid_loadout.sql`, **never apply remotely** without approval.
- Adds a Godot **display-only** envelope for paid loadout, requiring a fresh entitlement revision; no game runtime equips, save mutations, local purchase grant, or network wiring are introduced.
- Adds 13 focused backend test cases and a 12-check Godot smoke script. The tests were run against temporary local dependency stubs; they must be rerun against actual repository sources after applying this patch. They are not replacements for previous passing suites.
- Routes the new endpoint from Worker `index.mjs` behind default-off independent flags `JADE_PAID_LOADOUT_READ_ENABLED=false` and `JADE_PAID_LOADOUT_WRITE_ENABLED=false`; global IAP gate must additionally be true for POST. Existing RC2 summon/entitlement flags remain under `[vars]`, both false.

## Safety invariants

1. **No** local save schema migration. Legacy/earned Jade remains on the existing offline path. Paid Jade remains only server-owned.
2. **No** paid ownership import from client saves; canonical progression remains unprovisioned unless separately verified.
3. **No** special equipment ascension, refinement or runtime stat cutover; paid shards in entitlements remain read-only.
4. **No** Android paid-loadout transport activation; current paid entitlement/recovery/purchase gates remain locked.
5. **No** production Cloudflare migration, deploy, flag toggle or account mutation in this batch.
6. **No** Git commit/push/merge. `main` untouched.
7. Duplicate operation requests cannot create an additional write after successful commit. Retried requests with different payload are conflicts.
8. If an entitlement is revoked, the read path fails closed instead of displaying or equipping a stale paid item. A future server-controlled revoke/reconciliation endpoint must be designed and verified before launch.

## Remaining release blockers — DO NOT ENABLE

- Trusted server progression proof / canonical verified state onboarding, including fraud resistance and multi-device reconciliation. It is **not** safe to accept `progression.save` or a client-provided cleared-stage list as proof.
- Refund, revoke, Play purchase voided/refunded-event handling, durable paid-ownership reconciliation and reset of affected server loadout slots. Current canonical `inventory` does not include provenance per granted item; a complete refund design must account for that.
- Android/Kotlin transport for signed paid summon WRITE and paid loadout GET/POST, with explicit build gates, bounded JSON, account-switch invalidation and no tokens persisted.
- Godot runtime paid-loadout equipment stat overlay that is *ephemeral* and account-bound, plus active-run checkpoint policy; do NOT call `EquipmentManager.equip_item` on server-paid items because it writes `equipment.save` and triggers `InventoryManager` migration.
- Recovery semantics for lost paid summon request IDs and process death (pending IDs only, account-bound, idempotent). No double spend on timeout.
- WAF/rate limits, D1 staging migration dry run/rollback strategy, static catalog synchronization, controlled two-device Firebase Auth+App Check, Play Billing license tester sandbox, refund/revoke QA.
- Security review of full Worker bundle and regression suite run on the real source (original RC1 pass is not re-run unless changed code touches its scope).

## Apply locally (not executed by assistant on user's machine)

From **CMD**, with patch folder extracted OUTSIDE the repository:

```bat
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "D:\Godot\tools\Jade-IAP-RC2-Staging\Apply-RC2-Staging.ps1" -Project "D:\Godot\project\jade-ascendant"
```

The script refuses any branch/HEAD mismatch, conflicting changes in install targets, source blob mismatch, destination collision, or missing patch file. It uses only the specified checkpoint and patches source files locally. It does not commit, push, deploy or toggle flags.

## Focused QA after applying, combined once

```bat
cd /d D:\Godot\project\jade-ascendant\backend\monetization\cloudflare
node --test tests\paid_loadout_rc2.test.mjs
cd /d D:\Godot\project\jade-ascendant
godot --headless --path . --script res://tests/hybrid_paid_loadout_rc2_smoke.gd
git diff --check
git status --short --untracked-files=all
```

Use the already-installed Godot executable if it is not named `godot`. No tests requiring live purchase or production D1 are part of this batch.

## Explicit completion standard

RC2.1 backend staging is a *preparatory piece* for RC3. Do NOT label `RC Production PASS` until the blockers above have evidence. Next changes should focus on trusted progression, paid summon native request transport and crash-safe pending-ID recovery; then ephemeral paid equipment gameplay projection; then sandbox/refund end-to-end QA.

## FIX2 installer policy (2026-10-10)

The FIX1 clean-worktree requirement was overly broad and is superseded by FIX2. Unrelated modified or untracked files are preserved. This installer checks exact source hashes, checkpoint branch/HEAD, modified integration targets, and new-file collisions. It can be run again idempotently. A conflict in `index.mjs`, `wrangler.toml`, or one of the seven incoming files still blocks the installer *before writes*. See `INSTALLER_FIX2_LESSONS.md` in the extracted package.
