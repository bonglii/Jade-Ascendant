# Player Comfort: scope, findings and release list

## Implemented in this batch

| Finding | Result |
|---|---|
| Permanent Hero levels emitted without a UI subscriber | One compact celebration; multi-level grants coalesce. Actual save loads stay silent, no extra rewards are created. It waits behind Pause/loading, can appear on the paused Victory result, and survives a menu handoff. |
| Gray engine clear between startup scenes | Explicit branded clear color and persistent boot artwork through the first incoming frame. |
| Home's special frame differs from four other menus | Shared ornamental frame default for all five menus; geometry and touch targets retained. |
| Continuous dragon body snaps to each newest heading | Following joints with bounded bends/head turn and subtle traveling sway. Mesh budget stays12/8joints, at most2dragons. Hit cadence, damage, range, ownership and targeting unchanged. |
| V3 impact layers and varied click cues are excessive | Restore V2 SFX / original arsenal cues, remove extra per-hit impact bus, one fixed quiet touch asset/pitch, quieter result/progression cues. |
| Deferred Home refresh after leaving the tree | New transition scenario found a stale refresh callback; both shared Home refresh entries stop after detach. |
| Dashboard appears old | Live unauthenticated DOM already contained new11-tool Studio sidebar. Add a visible Comfort24.10marker on login and shared nav; owner-side Profile-only deploy prints the version receipt. |

## Remaining polish / ideas, ordered

1. **Owner choice needed — BGM:** listen to the two options in PLAYER_COMFORT_AUDIO_CHOICES_2026-10-24.md. Keep at most one menu and one combat loop plus one shared click. Choose before the final AAB to avoid two exports.
2. **Release check — Android:** one pass over cold start, Hero-level reward, five navbar frames, speaker mix and moving dragon. Author native GUI evidence is not Android evidence. Reuse previously passed unrelated379checks.
3. **Operational clarity:** the dashboard revision marker is included now; verify Comfort24.10after the Profile deployment. Do not infer an old deployment only from similar login wording.
4. **Optional later — sound balance presets:** a single calibrated default mix is sufficient for release. Keep music/SFX/master controls; do not add more toggles or audio systems now.
5. **Optional later — level milestone affordance:** if real-player testing shows missed Hero milestone claims, add a contextual link from level feedback to the existing profile milestone reader. No new rewards, XP curve or economy changes are justified by this batch.

No new event, monetization system or broad content redesign is needed to fix these findings. Existing paid protections, saves, events and main are untouched.

## Evidence

Author native GUI60checks and isolated headless60checks passed; combat30checks and dashboard13unit checks passed. DOM interaction result is retained with the checkpoint. Strict editor import and9production guards passed. Normal owner-publisher/retry was simulated with local bare Git, not GitHub or Windows. Owner install, push, deployment, CI, AAB and phone testing remain separate receipts.
