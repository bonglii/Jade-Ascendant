# Play runtime transport fix — 2026-10-16

Live evidence: scheduled events ran at 01:30 and 01:45 but threw play_fetch_unavailable at the refund fetch catch. PC tail connected using encrypted DNS; device read-only wallet was independently confirmed. These facts separate the current server refund failure from the earlier local DNS/auth issues.

Defect: refund and dormant RTDN key requests still used redirect:error, rejected by workerd's actual Request parser (src/workerd/api/http.c++, Request::tryParseRedirect). The implementation accepts follow/manual, despite broader documentation listing error. Use manual plus rejection of non-success/3xx responses. Preserve global native fetch receiver for refund, OAuth, verify, consume and RTDN calls. No redirect forwards OAuth credentials.

Three runtime-compatible fixtures failed before the fix (refund, full Play gateway, RTDN) and passed after. Full backend 433 tests pass, including explicit HTTP 401/403/429/5xx, timeout and no credential/body leakage, actual signatures, OAuth redirect refusal, and existing refund durable cursor/replay tests. Tests are local fixtures, not live Play evidence. Production and RTDN activation flags remain unchanged. No native source/AAR, migration, game balance, saved player data or credential change.

Earlier review fixed the key verifier but missed this related transport class; audit all Worker fetch call sites together and test with workerd redirect semantics rather than only Node fetch. Do not treat the old generic exception as proof of bad service-account permissions. New fixed labels distinguish play_http_403, play_http_401, play_fetch_timeout, play_fetch_unavailable, play_redirect_denied without printing secrets or response bodies.

Delivery: backed-up allowlisted file replacements, existing publisher, staging Worker-only deploy (schema already verified), readiness SELECT and process-scoped HTTPS-DNS tail. No automatic purchase, migration rerun, production unlock or native rebuild. Installer/Windows/live Play execution not performed here; new GitHub CI and deployed refund result still pending.
