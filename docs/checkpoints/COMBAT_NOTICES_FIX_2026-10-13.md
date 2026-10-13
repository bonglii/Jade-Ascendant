# Cultivation header and combat notices — 2026-10-13

## Changes
- Reserve horizontal space for DAO FOUNDATION; the narrow counter no longer takes all width. Numeric counts remain unwrapped.
- One safe-area layout helper centers pre-warning, arrival and phase notices under the actual TopHUD/BossPanel rectangles. No animation writes absolute panel coordinates or retains conflicting old offsets. Deferred layout settles wrapped text; resize uses the same geometry in both effects modes.
- Boss stage tag is in the warning's content flow, instead of a direct PanelContainer child that covered all copy. Main warning, stage identity and name are visible together.
- Reuse inspected approved stage_boss seal art, add native ceremonial corner strokes, stronger border/glow and preserve realm-themed colors. No new raster import dependency.
- Foundation warning stage identity falls back to actual Journey chapter/stage, including older scenes without realm properties. This is presentation only.
- On narrow screens the boss HP header puts its name on a full row instead of squeezing it between phase and HP labels.
- Achievement holds full opacity for five seconds in both effects modes, then fades. More readable text and responsive width. Pending achievements wait for active boss notices; active ones yield and pause their timer when a notice begins. Long toast copy is bounded with ellipsis (full details remain in Trials). Scene changes safely abort the presentation. Rewards/unlocks remain solely with AchievementManager.
- Fix the same premature-fade sequencing error in the phase banner: enter and secondary scale can be parallel; hold and exit must be separate steps.

## Validation
- Godot 4.7.2: 100 focused checks, zero failures. Four viewports (320x568, 390x844, 648x1152, 720x1600), normal/reduced effects, actual boss spawn, geometry, tag occlusion, queue and real elapsed opacity/finish checks for both modes.
- Existing premium tutorial/player/boss regression: 472 checks, zero failures.
- Native X11 previews inspected: Foundation header no vertical letters; pre-warning and arrival below HUD; achievement alpha=1 at reading time. No script errors. Existing resource-leak messages at test teardown are not a release/device validation pass.
- Android device test and re-export required in the complete Windows project. The restored QA project has a pre-existing TopHUD minimum-width overflow at forced 320 logical pixels; this patch fixes notice geometry and boss-name wrapping, not the full top-HUD redesign.

## Windows
Apply after Jade-Ascendant-Cultivation-Mastery.patch:

```bat
git apply --check "D:\Godot\tools\Jade-Ascendant-Combat-Notices-Fix.patch" && git apply "D:\Godot\tools\Jade-Ascendant-Combat-Notices-Fix.patch"
backend\player_identity\publish_combat_notices.cmd
```

Open Godot and re-export Android. No backend deployment. The publisher permits already-authorized pending prerequisite files, protects main/production, rejects unrelated staging/outbound changes, and verifies the remote SHA before printing the actual GitHub commit link. Session GitHub write access remains 403; no push is claimed here.
