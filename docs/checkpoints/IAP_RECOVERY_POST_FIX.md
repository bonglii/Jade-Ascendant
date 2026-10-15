# Recovery zero-byte POST compatibility — 2026-10-16

Device evidence: confirmed wallet 0 / read-only snapshot success, refund schema and monitor both ready, but repair stage unavailable. The legacy client allowlist hides INVALID_REQUEST and several other fixed native outcomes. This report alone does not prove the exact HTTP response.

Concrete reproducible defect: recovery rejected every non-null Request.body even when the POST carried zero bytes. Native HTTPS intentionally constructs a zero-length POST body; HTTP runtimes may expose it as an empty stream. A test using Content-Length:0 plus body:'' returned 400 before this fix, and 200 after. This is consistent with the hidden INVALID_REQUEST outcome; live response must still be checked after deployment.

Accept only truly empty POSTs: reject positive/invalid lengths, query parameters and any non-empty chunk; wait at most one second and inspect at most eight empty chunks without buffering arbitrary data. Cancel/release the stream on exit. Keep Firebase identity, App Check, server-only ledger ownership, refund and atomic credit guards unchanged. Server emits JADE_IAP_REPAIR status=<number> stage=<fixed server label>, with no accounts, tokens, Google bodies or ledger payloads.

Client source preserves all fixed native recovery error labels instead of turning INVALID_REQUEST into unavailable. This reporting change takes effect on the next normal export. The server fix can be tested using the current APK; its successful SERVER_LEDGER_RECONCILED status was already recognized.

Validation: backend 437 tests passed; new zero-byte/replay test failed with HTTP400 before and passed after; non-empty body disguised as length0 and nonterminating streams remain rejected. Empty-ledger repair returns zero verified/zero recovered without inventing wallet ownership. Existing ledger replay/refund tests remain intact. Godot server Jade delivery 31 checks passed with no ERROR output. Local fixtures are not Android purchase evidence.

Next: scoped backed-up replacements, publisher, staging Worker-only deploy, then live tail and press RESTORE. This is an on-demand POST; no cron wait required. Need server 200/server_reconciled and matching device response. Zero recovered purchases is not proof an old consumed transaction can be restored if it never entered the verified server ledger. No purchase, migration, native AAR, secret, production or save changes are performed.
