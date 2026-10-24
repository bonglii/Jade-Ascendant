# Jade Studio Elegance — 24 October 2026

Base: `f3dc8f064ea7868c8af2d56db980624109d9d813`, branch `checkpoint/iap-fasttrack-20261010`.

## Changed

- Shared navigation groups Communication, LiveOps and Management across Mail Studio, Dragon Odyssey, Heavenly Trials and Player Insights. Functional headings, consistent spacing, restrained jade/gold surfaces, readable controls, compact responsive layout and direct feature links.
- Contextual Indonesian guides explain recipients, gifts, scheduled mail, archive/claim distinctions, gacha targets, in-game announcements versus phone push, event freeze/pause rules, external ad/Play setup and opt-in analytics limits. Long notes are available on demand.
- Mail equipment picker starts collapsed; currency and equipment rewards remain supported. The paper preview and send/review stages are clearer.
- Trials distinguishes no published rotation from a new draft, explains the next action, proposes Monday04:00 WIB and preserves locked published schedules. All admin datetime fields still use the one existing fixed-WIB helper.
- Compact Hero puts Build Journal beside the title instead of consuming a full pinned row. Backpack reader increased from72px to114px on320×568 and119px in896×504; five columns and equipped row remain fixed.
- Home publishes its complete authored stack minimum height before the parent container sorts. The390px shortcut row can now scroll fully into view. Native tests distinguish real overflow from a completely fitting layout without adding dead space.
- Odyssey smoke uses the current homing courier API, checks moving bosses, level7 twin dragons, bounded effects, revoked authorization, range and identical-duplicate upgrade rules. It fails promptly instead of hanging on an obsolete call.
- Profile deploy accepts only the already documented equivalent local IAP-config exception, validated by all nine existing gates. Unknown backend edits still stop; local config is never rewritten or deployed as IAP.

## Retained

Player saves, balances, rewards, prices, pity/target logic, account credentials, CSRF/nonces, authenticated no-store responses, lazy/coalesced admin reads, unsaved drafts, native AAR/exporter and all nine live payment protections. No migration, event activation, player mail or push notification is performed by this batch. Profile deployment uses the existing local Worker config and `--keep-vars`; IAP Worker and main remain untouched.

## Evidence and remaining owner steps

The generated dashboard was inspected in the cloud browser with isolated sample data: desktop,390px frame, navigation, paper preview and Trials/Odyssey states. It is a preview of the real source UI, not a production deployment or delivery test. Source DOM25 checks, backend/WIB checks, native X11 Hero160 and Home gesture/layout suites, plus current Compass30 checks are recorded separately. Local bare-Git publisher simulation is not a GitHub/Windows/deploy receipt.

Run the portable owner launcher once; it installs, tests, commits/pushes, prints the real GitHub commit link, preserves game-local edits and deploys only Profile. Retry the same launcher on interruption. After exact-SHA CI is green, one client AAB through `export_production.cmd` is needed for the Hero/Home changes; the dashboard updates immediately after Profile deployment. Android, real deployment and Play review remain separate confirmations.
