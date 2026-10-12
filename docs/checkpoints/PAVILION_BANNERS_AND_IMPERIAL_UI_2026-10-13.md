# Pavilion banner operations and imperial jade UI

Delivered scope: premium native Pavilion controls and Daily Meditation, plus banner configuration in the existing authenticated Operations Studio. Main, paid purchase authority and paid summon paths remain parked.

## UI

The new original `assets/ui/pavilion/sanctum_premium/imperial_jade_frame.png` is generated through built-in ImageGen. Native StyleBox draws nine source regions with explicit small destination corners. The high-resolution PNG therefore cannot inflate mobile minimum sizes; center text stays within fixed content margins. Buttons have separate normal/hover/pressed/disabled surfaces, a transparent focus outline and short pressure/release animation; reduced effects skips that animation. Summon target tiles and service panels use the same jade/bronze material. Daily Meditation uses the existing generated celestial seal, a centered circular altar, themed frame and layered claim CTA. Generation prompt and SHA are in `asset_sources.json`.

## Dashboard and configuration

`Banner gacha` is a new tab in the existing username/password dashboard. It offers 1–5 reviewed, already-shipped Legendary equipment IDs; title/subtitle; two built-in background presets; start/end dates; four base rarity rates totaling exactly 10,000 basis points; explicit preview/publish; enable/disable; revision history and previewed rollback. Schedule inputs use the browser's local timezone and are stored in UTC seconds. Up to 12 entries; edit an ended entry for a subsequent rotation. The most recently published/edit-promoted enabled entry currently within its schedule wins. Disabling it may reveal another still-valid entry. Rollback restores the original schedules, so an already-ended banner stays ended.

Publication is an atomic compare-and-swap on the expected document revision. Immutable revisions and audit entries append together. Stale edits fail without changing the active document. Retrying the same request ID and normalized document returns the existing publication; reusing the ID for different contents is rejected. All admin mutations use the existing cookie/origin/CSRF checks. New tables are additive and do not touch UID/mail/player/receipt tables.

Public `GET /v1/pavilion/banner` exposes only non-sensitive banner configuration, revision and server time. It supplies a lease of no more than 300 seconds, shortened at the next schedule boundary. The Android client refreshes on opening Pavilion and about every 60 seconds while that view remains alive, using the existing certificate-verified hostname/IPv4 routing. It rejects unknown assets/items, non-Legendary IDs, duplicates, malformed/fractional rates, stale revisions, invalid schedules and leases. Monotonic process time controls lease expiry; phone clock changes cannot extend an expired banner. Failed requests retain only an unexpired validated configuration. No valid active configuration uses the embedded Nine Heavens banner and 60/29/9/2 rates. Desktop/headless QA never sends production requests.

Featured IDs are offered Wish target choices; the banner does not secretly boost every featured item or unlock progression-gated equipment. The existing saved Wish target remains valid outside the new featured list and is displayed with a retained-target note. No server banner change resets pity, Fate, target, currencies or inventory. The player may explicitly choose another unlocked Legendary target, preserving the existing rule that a target change clears target-specific Fate. Natural Legendary preference stays 50%, one miss activates Fate, and hard pity limits stay 10/30/50. Effective odds continue to redistribute unavailable rarity pools according to the existing rules. A ten-pull pins its effective rates once before rolling. Paid economy/paid summon branches do not consume this client configuration.

Banner UI updates wait until an in-progress reveal closes. Names/art still remain concealed until each reveal completes; the configured rarity odds feed the real local roll and Rates display. This is live configuration for the existing local free summon economy, not server-authoritative loot or cloud save. Truly new equipment/mechanics/assets must ship in APK and be added to the reviewed catalog before the dashboard can offer them. Arbitrary remote image uploads are not accepted; artwork presets are already packaged and consistent with the game.

## Apply and deploy

Incremental patch base tree: `ade2c7c43021bf0754689b453cb807a63b51993d` (after Unified Reveal). Existing mutable `publish_paths.json`, `publish.ps1` and `publish_gacha.ps1` are not patched.

From Windows CMD in `D:\Godot\project\jade-ascendant`:

```bat
git apply --check "D:\Godot\tools\Jade-Ascendant-Pavilion-Imperial-Banners.patch" && git apply "D:\Godot\tools\Jade-Ascendant-Pavilion-Imperial-Banners.patch"
backend\player_identity\deploy_pavilion.cmd
backend\player_identity\open_mail_dashboard.cmd
```

Then open Godot to import the new PNG and re-export/reinstall Android once. The deploy launcher uses the explicit System32 PowerShell path, parses both new PowerShell scripts before changes, runs all three Node suites, builds the reviewed icons, applies the repeatable banner schema and deploys the existing Worker using `wrangler.local.toml`. It does not replace the admin password, bootstrap secret, UID database or existing local routing settings. Existing authenticated Wrangler/local configuration on the deployment Windows account is required. Linux QA cannot execute Windows DPAPI/PowerShell or deploy that account's live Worker.

An isolated local review commit was prepared against remote checkpoint `9bb9b43e2d4b20fcd5cd46c238ed829b8df33842`, including approved preceding gifts/mailbox/gacha changes. GitHub CLI publication lacked credentials, and the connected GitHub integration rejected blob creation with HTTP 403 (`Resource not accessible by integration`) despite the repository metadata reporting push permission. No new GitHub commit or branch was published. A normal user-side publish is available via `backend\player_identity\publish_pavilion.cmd`, which guards the original authorized checkpoint branch, stages an explicit union allowlist, runs server tests, pushes normally and prints the actual verified commit URL. Do not run both Git pull and this incremental patch over the same changes.

## Validation

- Node: 48 tests pass across identity, mail and banner routes; malformed config, schedule boundaries, priority, expiry, disable, rollback, stale publication, retry idempotency, auth/CSRF and additive migration.
- Native Godot: 701 gacha checks; 67 banner checks, including configuration arriving during reveal, saved target/Fate/pity/economy preservation, real Rates values, variable featured count and mobile containment; two restart checks.
- Actual Chromium + Worker handler + SQLite: login, item selection, preview invalidation, publish, public config, disable, rollback, 390px mobile containment, legacy mail sending; no JS/CSP errors.
- Native renderer: home, meditation and mobile screenshots visually reviewed. Pre-reveal texture secrecy across all four rarities is checked in OpenGL; Rare blue and Epic purple frames remain distinguishable.
- Existing server gift test: 60 checks. Whole-engine exit resource warnings in older fixtures are separate from script/parse errors and are not claimed resolved by this change.

Live Worker activation and Android acceptance occur on the user's deployment laptop; no live dashboard change is claimed by local QA.
