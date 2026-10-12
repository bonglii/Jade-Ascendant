# #9 — Repeating Seven Days Login

Date: 12 October 2026
Branch: `checkpoint/iap-fasttrack-20261010`
Base: local Sprint 1 UI checkpoint `9d121ab`; published repository baseline remains `42837f6` because GitHub write access is unavailable.

## Accepted prior work

Developer confirmed #6 resource safe area and #12 Hero filter text are safe on device before authorizing continuation to #9.

## Behavior

Seven active dates unlock seven rewards. Missing calendar days does not reset progress. A cycle stays available until every reward has been collected. After all seven are claimed, the next strictly later active date begins Day 1 of the next cycle. Claiming an overdue last reward may begin the next cycle today when today is later than the final recorded date. The same date cannot count twice or immediately generate another cycle.

The existing append-only activity ledger determines the cycle and active day. Cycle 1 retains original `liveops:new_player:claim:<day>` markers and reward source IDs. Subsequent cycles use `liveops:login_cycle:claim:<cycle>:<day>` and `live_ops_login_cycle_<cycle>_day_<day>`. Old activity and claim records are never erased. No new save domain/schema or migration write is needed.

Reward and claim marker remain in the same existing RewardManager save batch. A manager-level in-flight lock rejects reentrant login claims and activity advancement while reward callbacks run. Failed grants release the lock without applying a new runtime claim snapshot. Activity polling retries blocked writes even when the current date is unchanged. Ledger deduplication uses a dictionary so accumulated repeating activity does not require quadratic duplicate checks.

The event screen displays the cycle number and selects Day 1 automatically on a cycle change while open. A completed cycle shows when the next cycle can begin. The Event Center indicates the next cycle rather than permanent event completion. Indonesian strings are included; read-only saving status remains authoritative.

## Validation

Official Godot `4.7.2.stable.official.ed1daf0bf`, Linux headless, actual production managers, real isolated save batches, and the actual Seven Days event scene.

- Main regression: 364 assertions, 0 failures.
- Separate process restart: 8 assertions, 0 failures.
- Legacy activity and existing claims preserved; unrelated mailbox marker preserved.
- Unclaimed reward holds rollover; duplicate/invalid/backward dates and out-of-range/locked claims denied.
- Three full repeating cycles grant exactly the catalog Spirit Stones and Refinement Shards.
- Duplicate and reentrant claims grant no additional reward; callback activity recording rejected during the claim.
- Save barrier prevents claim/activity writes; release allows retry on the same local date.
- Overdue final claim safely starts today's next cycle and exposes exactly one new reward.
- Persisted Pavilion state equals runtime state; journal is cleared after every claim.
- Open UI follows cycle transitions; restart retains cycle/day/claims and permits the next valid rollover.
- Final logs contain no GDScript errors, runtime errors or shutdown leak warnings. The harness waits for real reward presentation callbacks before exit.
- `git diff --check` and patch application check pass.

Reproducible regression script: `tests/login_cycle_smoke.gd`. Run in a disposable QA project with `user://` isolated before autoload initialization; its data directory must contain `jade_login_cycle_qa`. In the tested Linux setup, XDG_DATA_HOME points at a fresh `/tmp/jade_login_cycle_qa_*` directory. Run Godot with `--headless --path <QA-project> --script res://tests/login_cycle_smoke.gd`, then run again with `-- --verify-restart` using the same save directory. The disposable QA project disables editor plugins and resolves the existing Firebase autoload UID to its script path; production project settings are unchanged.

## Limits and delivery

Android visual/device approval remains pending for this new event screen state. Date authority remains the existing offline local calendar: backward/duplicate dates are rejected, but server-verified time and device-clock manipulation prevention are not introduced by this patch. Rewards are the unchanged seven-day catalog, now intentionally repeatable.

IAP remains parked; production/backend/main and unrelated developer files are untouched. GitHub publication remains blocked by missing terminal credentials and the connected integration's HTTP 403 write rejection. Changes are committed locally and delivered as `Jade-Ascendant-Login-Cycle.patch`; no published commit URL is claimed.

Next priority after device confirmation: #22 — Mailbox deletion, unclaimed attachment protection, read/claim flags, badges and persistence.
