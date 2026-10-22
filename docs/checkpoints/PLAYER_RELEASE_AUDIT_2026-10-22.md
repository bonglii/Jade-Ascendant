# Player release audit — 22 October 2026

Base a2f0b9410f1af3b7478d5f76fe626d664ac88ad6. Scope: inspect the actual game as a player and developer, fix proven problems, prepare a submission candidate for 23–24 October. Google review/publication timing is not established by this work.

The prior Combat Clarity source was recovered from its completed checkpoint and verified by exact file hashes. The observed remote still points at a2f0b94; installation or publication of that delivery is not assumed. This package includes its 28 files and the new fixes, accepting exact known intermediate hashes so the owner applies one package. No older download folder is required.

## New findings and fixes

| Finding | Concrete correction | Evidence |
|---|---|---|
| Continue adds a false HP hit | Load HP before restoring combat counters; reset the ledger health baseline to loaded HP. | Real wounded checkpoint reproduction failed 2 of 6 assertions before the fix. Main + separate-process restart now pass, including the next real hit. |
| Defeat does not clearly explain the run or next step | Read-only summary of actual wave/time/level, known HP hits/loss, remaining boss HP, contextual advice, actual weapon damage and taken skills; Hero opens the existing equipment page. | Actual death, boss at25% HP, actual acquired skill report and Hero scene navigation. |
| End-run action can race revive | All three exit routes serialize against a pending revive; the manager refuses finalization while pending. Existing atomic recovery remains the only grant route. | Retry/Home/Hero refused during pending revive; verified-fixture revive succeeds, metrics continue, repeated Hero action grants recovery once. |
| Large result numbers could occupy too much room | Use the existing compact K/M/B/T number helper for damage values. | 1e12 damage rows, narrow layouts, native GUI input and actual software renders. |
| Adding an action crowded the smallest phone | Hero action lives with its advice in the scroll reader. Facts/advice precede report/recovery details; narrow title reduces size. | Actual320px render caught the issue that geometry-only checks missed; revised render inspected. |

Incoming HP loss is optional local report metadata, not a new permanent save domain or reward authority. Legacy checkpoints preserve their known hit/death counters and explicitly mark incoming-damage history incomplete. Defeat does not freeze the combat ledger because revive may resume the same run. Victory keeps its existing final-hit freeze.

## Input-driven play, not a balance claim

Seed22102026; isolated accounts; actual authored scenes, production attack/HP/collision/XP, real movement actions and actual offered choices. Initial profiles are declared fixtures. No in-run invulnerability, forced damage, enemy/wave override, ad or purchase. Fixed60-tick acceleration means game seconds below are simulated time, not measured Android FPS.

| Profile | Actual outcome | Interpretation |
|---|---|---|
| Fresh1-1, default Sword, offensive choices | Victory129.10s, Lv17,9 HP hits | Tutorial can be completed and the stage won with the input pilot. Introductory boss dies quickly for this build; one run does not justify retuning it. |
| Fresh1-1, defensive choices | Victory166.48s, Lv7,24 HP hits | Different offered/build choices produced a visibly longer fight. |
| Realm II1, cultivation5, ChainLv10/1star + Moon Seal | Defeat144.92s, wave9, Lv18 | Partial entry profile and pilot limits; not proof of unfair midgame difficulty. |
| Realm V5, cultivation10, GlaiveLv30/3star + Nine Heavens | Defeat178.22s, wave6, Lv19 | Not a maxed account; no blanket HP/damage change made from this sample. |

An earlier offensive pilot died17.27s because its path policy entered crowds. That author-harness result is retained as history and was not used to nerf the game. Reduced effects was enabled in these sessions; normal-effects rendering is checked separately. This is not a human usability study, full campaign completion or phone heat/performance measurement.

## Release scope assessment

| Area | Assessment for this batch |
|---|---|
| Core combat/readability | Existing authored telegraphs/arena/patterns retained; no new crash observed in completed sessions. Defeat feedback and Continue accounting fixed. |
| First session/progression | Actual tutorial prompts and both fresh profiles reach victory. Existing Hero/Library/mastery/personal records/Trials reused. No redundant tutorial or event system added. |
| Save integrity | Wounded Continue, separate process, paid run recovery, nine-domain backup/journal and optional legacy metrics checked. No save reset or account-hold bypass. |
| Economy | Previous production catalog/cadence audit and767 economy assertions +4 restart retained for unchanged prices/rewards. No model is presented as guaranteed calendar income. |
| IAP/ads/accounts | User-confirmed real IAP success remains previous evidence. Nine current production gates pass locally. No new checkout, refund, ad impression or remote account test performed. |
| UI/mobile | Defeat compact bounds, hidden-scrollbar axis, first native swipe and actual software images checked. Existing shared policy preserved. |
| Content/events | Existing rotations and admin controls retained. New event concepts remain parked; no event autoactivation or notification broadcast. |
| Workflow | Combined portable install, hash checks, backup/rollback, index ownership and resumable QA/publish. Native/config/migrations untouched; use the existing production exporter for the new AAB. |

## What remains outside the author workspace

The package is not yet installed or pushed on the owner's Windows PC, and its AAB has not been exported/uploaded or tested on a Play-installed phone. GitHub Actions runs only after a real push. Live DNS/carrier latency, device heat/frame-time, purchase/refund delivery and external console settings are not re-proven by a local source contract. No zero-bug guarantee is claimed.

After owner install/QA/push, export once with backend/player_identity/export_production.cmd, use the next owner-chosen version code, and follow the existing Play test/submission flow. The useful short second check is the new build's identity plus wounded Continue and defeat/Hero behavior; do not repeat all old configuration work. External publication remains an owner Play Console action.
