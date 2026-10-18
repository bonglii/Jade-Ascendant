# Opt-in Android update notifications

Included with Odyssey Mobile Readability R2 in one native build and one final AAB export.

- Device preference, no Google-account requirement. A one-time explanation waits for safe HOME; only Enable triggers the Android permission dialog. Not now is respected. Settings exposes enable/disable, subscription state and Android settings.
- FCM auto-init and unused Firebase Analytics collection are disabled by default. Explicit opt-in plus OS permission enables topic subscription. Opt-out blocks display immediately, including while network unsubscription is pending. No registration token is logged or sent to our own database.
- Data-only release messages are bounded plain text, carry a target version code, campaign ID and seven-day expiry. Current/newer installations, old/duplicate targets and expired/invalid payloads stay quiet. Notification click opens a fixed official Play Store URL; the sender cannot supply another link.
- Dashboard: preview/confirmation protected by existing admin session and CSRF, read-only validate_only readiness check, immutable campaign history, 3/hour limit. Retries with the same request ID do not repeat an uncertain/accepted send; Firebase acceptance is not proof that every phone received it.
- Profile Worker stores broadcast audit metadata only. It calls the existing bound IAP Worker with its existing shared internal key. A separate OAuth messaging scope uses the existing server-only service account; old Play OAuth, wallet, refund and event logic stay unchanged.
- If Google rejects FCM with 403, enable Firebase Cloud Messaging API and grant Firebase Cloud Messaging API Admin to the service account displayed by the dashboard in project jade-ascendant. This server-side setup does not require another AAB. Do not broadcast until the update is available to the intended Play track.
- Android force-stop, offline devices, revoked permissions and platform delivery policies can delay or prevent delivery. No receipt count is invented.

Verification and remaining PC/device actions are recorded in the delivery package STATE.json. This is not a claim of a live broadcast or a finished device test.

Data safety follow-up: installation/device identifiers processed by FCM for Developer communications are collected. Review the existing Device or other IDs entry and add Developer communications purpose where appropriate; keep existing ads/analytics declarations intact. Service-provider processing is distinct from independently shared advertising data. Notification permission is optional and is not permission to collect unrelated personal data. Public privacy policy has the new messaging section.
