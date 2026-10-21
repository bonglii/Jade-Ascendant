# Personal combat records — 21 October 2026

Base 227cedb810a3c7745611ca90fba5bb8b1b5a9f6a, checkpoint/iap-fasttrack-20261010. Previous Player Direction batch is confirmed on GitHub; do not reinstall or redo it.

## Player behavior

Journey's selected-stage panel gains Combat Records. The same existing Trials engraving/frame artwork, stage illustrations, jade/gold colors and shared mobile scroll policy provide the sheet; no new raster generation is needed. Browse five realms, best recorded time, recorded clears, and last-clear skills/actual armament, total applied damage and HP/death statistics. Journey also bounds long header/reward text and adapts its map nodes/plates without rebuilding the page on resize; a compact height keeps both actions reachable. The sheet opens once, scrolls on the first native swipe, fits narrow phones and restores the prior Back handler. It never chooses or starts a stage.

Each stage has three personal achievements: Clear; Survivor (no death, so a rewarded revive does not qualify); Untouched (no HP loss and no death). Shield-blocked attacks do not count as HP hits. These are records without extra currency. Best time and earned medals persist independently of the latest build. Existing stage clears are preserved but historical statistics are not invented. New clear counts begin with this update. No extra popup is introduced: Victory includes a compact saved/new-best record line. Once campaign/mastery/daily/earned-event priorities are settled, Home suggests an existing stage whose untouched record is still missing. Tapping uses the established Journey flow; Home never starts a run itself.

## Save and runtime boundaries

Optional stage_records lives in the existing Journey v1 domain. No new autoload, schema migration, server endpoint, Worker deploy, native rebuild or account ownership mechanism. Existing nine-domain backup transports the field; client/load validation drops invalid optional rows without invalidating old progression. All stored counters are bounded integers; JSON numeric types normalize on load. Personal records follow the existing Journey save/account/restore behavior, not a new leaderboard or anti-cheat authority.

Checkpoint combat reports retain version1 and gain optional HP-hit/death/complete metrics. Older complete damage reports keep their damage totals; absent HP history stays incomplete, so no no-hit/no-death medal is invented after Continue. New checkpoints restore these metrics. Applied-HP-loss accounting and source list are shared with the production ledger. Record capture is deferred until the boss killing call returns, after the existing stage/reward transaction succeeds. A failed optional-record write preserves previous records and reports that the record was not saved; it never retries/grants currency.

No new skills, gear, enemy stats, damage multipliers, drop rates, income, prices, paid checkout, ad units, refund protections or event schedule changed. This creates personal replay targets, not an endless mode, weekly reward track or new event. Personal time reflects the player's evolving build and is not normalized competition. Last-run damage is labelled partial when legacy damage history is incomplete.

## Delivery

One resumable verified Windows installer/publisher. Existing notes and unrelated changes are preserved; no force push, automatic merge or lock removal. Close Godot, run the included apply_and_publish.cmd, then use backend/player_identity/export_production.cmd after STAGE_RECORDS_BATCH=PASS. No backend deployment is required. The Windows publisher prints a real commit URL after pushing. Author verification and software render fixtures do not constitute Android phone playtests or new production-purchase evidence.

## Verification

621 existing UI/flow checks plus84 new stage-record checks and3 process-restart checks. The existing real-caster run-report suite passes176 checks and4 restart checks: final killing hit, applied damage rather than overkill, source attribution, legacy/Continue, actual skills and responsive result UI. Total game checks888. Backend guards120 plus2 new account-isolated record-backup/capacity tests pass (122 unique cases). Portable install/scoped publishing regression21 passes using local bare Git fixtures; this is not an author GitHub push. Five native software-rendered phone-size screenshots cover Journey entry at390/320, records at390/320 and Realm5 records. These are isolated render fixtures, not Android phone tests.

The first author run-report wrapper expected RUN_REPORT instead of the script's real RUN_REPORT_QA marker. Godot exited0 with176 passing checks and no errors; the verification parser accepted that actual evidence, preserved the original diagnostic metadata, and ran the4-check restart separately. Unchanged real-caster tests were not repeated solely for an author wrapper typo.

Legacy stage1-6 remains in save validation/history compatibility, while Home recommendations and the records browser follow the actual Journey presentation catalog. Hidden stages are not advertised as unreachable replay goals.
