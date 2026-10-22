# Combat clarity and progression audit — 22 October 2026

Base: `a2f0b9410f1af3b7478d5f76fe626d664ac88ad6`. Previous Player Journey batch was confirmed safe by the owner; that real remote commit was fetched before this isolated continuation.

## Changes completed

- Continue now retains consumed elite slots, the remaining normal spawn timer and the unfinished elite’s health ratio/relative position. Its original slot and Realm IV/V lightning adapter are retained. Restore emits no kill/reward events. Missing or invalid optional metadata cannot invalidate a valid legacy player checkpoint. Existing Qi Magnet awards remain the independent two-token ledger. This is not a full crowd/projectile/boss-world snapshot.
- Combat Stats now shares conditional damage rules with the hit calculation, including high-HP mastery. Read-only previews do not freeze mastery choices. Each active weapon reports its actual cast interval and any supported TEMPO multiplier. Damage values are pre-crit factors; orbit/formation hit intervals are separate.
- Power shows its real additive multiplier, Insight its actual next EXP factor, and Attack Speed the actual next primary cast interval or TEMPO gain. Those previews never alter weapon timers or roll RNG. Selection eligibility/owned-skill weighting and combat stats are unchanged.
- The stats panel reuses the approved emerald/gold record frame and navy button. Responsive bounds, shared native scrolling, fixed close/back and a concise legend replace its old fixed-size layout and stale generic cooldown footnote.
- A fast boss death exposed deferred HUD callbacks carrying a freed Node. Boss/phase/layout callbacks now pass instance IDs and resolve/validate at execution time. The actual instant-death mastery fixture reproduces the former error and passes after the fix. No boss HP/pattern change.

## Authored pacing and reward model

The exporter reads all26 authored scenes, their actual final-wave property and stage profile, and the production RewardManager. Pre-boss durations exclude the boss, skill selection, menus and network waits. Stone rates are mathematical upper bounds from the survival duration, not measured play income, TTK or Android performance. Retired fragments are converted by the actual shared reward path.

| Stage | Time before boss | Repeat Stones | Repeat Hero EXP |
|---|---:|---:|---:|
| 1-1 | 2:06 | 120 | 40 |
| 1-2 | 2:42 | 120 | 50 |
| 1-3 | 3:00 | 150 | 60 |
| 1-4 | 3:18 | 160 | 70 |
| 1-5 | 3:54 | 210 | 100 |
| 1-6 | 4:12 | 260 | 130 |
| 2-1 | 2:42 | 215 | 90 |
| 2-2 | 3:00 | 260 | 110 |
| 2-3 | 3:18 | 285 | 130 |
| 2-4 | 3:36 | 355 | 150 |
| 2-5 | 4:12 | 450 | 200 |
| 3-1 | 3:36 | 480 | 160 |
| 3-2 | 3:45 | 550 | 190 |
| 3-3 | 3:54 | 620 | 220 |
| 3-4 | 4:03 | 740 | 260 |
| 3-5 | 4:30 | 910 | 350 |
| 4-1 | 3:54 | 1,125 | 420 |
| 4-2 | 4:03 | 1,260 | 475 |
| 4-3 | 4:12 | 1,395 | 530 |
| 4-4 | 4:30 | 1,530 | 585 |
| 4-5 | 4:39 | 1,665 | 640 |
| 5-1 | 4:12 | 1,775 | 750 |
| 5-2 | 4:21 | 1,950 | 835 |
| 5-3 | 4:30 | 2,125 | 920 |
| 5-4 | 4:48 | 2,300 | 1,005 |
| 5-5 | 4:57 | 2,475 | 1,090 |

Fresh daily rotations sampled on28 specified dates (1–28 November2026) contain six quests,300–340 Stones, require2–4 stage clears, and have a highest run-level target of7–12. This is a deterministic policy sample; an existing legacy expanded daily list can differ. Daily progress targets overlap, so kills/levels are not summed as extra runs.

Seven fully claimed active daily sets plus seven login claims model400 earned Jade (140 daily completion +160 active-cycle bonus +100 login) and5 Seals (4 active-cycle +1 login). Excludes ads, events, achievements, first clears, gifts and paid purchases. It does not promise these rewards within seven calendar days.

| Permanent weapon stars | Level cap | Stones from Lv.1 to cap |
|---|---:|---:|
| 1 | 10 | 720 |
| 2 | 20 | 2,470 |
| 3 | 30 | 5,220 |
| 4 | 40 | 8,970 |
| 5 | 50 | 13,720 |

## Assessment and remaining evidence

- Late-stage rewards scale upward; a first-map-only farming claim would be false. The longer pre-boss segment is authored126–297seconds; actual boss time/build survival remains material to farming efficiency.
- Daily premium access currently waits for every selected daily claim. Requiring up to four clears may be too much for short sessions. Before changing that established policy, compare completion rates and session length from actual testers. A core-task/optional-bonus split is the next design candidate; no new tracking or price change is enabled here.
- Existing mastery, personal records, build advice and Heavenly Trials already provide repeat targets; they are retained. This batch does not add a second duplicate endgame or announce an event.
- Existing runtime fairness/cadence, exact atomic economy debits and paid separate-process Continue are validated again where affected. Live paid IAP already passed owner testing in the preceding history; it is not claimed as a new purchase test here.
- Real Windows launcher execution, the new Play-installed AAB, phone thermal/frame-time behavior, observed boss duration, real daily completion and retention remain external evidence. Local models and software renders do not replace those.

## Delivery

Client-only delta: scoped install/QA/push, then the existing production AAB exporter. No Worker deploy/schema/secret, native rebuild, Play product/ad-unit change, balance/reward grant, event activation or broadcast. Checkpoints record author and owner stages separately.
