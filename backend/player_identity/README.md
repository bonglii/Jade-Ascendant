# Player identity service

Separate Cloudflare Worker and D1 database; never deploys or modifies the IAP worker/database. Public UID is 12 uppercase letters/numbers, for example `JA123456789A`.

`POST /v1/player/register` accepts exactly `{}` with `Content-Type: application/json` and a Firebase ID token in `Authorization: Bearer ...`. It verifies the token's RSA signature, issuer, audience, expiry and supported provider (Google or anonymous) against the pinned Jade Firebase project. It stores only a SHA-256 owner binding, unique public UID, and creation time. Client UID/name/owner values cannot claim an identity.

Database constraints enforce one UID per authenticated Firebase subject and no duplicate public UID. Concurrent registrations converge; random UID collisions retry, with bounded attempts. Google linking that preserves the Firebase subject preserves the UID. Logging into a different account selects a different server identity. Anonymous accounts remain device-bound unless linked to Google; registering an ID is not Cloud Save.

This profile-only service uses Firebase Auth, not the IAP App Check/native transport. It now also serves the mail dashboard and authenticated mail routes described below. Wallets and gameplay remain local; this is not a server economy or cloud-save service. Apply rate limiting to anonymous-account creation if opening signup at scale; Firebase Auth verification alone is not an anti-bot system.

## Test and deploy on Windows

Requires Node 22.13+ (Node 24 recommended), npm, and the existing Cloudflare account. From the repo:

```powershell
node --test backend/player_identity/identity.test.mjs
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File backend/player_identity/deploy.ps1
```

If Wrangler reports no login, run `npx --yes wrangler@4 login` locally, then rerun deploy. The script creates/reuses only `jade-player-identities`, applies an idempotent table definition, deploys only `jade-ascendant-player`, checks `/health`, and writes the actual deployed worker URL into the Godot client. Generated `wrangler.local.toml` is ignored; no credential is persisted by these scripts.

Re-export Android after deploying and applying this patch. Open Home → Profile; the real acceptance evidence is **SERVER CONNECTED** with a 12-character UID. Until a successful authenticated response is saved, the UI labels its alphanumeric local fallback as **DEVICE ID**, never a server UID. The same Google account on another device can retrieve its server UID; gameplay and player name remain local.

Publish the completed patch sequence using `publish.ps1`. It stages only the reviewed file allowlist, protects main/production and IAP sources, runs tests, commits if needed, pushes normally, verifies the remote SHA, and prints the real GitHub commit URL. It does not force-push or stage local logs, Firebase credentials, or node_modules. If the remote has advanced, resolve that branch state before publishing.

## Mail dashboard

