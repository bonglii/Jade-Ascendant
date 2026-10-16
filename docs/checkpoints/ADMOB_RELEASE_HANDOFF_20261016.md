# AdMob / UMP release handoff

## Source audit and changes

Production App ID and rewarded unit remain the already configured publisher `3082528078187093`. Debug continues to use Google's test rewarded unit. This batch does not change the monetization native AAR, billing targets, prices, ad reward amounts or the existing five non-revive daily cap. Standard rewarded rules still require the matching earned callback and a durable local reward-policy record; dismiss/failure alone does not grant.

A material consent race was fixed: opening privacy options now closes the ad gate, destroys the cached ad, stops pending retries and invalidates the old load generation. An old SDK success/failure cannot re-populate a cache or alter a newer load after the privacy change. Form errors remain closed and retry consent. Concurrent consent forms, privacy forms and rewarded playback are guarded. The release privacy entry updates after delayed UMP readiness instead of only at menu construction. Copy support now includes safe ad provider/state/test-mode/consent/native-plugin/load-error fields.

No server-side AdMob SSV cutover is implemented or implied by the word “verified” in an SDK callback signal. Optional non-paid ad rewards remain protected locally. Server-paid Jade/purchase authority is unchanged. Existing parked server-SSV prototypes are not activated.

## Remaining account-side setup

In AdMob, using the owner's account:

1. Confirm this Android app is linked to the correct Play listing/package, approved for serving where required, and that the existing rewarded unit belongs to this app. Check account/app policy or readiness holds. Source-valid IDs do not prove serving approval or inventory availability.
2. Under Privacy & messaging, publish applicable European consent and US-state privacy messages for this app; use the new live privacy-policy URL. Check the actual target audiences/countries against Play Console. Child-directed/mixed-audience choices need the corresponding SDK request treatment and an age-appropriate implementation before launch; none is silently assumed.
3. Confirm the developer website displayed in the Play listing and configure the **actual personalized app-ads.txt snippet** from AdMob at the domain/root AdMob expects. A repository subdirectory, a local file or an unverified URL is not evidence of crawler verification. No website ownership or app-ads.txt status was proven in this batch; copy the account-provided snippet, not an invented seller record.
4. For release integration checks, register the test device in AdMob so the production ad unit serves test ads on that device. Do not generate repeated live impressions/clicks for QA. Debug still uses Google's test unit. The GDScript AdMob wrapper is v5.1.0; confirm the SDK versions actually packaged in the final AAB and any mediation adapters rather than equating wrapper version with Mobile Ads/UMP version.

## One efficient device observation after the final batch AAB

Use a registered test device. Open Settings → Privacy & Support. In a region requiring UMP, verify the consent/privacy entry and revocation behavior; an Indonesia-only run does not prove EEA consent behavior. Watch one eligible test rewarded ad through an existing placement, confirm exactly one promised reward, and confirm closing before earned does not grant. Copy support only if loading/consent stalls; the new safe fields distinguish missing native plugins, unresolved consent, lack of inventory and load errors. Do not repeat successful real-money billing tests.

The desktop fixtures simulate callback order/privacy invalidation and UI layout, not a real native UMP form, live ad inventory, app-ads.txt approval, store review or production SSV. Source readiness is not public launch approval.

## Official references

- https://developers.google.com/admob/android/privacy
- https://developers.google.com/admob/android/privacy/play-data-disclosure
- https://developers.google.com/admob/android/rewarded
- https://developers.google.com/admob/android/test-ads
- https://developers.google.com/admob/android/ssv
