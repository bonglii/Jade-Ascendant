# Odyssey UI / ad delivery repair

User feedback 2026-10-19: pause the proposed new sect-defense event. Repair the current Odyssey: animations insufficient; request-dependent buttons repeatedly dim/brighten; watched ads do not add dice; mission/shop layout is badly clipped. Both supplied phone screenshots were read successfully.

## Confirmed source defects and repairs

- The bottom atlas cells include 32–44 pixels of unpainted dark background inside the old regular-grid crop. Nine-patching that strip makes large dark bands that cover content. The original square-frame corner ornaments also exceed the small button's nine-patch margins. Actual Godot rendering reproduced both problems. Crops now follow painted frame bounds; standalone frame textures are cached once; uniformly smaller button textures use correct corner bands. Cards have safe text padding, readable progress bars, full-width actions and a fixed scrolling sheet/footer. The die badge uses the actual engraved die plus readable pips.
- Every background ad-receipt GET set busy/status and disabled most controls. Read state now preserves presentation and browsing, queues one intentional mutation until the read completes, and fences actual writes. Claimed buttons remain disabled. Unavailable ads update their own feedback instead of poisoning event connection status. Shop offers no longer vanish during a background read.
- AdMob key fetching used unbound global fetch and redirect:error, unlike already repaired Firebase/Play adapters. It now uses the same Workerd receiver/manual-redirect pattern, denies redirects and keeps its trusted URL/cache/signature boundaries. This is a concrete source defect and a strong likely explanation for the reported missing live reward; no live server tail/AdMob console access was available here to prove that particular failed view's cause. Preflight checks server config and key availability before playback, preventing known-broken verification from wasting a view. Expected ad-unit metadata is checked against the client setting.
- SDK playback previously consumed local event daily quota before any SSV proof. Event quota now remains with the signed server receipt; other placements keep their policy. Event intent/wait state is persisted per owner before opening the ad, survives restart, polls with bounded backoff through the existing intent lifetime, and stops only on matching server confirmation/expiry. No local die grant is introduced. Missing/late receipts get explicit feedback. A verified receipt now retries up to three CAS races while immutable transaction/intent records prevent duplicate dice. Server cap stays two signed rewards/day.
- Die motion adds a grounded shadow, tumbling/squash, controlled deceleration and engraved-seal reveal; reduced effects stays fast. Board traversal keeps the previous fast duration while removing the stop/start bounce on every tile. Popup fades do not resize or reflow text.

## Validation

35 Node tests passed: existing 26 +6 ad receipt/owner/config/cap/replay/CAS tests +3 Google-key receiver/redirect/cache tests. Cryptographic tests sign fixture callbacks with test EC keys and test tampering; these are not production ad receipts.

Godot 4.7.2: four-viewport UI smoke plus dedicated restart/receipt/account/SDK-policy tests passed. Checks include eight repeated background read cycles, unchanged button availability, one queued tap, unchanged other placements' limits and no local ad grant. Managers/native transport are explicit test doubles.

Real OpenGL Godot renders were inspected at 648x1440 and 360x800 using actual current art/font/actor dependencies, not placeholder art. Main, missions, shop and journey sheets rendered. This caught defects missed by the earlier bounds-only test. Local Mesa VSync warning is environment-specific; no script/parse errors remain. Phone GPU performance and a real newly watched AdMob reward still require the Play-installed build.

## Delivery

The package installs scoped changes with backups and normalized hashes; it does not replace wrangler production config, secrets, signing files, save data or main. Existing native proof is reused when valid. Launcher performs isolated QA, checkpoint commit/push (prints real URL), IAP Worker-only deploy with --keep-vars, one owned Godot release AAB export and metadata verification. New metadata odyssey_reliability_revision=1 rejects reuse of the older AAB. No migration or Firebase setup is needed. Do not rerun unrelated past repairs. Completed stages are journaled by package hash.

Official references consulted: https://developers.google.com/admob/android/ssv and https://developers.cloudflare.com/workers/wrangler/commands/workers/ . Public AdMob SSV callback remains https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/odyssey/ssv . The deployed existing ad-unit/reward-label values are retained; this environment did not change the AdMob console.

Pending workstation evidence: successful publish/deploy, fresh owned AAB metadata, real Play-installed rewarded-ad callback and increment. No commit/deploy or live-ad success is claimed from this environment. Historical views without a signed receipt are not blindly credited.
