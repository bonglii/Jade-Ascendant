# Tester reliability batch — 26 October 2026

Base: `8654ad52c8237f2cb8832b77c2f5adefe1b2d219`. Video work is paused.

| Request | Change |
|---|---|
| Jade differs between menus | One last-confirmed paid-wallet display, monotone revisions, separate spend authority. Transient network loss cannot turn a known paid balance into zero. Account changes still clear the previous account. Sync reads do not create reward toasts. |
| Pavilion formation gap | Remove the reserved single-item footer height from the 10-result formation. |
| Plain realm thumbnails | Replace stage 4-3 and 5-3 textures with new environment illustrations; all 25 thumbnails inspected. |
| Preconnect server features | Prefetch public Pavilion banner at startup; reuse warm Odyssey/Trials reads; reduce redundant background reads. Existing profile, wallet, mail, cloud backup and ad SDK startup warmups remain in use. A mutation still waits for its real server acknowledgement. |
| Real-money IAP | Existing production host and all nine release gates retained. Closed-test enrollment alone does not force test payments; Google Play license testers receive test payment methods. |
| Crowded combat | Reuse Compass mesh/GPU buffers, cap dense cosmetic text/impact overdraw, budget offscreen enemy/pickup cosmetics and avoid redundant nodes on skills with authored cels. Enemy population, movement, damage, attack timing and XP totals are unchanged. |
| Currency feels excessive | Halve the new top-up base amounts. Audit earned income versus costs; preserve existing balances and purchasing power, with no arbitrary nerf to earned rewards. |
| Early gacha text | Suppress legacy result drawing and keep ritual text neutral until the relic lands; rarity remains visible through its effect color. |
| Gacha motion | Full-rate active reveal, slower eased landing, smaller lift/rotation and textured glow; reduced-effects behavior retained. |
| Compass body spam | Suppress the generic player-origin cast pulse for the continuous dragon. Keep the authored Compass/dragon effects. |
| Seals bypassed | Prioritize seals, allow an atomic seals + earned-Jade 10-pull, disclose its exact cost, and guard every paid entry point against bypassing owned seals. Hide the paid row while owned seals can be used. Ad quota is explicitly a quota, not a balance. |
| First top-up ×2 | Server-controlled once per account/pack on six new Play SKU aliases. Base 50/275/600/1250/3250/7000; first totals 100/550/1200/2500/6500/14000. Legacy SKU promises and restored purchases retain their original grants. |
| Event banner swipe | Manual horizontal swipe, reverse swipe and a short hold before autoplay resumes. Native vertical scroll and click cancellation remain shared. |
| Library empty detail | Content-sized popups, bounded long descriptions and native scrolling; settle wrapped-label minima before revealing, avoiding a large-to-small flash. |

## Top-up activation — one owner action after deployment

The launcher does **not** invent or silently activate Play products. Create these six one-time consumable products in Play Console. Copy each price/region configuration from the corresponding existing product. Keep legacy products available for old installations and recovery. New clients automatically prefer a returned v2 ProductDetails; absent products fall back to the unchanged legacy pack.

| Existing Play product | New Play product | Base | First total | Price |
|---|---|---:|---:|---|
| `jade_pouch_100` | `jade_topup_50_v2` | 50 | 100 | Same price, currently Rp18,000 |
| `jade_pouch_550` | `jade_topup_275_v2` | 275 | 550 | Copy existing Play price |
| `jade_pouch_1200` | `jade_topup_600_v2` | 600 | 1200 | Copy existing Play price |
| `jade_pouch_2500` | `jade_topup_1250_v2` | 1250 | 2500 | Copy existing Play price |
| `jade_pouch_6500` | `jade_topup_3250_v2` | 3250 | 6500 | Copy existing Play price |
| `jade_pouch_14000` | `jade_topup_7000_v2` | 7000 | 14000 | Copy existing Play price |

The stable internal product IDs and native purchase journals stay compatible. The bonus is computed inside the existing D1 credit batch and recorded in its immutable credit event. Concurrent requests, restore, repair and a reversal cannot repeat it. Refund/hold/freshness gates remain mandatory. No migration, AAR rebuild, price change or automatic event activation is required. Deploy the reviewed IAP Worker **before activating these Play products**. The conditional “first purchase” copy describes the rule; the server decides eligibility, including after reinstall.

## Economy check

A normal summon costs 100 Jade; 10 pulls cost 900. Daily completion adds 20 Jade, so daily completion alone buys one single every five active days. Stage 1-5 provides 500 Jade plus the separate starter-Seal path. These are bounded onboarding/revisit rewards, not evidence of recurring runaway income. Tester screenshots alone cannot distinguish dashboard/test grants from ordinary income. Existing wealth is not deleted; earned rewards and upgrade costs are retained until actual new-account progression data supports a change. Source audit: `scripts/data/economy_catalog.gd` and `scripts/managers/pavilion_manager.gd`.

## Verification and limits

Source, isolated save/transaction, actual D1/SQLite concurrency, layout and injected native-input regressions are recorded in the active state. The broad historical suite also contains old “production must remain locked” assertions already failing at the base; the current executable Cloudflare/production contracts are the release gates. No new failure names were introduced in that historical comparison.

A Linux headless run is not a Snapdragon 680 frame-rate test. A local Xvfb setup was rejected by automatic review for system-directory/TCP side effects; it was stopped. The dedicated CI workflow runs the real renderer, native gestures and pixel secrecy test. No Android, new live purchase, CI, deployment or AAB pass is claimed without its receipt.

After the single batch launcher finishes, close the old Godot editor and use `backend\player_identity\export_production.cmd` for one new AAB. Keep the owner's current version/signing/export settings; this package never downgrades them. Short device check: mixed-seal summon, menu balances, one full crowd wave, Library scroll and banner swipe. A Play license-test purchase checks first bonus and a repeat; normal real-money checkout uses a non-license-test account.
