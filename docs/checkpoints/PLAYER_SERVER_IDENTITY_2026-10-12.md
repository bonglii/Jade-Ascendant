# Server-backed alphanumeric player UID

Incremental patch base: short-UID patch `f7dac6e`. No new local commit is made for this delivery: the user's new rule requires a real GitHub link per commit, and this session cannot publish through the current integration.

Recovery delivery: `Jade-Ascendant-Server-UID-From-Batch3.patch` consolidates Short UID and server identity directly from original Batch 3 (`43bd6bf`). Use this variant when the incremental patch fails on the player identity manager and profile test. A failed `git apply --check` does not install the deployment script. Deployment must be chained only after successful apply.

## Implemented

- Separate `jade-ascendant-player` Cloudflare Worker and `jade-player-identities` D1 database, with pinned Firebase Auth verification. Public UID is 12 letters/numbers, without punctuation. Unique SQL constraints prevent duplicate UIDs and multiple assignments to an account; concurrent requests converge and collisions retry.
- Godot uses the existing Firebase addon's ID-token callback and a dedicated HTTPRequest. Tokens are memory-only, redirects are disabled, responses are bounded, and timeout/backoff avoids continuous requests. No new IAP/native bridge methods are required.
- Registration is automatic when a Firebase identity is available. The response must match the pending authenticated owner and current native session. The identity is displayed only after its cache commits. Late responses from a switched account cannot overwrite or expose another account's UID.
- Per-account cached server UIDs survive profile reload. Offline cache and the alphanumeric local fallback are distinguished in the UI. Account changes switch only the identity display; gameplay/name remain local. Google linking preserves UID only when it preserves the Firebase subject; anonymous profiles are not cross-device accounts.
- Scripts create/reuse only the player database, deploy only this worker, validate health, update the client's actual endpoint, and publish only reviewed patch files to the checkpoint branch. The publish script prints a commit URL only after remote SHA verification.
- Working rules are persisted in AGENTS.md. Mistakes and preventive actions are recorded in LESSONS.md. Earlier UI checkpoint Markdown whitespace was cleaned to keep the full publish range valid.

## Validation

- Node real RSA JWT and real SQLite integration: 9 tests passed. Includes token signature/issuer/audience/provider/expiry, denied auth, invalid payloads, error sanitization, same-owner races, 100 independent owners, UID collisions, and bounded exhaustion.
- Godot profile regression: 537 checks passed.
- Godot server binding/transport callback fixture: 32 checks passed. Includes real JSON number parsing, malformed/mismatched responses, write failure, cached UID, account switch, late response isolation, and eight untouched gameplay saves. This fixture simulates server responses; it is not a live Android connection.
- OpenGL profile rendering inspected using a saved server-response fixture; exact UID clipboard and label fit checked. Desktop/native keyboard validation remains distinct from Android device review.

## Outstanding external execution

This environment has no Cloudflare deployment credential, Wrangler login, or writable GitHub session. A server has not been deployed and no live authenticated Android registration is claimed. Windows PowerShell scripts were reviewed but could not execute in this Linux runtime. Deploy from the user's existing Cloudflare login, re-export Android, and verify `SERVER CONNECTED` with a 12-character UID. Then use the publishing script to get the actual GitHub link.

Player registry only: no mail rewards, economy, wallet, IAP, cloud-save, or admin writes are enabled. The next batch can build authenticated targeted mail on this registry.
