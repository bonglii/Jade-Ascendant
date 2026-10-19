# Odyssey shop, bounded notices and Firebase diagnosis

Scope: four requested fixes in one resumable Windows delivery. No save reset, new Play product, price override, event auto-start, purchase/refund bypass or automatic broadcast. Existing live-payment configuration is preserved.

## Implemented

1. Announcement letter uses a fixed panel shell, ornamental insets and an independently scrolling title/body. Update permission education and event shop are bounded with hidden scrollbars, wrapping copy and fixed actions.
2. Native HTTPS policy now admits exact /v2/odyssey and /v3/odyssey routes. Native requests use v3; URL policy rejection gets its own status. Host/SNI/TLS, body bounds, auth, no redirects and no implicit POST retry remain. Legacy routes stay compatible.
3. TRAVEL SHOP opens while offline. It separates Jade-to-dice exchange from six Google Play Jade packs. Bonuses are 1/3/5/8/12/16 dice for 100/550/1200/2500/6500/14000 Jade, once per SKU per active season after the migration cutoff. Actual localized prices remain Google Play ProductDetails. All six yield at most 45 bonus dice. Max journeys remains 152; unused dice expire; no extra Compass copies. Treasury shows active bonus badges, offer details and already-claimed copy; returning refreshes server evidence.
4. FCM check distinguishes disabled API and IAM permission denial, keeps bodies/credentials private, provides exact setup links and a setup launcher. This environment cannot modify the owner's Google project IAM. The launcher applies the minimal messaging role through an existing authenticated gcloud, or opens the exact Google API/IAM pages for the administrator. Actual Firebase validate-only success remains an external check.

## Evidence and limits

- 21 Node tests: 16 SQLite/service bonus cases and 5 FCM cases, including first grant, all six tiers, once-only restore, wrong account/amount, pre-rollout/expired/void credits, hold/refund race, CAS retry, event/config changes, migration rerun, old protocol reads, daily sync and exact command replay. No real purchase, grant or push.
- 18 targeted JVM tests compiled against production TrustedIapHttps/IapTransportPolicy/OdysseyContractV1 and real OkHttp TLS/MockWebServer dependencies. Includes exact event GET/POST and forged bonus metadata. This is not a complete Android release build.
- Godot 4.7.2 isolated UI checks exercise four viewports (360x640, 412x915, 648x1152, 840x400), long announcement/URL scroll, permission consent, offline shop access, bonus pack entry, Treasury copy and return destination. Container checks used placeholder textures because full project art was unavailable; the Windows launcher reruns with actual installed art. They are not physical-device playtests.
- Wrangler 4.151.0/workerd local accepted all 14 fixture schema statements including migration 0015 and immutable triggers. No remote D1 was accessed here.
- Full debug/release JVM build (at least 220 executions), compiled native provenance, GitHub commit/push, remote additive schema/Worker deployment, Firebase project configuration and final Play-installed AAB remain Windows/device stages. The supplied launcher performs the available stages and records progress; it does not claim production validation before those stages run.

## Resume

Use only this package's apply_and_publish.cmd after installation. It recovers an interrupted owned export, tests, reuses a matching native receipt or builds once, publishes scoped files, applies additive schema 0015 and deploys existing live Workers, prepares Firebase configuration, opens the owned production editor and verifies the exported AAB. Completed stages are retained by manifest hash. The current export launcher is repinned after compilation; caller-local export/signing presets are never replaced.

Actual commit URL is printed only after a successful git push. No commit was published from this preparation environment.
