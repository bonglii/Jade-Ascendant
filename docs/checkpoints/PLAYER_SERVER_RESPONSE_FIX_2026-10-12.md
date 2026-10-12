# Player server response parsing and safe diagnostics

Device/editor screenshot showed JSON.parse_string errors at the registration callback. The original callback parsed every body before checking HTTP transport/status. An empty failed-request body therefore emitted a JSON engine error and obscured the actual connection failure.

The client now checks transport result, HTTP status, and body presence before JSON parsing. Malformed 200 responses use JSON.parse with a checked result. Native token strings must have JWT shape before a request starts. Token/provider messages are never printed. The profile shows fixed failure codes for network, HTTP, empty/malformed response, token, or identity-save errors; a cached server UID remains available.

Profile/client variable names that shadow Node fields/methods were cleaned. Unrelated existing IAP warnings were left within their parked scope.

Validation: 47 real Godot binding/response checks passed, including empty/non-JSON failures and a native error string rejected as a bearer token; 537 profile regression checks passed. No JSON or GDScript engine errors in these runs. These fixture results do not establish live Android authentication success. The deployed worker is unchanged and does not need redeployment. Re-export Android, inspect Profile's diagnostic state, and use that state to resolve any remaining connection problem.

Patch base is the delivered server-UID tree (original incremental or consolidated variant); no local-only commit link is fabricated.
