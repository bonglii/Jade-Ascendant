# Heavenly Trials implementation

Base: 60fd56de78f455eaddd01b86b24676e9ff6b531b. Stage Records was already published and is not repeated.

Three free-entry tiers unlock after Journey 1-5, 2-5 and 3-5. Reset is Monday 04:00 WIB (Sunday 21:00 UTC). The five-theme rotation freezes each week's boss, rule and reward. Entries last at most fifteen minutes of wall time; combat is limited to five minutes. Journey progress/checkpoints are neither begun nor completed by Trials. Continue restores a separate account/session checkpoint and reuses existing paid-loadout verification.

Each tier's first weekly clear earns 40 free Jade, one free Pavilion Seal and 600 Stones. Total weekly base budget: 120 Jade, three Seals, 1,800 Stones. Optional signed ads add 600 Stones per tier, never Jade or Seals. Rewards use stable outbox IDs and the existing secure Mail receipt pipeline. Clear/Survivor/Untouched medals and best times add no currencies. A client-reported fight cannot prove combat authenticity; the service validates identity, session, timing and fixed weekly reward bounds, not every attack.

The dedicated Play product is `heavenly_trials_support_550`: 550 purchased Jade plus two bonus Seals. Only verified Play credits supply those Seals. Server-side Seal summons retain the existing paid pity/inventory, atomic command ledger and refund holds. Bonus Seals remain accessible from Pavilion even if the event is paused. The normal shop offers one purchase per week; every valid charged order is honored if checkout races or completes late. This is not a Play-enforced purchase limit.

No production gate, database ID, existing six product amounts/IDs, existing four ad units, weapon stats or equipment catalog hash changes. The additive schema is 0016_heavenly_trials.sql. Deployment creates no campaign and sends no push notification. The dashboard reuses existing authenticated admin sessions/CSRF and service bindings.

Required owner setup after installation: publish the dedicated Play SKU with a localized price; create a distinct Rewarded_Heavenly_Trials AdMob unit, amount 1, reward label TrialStones, SSV `/v1/heavenly-trials/ssv`; set IAP Worker vars TRIALS_AD_UNIT and TRIALS_AD_REWARD_ITEM. Keep ads/shop switches off until those are ready. Existing event ads and purchases continue working.

Author evidence is recorded separately from Windows full Android build, remote deployment, export and phone playtest. The installer must not label those later stages passed in advance.

## Author validation and limits

- Weekly backend13, profile/dashboard4, paid gameplay21, purchase/catalog22, unchanged event/mail/current-production regression122 checks have passing evidence.
- Real Godot suite validates separate save/load, account/action/ad recovery, actual boss phase restoration, final-hit ledger and Journey reward isolation; final counts are recorded in STATE.
- Existing hub337, shared scroll159 and player direction53 checks pass. New gestures use actual input dispatch, not just source scans.
- 25 pure Kotlin/JVM tests compiled and executed with actual contract classes. This is not an Android AAR/JNI build; the Windows launcher requires that full stage before publish and pins its receipt into export.
- Actual scenes rendered at320/390: hub, changed boss portrait, rewards, shop and boss arena. Localized shop price is a separate single-line label; its digits do not wrap through an ornate button border.
- Conditional offensive duration probe: seeded real boss AI/hitboxes with a scripted orbit pilot, test-only player invulnerability and a frozen build (rare Moon Seal four-piece, one-star level10 Nine Heavens sword, four run weapons at level3, run power4/attack speed2/crit1, permanent power/speed4/6/8 by tier). Tier1/2/3 stage5 bosses measured23.77/31.12/51.43 seconds; adding72-second warmup gives95.77/103.12/123.43 seconds. This does not prove survival, attainable choices during warmup, phone performance or every rotation's balance.
- One historical M1B2 disabled-era suite still fails the same five assertions on unchanged base60fd56d and this branch: it expects a disabled two-method bridge and obsolete file hashes. Baseline/comparison evidence is retained. Those checks were not weakened to turn an active production bridge into a disabled prototype.
- No production purchase, deploy, AAB export or phone playtest was performed here.

Implementation decisions: fixed reward budgets and preset boss rotation are intentional. Dashboard does not accept arbitrary reward amounts, client scripts or new bosses. First-clear deliveries use one stable mail per tier to reuse the proven receipt pipeline; retried claims do not send duplicates. Normal shop eligibility offers one weekly order; valid charged orders are always honored even if concurrent checkout exceeds that UI offer limit.
