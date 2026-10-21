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
