# Account-bound paid run recovery — 2026-10-15

Published base: 93ece438098712b9a1cc8fcca7f0e07b0c7c6ff1.
https://github.com/bonglii/Jade-Ascendant/commit/93ece438098712b9a1cc8fcca7f0e07b0c7c6ff1
Base CI: https://github.com/bonglii/Jade-Ascendant/actions/runs/38746196271
All eight base Godot modes completed their 1,686 assertions with zero assertion
failures. The job failed because rg was absent and Hero left playing audio during
shutdown. Backend and the complete Windows/native/PowerShell job passed.
The separate premium workflow also exposed an actual landscape layout constraint;
its native job used the same retired SDK tools default already corrected elsewhere.

## Implemented source
- Additive 0012 table: immutable, owner-scoped UUID run -> slots, stars and frozen
  weapon level. No copy counts/currency can be supplied in a run command.
- run_start and run_resume share authenticated native transport, strict schema,
  refund/verified-credit checks, guarded D1 transaction, revision CAS, same-UUID
  replay and durable cancellation. Neither command debits Jade.
- The local checkpoint stores only {version,binding,run_id}. A fresh authenticated
  server read and run receipt are required before Continue instantiates the player.
  Changing current hub gear/stars/levels cannot replace the old run's weapon.
- Current ownership and the 120-second lease still govern use. Effective star and
  weapon level cannot exceed current verified stars. Refund holds deny recovery.
- The source gate runs while the existing loading screen pauses gameplay. The paid
  manager remains ALWAYS-processing so native/timeouts cannot freeze loading.
- Timeout, account mismatch or cancelled server run leaves the old scene and
  checkpoint intact. Missing/removed runs return durable not_committed receipts
  rather than permanently blocking every subsequent paid command.
- A legacy/local checkpoint has no paid run reference and never acquires today's
  current paid hub selection. Existing local progression remains readable.
- New-run levels come from bounded next-run earned levels, including retries from
  an old gameplay scene. They do not reuse that old scene's frozen level.
- The native run-contract capability must equal 1. Old AARs fail closed before
  persisting new commands; matching compiled binaries have NOT been installed.
- Hero landscape scale now follows available height, preserving a usable backpack.
  Existing assets and pinned equipped row stay in place.
- Both CI workflows use installed grep rather than assuming rg. Premium SDK setup
  explicitly selects platform-tools, and all runtime logs are retained/aggregated.
- QA-only audio teardown stops context-driven restart and drains playback before
  exit; assertions remain strict, including ERROR/SCRIPT ERROR lines.

## Evidence in this workspace
Godot: exact retained CI 4.7.2.stable.official.ed1daf0bf engine. QA data directories
are isolated; only paired restart modes reuse their own fixture data.

| Verification | Passed |
| --- | ---: |
| Backend complete suite (includes 14 new run tests) | 418 |
| New paid run, actual transition/weapon/checkpoint/retry | 15 |
| Separate-process paid Continue, clamp/lease/timeout/account/cancellation/legacy | 30 |
| Paid V2 schema, journal, receipt and Armory | 56 |
| Existing local Hero progression / separate-process Continue | 141 / 6 |
| Hero spam and equipped UI | 734 |
| Premium responsive/layout/result/settings | 160 |
| Profile / Google callback / billing recovery | 54 / 21 / 36 |
| Combat report / legendary set VFX / combat skill polish | 175 / 90 / 261 |
| Player server binding / mail / mail gifts | 85 / 26 / 76 |

Final selected log for each mode: exit 0 and no ERROR/SCRIPT ERROR lines.
The run fixture uses a simulated authenticated native response, and warms the real
level PackedScene on the main thread before the shipping scene transition. It
proves the paid gate/instantiation order, not cold-threaded-load latency or a real
Android purchase. Cold threaded headless loads were nondeterministic in this test
harness; cold device launch/Continue is explicitly part of the remaining device gate.
Backend tests use real SQLite and exercise transaction rollback and race guards.
Kotlin run-command/parser tests were added but have NOT compiled/executed locally:
this workspace has no Android/JDK build toolchain. The next pushed CI must build
both variants, run all JVM tests and verify the new JNI capability. Existing AARs
and their old provenance were not fabricated or relabelled as this source build.

## Deployment / completion gates
1. Publish this source and inspect both complete CI workflows. Obtain the newly
   compiled native artifact/provenance, then package matching AARs before export.
2. Add schema/Worker to the existing tester-only staging using the checked deploy
   script. A real successful refund cron is required; no synthetic watermark.
3. Android staging: install matching build, purchase/consume/credit/summon/gear,
   process death and recovery, two accounts/devices, and cold launch/Continue.
4. Production configuration and an actually charged order remain a separate gate.
   Play license-test success alone is not real-money evidence.

No remote deployment, order, production activation, AAB/version/export or main-branch
change occurred. Existing player saves and money are not modified by this source
package. Local fixture weapon levels remain device-earned; locking them per run
is not a new claim that all free economy/progression is server-authoritative.
