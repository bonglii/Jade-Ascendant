# Paid client V2 candidate — 2026-10-15

Current status: `IAP_PAID_RUN_RECOVERY.md` supersedes the historical limitations
below for the new run-lock source. The immutable server run, pre-instantiation
gate and separate-process recovery fixture are implemented; new native compilation,
deployed staging/device and production evidence are still pending. This is not
money-ready and is not an instruction to export.

Base: a5fff4decc2d29ef24151dc4318cc1f0dba9a47f.
The actual pushed base matches the reconstructed server tree. Its GitHub backend
job passed. Native CI failed before compilation because setup-android defaulted
to retired SDK package `tools`; this batch explicitly selects `platform-tools`.

Implemented source:
- Native parser: pinned 56-item catalog, exact request/result schemas, account hash,
  bounds, ownership/slots/stars, rates/pity and matching operation receipts.
- Build-time V2 candidate flag: requires staging + sandbox credit for the supplied
  build command. Default and release remain locked. No production activation.
- Client: 120-second authenticated ownership lease, account clearing, per-account
  atomic pending-command journal, replay of the same UUID, cancellation receipts,
  and nonblocking UI signals that do not await a disappearing menu instance.
- Pavilion: separate Server Standard paid buttons; prices 100/900, fixed odds and
  separate pity/target are disclosed. Existing local pulls cannot debit paid Jade.
  Verified paid results use the existing reveal without an early equipment reveal.
- Server Armory: five-column catalog of owned paid gear, compact scrollable detail,
  correct-slot equip/unequip, identical-copy refinement, legendary target selection,
  and weapon levels paid with existing earned Spirit Stones. Existing imperial
  image assets are reused; no new placeholder icons.
- Combat: paid selection freezes for the runtime session. Paid slots/stars are an
  online overlay and are excluded from local equipment/checkpoint ownership saves.
  Expired ownership stops new paid starter attacks until verification recovers.
- Save boundaries: explicit local Jade for mail claims and local purchases; legacy
  inventory migration uses raw local slots; paid server balance cannot be imported.
  Stored legitimate weapon levels are retained before login, with effective level
  still bounded by the current item's stars.
- Mobile: deferred touch-style callbacks now carry weak references across the queue.
- Optional staging deploy script checks the exact staging Worker/database, applies
  only additive idempotent schema, and never seeds a fake refund-monitor cursor.

Evidence:
- Published base commit a5fff4d: GitHub backend job SUCCESS, reward/refine jobs SUCCESS.
- Base native job FAILURE at SDK setup; no native compile success is claimed.
- This workspace: backend 404/404 passed; catalog/CI structure/patch whitespace checked.
- This batch's new Kotlin tests, native build and Godot contract/geometry/regression
  checks are added to CI. They have NOT executed here: the workspace has no Android
  toolchain/Godot and the engine download timed out at the proxy.
- The package does not replace installed AARs or alter old build-proof hashes.

Next gate: publish and inspect the new CI run and native artifact. Do not re-export
with the old AAR. Staging deployment and Android test purchase follow a successful
build/client check; production/real-money configuration stays separate.

Remaining limitations before money-ready approval:
- Need actual Android Keystore/process-death/account-switch proof and deployed Play,
  App Check, purchase/consume/credit/refund evidence. No new paid order was performed.
- Runtime selection freezes within one process. A restarted/continued run currently
  re-verifies the current server selection; server-backed persistent run-loadout
  locking is not implemented. Do not promise cross-device/restart loadout freezing.
- Device token journal does not survive uninstall/data deletion. Grant-ready server
  ledger can restore credited purchases; pending-consume still requires Play evidence.
- No production native target is enabled by this candidate. This is not an AAB for
  internal test 1.0.7; version/export configuration remains the user's responsibility.
