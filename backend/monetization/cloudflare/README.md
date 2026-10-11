# Jade Ascendant IAP — Cloudflare Worker + D1 (PREDEPLOY)

This new backend candidate is a **separate route from the older Firebase Callable**.
It reuses the existing `../src/purchase_authority.mjs` policy and product allowlist.
It deliberately does NOT modify the Android bridge, local purchase gate, or existing Firebase files.

* Project: jade-ascendant (Firebase **Spark** retained)
* App Check App ID: 1:350718070767:android:e5520012a501d2856cf01a
* Worker POST path: `/v1/iap/authorize`; JSON exactly `{ "purchase_token": "opaque-token" }`.
* Required headers: Firebase ID token `Authorization: Bearer <idToken>`, App Check `X-Firebase-AppCheck: <appCheckToken>`.
* Google Android Publisher API called with a service account credential stored ONLY in secret `PLAY_SERVICE_ACCOUNT_JSON`.
* D1 maintains deterministic global purchase-token ledger and compare-and-swap revisions.
* Default response: HTTP 503 `purchase_backend_disabled`.

## What is STILL BLOCKED

**Never switch `JADE_IAP_BACKEND_ENABLED` to true or the Godot purchase activation flag yet.**
1. Service account permission in Play Console + Google Play Developer API need to be verified; Cloudflare secret is not yet configured.
2. `JadeMonetizationNativeBridge.kt` still calls Firebase Callable, not this Worker. Needs a separate Android bridge patch and validated signed release AAR build.
3. Replay protection for App Check limited-use tokens is not implemented as a one-time consumption endpoint. Standard JWT signature validation is implemented. Production security review must decide whether this gap is acceptable or implement enforced replay protection.
4. Server-side ledger prevents purchase-token re-authorization to other UIDs and returns stable grants, but **grant replay across multiple local saves/devices is not the same thing as server-authoritative account balance**. Need account-level economic reconciliation for cross-device purchases and refund handling before commercial release.
5. Revisit concurrency and consume/retry scenarios under real Play license-test purchases, as well as anti-abuse rate controls, before enabling.
6. Reconcile existing M5/M6 locked security tests with a deliberate production activation approval; never silently bypass them.

## Developer-only offline verification

`node --test tests/*.test.mjs` (Node 22, no Cloudflare account needed).
Optional, once user has created a Cloudflare account: `npm install` then `npx wrangler d1 create jade-iap-ledger`.
Copy the returned D1 UUID into `wrangler.toml` and apply migrations **locally**:
`npx wrangler d1 migrations apply jade-iap-ledger --local`.
Do not run `--remote`, `wrangler deploy`, or `wrangler secret put` until explicitly reviewed.

Security note: Cloudflare Workers/D1 Free have hard quotas; exhaustion must fail closed (no grant). Service-account JSON is sensitive and must never be committed, pasted into chat, or bundled in APK. No GitHub mutation or deployment is performed by the installer.
