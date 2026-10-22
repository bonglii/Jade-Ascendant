# QA17 release candidate: mobile regression closure

Base: `14f64e4ae41c1cd69719bdc79412c43dc9a597fb`, branch `checkpoint/iap-fasttrack-20261010`.
The nine companion features are already upstream at `71f6753`; this package fixes their release regressions rather than applying those features again.

## Changed

- Settings recovery actions keep complete labels when opened on compact screens; the initial collapsed state remains deliberate.
- Home uses its current contextual primary action. Continue shows the same saved stage that the real resume route opens, including older saves without stage identity.
- Narrow resource counters use a shorter display without changing actual balances. Equipment refresh stops safely after Hero detaches; applying an identical preset avoids a save and redraw.
- Journal titles and preset actions fit compact widths, with readable preset error messages. Training uses real PlayerHealth, fits its controls and joystick below the HUD, and supports the existing six skills without advancing permanent quests, mastery, or paid-run tracking.
- The previously documented optional analytics rollout HOLD is enforced in the client. Existing saved opt-in cannot collect/upload during the hold; the unfinished opt-in card is hidden. Existing agenda, backend and dashboard source remain available for the separately disclosed rollout.
- Updated stale fixtures to exercise actual visible recovery controls and the single contextual Home CTA. Added isolated native first-swipe verification and a pinned-engine GitHub workflow that records failures.

## Reused / preserved

Existing nine live production IAP gates, prices, wallet/refund rules, native AAR pair, server endpoints, player save contents, authored equipment and combat balance, current production exporter. This batch does not deploy Workers, rebuild native, change the app version, or auto-submit to Play.

## Author verification

Official Godot 4.7.2 archive SHA256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

| Focused suite | Passed checks |
|---|---:|
| Public recovery UI | 32 |
| UI reliability and numeric boundaries | 949 |
| Contextual Home / legacy checkpoints | 180 |
| Companion / six real training skills / persistent-state isolation | 48 |
| Compact layout and first-swipe input, headless | 122 |
| Compact layout and first-swipe input, native software rendering | 122 |

All of the above finish with zero failed checks and no SCRIPT ERROR/ERROR output. Native software rendering produces a VSync capability warning and an ObjectDB shutdown warning; this is retained in evidence, not described as an Android leak test. Further native warning details, when available, are recorded with the author evidence.

Affected integration suites also pass: paid-run recovery 15 checks plus 30 restart checks; run review 7 plus 33 restart checks; Hero upgrade burst 737; player trust 31; public recovery 33; all 132 Profile backend tests; production contract 9 gates. Author tests use disposable fixtures and do not charge, deploy, or modify real player saves.

## Remaining release steps

1. Apply/publish this exact package to the clean QA13 clone. The launcher prints the actual new commit URL only after normal push and remote confirmation. It preserves backups and resume receipts, refuses unknown local edits and never force-pushes.
2. Wait for workflows for that exact commit, including the formerly failing Player trust, Public readiness and UI reliability jobs plus the new QA17 native check. Local results do not claim a remote CI pass.
3. Fast-forward the actual game project to the verified commit, preserving unrelated local changes. Close the older Godot editor and use the established production export launcher. The Play version code must exceed the one already uploaded; no version is guessed here.
4. Upload the signed AAB to the test track, update the Play-installed build, then verify startup, existing account/save, one real first swipe, training entry/exit and the production wallet. Previous successful paid purchase evidence is preserved; no extra charge is required just for this UI batch.
5. Complete the owner's Play Console submission after checking the current listing, disclosure and build. Store review/approval and the owner's device/export actions remain unverified here.

No date guarantee is made for Google's review. The requested release target remains 24–25 October 2026; this package closes the observed source regressions, not the external review process.
