# Home + Boss Flow — 24 October 2026

The Home chapter card now keeps chapter navigation available when Trials rewards are ready. Celestial Event copy stays inside the ornamental card. Boss pre-warning and arrival use the existing boss art in a compact ribbon, and Pause retains input priority.

## Changes

- **Chapter access:** claim-ready Daily/Achievement rewards no longer replace the chapter action. Existing valid Continue/Recovery priority stays intact; an active saved run also has a separate Chapters button. The card opens chapter selection without granting rewards or overwriting the run.
- **Celestial Event:** eyebrow, event title, progress, reward and CTA have explicit artwork-safe bounds on narrow and wide layouts; long EN/ID copy truncates inside its assigned line budget.
- **Boss warning:** shared pre-warning/arrival ribbon uses existing ornate frame, serif type and a square crop from the actual boss atlas. Prototype side diamonds/extra rules are removed. Restrained scale animation and an immediately fitted layout avoid oversized first paint.
- **Pause:** Pause and skill-choice modal layers sit above the boss notices. Notice reveal/reading timers stop while paused; Resume remains clickable with full and reduced effects.
- **Related small-phone defect:** the existing achievement notice needed a compact seal/type/line budget to stay inside the viewport. Reward mechanics and display duration are unchanged.
- **Backsound:** intentionally deferred as requested.

## Validation and limits

Author fixture results: Home/boss **84 checks**, existing Home **195 checks**, combat/achievement notice **100 checks**, all with zero failures in native X11 GUI. Latest Home/boss source also passed **84 checks** through the standard headless runner. Tests use isolated userdata, real chapter and Resume taps, EN/ID and compact phone layouts. Existing shutdown-only RefCounted(reference_count=0) engine warnings are recorded; this is not a claim of warning-free or Android testing.

Publisher simulation used local bare Git transport, including clean-base two-stage install, published Studio parent reuse, repeated resume, paths with spaces, scope checks and a retained unstaged valid production IAP config. Existing 14 safety-primitive test results are reused. It did not publish to GitHub or deploy.

## Owner handoff

Extract the complete `Jade-Home-Boss-Flow` folder under `D:\Godot\tools`, close the older Godot editor, then run its `apply_publish_and_deploy.cmd`. No earlier downloaded folder is needed. The launcher completes the prior Studio stage only if it is still pending, then publishes this client delta; successful stages are reused. It syncs through the established preserving workflow. A Profile dashboard deploy happens only if the prior authorized refresh lacks a matching successful receipt; vars are retained.

No IAP Worker deployment, migrations, event activation, push/mail sending, native rebuild or save deletion is included. Production protections remain nine of nine. Unknown edits and unreviewed newer commits stop before overwrite; never reset or force push.

Owner GitHub push, exact final-SHA Windows CI, client AAB export and Play-installed Android review are separate pending stages. After final-SHA CI is green, export one AAB with `backend\player_identity\export_production.cmd`.
