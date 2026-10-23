# Jade Ascendant working agreement

- Make routine decisions autonomously. Work efficiently and carry authorized work through implementation and appropriate validation.
- Provide a real GitHub link for every published commit. Never fabricate a link for a local-only commit. If GitHub write access is unavailable, prepare a reviewable patch and publishing procedure and report the limitation before claiming publication.
- Before any polish, inspect the actual assets, scene composition, and runtime presentation; decide which of those needs work from evidence.
- Record meaningful mistakes and their preventive action in `docs/checkpoints/LESSONS.md` so the same issue does not repeat.
- Speak naturally as a development partner; offer useful game-development ideas without unnecessary chatter.
- Main/production and parked IAP remain untouched unless the user explicitly expands that scope. Player-profile server work uses its own service/database.

## New weapon and equipment balance gate

User-approved rule, 2026-10-14: every new weapon or equipment item must pass a balance review before it is considered finished.

- Define its role and tradeoffs first. Evaluate single-target bosses, groups and practical range; rarity alone does not require winning every comparison. The item must have a useful, distinct role.
- Inspect authoritative runtime stats, inherited scene overrides and existing assets. Measure actual hits and damage with production attack code; projectile count, chain count, animation or VFX are not proof of damage. Separate per-cast damage, persistent-effect exposure and full-run DPS.
- Check early and late progression, level/star milestones, effective cooldown floors and the benefit of Attack Speed/Power upgrades. Avoid upgrades that promise a benefit the item cannot receive. Keep performance bounds and readable cast timing while balancing their impact on growth.
- Verify that hitboxes, range, endpoint, release timing, returning/spinning phases and VFX describe the same attack. Check stationary and moving targets where movement can change the result.
- Review incoming-damage pressure, simultaneous hit events, shields, armor, healing and boss counterplay when the item affects them. Do not assume independent enemy cooldowns prevent burst damage on the player.
- Check set passives, DoT, critical hits and resonance interactions: weak first hits must not silently undermine the intended role; stacking, refresh, recursion, caps and boss modifiers must be intentional and correctly disclosed.
- Evaluate acquisition and upgrade costs against existing items and player income. For gacha, include duplicate requirements, pity, a fixed-target default-rate simulation when relevant, and clearly scoped F2P cadence. Do not call modelled active days guaranteed calendar acquisition times or assume live-banner rates/ad availability.
- Preserve the agreed progression: four armor/accessory pieces per set; weapon independent; identical duplicates for star ascension; permanent weapon levels separate from stars with caps increasing by star. Check unlocks and progression/idle caps when adding content.
- Scale validation to the change: test the new item's mechanics plus representative affected existing items, reuse unchanged audit results, and broaden only for new changes or unresolved failures. Preserve saves, mobile performance, theme consistency and parked monetization gates. Label fixture measurements, design targets and phone playtest results separately.
- Completion requires reviewable evidence, a clear balance assessment and any remaining limitations. Resolve material implementation defects; do not hide them with blanket HP/damage buffs or nerfs. Record meaningful mistakes and prevention in LESSONS.md.
- New attacks must register their run-report damage source and acquired-skill identity, including delayed projectiles, area hits, returns, resonance and DoT. Count applied HP loss, preserve the final killing hit and verify checkpoint/Continue totals; utility skills appear in the taken-skill list without invented damage.

## Shared mobile scroll rule

User-approved consistency rule, 2026-10-20: every new/reworked menu and popup must use `scripts/ui/mobile_scroll_policy.gd` through the existing global touch guard. Do not implement a separate gesture router, alter every button's eligibility during a swipe, or hide a scrollbar by disabling its axis. Keep artwork/layout out of the input chain, preserve deliberate editor/slider/custom controls and nested viewport boundaries, and let native scrolling cancel release-mode button presses. Verify a first swipe starting on a real card/button with native GUI input, absence of accidental navigation or claims, and narrow-phone layout; setting scroll values directly is insufficient. Inspect texture alpha and actual compact-button/header renders before declaring black matte or clipping fixed.

## Player flow continuity — 2026-10-21

