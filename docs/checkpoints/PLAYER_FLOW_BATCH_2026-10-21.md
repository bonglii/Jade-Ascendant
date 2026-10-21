# Player Flow and Consistency — 21 October 2026

Base: fetched checkpoint/iap-fasttrack-20261010 at a3dff88. Main and the old dirty author snapshot are untouched. User confirmed the prior Event Touch revision 2 was installed and committed; four current screenshots were inspected successfully from the new attachment paths.

## Scope and status

| Request | Implementation |
|---|---|
| 1. Faster board ads | Warm the video and reserve its signed intent during authenticated idle menus. A tap consumes the installation-local prepared nonce and opens the ad without an extra intent round trip. No video opens from prewarm; SSV still grants dice. |
| 2. Mailbox claim/delete latency | User mutations preempt a background GET that has exceeded 1.5 seconds; claims/acks retain batches of eight while up to four independent per-letter operations run concurrently with independent primary sessions. No optimistic economic grants or dropped receipts. |
| 3. Cancelled/failed checkout | Clear explicit Play cancellation/failure active-product state before emitting UI callbacks. Actual pending/uncertain purchases retain recovery and server verification. |
| 4. Black rectangle | Suppress phone tooltips after dynamic refresh; round glyph controls without stretching them into tall ovals. Existing alpha-safe material remains. |
| 5. Journey count | Server v4 state moves to full laps, thresholds 4/8/12. Immutable claim IDs remain 24/48/72; earned legacy thresholds and previous claims remain valid. Rolls remain separate for daily tasks, animation and the 152-roll cap. |
| 6. Settings/save | Notification controls removed from Settings. Necessary cloud backup/restore kept in a collapsed Account & Save Recovery section. Local atomic save/backup behavior remains; corruption recovery is exercised with isolated userdata. |
| 7. Boss arena | Physical jade enclosure shared by normal stage bosses, with escape clamps for player and boss. Removed on boss defeat. No HP, damage, movement-speed or attack buffs. |
| 8. Trials/records | Six daily quests, three new rotation candidates and six new long-term achievements. Existing daily claims preserved. Seven sculpted SVG insignia replace line-drawn category icons; new achievements include earned Jade/seals. Daily premium completion bonus is unchanged. |
| 9. Home events | Rotate real available events every 6.5s; prioritise claimable events. Completed one-time events and expired seasons disappear, preserving only earned claim grace. |
| 10. Consistent stage-clear popups | Ladder, Pilgrimage, Boss Hunt, Treasure Hunt and Five Elements share popup ownership/entry path, compact header insignia and readable counters. Landscape header duplication and stretched divider blocks addressed. |
| 11. Startup connections | Existing autoload mail, account/paid services and backup hooks remain. Odyssey boot prewarm now recovers its durable pending command rather than waiting for a menu; ad-intent preparation joins idle startup. No fake connected state or skipped identity checks. |
| 12. Celestial design | Approved design retained; visibility, compact text, numeric wrapping and consistent popup entry refined. |
| 13. Profile | Level, rank and selected realm/stage added alongside name/UID edit/copy and real connection state. |
| 14. Numbers | Shared compact K/M/B/T/Qa/Qi display for resource counts, finite/nonnegative formatting tests, one-line numeric event markers, natural width for stage tags. Live Play prices remain exact platform strings. |
| 15. Dashboard | Shared jade/gold Studio theme, responsive forms/cards/tables, current Journey labels, isolated-DNS desktop shortcut, normal username/password opening without requiring the old protected setup key. Optional custom admin origin is supported locally. |
| 16. Player/developer audit | Cross-flow audit found and fixes onboarding overflow, short-lived draw texture references, vertical achievement reward text, disabled achievement controls consuming drag, stretched separators, stale milestone dots, expired/complete-event visibility, and dice purchases beyond remaining playable season capacity. See lessons and evidence. |

## Economy and compatibility

A 72-lap reward cannot be reached in the current 152-roll season (mean movement 3.5 on a 20-tile board yields about 26.6 laps at the cap). The new 4/8/12-lap thresholds correspond to about 23/46/69 average rolls; the existing rewards and 24/48/72 command/receipt identifiers are preserved. This stays near the previous 24/48/72-roll cadence without requiring a native protocol or ledger migration. Unversioned legacy state retains its roll rule until v4 activation; v4 state is explicitly versioned and remains lap-based across requests so an older endpoint cannot repeatedly reset grandfathering. Previously earned v4 roll milestones are grandfathered once, not increased by future rolls.

Two daily records per discipline add regular play goals. Six long-tail achievements add a finite 420 earned Jade and nine Pavilion Seals in total; they do not write the paid wallet. Existing claim IDs are unchanged. Paid dice exchanges cannot charge for dice that exceed remaining season capacity. Current Play product IDs, prices, dice bonuses, ad unit IDs/caps, SSV signature/nonce rules, refund holds and all nine live production gates remain unchanged.

## Delivery stages

This is a client + two Worker source batch; no native rebuild or schema migration is needed. The portable Windows launcher installs verified files, runs the exact focused game/server checks, commits/pushes scoped files on the checkpoint branch, deploys the existing profile and IAP Workers, and creates the dashboard desktop shortcut. Each completed stage has a receipt; a failure preserves installed files, backup, cache and logs. No force push, deleted Git lock, database reset, account reset, secret creation, FCM broadcast or event reschedule.

Author Git push dry-run has no write authentication. The user-side launcher prints the actual commit link only after a successful push. This document does not claim that user-side deploy/export/device QA has happened.

After the launcher passes, use backend\player_identity\export_production.cmd and export the AAB from that editor; upload through the existing Play internal-test workflow.

## Remaining external constraints

- A normal dashboard URL that avoids the problematic workers.dev network route needs an actual owned domain and its Cloudflare route/certificate. No domain was supplied, purchased or fabricated. Until then, the desktop shortcut uses encrypted DNS only for its isolated browser profile; Windows DNS and certificate verification are unchanged.
- Real ad availability, Google checkout UX and mobile network latency remain provider/device dependent. Fixtures prove dispatch/order/ownership and UI behavior, not production end-to-end timings or real purchases.
- The new Sect Gate event remains parked; this batch does not implement it or add weapons/equipment.

Validation: 568 game assertions, 120 selected backend tests and 21 portable installer/publisher checks passed. Eleven phone-size software renders were inspected for the affected flows; no Godot script errors remained. Windows COM shortcut execution, dashboard browser rendering, real device ad latency and production deploy were not executed here. Validation results and final state are saved with the package and docs/checkpoints/PLAYER_FLOW_BATCH_STATE_2026-10-21.json. Resume from that evidence, not an older download directory.
