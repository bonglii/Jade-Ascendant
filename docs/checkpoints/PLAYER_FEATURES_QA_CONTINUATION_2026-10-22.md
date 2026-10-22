# Jade Ascendant — player features / source batch continuation

**BASE:** checkpoint/iap-fasttrack-20261010 @ `ece467fb141ba1c6175cfbb136a8ce4dce9765bf`

## Verified locally

- 13/13 Node 22 portable regression tests PASS against actual companion.mjs and schema with isolated SQLite and stubbed import dependencies.
- JS syntax PASS for companion.mjs, worker.mjs, dashboard.mjs and mail.mjs.
- Fixed event agenda cache transitions, added independent 30-day purge on the existing Profile scheduled Worker hourly tick, and ensured dead training dummies leave `enemy` group.
- Added `backend/player_identity/companion_sqlite.test.mjs` to the exact-SHA GitHub Actions workflow to validate real source dependencies when applied/pushed.
- Installer is a local-only, exact-SHA, clean-tree, checksum-validated, rollback-capable overlay. No commit, push, migration, Play Store or device action performed.

## Release gates not met

- Full-project Godot 4.7.2 import and arena runtime smoke **not executed** here (no Godot binary/full checkout).
- GitHub write tool denied branch create (`403 Resource not accessible by integration`); no workflow run exists for this package.
- Profile D1 staging migration and authenticated real-client analytics, privacy publisher review, Android account-switch/safe-area touches, native rewarded ads and refund lifecycle remain open.
- The existing 5 failing workflows on GitHub ece467f were not rerun by this local-only package.

## Important safety boundaries

- Telemetry is off by default, never a grant authority, and never a revenue or real-money entitlement.
- New hourly purge only affects `player_gameplay_metrics_v1`, and first checks for optional schema table presence. The existing mail cron continues independently.
- Training dummy destruction gives no XP, item, currency, kill signal or Journey stage clear.
- No IAP native gate, public deployment config, production database, main branch or user save has been altered.
