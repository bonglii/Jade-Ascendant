# Player direction, reward receipts and build audit — 21 October 2026

Base: `45c2f18e130cd7f96c8cf535c9d4c3a936bfcad6` on `checkpoint/iap-fasttrack-20261010`. The preceding player-flow batch is confirmed published. This batch prioritises player direction and reward clarity, then audits existing builds/endgame. The proposed new event and new weekly mode remain parked.

## Implemented player behavior

- Home chooses a real, unlocked, implemented uncleared stage. A completed selected realm yields to the next available realm. A saved run takes priority; progress recovery takes priority over a new run. Guidance is read-only until a deliberate tap.
- The primary button resumes the saved run, preselects the suggested stage in Journey, or opens the appropriate existing Cultivation, Trials, Events or Library page. It never silently starts a new combat run. Opening Home does not overwrite a stage choice or checkpoint.
- Stage 1-1 and 1-5 explain their relevant unlocks. After all stages, Home exposes unchosen mastery, the existing Golden Core trial, daily completion/claims, earned event rewards or build exploration.
- Profile has Recent Rewards: a local, account-isolated cache of up to 30 newly received records. Data comes from the existing post-commit RewardManager signal and uses its applied payload. Repeated legitimate stage clears have separate display event identities even when source IDs match. Batch claims coalesce; no replay/grant button exists. This is not purchase order history, a cloud ledger, an inventory backup or an analytics upload.
- The receipt cache uses bounded, validated JSON, atomic replacement and a backup. Large item collections prune older display records to remain under the 64 KiB reload bound. Corrupt cache recovery cannot change a wallet or player save domain. Earlier rewards cannot be reconstructed retrospectively by this UI.
- Library gains Builds: the current dominant set, full-set/passive activation, playstyle advice for all 11 sets and mechanics for all 13 permanent armaments. The weapon remains independent; four armor/accessory pieces activate a set. Mixed 2+2 sets do not add both sets' tier bonuses, matching production behavior.
- Correct stale Compass copy: the current event threshold is 12 complete laps past START. Historical immutable reward IDs and existing ownership remain unchanged.

## Audit findings and balance assessment

The corrected read-only exporter covers 57 active equipment definitions, 11 sets, 26 authored stages and 44 configurations across 11 runtime weapon/art families (Lv.1/3/5/7). Permanent armaments include several variants that share an art family; configuration rows are not measured DPS or evidence that one weapon wins every matchup.

| Permanent weapon stars | Level cap | Stones from Lv.1 to cap | Damage from permanent levels at cap |
|---|---:|---:|---:|
| 1 | 10 | 720 | +9% |
| 2 | 20 | 2,470 | +19% |
| 3 | 30 | 5,220 | +29% |
| 4 | 40 | 8,970 | +39% |
| 5 | 50 | 13,720 | +49% |

Gameplay and audit now call the same pure cost function. The numerical curve is unchanged. Star ascension still needs identical duplicates; combat skill levels are separate.

The old audit accidentally used the former cost curve and put the event-exclusive Compass in its normal collection simulation. Both are corrected. With seed 13102026, 1,000 modelled campaigns, default offline rates, full normal collection, a fixed Glaive target and fresh pity: mean first copy 41.904 pulls; mean five copies 208.539; median 209; p95 282; largest observed 397. The model's hard upper bound is 495. These are simulation results, not live banner guarantees, calendar-day acquisition estimates or paid checkout measurements.

The old economy fixture expected retired refinement fragments. Production already converts those intervals to Spirit Stone. At tier26, base hourly stones are198 plus20 from the retired-fragment conversion, giving218 per full hour; a capped12h claim with the tested remainder gives2,616 stones and720 Hero EXP, with no fragment item. Optional doubling gives5,232 stones. The fixture now checks this existing policy and exact atomic debits/restart behavior. Bulk economy testing suppresses unrelated semantic SFX in Dummy audio; it does not claim audio QA.

Build roles are distinct in the production catalogs: bleed/poison pressure, high-HP burn, armor/precision, slow, low-HP finisher, and hit-free shield recovery. The guide discloses non-stacking, boss reductions and activation conditions. No blanket HP/damage changes were made. Existing combat-hit evidence is reused; this batch does not claim new moving-target run-DPS measurements or a player-derived tier list.

Endgame is finite:26 implemented stages; three permanent cultivation paths capped at10; two mastery choices per path; a Golden Core trial using stage1-5 with at most3 HP hits; one realm advancement. After completion, daily tasks, available events and collection/build exploration provide repeat reasons. The new guidance makes these visible but does not turn them into a new endless/weekly mode. A reusable weekly challenge remains the next content-design candidate after the parked event discussion resumes.

No player analytics were newly enabled. Retention, observed build preferences, real network latency, ad availability and real-purchase UX still need actual player/device evidence. Existing support and production payment protections remain.

## Delivery and recovery

One resumable Windows package: verify/backup/install > focused game/economy/audit QA > scoped commit/push. No Worker deploy, schema migration, native build, ad-unit change, price change, broadcast or event reschedule. Re-export the AAB using `backend\player_identity\export_production.cmd` from the release editor, then use the existing internal-test workflow.

Direct author Git push has no HTTPS write credentials. The Windows publisher prints the real commit link only after a successful push; no author-side new commit or deploy is claimed. See `PLAYER_DIRECTION_STATE_2026-10-21.json`, package validation logs and renders to resume without repeating completed work. Software-rendered phone-size fixtures are not Android phone playtests.
