# IAP client validation — 2026-10-15

Published base: 0d0736979296e77e354a4705cb4c138e3ffd2ae3.
Run: https://github.com/bonglii/Jade-Ascendant/actions/runs/38742081520

Actual result: backend SUCCESS; complete Windows/native/PowerShell job SUCCESS.
Godot paid client job failed. It exposed two product defects: a 16-field snapshot
count rejected the actual 15-field contract, and an Armory `Skin` constant shadowed
the native Godot Skin class. Initial positive/real-JSON cases correctly failed;
opening the real panel then produced a parse error and the harness timed out.

This correction derives the count from explicit protocol field names, verifies
parity with native/fixture keys, renames the constant to ArmoryFrame and clips long
button labels. A watchdog bounds errors in the paid QA coroutine to 25 seconds.
The CI engine is retained before test execution for matching local reproduction,
so future corrections can be verified before another user publish where possible.

Native source, compiled AARs, ownership/debit/refund checks and production activation
are unchanged. The corrected Godot runtime has NOT yet been executed. This is not
money-ready evidence. Publish and verify the next CI before export or deployment.
Persistent paid run/Continue recovery, staged device proof and production/real-money
proof remain outstanding. Existing player saves and release version are preserved.
