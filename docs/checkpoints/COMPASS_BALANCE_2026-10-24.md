# Compass pursuit — scoped balance review

Base:802ff424. Ten seconds per case, actual production attack code, PlayerStats and HP-applied RunCombatLedger; isolated high-HP targets, not Android/full-run DPS. Legacy files read from the exact base and run only in the author fixture. No live purchase, reward or account writes.

Role: reliable nearest-threat pursuit; less early crowd coverage than the old multi-mark path. Lv7 separates two targets, while a single boss shares one budget. Prices/acquisition/star duplicates/permanent upgrade costs are unchanged. Other armaments and their cadence floors are unchanged; reuse prior accepted balance evidence for them.

|Combat Lv|Speed factor|Target|Legacy DPS|Pursuit DPS|
|---|---|---|---:|---:|
|1|1.0|boss|8.2|8.25|
|1|1.0|moving|1.0|8.25|
|1|1.0|crowd|12.8|8.25|
|1|0.2|boss|43.75|35.625|
|1|0.2|moving|4.375|35.625|
|1|0.2|crowd|67.813|35.625|
|3|1.0|boss|16.4|16.5|
|3|1.0|moving|2.0|16.5|
|3|1.0|crowd|34.8|16.5|
|3|0.2|boss|87.5|71.25|
|3|0.2|moving|8.75|71.25|
|3|0.2|crowd|178.125|71.25|
|5|1.0|boss|32.16|30.938|
|5|1.0|moving|3.0|30.938|
|5|1.0|crowd|84.9|30.938|
|5|0.2|boss|172.594|133.594|
|5|0.2|moving|13.125|133.594|
|5|0.2|crowd|419.531|133.594|
|7|1.0|boss|42.88|41.25|
|7|1.0|moving|4.0|41.25|
|7|1.0|crowd|113.2|68.063|
|7|0.2|boss|230.125|178.125|
|7|0.2|moving|17.5|177.188|
|7|0.2|crowd|559.375|293.297|

At speed factor1, stationary single-target DPS stays about+0.6% to-3.8% of legacy in this finite10s fixture. Moving-target exposure improves greatly because the old path mostly missed. Fast factor0.2 loses roughly19–23% against a stationary boss in this finite window; the new cadence is limited to4 strikes/s, retains tempo potency and trades raw stationary burst for pursuit reliability. Early crowd DPS is deliberately lower; Lv7 gains65% additional budget only when a different second threat is present. Neither dragon damages enemies beyond320px (boss230px) from the player.

Strike coefficient0.375 × base damage (10,+5/combat level), normal interval0.45s/floor0.25s; requested cooldown retains the production0.1s lower clamp. Excess speed becomes potency through the existing manager, capped5. One outstanding strike per dragon, no accumulated backlog. Lv5 afterimage25% after0.12s; maximum2 queued echoes. One critical resonance bonus40% of that strike per interval; echoes cannot resonate. Simultaneous boss hits split50/50.

189 focused assertions:24 new cases with exact ledger/Continue/skill rows/bounded actors; critical and bounded resonance; permanent level50 multiplier1.49 and star-dependent caps10–50; Reduced Effects unchanged damage; pause; nearest/dead/range retargeting; authorization/weapon cleanup; HP-capped final kill;430px/48-segment arena clamps and alpha/fade. Original source/UI suites91+159+238 and30 schedule/WIB cases are reused for unchanged inputs.

Visual audit: generated straight dragon is a curved mesh body plus rigid clipped head, preventing head triangles; maximum2 couriers,12 body joints/30Hz mesh updates, or8 joints/20Hz in Reduced Effects. Movement/damage remain physics/cadence based in both modes. Impact buffer max8, echo buffer max2. Arena floor is one texture, two thin boundary passes and8 small lamp cores. Renderer proof is X11/Mesa, not phone frame-time evidence.

Assessment: useful distinct event weapon; no blanket enemy HP, weapon price or economy buffs. Owner export/phone playtest and current exact-SHA CI remain separate stages.
