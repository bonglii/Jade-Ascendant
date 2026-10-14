# Quiet result sheets and run combat report — 2026-10-14

Base: bebf04ca5c5f4fdb47c4268769ab3f346ae3bc88 (Elite Pacing). Apply prior Combat Fairness, Economy Progression and Elite Pacing packages first.

Inspected the user's720x1600 victory screenshot and real frame/parchment assets. The large gold/qi frame dominated the content. Replaced result, mail-paper and dashboard-announcement popup frames with lightweight repo-native SVG sheets and subtle gradient buttons. Reuse existing reward/skill icons and game backdrops; no generated raster replacement required. Victory omits the redundant hero illustration, eyebrow, hint and wallet balance; primary action stays pinned, long content scrolls. Defeat shares the calmer frame/buttons through the existing controller. Reward amounts/authority, victory/defeat behavior, ad offer gates and language routes remain intact.

Mailbox removes the ornate overlay, gives more room to content, uses a light parchment sheet, and keeps claim/delete within the page. Short landscape readers reduce decorative vertical gaps and suppress the redundant scroll hint; actions remain accessible. Subject/sender/body/attachments retain their full source text with vertical scrolling, plain-text server mail and unchanged claim authority. The announcement popup from the dashboard also uses the quiet sheet and bounded reading region; backend unchanged.

## Damage and skills

Victory adds DAMAGE and SKILLS tabs. Damage rows sort by total and show acquired weapons even when their damage is zero. Totals are actual enemy HP lost, including real crit, splash, piercing, chains, return phases and resonance. Overkill is capped, dead targets and phase-ward rejection credit zero, phase-threshold hits credit only the accepted portion. Final killing hit is recorded before deferred victory capture freezes the ledger. Numeric totals/level columns reserve space and never wrap into one-character vertical strips. Display numbers are rounded; stored totals retain floating precision.

Twelve bounded source buckets: Spirit Sword/starter sword equipment, Chain, Glaive, Fire Orb, Thunder Talisman, Yin-Yang Blades, Sword Rain, Eight Trigrams, Heavenly Tribulation, and set bleed/poison/burn. Heavenly Tribulation synergy and set effects have their own rows instead of falsely attributing them to a weapon. No hit-event history, extra combat timers, damage calculation changes or reward grants.

SKILLS lists actual acquired run weapons, final run levels, Power/Attack Speed/Sword Intent, movement/insight/health/shield/armor/healing skills and unlocked resonance. Untaken skills are excluded. Permanent equipment levels and cultivation bonuses are not reported as run choices. New weapon rules now explicitly require damage-source and skill-report registration alongside the existing balance gate.

Run totals persist as an optional versioned checkpoint field; Continue restores the latest durable ledger (including normal stage/background autosaves). Old checkpoints or an invalid optional report remain playable, start fresh tracking and disclose partial totals. Previous untracked damage cannot be reconstructed. New run instances start empty. Completed runs freeze totals; no cross-run leakage. No player save deletion/schema-version bump.

## Evidence

Godot4.7.2 Linux headless, isolated profiles: run report172 + restart4 + mailbox expanded gifts673 + result/announcement74 + combat skills261 + Chain59 + Glaive66 + HERO125 + HERO restart6 =1440 checks. Zero final assertion failures or script errors. Additional native X11 renders were inspected for victory damage, skills and long server mail; their repeated checks are not added to the1440 count. SVG import completed. Existing shutdown ObjectDB/resource cleanup warnings remain; Windows launchers source reviewed and actual Android screenshot confirmation not claimed.

Run-report tests exercise all eight real caster attacks and compare source totals with actual target HP loss, then cover overkill/ward/phase threshold/final boss hit, every bucket, utility/untaken skills, malformed optional stats, old checkpoints, real save/Continue/restart, four viewport sizes and inner numeric-label geometry. Mailbox checks include English/Indonesian, portrait/landscape/tablet, maximum plain-text body/long tokens/title/sender, jade/seals/equipment attachments, scroll endpoints and refresh position.

Native previews are QA fixtures: displayed rewards are presentation-only200stones/2shards/55EXP, with no wallet grant. The damage preview uses a real17HP final-hit fixture and zeros for other acquired weapons; it is not a full-run damage measurement. Skill fixture levels are test state. Main game previews retain existing background artwork.

## Lessons

Recorded locally in LESSONS.md: parent bounds do not prove inner text legibility; reserve non-wrapping numeric widths and inspect native images. Capture victory after take_damage returns to include the boss killing hit. Use the real paused result flow in native fixtures, assign/append typed arrays and avoid unresolved autoload globals in preloaded test scripts. Compare restart with latest durable checkpoint because live stage autosaves may advance during a probe. Shared LESSONS/BACKLOG transport is excluded to avoid previous context conflicts.

## Apply/publish

Apply Jade-Ascendant-Quiet-Results-Report.patch from the Windows project, reopen Godot/import, then export Android. No backend deploy. Publish with backend\player_identity\publish_quiet_results.cmd. The scoped publisher allows the preceding three packages and this one, checks authorized checkpoint/origin/ancestry, stages only approved files, forbids force push and verifies remote SHA before printing GITHUB_COMMIT_URL. Direct GitHub authentication remains unavailable in this session; a local commit is not claimed as published. Main, Google latency and parkedIAP remain untouched. New skill/equipment/weapon/event proposals remain for later discussion.
