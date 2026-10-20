# Celestial / Odyssey touch and presentation batch — 2026-10-20

Base inspected: checkpoint/iap-fasttrack-20261010, 23f6253.

## Changes

- One shared native ScrollContainer policy for existing and dynamically created UI. Decorative card/layout Controls pass the gesture to their scroll owner; action buttons act on release and native scroll begin cancels the pending press. Editors, sliders, selectable text and custom GUI input retain their interactions. Nested scroll owners remain independent; disabled axes stay disabled. Native momentum is retained. No global gesture simulation.
- Hidden scrollbars, a common 6px deadzone and no focus-driven scroll jump. Old per-page disable-all/restore behavior removed from LiveOps; a swipe no longer flickers every action or restores obsolete eligibility.
- Celestial hub card spacing and touch surfaces cleaned up; claim dots use unchanged manager-owned readiness.
- Board manual Reconnect action removed; automatic retries continue with capped backoff while focused. No fake connected status.
- Board popup titles use a complete measured header with contained illustration and close control, with no dark strip across a clipped banner. Rounded jade controls/panels and ivory cards use transparent SVG corners rather than opaque atlas margins. Scrollers have no theme matte.
- Travel Shop item summary stays left, Play-formatted price stays right; Jade exchange rows follow the same layout. Product IDs, charge flows, server eligibility, bonus claims, prices, odds and limits are unchanged.

## Validation status

- Native GUI swipe regression reproduces the original blocked layout (0px scroll) and the shared policy moves it without firing its button.
- Focused suite covers first swipes from event artwork/cards/buttons, board, missions, rewards, info and shop; title/price containment at 320/390/648px, no mutation by swipes, one popup under repeated taps, real transparent material corners.
- Existing Hero, Trials, Mailbox and local event detail pages are included in shared-policy coverage.
- Final results are recorded in the delivery EVIDENCE files. Desktop native touch emulation and software-rendered fixtures are not an Android device playtest.

## Delivery

Client-only batch. No native rebuild, Worker deployment, database migration, account reset or payment gate changes. Install once, run targeted QA, publish only listed files on the existing checkpoint branch. Re-export the AAB through the existing verified production-export launcher; reuse the current native candidate. Completed install/QA/publish stages have resumable receipts. No dependency on an older download folder.
