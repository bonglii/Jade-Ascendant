# Player identity authentication diagnosis

After Android Private DNS changed, Profile registration reached the Worker and returned HTTP 401. Google logout/login did not resolve it. Android permissions and relative clock are confirmed; DNS-selected endpoint routing was separately isolated with strict-TLS curl. No authenticated server UID success is claimed.

The previous profile route reused an opaque InvalidIdentity error which also masked a failed Google JWKS fetch as 401. Isolate profile-only labeling in auth.mjs while retaining the existing RSA verifier and signature requirement. Emit only fixed JADE_PLAYER_AUTH stage codes, never token/header/claims/account content. Keep public error responses generic. Key endpoint transport/HTTP/format unavailability becomes 503, rather than accusing user credentials. Invalid credentials remain 401 and cannot reach UID allocation.

Labels: server_project, bearer_format, token_format, token_header, token_issuer, token_audience, token_expired, token_issued_time, token_subject, token_auth_time, token_provider, token_signing_key, token_signature_or_cached_key, keys_transport, keys_http, keys_format. Cached-key rejection cannot be narrowed further without a fresh lookup; the label deliberately preserves that ambiguity. JWT metadata used for labels is not trusted for identity.

Validation: 13 Node tests passed, including real RSA signature acceptance/forgery rejection, SQLite uniqueness/concurrency, issuer/audience/expiry/provider rejection, unavailable key services, unknown key denial, fixed log messages and no allocation after auth failures. This does not confirm the live phone token. Shared monetization/IAP verifier, Android source, Worker TLS settings and database schema are unchanged.

Deployment from Windows repository root after applying the patch:

```cmd
node --test backend/player_identity/identity.test.mjs && npx --yes wrangler@4 deploy --config backend/player_identity/wrangler.local.toml
npx --yes wrangler@4 tail jade-ascendant-player --config backend/player_identity/wrangler.local.toml --format pretty
```

Wait for the tail connection, retry Profile Connect on the phone, copy the JADE_PLAYER_AUTH stage line, then Ctrl+C. No Android export is needed. The ignored wrangler.local.toml comes from the user's already-successful deployment and preserves the existing database binding. No commit is created because remote publishing credentials remain unavailable; do not present a fabricated GitHub URL.
