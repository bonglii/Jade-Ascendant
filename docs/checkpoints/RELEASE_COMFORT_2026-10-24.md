# Release comfort batch — 2026-10-24

Base: b0019c1e34e894266049db128e9fce3232241b22. See the matching state JSON.

All seven requested items are included. Normal reach is400, boss reach300;
YinYang orbit is144 (Reversal172.8), with the same six blades at level7.
Damage, cooldowns, critical/resonance rules and hit caps are unchanged. New
reach is validated with real moving Compass targets and actual fan/spear hits,
plus previous per-cast damage assertions and glaive swept boundaries.

The connection chime was equipment-change audio triggered by paid loadout
revalidation, not a distinct connection cue. A scoped depth guard quiets those
notifications without dropping stat/UI refresh signals or manual equip sounds.

The reward reader is now above Profile. The real milestone claim is rendered
at phone size. No duplicate reward is created by the presentation change.

Operations: Odyssey and Heavenly Trials have clear pause/resume buttons for
published schedules. Unsaved drafts must be saved/reloaded first. Changes use
existing session/CSRF APIs and preserve schedule, rewards and progress. Expired
seasons are not restarted through the quick action.

Announcements: choose Normal (until read) or Sambutan (first presentation only).
The first presentation is persisted for that account before display at safe Home;
closing/reopening does not replay it. Existing read acknowledgements remain the
server delivery mechanism. A crash before dismissal is acknowledged on the next
feed. Different accounts have independent markers. Messages are not restricted
to newly created accounts: eligible new and existing players receive while active.

Deployment adds player_announcement_presentation idempotently before deploying
only the Profile Worker. Existing announcement/mail/read records remain. Worker
vars are preserved with --keep-vars. No IAP Worker, secret, payment flag, event
activation or notification send is part of this batch.

Owner stages are distinct: package verification/install, scoped commit and push,
game sync preserving local edits, additive Profile migration/deploy, exact-SHA CI,
one new client AAB (>32), then Android validation. Author fixtures never establish
remote-deploy, production payment, Windows or phone PASS. Existing native release
candidate and production exporter remain the export path.