Latest user-confirmed IAP status supersedes historical parking notes: real non-tester payments work. Preserve all existing live payment protections and configuration. Resume the current batch from docs/checkpoints/PLAYER_FLOW_BATCH_2026-10-21.md and docs/checkpoints/PLAYER_FLOW_BATCH_STATE_2026-10-21.json evidence before doing work again. Do not repeat passed unchanged work. Stage names installed/committed/pushed/deployed/exported/device-tested are separate facts. All stage-clear event entry points use the shared popup, numeric markers keep natural width, touch tooltips do not persist, and event visibility follows actual completion/time with earned-claim grace. Never reuse one ad nonce across devices or show an ad merely because a background prewarm completed.

## Player direction continuity — 2026-10-21

Resume the current guidance/receipts/build batch from docs/checkpoints/PLAYER_DIRECTION_STATE_2026-10-21.json and PLAYER_DIRECTION_AUDIT_2026-10-21.md. Home guidance is read-only until tapped; recovery/Continue precede new progression. Receipt history is a bounded account-isolated display cache of actual grants, never a balance/restore authority. Preserve valid repeat grants sharing a source ID. Share audit and production cost rules, disclose set/weapon separation, and reuse evidence for unchanged combat. The proposed new event/weekly challenge stays parked until its design scope is resumed.

## Personal stage records — 2026-10-21

Continue from docs/checkpoints/STAGE_RECORDS_STATE_2026-10-21.json. Personal clear/time/HP medals are optional Journey statistics, not reward, leaderboard or purchase authority. Capture only after a committed victory and after the final hit returns. Continue must restore hit/death counters; a legacy checkpoint without them is explicitly incomplete and cannot award no-hit/no-death medals. Preserve old Journey progress if optional records are absent/corrupt. Use the shared touch-scroll policy and existing record artwork. New weekly/event modes remain parked; existing-stage replay is the current scope.

## Heavenly Trials continuity — 2026-10-21

Resume from HEAVENLY_TRIALS_STATE_2026-10-21.json and the approved design before editing. Weekly sessions, frozen rules, pending commands, ad intents and local Continue files are account isolated and independent of Journey. Client combat reports are bounded plausibility evidence, not a server simulation or cryptographic proof of combat. Personal records never grant currency. Dedicated Trials ads double Stones only after signed SSV; callbacks alone never grant. Trial support purchases keep Jade and bonus Seals in the existing paid ledger and use Pavilion's existing reveal and refund protections. Preserve all nine live production gates. Check compiled native method, build provenance and AAB feature metadata before declaring a new export current. Deployment does not activate the rotation or send notifications. Save durable checkpoints after each meaningful stage so a runtime reset cannot erase the latest corrections.

## LiveOps operations continuity — 2026-10-22

Use LIVEOPS_CONTROL_STATE_2026-10-22.json before resuming. Operational GETs are read-only, account-free summaries; admin refresh never replaces an unsaved draft or grants goods. One new weekly campaign occupies one reset slot; preserve frozen existing sessions and pausable historical campaigns. Validate ads/Play readiness without claiming external delivery/publication from local configuration alone. Preserve dashboard-managed Worker vars with --keep-vars on live deployments. Backend-only batches reuse the current client/native/AAB and keep separate resumable index/IAP/profile deployment receipts.

## Durable checkpoints — standing rule, 2026-10-22

User instruction: always save checkpoints against connection loss or usage limits. At each meaningful completed stage, before long or expensive steps, and before delivery, update the active batch state with the base commit, changed scope, validation evidence, separately confirmed installation/commit/push/deploy/export/device-test status, remaining work and exact next action. Keep a current-work pointer in docs/checkpoints/CURRENT_WORK.json. Save a durable recovery snapshot when the author workspace can expire; an unsaved scratch file is not a durable checkpoint. Resume by reading that pointer/state and inspecting the actual Git diff and stage receipts. Reuse passing evidence for unchanged inputs; never rerun an entire batch merely because chat resumed. Mark an interrupted/in-progress step explicitly and rerun only what its actual evidence requires. Local fixtures and simulations never establish a Windows, remote-deployment or phone-test PASS.

