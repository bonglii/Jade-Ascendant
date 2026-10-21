# LiveOps Control Desk — 22 October 2026

Base:3e1904c6f96491cf1ade393af3db68d4cfae5e30, the user-confirmed Heavenly Trials installation/publish/deploy. The user is exporting/testing that AAB. This follow-up changes server/dashboard only; no client scene, asset, Godot script, native library, release receipt or export setting is changed.

## Player and operator behavior

- The existing authenticated `/admin/trials` dashboard shows the current rotation and a five-week WIB/UTC calendar, including future campaign overrides. A published future campaign remains selectable rather than disappearing behind the current campaign.
- Published identity, start, theme order and reward budget stay frozen. Pause/resume retains custom existing theme/reward values. Drafts default to the next free Monday04:00 WIB slot. Refresh and temporary network failures preserve unsaved form data. A fresh read follows confirmed writes so a late background read cannot overwrite their visible state.
- Operations show current-week participants, attempts, clears, nonexpired active sessions, claimed/claimable tiers and ad bonuses. Pending/expired mail counts are an all-Trials delivery-queue summary. These are approximate operational snapshots across several queries, not transactional player balances or a permission to grant goods.
- Read-only operations verify required table presence, refund watermark freshness, configuration of the Profile binding and dedicated ad unit. They never create a week/session/mail, reconcile paid goods or contact Google/AdMob. Missing tables are reported rather than created by GET. Play Console publication, price and live ad delivery remain explicitly unverified.
- The dedicated Play product ID and SSV callback have copy buttons. No unit ID is invented or reused. Ads/shop switches do not publish external products or send notifications.
- Duplicate reset-slot publication is prevented in the same atomic database write, including concurrent new campaign IDs. Existing published campaigns retain pause/resume. Legacy collisions are displayed as ambiguous rather than guessing another rule.
- New covering indexes accelerate week summaries and the existing pending-mail queue. The idempotent0017 migration changes no table, row, balance, campaign or reward. Current live deployers preserve dashboard-managed vars using Wrangler's verified --keep-vars option.

## Validation

Read-only SQL tests enforce SQLite query_only. Tests cover real admin cookies/session and fixed internal service routing, bad keys, all nine live gates, missing schema, data privacy, timezone/rollover/paused/future schedules, concurrent publish rollback and index query plans. A real Chromium browser runs the actual HTML/CSP with a local SQLite-backed API fixture: custom immutable rewards, draft recovery, spam submit, concurrent refresh/write, conflict recovery, malicious label escaping and320/390/1365 layouts. No live services, user session or purchase is used. Browser images are internal-only QA and are excluded from deliverables/checkpoints.

The Windows package validates all files before writing, backs up changes and atomically replaces each file. A paused/failed install can resume. Existing local notes and local deployment-script repairs are preserved. For five current legacy deployers, only the --keep-vars addition is merged; other unknown edits are excluded from the scoped Git commit. No force push, automatic merge, index.lock removal, DNS change or obsolete download folder dependency exists.

The batch records separate QA/publish/index/IAP/profile stages. A failed profile deployment does not repeat the completed index/IAP stages. Full native and device QA from the previous batch is reused because those sources are unchanged. Remote deployment and actual Windows PowerShell execution are not claimed from author Linux tests. The included Windows CI parses the actual scripts.
