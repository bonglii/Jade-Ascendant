# Celestial Gate + automatic mail — 2026-10-14

User-approved entrance preview implemented as separate scenic background, transparent wordmark, generated carved jade button texture and native responsive panel. Removed the duplicated title/studio line, condensed login status, moved truthful device-local save copy below the panel. Google becomes primary when the existing provider reports ready; Guest is primary otherwise. Disabled/busy/anonymous-preparation states retain existing semantics. Existing restored Google sessions bypass entry; Guest still reaches actual Home. Authentication transport, credentials, cloud-save capability, progression and paid gates are unchanged.

Portrait uses a centered compact lower panel; landscape uses logo/art left and account panel right. Font size follows a stable layout value, not an entrance animation. Only panel opacity fades0.28s, disabled with Reduced Effects. Container minimum-size changes settle wrapped content within safe area. Body/status remain native and localized. Title uses an OS serif font with normal fallback. Character/fox placement was adjusted after native render showed the first background's feet below the panel.

## Automatic mail

- Removed manual Sync button entirely; Inbox/reader toggle and status remain.
- Automatic list refresh every180s after a successful final page;15s heartbeat checks due time without doing network work on each heartbeat.
- Opening mailbox or resuming/focusing the app refreshes when the last successful cache is at least30s old; healthy fresh cache is reused.
- Minimum15s between list starts; no overlapping list while refresh/pagination is active. Repeated profile events/reopens do not flood requests.
- Failures retry after60/120/240/300s; later failures remain capped300s. Reopen/focus does not bypass failure backoff. Successful final page resets failure count and schedules180s.
- No new list starts while backgrounded. Already pending durable delivery/ACK behavior remains unchanged. This is foreground app polling, not a background OS notification service.
- Account switch/logout cancels pending old-owner work and resets sync clocks/backoff. Existing owner-scoped cache, receipt/journal, immutable mail rewards and auth renewal checks stay authoritative.
- Existing letter signature/scroll restoration preserves the open letter and its offset across sync. Cached mail remains readable offline. Claim/delete/read remain deliberate actions; no automatic reward grant was introduced.

## Validation

Godot4.7.2 Linux, isolated QA profiles, native OpenGL rendering. New suite260checks covers two locales,five viewport sizes(320x568,390x844,648x1152,896x504,1280x800), unavailable/ready/busy/anonymous-preparation states, safe panel/footer bounds,48px minimum targets, logo uniqueness, primary order, pure scheduler clocks/backoff, successful page reset, absent manual sync, actual Guest navigation, restored-session navigation and unchanged progression.

Affected regression: mailbox paper533,server mail26,gifts77+restart6,menu performance/touch33. Total935 completed checks, no assertion failures or SCRIPT ERROR in final logs. Existing ObjectDB/resource shutdown diagnostics remain. Native renders inspected. Phone auth/network/notification delivery and Windows PowerShell execution are not claimed as tested here.

## Delivery and publication

Local base is Ascendant Arsenal1b43bb781cd0f8bea37a93f2e3085f6301502c6b. Bundle contains an incremental patch and a combined Quiet Results995cd667a12bc75399906d486fd0662b2df8b2ab-to-current patch, plus a CMD/PowerShell preflight selecting the matching package. Both are tested against clean base trees. Installer protects main, checks before applying, detects already-installed package and never force-applies/reject-splits. Existing unrelated edits are preserved. Publisher extends the accepted checkpoint allowlist, uses explicit remote fetch refspec and verifies pushed SHA before printing the GitHub commit URL. No backend/server deployment is required for this client-only batch.

Preventive notes:
- Do not infer whether the immediately preceding Arsenal patch was installed; preflight actual files and offer compatible bundle paths.
- Native panel heights/touch targets can differ from concept raster. Inspect production render before finalizing character composition and nine-slice endcaps.
- GDScript accepts shorthand decimal literals that Godot scene-resource text does not. Use leading zeroes in `.tscn` Color values.
- QA project must expose backend catalog for gift tests; use typed-array append instead of assigning an untyped Array to the typed incoming-page field.
