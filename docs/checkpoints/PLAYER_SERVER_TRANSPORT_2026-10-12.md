# Registration timeout transport update

Phone screenshot reports `network_13`: Godot HTTPRequest.RESULT_TIMEOUT, not an authentication rejection. The previous client had a 12-second total request deadline and unthreaded polling.

Changes: threaded HTTPRequest, a bounded 30-second deadline, explicit Godot User-Agent/JSON Accept headers, and always-processing transport during gameplay pause. TLS verification, signed Firebase identity, account-response matching, body limits, redirect rejection, and retry backoff remain intact. Profile names a timeout explicitly.

Validation: 53 Godot response/cache/transport checks passed, including timeout handling, finite deadline, threaded transport, pause processing mode, and UI timeout copy. The deployed health route returned `ready: true`; live unauthenticated and invalid-signature POST probes returned 401 JSON as expected. These probes used the environment's HTTPS proxy, took roughly 8–9 seconds including network/proxy overhead, and did not write identities. They are not a measurement of server compute time or the phone's network latency. Direct-egress Godot probing in this environment failed (result 3); this runtime has an HTTPS proxy and cannot establish equivalent direct Android connectivity.

The patch improves transport headroom and scheduling; it does not establish the root cause of the phone's timeout or prove authenticated Android registration. If the phone still reports network_13, open the same deployed `/health` URL in Chrome on that phone and network to distinguish service reachability from the app transport. No server code changed; apply after Server Response Fix and re-export Android.

References: https://docs.godotengine.org/en/stable/classes/class_httprequest.html
