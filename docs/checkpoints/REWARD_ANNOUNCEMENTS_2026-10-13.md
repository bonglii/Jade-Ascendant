# Reward presentation and Sanctuary broadcasts

Baseline: checkpoint/iap-fasttrack-20261010 at aea263d (Qi Magnet).

## Result presentation
Inspected real Godot before/after renders and the existing approved jade/crimson
frame, scenery and button artwork. Reuse those assets through one shared
ResultCeremony controller. Actual stone/shard/HERO EXP rewards appear in a
responsive grid; HERO EXP was previously omitted whenever reward chips hid the
text summary. Existing reward authority and actual applied amounts stay intact.

Result content scrolls vertically, while retry/home/revive controls remain
visible. Typography does not change size on resize. Repeated refresh removes
old card nodes before replacement so queued deletion cannot cause a layout jump.
The older flat V3 presenter skips these surfaces; there is one styling owner.

## Announcements
Dashboard Pengumuman supports plain-text preview, confirmed publication,
notice/event/maintenance kinds, optional start schedule, 1/7/30-day duration,
history, read counts and cancellation. Up to 20 active/scheduled broadcasts;
50 recent publications in history. All verified server accounts may receive an
active broadcast, including accounts registered after publication. No reward,
HTML, rich text, executable link, equipment or currency payload is accepted.

The new client opts in through its existing mail-list request. Announcements
arrive on the final inbox page with no extra token request/polling timer. The
existing authenticated identity/account-binding checks also protect read ACKs.
Read markers are stored once per server account, and locally in the existing
server-mail domain. Retry uses the same immutable request ID. Admin routes reuse
session, same-origin and CSRF checks, with a signed five-minute preview proof.

The global announcement queue waits for HOME, completed transitions and other
dialogs. It does not interrupt combat, results, boss notices or level-up panels.
Text and titles scroll, while the acknowledgement stays visible. Owner changes
clear the queue; expiry or a cancellation snapshot removes pending/active text.
The server clock drives expiry, avoiding reliance on the phone wall clock.
Modal artwork loads lazily so empty notification queues do not load extra PNGs
at startup. Original main/production, Google login and parked IAP are unchanged.

## Apply and deploy
Apply Jade-Ascendant-Reward-Announcements.patch in the Windows project. Run
backend\player_identity\deploy_reward_announcements.cmd, reopen Godot, then
re-export Android. The additive CREATE TABLE IF NOT EXISTS migration preserves
existing mail/player/banner data and the dashboard password. No key rotation or
database recreation. Existing broadcasts become available on the next mail sync.

Publish via backend\player_identity\publish_reward_announcements.cmd. It stages
only this package on the authorized checkpoint branch, explicitly creates its
remote-tracking ref and prints the commit link only after remote SHA validation.

## Lessons
Avoid native Godot method names such as set_owner for string account setters;
use set_account_owner. Wrap labels created during refresh as well as labels
present at ready. A fresh-profile onboarding overlay legitimately blocks a
broadcast; QA must finish the actual onboarding rather than weaken that guard.
Shared LESSONS.md is recorded locally and excluded from this patch.

## Validation
61 identity/mail/banner/announcement Node tests pass against real SQLite.
74 focused Godot layout/queue checks pass in headless normal/reduced-effects
and a native X11 render; 472 existing combat regression checks also pass.
Actual result screenshots were inspected at 648x1152, announcement at 390x844.
Dashboard DOM interactions pass: navigation, text safety, preview, a failed
publication followed by the same immutable retry, form reset and cancellation.
This DOM check does not establish browser CSS rendering.
Windows PowerShell is unavailable in this environment; the launchers were
reviewed and the deploy launcher parses both PS1 files before remote changes.
No live deployment, broadcast, or GitHub push was performed here.
Native QA shutdown reports ObjectDB leak warnings from the full loaded scene;
focused assertions pass and prewarm is drained before exit.
