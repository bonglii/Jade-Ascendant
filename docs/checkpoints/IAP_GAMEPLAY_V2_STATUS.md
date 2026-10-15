# IAP delivery: source checkpoint, 2026-10-15

Base: 70e9d16b2990ce46fe0469090ecd43e5989f9f15.

This package is a source checkpoint for continued development. It is not a
money-ready release and does not deploy, buy anything, or change version/export
configuration. Do not re-export Android using the old installed AAR: it cannot
implement the new durable recovery methods. Publish first to run native CI.

Implemented and reverified here:
- A pinned server catalog of all 56 active equipment items, excluding retired Bell.
- Additive V2 paid inventory with real duplicate counts, duplicate-only refinement,
  independent weapon slot, wish target and separate server summon pity.
- Atomic server-wallet debit + outcome + inventory + idempotency receipt. CAS and
  durable cancellation fence retries from two devices, stale requests and late HTTP.
- Exact migration from immutable V1 outcome history. Missing proofs fail closed.
  Original balances, outcomes and legacy fragments remain preserved.
- Refund hold and fresh reconciliation watermark checked before and inside commits.
- Separate opt-in staging configuration and production entrypoint. Existing deployed
  production configuration and release activation flags remain unchanged.
- Android source: encrypted device Keystore/AtomicFile pending purchase journal,
  per-account replay before Play owned-purchase rescan. No Firebase/App Check token,
  local currency grant or raw purchase-token logging. Records retire only after a
  validated server-wallet receipt. Unsupported old AAR blocks checkout safely.
- CI builds/tests both native variants, checks JNI and publishes candidate AARs plus
  actual build receipts. Release remains locked. Historical binary hashes are not
  rewritten to claim compilation that has not happened.

Verification in this workspace: Node 24, full Cloudflare suite 404/404 passed.
Native compilation, Android Keystore/process-kill behavior and Godot runtime have
NOT been reverified in this workspace. CI must run after publishing.

Remaining before real-money approval:
1. Verify native CI and device journal/account-switch/kill/restart behavior.
2. Finish the V2 client: signed snapshot parser/lease, pending command journal,
   explicit paid summon UI, server armory/refine and paid combat loadout overlay.
   Existing local inventory/save must never acquire paid balance or paid items.
3. Rebuild a deliberately configured production bridge only after client cutover;
   configure/deploy authenticated production Worker, Play API/App Check/refund cron.
4. Prove Play-installed checkout -> verified server credit -> spend -> received gear,
   same-account second device, interrupted delivery, idempotent replay and refund hold.
   License test purchases are not real charged orders. An actual charged transaction
   requires a non-license-test account/device and the user's real payment approval.

Known limit: device journal survives process death/update, not app-data deletion or
uninstall. Grant-ready server ledger survives reinstall; pending-consume records
still need the token/verified Play evidence. Do not promise universal recovery.

Workflow lesson: preserve source checkpoints before long QA runs; a transient
workspace reset is not evidence that earlier test results validate rebuilt sources.
Inspect shipping scenes/native artifacts, not only legacy code or old hash receipts.
