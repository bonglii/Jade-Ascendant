# Approved Jade Sanctuary Home, 2026-10-14

The first selected concept is now a native Godot Home: clean front-facing Lin Yue illustration, floating jade sanctuaries, three-currency wallet, compact interactive profile, mail/settings shortcuts, scenic Journey deck, featured Celestial Boss Hunt, three shortcuts, and the existing five-tab navigation. The background has no baked text/buttons. Gold/jade frames use authored alpha textures; the Library has a new vector grimoire seal.

## Scope and authority

The new presenter derives from the existing Home presenter and reuses its profile sheet, popup ownership, localization, Meditation and menu handlers. Journey shows the selected chapter's real clear count and first uncleared stage even if clears are non-contiguous. Continue uses MainMenu's validated checkpoint and remains independent of the selected chapter. It refreshes on save events and entry; periodic badges never re-read the checkpoint file. Boss progress, claim indicators, upcoming Spirit Stone reward, login day, Meditation readiness and mail badges come from their existing managers. Preview currency/reward numbers were never seeded into production. Wallet plus buttons open existing gameplay sources; they do not enable purchase/IAP.

Wallet resource order stays Stone/Jade/Seal so reward flights remain correct. Home-only balance abbreviations are rounded down to one decimal for large values; other screens retain exact grouped numbers. The new art loads only for Home; nav/resource helpers keep their existing appearance on other pages. Saves, economy rules, backend and parked monetization gates have no content/schema changes.

## Responsive and touch behavior

Small portrait devices use three vertical shortcut cards. Short/landscape screens can scroll the shared lower panel while bottom navigation remains accessible. Header icons and CTA keep at least 42 logical pixels of height. Ornamental source crop margins stay fixed; canvas scale adapts their corners without spilling beyond small buttons. Native Button text renders above decorative layers. Navigation labels are measured against each tab's width. Fonts and widgets are built before first presentation, with no periodic page rebuild.

Actions activate on release. A swipe's accumulated movement stays cancelled even if the pointer returns to its starting point; scroll changes and active transitions also block activation. Existing global mobile hover suppression remains in effect. Wallet hitboxes follow settled HBox cell sizes and reject stale scene IDs.

## Validation

193 targeted assertions passed with zero runtime/script errors: five viewport geometries, real profile/progress, non-contiguous clear selection, validated Continue and save-signal invalidation, unchanged economy/checkpoint contents, all Home popup routes, drag-return cancellation, stable first-open fonts/node counts, native Journey/Library/Trials/Pavilion navigation, stale wallet rejection, repeated Home return, and resize after owner deletion. Native capture also completed without runtime/script errors. Scope remains menu presentation; unchanged combat/backend suites were not rerun.

Screenshots are actual native GL compatibility renders at 648x1152, 390x844, 320x568 and 896x504, using isolated Guest saves. Fixture timings are desktop/container observations, not phone performance claims. A phone/export playtest remains the final device confirmation. The scoped editor import exits explicitly with --quit so CI does not wait on the editor session. Windows launchers use SystemRoot's full Windows PowerShell path. The scoped CI job includes a Windows PowerShell AST parse; that Windows job has not run locally.

## Installation and publishing

Extract Jade-Home-Sanctuary.zip into D:\Godot\tools, then run the package's apply_home_sanctuary.cmd. It checks the exact repository root and authorized checkpoint branch, verifies the complete binary patch with strict whitespace, and checks for an already installed patch. A mismatch aborts without forced/partial application. Wait for Godot asset import, then re-export Android. No backend deployment is required.

Run backend\player_identity\publish_home_sanctuary.cmd from the project root. Its explicit fetch refspec recreates origin/checkpoint/iap-fasttrack-20261010 correctly, checks fast-forward ancestry, stages only this package, preserves unrelated work, checks whitespace, pushes without force and prints a real commit URL only after remote SHA verification. Direct GitHub integration write access returned 403; local/package completion does not claim remote publication.

## Animated Lin Yue handoff

The installed background is static. The selected character's moving background remains the user's future input; no fake skeletal animation was added. Clean background: assets/ui/home/sanctuary/background.png. Recommended input: 6-second seamless 9:16 loop, fixed camera/composition and unchanged face/pose/sword. Subtle breathing, hair/robe sway, jade aura, waterfalls and mist only; no zoom, cuts, gestures, facial morphs or new objects. Match first/last frame. The future clip must preserve the face's upper portrait placement and readable lower-panel contrast.

## Lessons carried with this feature

- Decorations on BaseButton children can cover native text. Draw the glass/frame behind the parent and verify actual renders.
- NinePatchRect minimum size comes from patch margins. Preserve source cut lines, fit the canvas and scale corner ornaments for small devices.
- Before shrinking a ScrollContainer, update its child's minimum width. Otherwise the previous larger minimum can pin the scroll region outside the new viewport.
- Font changes can retain old control minimum sizes; reset the intended label size after theme updates and inspect small-screen captures.
- HBox cells settle after parent resize callbacks. Relayout wallet hitboxes after cell resize rather than assuming the parent's first callback has final child geometry.
- Persistent viewport callbacks need per-frame callable identity and explicit disconnection when their owner leaves. Test navigation/reentry and resizing after deletion, and reject logs with any runtime error even if assertions pass.
- Validate the live file preimages and exclude generic evolving LESSONS from transport to avoid repeating historical patch conflicts. Record these lessons in the repository and in this new feature note.