## Player Journey reliability — 2026-10-22

Resume from PLAYER_JOURNEY_STATE_2026-10-22.json and the actual diff before repeating work. Admin-issued event equipment must be usable through acknowledged server grant evidence, independent of event milestones; event outbox, paid refund and account guards remain authoritative. Run-gate reasons stay distinct from account mismatch. Masked local email suffix hints are display metadata only; raw email is not stored in saves/support/backup and unknown legacy owners are never guessed. Preserve the old checkpoint until new-run verification succeeds. Use existing assets and shared mobile scroll behavior for Realm/dialog changes. The fourteen-area project assessment is tracked in PLAYER_JOURNEY_AUDIT_2026-10-22.md; source review and models are not phone/retention/performance proof.

## Combat clarity and cadence — 2026-10-22

Resume from COMBAT_CLARITY_STATE_2026-10-22.json before repeating work. Optional encounter cadence preserves authored elite slots, remaining spawn time and unfinished elite health without replaying kill/grant signals; old checkpoints remain valid. A cadence snapshot is not a full world/boss/projectile snapshot. Stats and upgrade previews must use production cooldown floors, TEMPO caps and conditional damage rules; read-only display must not commit frozen mastery choices or roll RNG. Keep authored prices/HP/damage until runtime or player evidence justifies a change. Reuse the existing xianxia frame and native touch scroll policy; validate compact renders and first swipes. This client-only batch does not rebuild native or deploy Workers.

## Player release audit — 2026-10-22

Resume from PLAYER_RELEASE_AUDIT_STATE_2026-10-22.json. Restore run-report counters only after checkpoint HP emits, and resynchronize the ledger health baseline; loading a wounded save is not a combat hit. Incoming HP loss is optional report metadata and legacy history stays explicitly unknown. Defeat review is read-only and never freezes the ledger while revive remains possible. Every defeat exit must serialize with pending revive and existing atomic recovery grants. Inspect actual compact renders: extra fixed actions must not crowd the reader. An accelerated input pilot uses actual combat but is neither human play nor Android frame-time proof. Reuse unchanged passing evidence and combine known delivered intermediate source safely in one portable package. Preserve all nine current live production gates and the established production exporter.

## QA17 release continuity — 2026-10-23

Resume RELEASE_QA17_STATE_2026-10-23.json on actual checkpoint14f64e4 or its verified QA17 child. The nine companion features already landed in71f6753; never reapply the older feature checkpoint. Test Cloud Backup only after opening recovery tools; retain the contextual primary Home action and legacy checkpoint defaults. Practice must supply real PlayerHealth without advancing quests, mastery or paid-run state. Stop queued Hero work after detach and keep narrow wallet display separate from actual balances. Optional metrics remain held by METRICS_ROLLOUT_APPROVED=false pending the existing disclosure/staging rollout; preserve all nine live IAP gates. Owner installation, commit/push, exact-SHA CI, export, Android and Play review are separate receipts. Reuse unchanged passed suites; use the portable owner publisher when author push authentication is unavailable.

## Retention and dashboard continuity — 2026-10-23

User asks for concise progress/final text: outcome, unresolved issue, next action. Resume RETENTION_DASHBOARD_STATE_2026-10-23.json against actual1575180 or its verified batch child; do not reapply QA17. Distinguish source/fixture health from real-player retention. Home must keep recovery/Continue first, expose earned claims, recommend only affordable cultivation, and consume collection-reader navigation once. All admin datetime-local values mean WIB; use admin_time.mjs, never browser-local parsing or a second offset. UTC aggregate days stay labelled UTC. Cache only the public content-versioned stylesheet; admin pages/APIs remain no-store/authenticated with their nonce/CSRF protections. Unopened tabs do not fetch history/drafts, repeated navigation coalesces reads and never replaces an unfinished banner. Profile-only deployment uses --keep-vars, exact checkpoint commit and existing profile config; no migration, IAP Worker deploy, event activation or notification send. A denied local browser preview is not visual validation. Reuse passed unaffected suites and preserve concrete stage receipts/checkpoints.
