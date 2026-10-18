# Jade Dragon Odyssey — delivery and balance review

## Scope
- 14-day, 20-tile celestial board with Lin Yue token and animated confirmed movement.
- Server-generated unbiased d6; client cannot submit a die result, cost, victory or ad success.
- Quiet Grove supplies; three timed Dragon Gate counters with visible stances and base reward on failure.
- 3 login dice + 3 mission dice per UTC day. Optional 2 verified ad dice/day.
- 1 die/25 Purchased Jade or 5/100; at most 10 bought/day, 40/season. The shop distinguishes verified Purchased Jade from locally earned Jade.
- Milestones 24: 2 Pavilion Seals; 48: 3 Seals + 500 Spirit Stones; 72: one guaranteed Heavenweaver Compass. Mail delivery is retried without duplicate attachments.
- Event schedule and reward values are immutable after publication. Pause/ad/purchase availability may be toggled. Three-day milestone claim grace; unused dice expire.
- A new season may start only after the previous claim grace. Previous Compass ownership is still recognized.

## Authority
Dice state and paid wallet changes share the IAP D1 transaction. Failure injection and concurrent purchase tests check rollback and single spending. Existing wallet enum calls a debit summon_debit; its item_key identifies Odyssey dice. No enum/table rewrite or change to ordinary summon pricing/catalog.

Google AdMob SSV verifies the original query bytes, trusted Google P-256 key, unit, amount, label, timestamp and server nonce. Local ad completion never grants a die. Google keys are fetched only from the pinned official source; account identity comes from the server intent rather than callback user_id.

Rewards use the established installation/receipt Mail claim flow. Old clients cannot see or claim the new weapon. Compass eligibility is verified online at start/Continue, with the current run's authority frozen; paid-origin ownership cannot authorize a new run on a refund-held account. Manual Mail gifting alone does not create a Compass milestone entitlement.

## Compass role and measured fixture damage
A delayed, dodgeable multi-target path weapon. No crowd control. Combat Lv.1/3/5/7 selects 2/3/4/5 targets. At Lv.5 it returns along the same locked path at 35% damage. Permanent weapon levels/stars keep existing 10/20/30/40/50 caps and identical-duplicate ascension.

Production cast code, stationary boss, no outside damage/critical/set bonuses:

| Combat level | Damage/cast | Cast cooldown | Fixture DPS |
|---|---:|---:|---:|
| 1 | 20 | 2.4s | 8.33 |
| 3 | 40 | 2.4s | 16.67 |
| 5 | 78.9 | 2.4s | 32.875 |
| 7 | 105.2 | 2.4s | 43.83 |

These are cast-fixture values, not full-run/phone DPS. The existing Chain's Lv.7 stationary primary is 40 DPS plus slow; ordinary two-sword Lv.7 attacks can reach 80 primary DPS if both land. Compass trades reliable single-target pressure for its distinct multi-target geometry. Attack speed is bounded at a 1.5s cast floor; excess tempo becomes potency under the existing capped policy. Weak critical marks do not consume the one-per-cast dragon resonance. A moving target that escapes the path takes only its mark.

At most 64 collision candidates, 12 dragon contacts per phase, 5 marks and a short bounded trail. Sweeps split at every path knot, including coarse frames crossing outward and return travel. Dragon face, collision position and path endpoints share the same coordinates.

## Acquisition model
No event-weapon gacha probability. One copy at exactly 72 completed journeys. Six free journeys/day reach it in 12 active event days; with two available verified ads/day, 9 active days. These require daily mission claims and actually available ads; missed days do not become guaranteed calendar acquisition. Eight 5-die packs cost 800 Purchased Jade for 40 bought dice; max purchased cadence plus all daily free/ad dice can reach 72 in four active days. Extra journeys do not award another Compass. Identical duplicates require another eligible season/entitlement, not fragments.

## Validation
Current source: 86 relevant Node backend/regression tests; 22 production-cast/inventory checks; 3 pure-JVM event protocol tests; all 309 production GDScripts load with all 41 engine-enabled warning categories treated as errors. Native portrait captures include the board, route choice, Jade shop and reward ceremony. PowerShell parser/scope checks passed.

Windows Android AAR build, full JNI inspection, live SSV delivery and Play-device smoke are external remaining gates. The batch launcher invokes the established Android builder and refuses to publish a candidate without its source/JVM/JNI proof. The local pure-JVM tests are not a claim that the full Android AAR was built here. No live ads, purchase or Cloudflare deployment was performed here. GitHub write credentials are unavailable in the container; the PC publisher prints the actual resulting commit link.
