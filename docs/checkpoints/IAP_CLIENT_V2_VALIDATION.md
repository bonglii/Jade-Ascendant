# IAP client validation — 2026-10-15

Published source base: 9b0e62d87e9e17541556e160aefb7e933a78e7e2.
CI: https://github.com/bonglii/Jade-Ascendant/actions/runs/38744214986

Backend: SUCCESS (404 checks). Windows/native/PowerShell: SUCCESS, including
compiled debug/release AARs, Kotlin tests and provenance/publisher checks.
Godot: FAILURE at one of 51 paid-client checks: replay dictionary equality.
Later suites did not execute because the old CI loop stopped at the first failure.

Root cause confirmed locally using the actual CI engine artifact:
Godot parses JSON integers as floats; nested Dictionary equality is type-sensitive.
The initial command was int-typed but the journal copy was float-typed. This also
prevented initial server receipts from clearing the journal, not just a QA issue.
Commands are now validated then normalized into canonical bounded integer fields
before durable storage, dispatch and recovery. QA checks actual first-response
retirement plus identical serialized replay after disk read and after timeout.

Engine: Godot 4.7.2.stable.official.ed1daf0bf, from CI artifact 11977417153.
Artifact ZIP SHA256:
ab279ec59cb8a2bb9fcd6ad3277f1b36e50fb0a55f6aa239d662389605d53fc3
ZIP digest and CRC verified before extraction/execution. No replacement engine.

Local runtime results after correction (exit 0; no ERROR/SCRIPT ERROR lines):

| Check | Passed |
| --- | ---: |
| Paid V2 schema, journal, initial receipt, replay, account/overlay, Armory geometry | 56 |
| IAP delivery boundaries and recovery UI | 15 |
| Server Jade delivery | 31 |
| Hero progression and actual checkpoint/combat | 141 |
| Hero separate-process Continue (local equipment) | 6 |
| Hero upgrade burst/UI | 734 |
| Pavilion actual UI/reveal, two locales and five viewport sizes | 701 |
| Pavilion separate-process restart | 2 |
| **Total** | **1686** |

Each suite ran in a dedicated QA data directory. Restart modes reuse only their
own preceding fixture. The correction was runtime-verified before packaging.
CI now runs all eight modes and retains all logs even if an earlier mode fails;
completion markers prevent a silent early exit from counting as success.

Unchanged backend/native source was not rerun locally: the published CI passed.
The new source still needs its remote CI confirmation after publication.

This does not establish production or real-money readiness. Remaining gates:
server-backed persistent paid run/Continue locking (the six Continue checks above
are existing local equipment behavior), deployed staging/device purchase recovery,
then production configuration and proof of an actually charged order. No deployment,
new paid purchase, production activation or Android export/version change occurred.
