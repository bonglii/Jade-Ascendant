# Same-engine health probe for persistent registration timeout

Current evidence: the user deployed the player Worker successfully (version `c8b67044-f97a-4bab-b26a-64133d0d83e5`, D1 `1089de95-8cdc-447d-a9e3-9e743d200cba`). Phone Chrome returns the expected healthy JSON, while the game still times out after transport headroom was increased. Browser success does not establish game transport or registration success.

The registration client now records its last engine stage: DNS, TCP/TLS connection, connected, request, or body. After a registration timeout, it performs a bounded ten-second GET of the same worker's `/health` endpoint through the same engine HTTP stack. The probe carries no authorization header or player information, writes nothing, and cannot register or claim an identity. Its result is shown with the original registration stage in Profile:

- `register_timeout_request__health_ok`: game GET succeeds; registration POST still timed out.
- `register_timeout_connect_tls__health_network_13_connect_tls`: both calls timed out during connection/TLS.
- `register_timeout_dns__health_network_13_dns`: engine resolving stage was observed before timeout.
- HTTP, malformed-body, and unknown stages remain explicit; a stage is an observation, not a proven root cause.

Retries and account checks remain active. Switching accounts cancels the health probe, and a stale callback cannot change another account's state. Existing server UID cache and local progress remain intact.

QA: 74 real Godot response/cache/probe checks passed with no GDScript or JSON parser errors. Probe fixtures test bounded requests, stage names, correct service identification, empty/malformed/403/timeout cases, visible diagnostic copy, and no registration from successful health alone. These fixtures do not establish authenticated Android success. Apply after Server Transport patch, re-export Android, let the timeout/probe finish, and collect the resulting Profile code.

No worker or IAP code changed; server redeployment is unnecessary for this client diagnostic update. No new local-only commit is represented as a published GitHub checkpoint.
