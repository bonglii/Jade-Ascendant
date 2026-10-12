# Targeted IPv4 route for the observed connect/TLS stall

Phone evidence: `register_timeout_connect_tls__health_network_13_connect_tls`; Chrome on the same phone returned the expected health JSON. Both game GET and registration POST stalled before the HTTP request phase. This identifies the layer that failed, but does not prove IPv6 itself is the root cause.

The client now resolves the trusted endpoint using a bounded asynchronous IPv4-only DNS query before registration. It connects to a DNS-derived address while retaining the original hostname for TLS certificate verification, SNI, and the HTTP Host header. No IP is hardcoded, certificate checking is not disabled, default CA trust remains, and redirects remain blocked. Up to four unique IPv4 addresses are retained in memory for five minutes; a failed health transport advances to the next address. If IPv4 DNS is unavailable, the original hostname route remains available. Account switching cancels the resolver and existing requests; each attempt gets a token for the current account.

Diagnostics distinguish the IPv4 route from the hostname route. Successful health remains only a connectivity check; it cannot allocate or display a server UID. Firebase verification and SQL uniqueness remain unchanged, and this patch does not alter IAP, rewards, gameplay, or save identity.

Validation:

- 84 real Godot response/cache/route checks passed: IPv4 selection/deduplication, endpoint path, hostname override, default CA trust, safe TLS, alternate-address limit, hostname fallback, and prior account/response cases.
- Three real loopback HTTPS cases passed using Godot HTTPRequest and a disposable test certificate: correct trusted hostname succeeds; wrong hostname is rejected; an untrusted certificate is rejected by the production default trust setting. Captured SNI and HTTP Host matched the original server hostname. The loopback test used a nonprivileged test port and did not contact the production database.
- Phone registration success is still pending. Apply after Connection Probe, re-export Android, and verify SERVER CONNECTED. If it still fails, retain the resulting IPv4 stage code as evidence; do not reapply timeout/parser/UID changes.

Server redeployment is unnecessary. GitHub publication remains through the user's verified publishing script; no local-only commit link is fabricated.

TLS API reference: https://docs.godotengine.org/en/stable/classes/class_tlsoptions.html
