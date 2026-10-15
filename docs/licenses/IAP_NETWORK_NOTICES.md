# IAP network dependencies

OkHttp and OkHttp DNS-over-HTTPS 4.12.0, Copyright Square, Inc., Apache License 2.0.
Okio is resolved transitively through the pinned OkHttp dependency, Apache 2.0.
License text: OKHTTP_APACHE_2_0.txt. Official source: https://github.com/square/okhttp

Native Gradle and Godot Android export dependency declarations must both include
okhttp and okhttp-dnsoverhttps. A plugin AAR is not a fat AAR; copying only the AAR
without the updated export plugin does not install its new runtime dependencies.

The service URL and TLS hostname are preserved. DoH bootstrap IPs identify the
fixed resolvers, not pinned game-service addresses. Platform certificate and
hostname verification remain enabled. No permissive trust manager or hostname
verifier is shipped; test certificates/trust roots exist only in JVM tests.