Deploy this extension after the existing identity service:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/player_identity/deploy_mail.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/player_identity/open_mail_dashboard.ps1
```

The first script runs 40 backend tests, applies additive mail tables to the existing PROFILE_DB, installs a generated 256-bit admin secret, and deploys the existing player Worker. The key is saved with Windows DPAPI for the current Windows user in ignored `.mail-admin-key.dpapi`. Preserve that file. Reruns reuse the key; the script never prints it. The launcher copies it to the clipboard for login and opens `/admin` in a dedicated Edge/Chrome profile. It resolves the exact host through HTTPS DNS and keeps hostname certificate verification, avoiding the hotspot DNS problem without changing Windows settings. Close that dedicated browser before reopening if its DNS mapping has changed.

Re-export Android once after applying this client patch. Sign in, open Mailbox, and press SYNC SERVER MAIL. First send a small gift to your own 12-character UID and verify one claim and its dashboard acknowledgement before broadcasting.

Dashboard supports single UID or all currently registered players, server-verified preview, notice templates, immutable messages, Spirit Stone, Celestial Jade, Pavilion Seal, Refinement Shard and catalog equipment rewards, expiry up to 90 days, history, per-recipient delivery/read/claim status, and cancellation. Broadcast captures registered recipients at send time; later registrations do not receive past campaigns. Preview expires after five minutes. Supported limits: 100,000 stones, 500 shards, 50,000 recipients per campaign. Celestial Jade mail credits the existing free/local balance; paid IAP wallet authority remains separate. Equipment is granted as ownership through the existing catalog and duplicate conversion.

Admin login is rate limited and uses a four-hour HttpOnly/Secure/SameSite cookie with origin and CSRF checks. Drafts are not published until confirmed. Retries with the same request ID do not publish duplicate campaigns. Cancelled/expired mail cannot reserve a new reward, but already reserved claims remain recoverable.

Player routes verify the existing Firebase signature/project/provider/expiry contract, and require the current signed owner context. Claims reserve one receipt per owner/mail, bound to the installation. Local currency, inventory and permanent claim marker commit in the existing save journal before the client acknowledges the server. A lost response or restart can retry safely; another installation cannot fulfil the pending receipt. Pending claims must finish on the original installation. Reinstallation/reset of an unfinished claim requires a future recovery tool; automatic transfers are not implemented. Local-save tampering and cross-device wallet synchronization are outside this feature.

## Current delivery status

The user confirmed SERVER CONNECTED and stable UID after restart on the live identity service. Mail implementation and local QA are complete; mail deployment and Android acceptance require the commands above on the user's Windows machine. PowerShell scripts have been reviewed but cannot be executed in this Linux workspace. No deployment or GitHub publication is claimed from this session. `publish.ps1` runs both test suites and prints a verified GitHub commit URL after a successful normal push.

Cloudflare CLI references: https://developers.cloudflare.com/d1/wrangler-commands/ and https://developers.cloudflare.com/workers/wrangler/commands/

## Studio upgrade — admin account and operations

From Windows CMD, after applying the upgrade patch:

```bat
backend\player_identity\deploy_mail.cmd
backend\player_identity\open_mail_dashboard.cmd
```

The CMD launchers use the explicit Windows System32 PowerShell executable and absolute script paths. Deployment first parses the PowerShell scripts and runs the backend tests. It applies the additive `mail_studio_schema.sql`, preserves existing identity/mail/claim records and the DPAPI admin key, enables the minute cron in the ignored local Wrangler config, and redeploys the same player Worker. No new database or provider account is required. Unexpected existing cron configuration stops for review rather than overwriting it.

Under **Akses admin**, choose a username and a password of 12–128 characters. Login now requires only username and password; existing accounts no longer require a second factor. Bootstrap-key login remains disabled after account setup. Password changes require the current password and revoke other sessions. There is one administrator account. Preserve the protected deployment key, which supplies the server-side password pepper.

Forgotten password recovery is performed from the original deployment Windows account:

```bat
backend\player_identity\reset_mail_admin.cmd
```

Apply and deploy the password-only patch first. The reset script runs backend tests, decrypts the existing DPAPI key locally, prompts for the desired username and new password twice with hidden entry, and prepares only salted/peppered password-hash SQL. It then updates the administrator through the already-authorized Cloudflare CLI, revokes old sessions, clears legacy second-factor material/recovery codes, and records an administrator reset audit entry. Neither plaintext password nor deployment secret is printed or written to SQL; the temporary hash-only SQL is removed afterwards. UTF-8 pipe encoding preserves non-ASCII passwords. Mail, identities, recipients, claims and history are untouched. No public password-reset endpoint or universal default password is added.

Drafts persist on the server (up to 100); reopening refreshes the composer expiry, so review it before sending. Scheduling supports 1 minute–30 days ahead with mail expiry later than the schedule. The server verifies the preview and then snapshots eligible recipients at execution, not at scheduling. Cron processes at most three due jobs per invocation to stay within the D1 Free query budget. A large backlog or transient outage delays execution; no mail is delivered before its due time. Cloudflare may take time to propagate the new cron trigger. Failed and cancelled jobs remain visible. Cancelling and sending are serialized by an atomic job/campaign transaction.

Player lookup supports an exact UID or UID prefix, with history and compose shortcuts. Segments cover activity within 7/30 days, inactivity over 30 days, registration within seven days, or a reported client version. Activity is recorded only after signed mailbox requests; unknown activity is excluded from activity/inactivity segments. Version is metadata reported by the client, not proof of a trusted build. Existing clients support normal mail and activity segments immediately. Re-export with this patch for version-based segments; keep `application/config/version` aligned with Android export version, or the current 1.0.6 fallback is reported.

History filters cover title, UID, mail ID and active/expired/cancelled/pending status. CSV exports the current filtered view (up to 5,000 campaigns), aggregates counts in one SQL query and neutralizes spreadsheet formula prefixes. Cleaning history moves the filtered campaigns to a reversible archive using a cutoff; newer sends stay visible. It never removes player mail or recipient/claim records and never enables old rewards to be replayed. Single campaign archive/restore is available in its details.

Pending-case resolution closes a reviewed case **without granting or transferring rewards**. The server cannot inspect the local wallet. It requires an explicit confirmation and case note, records an audit entry, prevents future reward redelivery, and displays administrator closure separately from client acknowledgement. Existing signed receipts already downloaded on the original installation may still finish there. Lost rewards cannot safely be transferred automatically without server-authoritative wallet state; this version deliberately has no reset/regrant endpoint.

QA: 40 Node tests; browser flows through actual handler/SQLite for search, drafts, schedule/cancel, archive/restore and password-only setup/login; native Cloudflare workerd + local D1 for PBKDF2/password-only login/cookies/send/archive and actual scheduled-handler delivery. Godot import and 26 server-mail checks passed after the optional version header. Windows scripts have parser preflight and reviewed launchers, but Windows DPAPI/browser launch/live cron still require acceptance on the user's machine. No production messages, admin changes or deployment were performed in this workspace.

## Gift catalog and Studio presentation

The Studio now uses navigation tabs for composing, players, drafts/jobs, history, account and audit. Compose has icon-backed currency inputs, equipment search with rarity/slot filters, selected-item controls, and a full attachment preview. All 44 icons reuse the actual game artwork byte-for-byte. Equipment images load only as their cards approach the visible scroll area. Desktop preview stays beside the composer; phone layout stacks the panels.

Gift limits per campaign: 100,000 Spirit Stone, 10,000 Celestial Jade, 100 Pavilion Seals, 500 Refinement Shards and at most five different equipment IDs, one copy each. Catalog contains the current 40 equipment items. Unknown IDs, negative/fractional/boolean amounts, unsupported paid-currency fields and extra equipment quantities fail validation. A duplicate equipment item follows the existing rarity conversion (5/12/30/75 shards); existing ascension state is preserved. Gift ownership does not auto-equip an item or trigger a summon.

Celestial Jade and Pavilion Seals update existing local pavilion counters. The inventory, progression, local pavilion currencies and permanent mail receipt commit through the same save journal before server ACK. Pure Jade or Seal gifts work without a dummy Stone grant. Claim feedback includes actual bonus currencies and equipment icons; duplicate results display the actual shard delta. This does not credit the server-paid IAP wallet or activate parked paid-purchase/summon paths.

The client advertises `X-Jade-Mail-Features: gifts-v2`. Older clients continue receiving compatible Stone/Shard mail; new gifts remain hidden until the player exports/installs the patched client. A claim without the feature flag is denied before reservation. Existing campaign payloads and identity ownership remain unchanged. Re-export Android once before testing new rewards.

Deployment additionally runs `build_mail_assets.mjs`, copies reviewed source icons into ignored `web_assets`, and configures the same Worker ASSETS binding. The generated directory contains `.gdignore` so it does not become duplicate Godot resources. No source art edits or binary assets in the patch are needed. Static icon requests are restricted to the admin asset route and authenticated sessions. Existing credentials, cron and D1 IDs are preserved; no new database tables are required for expanded reward JSON.

Verification: 40 backend tests, 60 client gift/catalog checks and six restart checks; 531 legacy mailbox geometry checks plus 657 checks with maximum expanded attachments across nine logical sizes/two languages; 153 mailbox/Skill Book transaction regressions. Browser checks cover tabs, filters, reward selection, preview invalidation, send, draft/jobs, archive, admin login and mobile overflow. Native workerd/D1 checks cover expanded reward publication, actual authenticated static asset serving, password login and cron delivery. No production gift or deployment was performed here. Run deploy_mail.cmd and install the exported Android client for live acceptance; username/password remain unchanged.

## Pavilion banner operations — 2026-10-13

`backend\player_identity\deploy_pavilion.cmd` applies additive banner tables and redeploys the existing Worker without changing the working admin account or secret. Open the dashboard through `open_mail_dashboard.cmd` and choose **Banner gacha**. Select 1–5 shipped Legendary relics, title/subtitle, a packaged artwork preset, start/end times and base rates totaling 100%; preview before publishing. The most recently published currently-valid entry wins. Disable and rollback create audited immutable configuration revisions. Existing Wish target, target-specific Fate, pity, inventory and currency are not reset by rotation. No arbitrary equipment IDs, artwork URLs or wallet grants are accepted.

Re-export Android once for the read-only banner client. It syncs on Pavilion opening and every ~60 seconds while the view is alive, uses server-time leases and validated packaged equipment/assets, preserves an in-flight reveal and displays the same effective rates used by the local free summon roll. No valid configuration uses the embedded Nine Heavens banner. This does not enable the parked IAP/paid summon authority or add Cloud Save. Brand-new equipment/assets/mechanics need an APK update and reviewed catalog update first. See `docs/checkpoints/PAVILION_BANNERS_AND_IMPERIAL_UI_2026-10-13.md` for contract, fallback and validation details.

Run server QA: `node --test backend/player_identity/identity.test.mjs backend/player_identity/mail.test.mjs backend/player_identity/pavilion.test.mjs` (48 tests). PowerShell deployment performs parser preflight, runs those suites, builds existing dashboard icons, applies `pavilion_schema.sql` idempotently and deploys using the existing ignored `wrangler.local.toml`. Live deployment/Android acceptance require the original deployment laptop.
