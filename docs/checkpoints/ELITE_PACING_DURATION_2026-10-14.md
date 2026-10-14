# Elite pacing and boss duration — 2026-10-14

Base: b0f4dff74dc7e8ade3beccdec2fc340ae632a58e (apply Combat Fairness and Economy Progression first).

## Shipped pacing changes

26 stage profiles retain their existing scheduled elite count and ordered type1/type2 identities. Slots are normalized: two elites4/8, three3/6/8, four2/4/6/8. 17 schedules change; every non-elite profile field is unchanged. No consecutive elite waves, no authored elite wave9. Last elite now has waves8 and9 before boss10.

Production EnemySpawner permits one live scheduled elite per arena. An occupied slot waits within its own wave and retries after the previous elite dies; dead/queued actors do not block. Once its wave ends, the missed slot is skipped, never carried into later waves. This intentionally prevents elite stacking for slow-killing builds: scheduled count is preserved, actual spawn/kill/EXP opportunities may be fewer if a previous elite survives an entire later slot. No free XP, magnet or missed-kill reward is fabricated. Normal spawning and wave timer keep running. Boss10 still clears remaining normal enemies/elites and hostile attacks, then spawns immediately. No new saved queue/schema.

Qi Magnet still uses the production schedule policy (first elite wave>=4, plus wave8), maximum two drops on actual combat kills. Thus two-slot stages use4/8, three-slot stages6/8, four-slot stages4/8. A missed milestone does not create a free magnet. Existing consumed milestone and pending pickup checkpoints remain compatible, including old wave5/9 ledgers. Restore retains historical integer wave4–9 IDs rather than filtering by the new schedule; a shared two-award cap prevents receiving extra new-schedule drops. A changed schedule does not replace already dropped/pending items.

## Boss benchmark

Actual stage boss scenes for4-1/4-5/5-1/5-5, live AI, movement, phase ward, hitboxes, real weapon manager/projectiles/DoT and crit. Godot4.7.2 headless60Hz, isolated profile, seed14102026, maximum300 simulated seconds. First pilot circles at160px with speed capped by actual player movement. Second pilot retreats toward310px for3s every10s. Damage to player is suppressed using test-only revive protection. Preboss hazards are disabled; no new skill/EXP choices during boss. No mastery or synergy selections. This measures conditional offensive time to kill, not survival or actual phone/full-run time. One seed per scenario, no percentile or population claim.

Defined acquisition-constrained scenarios (not proven to be earned in every run):

- Entry Sword: Moon Seal four-piece Epic armor at1star; Nine Heavens Star Sword1star/permanentLv10; permanent SwordPower6/SwiftQi6; starter+Fire Orb+Thunder Talisman+Heavenly Sword Rain each runLv4; Power4/AttackSpeed3/SwordIntent2.24 run choices total, including acquisitions/upgrades.
- Focused Chain/Glaive: Nine Heavens four-piece Legendary armor at2stars; respective independent armament2stars/permanentLv20; permanent SwordPower10/SwiftQi10; all6 run weapons eachLv5; Power4/AttackSpeed4/SwordIntent3.40 choices total. Expensive equipment/copy availability is assumed explicitly; no guaranteed F2P availability claim.

| Boss | Entry Sword, orbit | Focused Chain, orbit | Focused Glaive, orbit |
|---|---:|---:|---:|
|4-1 / HP22400|46.0s|20.3s|19.6s|
|4-5 / HP36500|73.3s|29.7s|28.2s|
|5-1 / HP39100|78.7s|32.6s|31.7s|
|5-5 / HP55800|109.2s|44.1s|42.3s|

5-5 with retreat pilot: Entry Sword147.4s (71.7% in range), Chain58.7s (73.0%), Glaive55.6s (71.2%). Every sampled boss dies and crosses its real phase gate. Full boss5-5 survival is not established by this probe because incoming damage is suppressed.

The fixed preboss timer is297s for5-5. Conditional combat sum is about7m24s for weaker Entry Sword versus5m56s/5m53s for the focused builds with the retreat pilot; skill-choice pauses/menu/wall time excluded. Earlier stage timings are in the raw rows. These are calculated timer+measured boss sums, not simulated entire stage clears.

Decision: keep current wave timers and bossHP. A suitable focused late build falls within the proposed45–90s final-boss target after interrupted attack uptime, while the lower-investment build takes longer. This sample does not justify blanket HP inflation to slow good builds, or cutting normal waves (which would cut XP/build opportunities). Elite spacing is the demonstrated scheduling defect fixed here. Intermediate boss encounters and human survival/playtime remain outside this sample.

## Validation and delivery

319 checks: pacing147, existing magnet110, orbit49, retreat13. Zero final failures/script errors. Forward/reverse patch application and exact file bytes verified against the base. Existing engine shutdown resource/ObjectDB cleanup warnings remain; no measured phoneFPS claim. Windows publisher source reviewed, not executed here. No assets, wave-duration/difficulty/enemy-cap values, bossHP/damage, gacha, economy, account/server, saves or parkedIAP changed.

Apply the patch then reopen Godot/import/re-export Android. No backend deployment. Publish using backend\player_identity\publish_elite_pacing.cmd. It scopes this package plus the preceding Combat Fairness/Economy packages, protects main, forbids force push and verifies remote SHA before printing the real GitHub URL. Local-only commit is not reported as published.

Lesson recorded locally in LESSONS.md: conditional untyped array literals cannot be assigned directly to Array[String] in Godot; use an untyped local list with typed iteration or assign_array. Scan SCRIPT ERROR alongside PASS and terminate a failed probe before retry. Shared LESSONS/BACKLOG files are excluded from the transported patch to avoid prior user-side context conflicts.

Compatibility lesson: rescheduling content can invalidate saved wave-index ledgers. Keep original saved awards/pending pickups, validate historical IDs and cap aggregate awards; test old completed/partial ledgers and malformed IDs.
