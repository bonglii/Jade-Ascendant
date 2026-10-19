# Odyssey ad and button flow

User: connected restored; ad tap and receipt verification feel slow; no visible Reward Granted after three videos; audit other event controls too.

## Repairs

Existing ad loading remains proactive and consent gated. New availability feedback distinguishes SDK loading, cooldown, server intent preparation, pending receipt and 2/2 confirmed daily rewards. Cache age is checked before reuse (refresh at 55 minutes); expired ads are replaced before playback. Trusted verifier keys are warmed off the authenticated GET response path via waitUntil; actual ad-intent POST still checks configuration/keys. This removes one possible cold fetch from the tap path without skipping verification. External network/ad delivery cannot be guaranteed instantaneous.

SDK earned starts an immediate server read, with initial two-second checks and bounded 4/8/15/30-second backoff, rather than the prior 8/15/30/60-second waits. SDK earned never modifies dice. Pending intent recovery remains durable/account-scoped. A late dismissal cannot discard an earned pending reward. A cancellation gets a 30-second receipt grace instead of two early polls. Long SDK playback cannot be silently cut off by the manager's old 90-second timer; the watchdog remains bounded at ten minutes. Existing placement caps/cooldowns remain unchanged.

The actual SDK options used empty user_id. New event ads pass their opaque server nonce. The signed parser accepts empty optional user_id from installed clients, keeps the exact signed bytes, rejects empty required fields and ignores user_id as identity. Owner still comes from the server intent, and signature/amount/unit/label/time/cap checks remain enforced. Without live callback logs this does not prove the cause of each reported historical view.

Only matching authoritative credit creates a four-second jade/gold Reward Granted +1 Dadu banner. It waits until ad dismissal and foreground visibility; another owner/receipt cannot settle the current reward; repeated reads do not repeat the notice. The previous small status line alone was insufficient. Daily limit stays two server-confirmed ad dice, not three videos. A read-only receipt diagnostic is included to distinguish consumed/awaiting/expired intents without exposing raw UID/nonce/token.

Actual Roll handler previously rejected every busy read although its button remained enabled. Roll and legacy battle counters now share one queued intentional action during GET. Mission, route and confirmed Jade exchange handlers were checked too; one pending tap is shared with ads, actual writes stay fenced and claimed missions stay disabled. Store browsing/close/back remain local. Receipt polling does not dim the whole event.

## Validation and limits

Local final QA covers 68 Node server/SSV tests (including full existing 24-test verifier suite), four resource collector tests, Godot 4.7.2 four-viewport UI tests, receipt/restart/account tests, actual pressed Roll/route/exchange tests, SDK earned/close/foreground/confirmation tests, and the real provider GDScript compiled against installed SDK wrappers. Android native calls/remote transport are explicit doubles, not live ad playback. A 100-second video, 56-minute cached ad and duplicate callback are simulated deterministically. Actual OpenGL renders with the existing game art at 360x800 and 648x1440 were inspected for toast size/readability. Original unchanged Kotlin response contract is rechecked separately over 20 generated wire cases. No live three-view credit is claimed.

## Delivery

One resumable backed-up source install, isolated QA, verified existing native reuse (rebuild only if its existing inputs are stale), actual checkpoint commit/push, production Worker-only deploy with existing vars retained, read-only ad receipt report, one owned release AAB export and verification. New odyssey_ad_feedback_revision=1 metadata prevents reusing the older AAB. No D1 migration, app data reset, payment gate, odds, event schedule, Firebase or AdMob console change. Actual GitHub URL is printed after successful push. Workstation push/deploy/export and Play-installed ad confirmation are pending; this environment has not performed them.

Primary references: https://developers.google.com/admob/android/rewarded and https://developers.google.com/admob/android/ssv .
