# Odyssey dashboard: WIB schedule and admin presentation

Scope: profile-worker dashboard only. No IAP-worker, schema, reward, player-save, Android-native or release-version changes.

- Jade/gold responsive control panel, readable status, milestone summary, current WIB clock and collapsible technical JSON.
- Input always means Asia/Jakarta / WIB (UTC+7), independent of the browser/Windows timezone. Preview shows start/end in WIB and corresponding UTC. New season defaults ten minutes ahead; 14-day duration and 3-day claim grace are explicit.
- Preview/confirmation before writes; no write on page load. Existing season ID/start/end/reward values preserved verbatim, including seconds. Only access toggles change. New season becomes available after the previous claim window.
- Session, nonce CSP, CSRF and backend validation remain in place. Values from the server render with textContent. Failed loads keep publishing disabled but allow retry.
- Profile-only deployment command: backend\player_identity\deploy_odyssey_dashboard.cmd. No AAB rebuild needed.

## Lessons and prevention

- Do not expose UTC-only scheduling or raw JSON as the primary admin workflow. Use a named timezone, convert explicitly, preview both time representations and preserve authoritative timestamps on toggle-only updates.
- Do not truncate published schedule seconds via datetime-local when saving access toggles: reuse the original server document.
- A native candidate build is not evidence that a manually opened Godot editor exports that candidate. Use export_production.cmd and its owned editor session for future native-dependent releases.

Validation: timezone/calendar unit cases, status boundaries, generated script syntax, authenticated dashboard/proxy tests and actual headless-browser desktop/mobile form checks. Remote deployment and phone behavior must be reported separately.
