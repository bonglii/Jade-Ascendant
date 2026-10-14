# Economy progression — 2026-10-14

Base: bbd7af5e76f1ffb8cc2207cc30ec3c328d77c487 (Combat Fairness package must be applied first).

## Weapon levels

Next-level stone cost is now `10 * (current_level + 3)` instead of `20 * (current_level + 1)`. Level 1 to 2 remains 40 stones. The slope is reduced because permanent levels grant 1% damage each, while stones also fund cultivation. Prices are shared by all existing armaments.

| Target level | Old cumulative stones | New cumulative stones |
|---|---:|---:|
| 10 | 1080 | 720 |
| 20 | 4180 | 2470 |
| 30 | 9280 | 5220 |
| 40 | 16380 | 8970 |
| 50 | 25480 | 13720 |

Total level-50 cost falls 46.15%. Damage growth remains +49%; one to five duplicate stars retain caps 10/20/30/40/50. Existing levels, stars, inventory and spent balances are retained. No retroactive refund or new save field. The current UI already obtains prices from the production manager; no duplicated display formula.

## Idle progression

Cap raised from 16 to 26 authored encounters. Only unique implemented stages in JourneyManager count; duplicate/unknown saved keys do not unlock or increase income. One-time unlock behavior and valid historical stages remain compatible.

| Clear tier | Stones/hour | Hero EXP/hour | Shards/hour |
|---|---:|---:|---:|
| 1 | 48 | 12 | 0 |
| 16 | 138 | 42 | 1 |
| 21 | 168 | 48 | 1 |
| 26 | 198 | 60 | 1 |

Shard intervals stay unchanged (maximum one per hour at tier16+); tier21 and 26 add Frostveil and Solar Nirvana titles. Ten-minute claim units, 12-hour storage cap, carried partial units/shards, rollback protection and atomic reward writes remain. Tier26 pays 2376 stones/720 EXP/12 shards per full 12-hour claim; completed optional rewarded double pays twice that. Pending ad snapshots retain the tier/reward prepared before an intervening clear. No new monetization activation.

Accrual continues to use the tier at claim/preview as in the existing system; this is not a historical per-second tier ledger. At max tier, level1-to50 costs about 69.3 accrual hours of stones alone (versus 184.6 hours at the old tier16 cap/old prices). This is a resource budget illustration, not guaranteed calendar progression: cultivation spending, claim cadence, stage-clear time and other income differ by player.

## Validation

Godot4.7.2 Linux headless, isolated test profiles: economy614 + economy restart4 + HERO125 + HERO restart6 + idle modal62 = 811 checks, zero failures or script errors. Covers all armament prices/caps, exact/insufficient wallet, durable level+cost, legacy idle normalization/restart, all26 authored clears, invalid/duplicate clear keys, capped/partial/repeated claims, reward snapshot and write barrier. Existing engine shutdown cleanup warnings remain. Windows publishers source reviewed; Android economy playtime not measured. Reuses prior combat balance evidence without rerunning unchanged combat/assets.

No boss/player damage, asset changes, gacha rates/costs/pity, duplicate requirements, backend deployment, Google sign-in, paid-wallet/IAP gates, or production/main changes.

## Publishing

Apply Combat Fairness first, then this patch. `backend\player_identity\publish_economy_progression.cmd` permits the scoped preceding Combat Fairness package plus this economy package, checks checkpoint ancestry, commits only approved paths, performs no force push, and prints a GitHub commit URL only after remote SHA verification. Shared LESSONS/BACKLOG files are excluded to avoid earlier user-side patch conflicts. Existing publisher authentication failure is not retried here. Re-export Android; no backend deploy.
