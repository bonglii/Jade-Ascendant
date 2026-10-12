# Pavilion sanctum redesign — 2026-10-13

User approved the interactive ritual direction after reviewing two static art concepts and a motion prototype. Scope: client presentation only, checkpoint branch; production/main and parked IAP untouched.

## Result

- Production Pavilion scene now uses `pavilion_sanctum_screen.gd`, extending the current fast-first-frame screen. The old implementation remains available as the parent; parked Forge/Aura remain parked.
- Inspected authored palace, altar, final equipment textures, legendary dragon, scene hierarchy and actual native baseline before composing. Original PNG files are unchanged. Preserve aspect ratios with native cover/crop; feather translucent dragon boundaries during rendering.
- Interactive five-relic Wish selector updates the focal relic with a short qi transition. Featured preview and active Rate-Up are labelled separately. Actual manager availability, Wish Fate and pity remain authoritative.
- Less dominant guarantee panel and readable summon costs from the existing economy. Native CTAs wrap on narrow screens; no negative component spacing or giant hidden image-backed hitboxes.
- Four distinct native ritual events: opening seal, Rare meridians, Epic seven-star formation, Legendary split gate and awakening dragon. Short durations 0.9/1.4/2.0/2.8 seconds. Skip is always available; reduced effects lands immediately without flash. Idle stage pauses while the reveal is open; rendering capped at 30 redraws/sec.
- Ten committed results open as a seal formation, individually revealed or revealed all. Each tile uses the actual equipment icon, name, rarity and actual duplicate-shard result. Narrow views use two columns, wider views three; the list scrolls while Continue stays pinned.
- Back/Continue close only the presentation. No grants, currency writes, rerolls or save APIs in the stage/result opening. Starting another summon during an open reveal is rejected before calling the manager.
- Watch Ad / Free 1× CTA calls the existing rewarded bridge. Verified completion grants one Seal through the existing path; user uses that Seal for one summon. Provider unavailability, cooldown and claim limits remain truthful. No fake ad completion or automatic summon in this client patch. Full ad integration remains the later planned phase.
- Indonesian strings added. Existing rates, session history, meditation, shared safe resource bar and navigation remain available.

## Validation

- Native Godot 4.7.2: 429 checks, zero failures; English/Indonesian, 320×568, 390×844, 540×960, 648×1152, 896×504; four rarities, actual duplicate amounts, viewport bounds, skip/all/back, reduced effects, natural sequence completion, actual ten-pull commit, double-tap guard, no grant on reveal.
- Fresh isolated QA installation: actual summon consumes ten Seals and commits ten pulls; restart checks retain those counters. No user/production save used.
- Existing identity/mail Node suite: 40 tests, zero failures (publisher changes only add reviewed client paths).
- Native OpenGL compatibility captures and recorded motion preview inspected; authored text/gear rather than a generated mockup. Desktop QA reports rewarded ads unavailable as expected; live Android provider completion is not tested here.
- QA: compare global coordinates to viewport bounds, not merely sibling sizes. Original bitmap aspect ratios are retained.
- Patch must be checked/applied against the last gifts-studio working tree; changed and added file bytes verified after applying to a temporary index. No new published commit is claimed here.

## User installation

1. `git apply --check "D:\Godot\tools\Jade-Ascendant-Gacha-Sanctum-R2.patch"`
2. `git apply "D:\Godot\tools\Jade-Ascendant-Gacha-Sanctum-R2.patch"`
3. Open/re-import Godot, export Android once. This is client-only; no server deployment or admin credential reset.
4. Verify single/ten summon, skip, reopening game, Wish selector, duplicate display, Indonesian and free-pull CTA provider state on the real phone.
5. `backend\player_identity\publish_gacha.cmd` publishes on the authorized checkpoint branch using the user's GitHub credentials, verifies the remote commit and prints its real `GITHUB_COMMIT_URL`. Never force push.

Next agreed work: distinct event imagery, new weapon role/mechanics, HP/damage/economy/weapons/VFX audit, then ad integration; parked IAP remains excluded.

## R2 packaging correction

The first patch failed the user's check on the mutable publisher path list, so none of its changes were applied. R2 excludes both existing publisher files and adds a dedicated gacha publisher that combines the local reviewed path list with an explicit gacha list. It retains branch/remote/protected-path/staging checks, standard push and remote SHA verification. It uses the explicit Windows PowerShell path and preserves exit status. Never recommend a forced/partial application to resolve this packaging conflict. Native source is identical to the validated redesign.
