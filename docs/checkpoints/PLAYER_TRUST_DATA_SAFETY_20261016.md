# Jade Ascendant — Data safety preparation

This is a source-audited owner worksheet, not a submitted Play Console form or a legal approval. Package: `com.yungdevstudio.jadeascendant`. Audit baseline: `0e3cb1e780a5a45c58fa7e5aa1e4d4715bc6cb08` plus this batch. Publisher/contact already configured in the project: Yung Dev Studio, yungdevstudio@gmail.com.

## Console values to use after the new profile deployment

- Privacy policy: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/privacy-policy.html
- Account/data deletion: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/account-deletion.html
- Does the app collect/share covered user data? **Yes.** Google sign-in, hosted profile/mail, optional cloud backup, verified purchases and AdMob are relevant. Do not answer No because ordinary gameplay can run offline.
- Encryption in transit: **Yes**, for the reviewed HTTPS/TLS app services and SDK traffic. This is not a claim of end-to-end encryption or a third-party security certification.
- Account creation: optional Google/Firebase sign-in. Guest mode does not remove the account-deletion requirement.
- Account deletion: **request-based support processing**, from the in-game Privacy & Support page and the public web page. Email submission is explicit; a draft is not a submitted request or immediate deletion. Describe the limited financial/security retention truthfully.
- Independent security review: **do not claim one** from source/CI tests.

## Data inventory and draft classifications

Check the current SDK Index/declarations against the actual shipped AAB before submitting. The Google AdMob disclosure describes its latest SDK; the Android AdMob/UMP binaries are installed by the owner and their exact SDK versions are not proven by the GDScript wrapper version in Git. Add any mediation adapter's disclosures if one is installed. No mediation source is newly enabled by this batch.

| Data type in Console | App source/use | Collection choice | Purpose and sharing review |
| --- | --- | --- | --- |
| Personal info: User IDs | Firebase UID/private bindings, public UID, profile/mail/backup ownership, App Check/purchase identity | Optional Google-connected features; required within those features | App functionality, account management, fraud prevention/security. Google/Cloudflare service-provider processing is reviewed separately from advertising sharing. |
| Personal info: Name, email address | Google/Firebase account metadata and support/deletion correspondence | Optional sign-in/contact | Account management, support and ownership verification. No raw email/name is appended to the in-game Copy support report by this batch. |
| Financial info: Purchase history | Play product/order/verification state, paid wallet transactions and refund evidence | Optional purchases | App functionality and fraud prevention/security. Card numbers and bank-account details are not received by game code. |
| App activity: App interactions / other actions | Ad impressions/taps/views; server mail reads/claims, activity, optional progress snapshots and paid gameplay actions | Ads/backup/purchases optional; some connected-feature records required while that feature is used | App functionality; SDK advertising/analytics/fraud purposes as disclosed by Google. AdMob data sharing is **Yes** where the SDK disclosure applies; do not apply the service-provider exception indiscriminately. |
| Location: Approximate location | AdMob IP-address processing can infer general location | Relevant while using optional ads | Advertising, analytics and fraud prevention. No precise/GPS-location permission is requested for these features. |
| Device or other IDs | AdMob advertising ID/app-set/device/account identifiers; App Check integrity information; local installation binding for server mail claims | SDK/feature dependent | Advertising/analytics/fraud prevention and app functionality. Check the exact final SDK/manifest and applicable consent behavior. |
| App info/performance: Diagnostics and performance data | Google Mobile Ads diagnostics and hosted-service network/security metadata | SDK/feature dependent | Analytics, app functionality, fraud prevention/security. Local source-location breadcrumbs are not automatically uploaded; a report is sent only if the user chooses to share it. |

An optional feature can collect data required to operate that feature. Answer per Console wording, not by copying “optional” into every question. Support requests can contain user-supplied information; collect the minimum needed and avoid asking for passwords, OTPs, Play purchase tokens, card information or an entire save file.

## Retention actually implemented / operated

- Local saves/checkpoints/settings remain on the device until replaced/removed there. Signing out and uninstalling are not server erasure.
- Profile backup: one latest and one previous nine-domain snapshot. The previous row is removed together with the latest on account erasure.
- Verified support request: remove Firebase Auth game identity, wait for existing signed ID tokens to expire, then process only that identity's profile and server gameplay rows. Do not delete a Google account.
- Limited purchase/wallet/refund/security evidence is not rewritten by the gameplay-erasure processor. Restrict access, document the case-specific reason/period, review at least annually and erase when the legitimate retention reason expires. Do not retain gameplay snapshots as “fraud evidence” by default.
- Cloudflare D1 disaster-recovery history can retain erased rows for up to 30 days under its plan. Do not reactivate erased accounts from that history; after a disaster rollback, replay completed erasure plans before opening traffic. D1 Time Travel is not a way to give deleted progress back to a player.

## Owner-only decisions before public publication

1. Confirm the displayed support inbox is monitored and handle deletion requests, including after the app is uninstalled. Process/communicate verified requests within the stated 30-day target; do not claim “fully automatic”.
2. Choose the actual target audience/age groups and distribution countries in Play Console. This project has no newly added age-screen flow; it is not approved as a Families/mixed-child-audience implementation. If child-directed or mixed-audience use is selected, configure TFUA/child-directed treatment and SDK/ad behavior appropriately before launch. Do not invent an age declaration from the wuxia art style.
3. Review all selected data types against the final AAB's SDKs and actual account practices, then submit the form yourself. No account credentials or Console submission are embedded here.

## Primary references checked 2026-10-16

- [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- [Google Play Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Google Mobile Ads data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [Firebase ID-token/session lifetime](https://firebase.google.com/docs/auth/admin/manage-sessions)
- [Cloudflare D1 Time Travel retention](https://developers.cloudflare.com/d1/reference/time-travel/)
