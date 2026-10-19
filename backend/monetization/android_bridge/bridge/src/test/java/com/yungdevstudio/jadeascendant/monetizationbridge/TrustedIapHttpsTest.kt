package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Test
import org.junit.Assert.*
import okhttp3.Dns
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.SocketPolicy
import okhttp3.tls.HeldCertificate
import okhttp3.tls.HandshakeCertificates
import java.net.InetAddress
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class TrustedIapHttpsTest {
    private val host = "jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev"
    private fun dns(vararg ips: String) = object: Dns { override fun lookup(hostname: String) = ips.map { InetAddress.getByName(it) } }
    private fun broken() = object: Dns { override fun lookup(hostname: String): List<InetAddress> { throw java.net.UnknownHostException("fixture") } }
    @Test fun encryptedLookupWinsOverPoisonedSystemDns() {
        val route=AtomicReference("");val d=TrustedIapDns(host,listOf(dns("104.21.21.160")),dns("108.137.176.189"),route)
        assertEquals("104.21.21.160",d.lookup(host).single().hostAddress);assertEquals("doh_primary",route.get())
    }
    @Test fun encryptedAndSystemFallbackAreBoundedAndRejectPrivateAddresses() {
        val route=AtomicReference("");val d=TrustedIapDns(host,listOf(dns("127.0.0.1"),dns("172.67.199.90")),dns("8.8.8.8"),route)
        assertEquals("172.67.199.90",d.lookup(host).single().hostAddress);assertEquals("doh_secondary",route.get())
        val s=TrustedIapDns(host,listOf(broken(),broken()),dns("1.2.3.4"),route)
        assertEquals("1.2.3.4",s.lookup(host).single().hostAddress);assertEquals("system",route.get())
        try { TrustedIapDns(host,listOf(broken()),dns("192.168.0.1"),route).lookup(host);fail() } catch (_:java.net.UnknownHostException) {}
        assertEquals("unavailable",route.get())
        try { d.lookup("attacker.invalid");fail() } catch (_:java.net.UnknownHostException) {}
    }
    @Test fun privateAndDocumentationRangesAreNotTargets() {
        for (ip in listOf("0.0.0.0","10.1.2.3","127.0.0.1","100.64.1.1","169.254.1.1","172.16.0.1","192.168.0.1","192.0.2.1","198.18.1.1","198.51.100.1","203.0.113.1","224.0.0.1","::1","fc00::1","fe80::1","2001:db8::1"))
            assertFalse(ip,TrustedIapDns.publicAddress(InetAddress.getByName(ip)))
        assertTrue(TrustedIapDns.publicAddress(InetAddress.getByName("2606:4700::1111")))
    }
    private fun withServer(certHost: String=host, trusted: Boolean=true, run:(MockWebServer,TrustedIapHttps,String)->Unit) {
        val certificate=HeldCertificate.Builder().commonName(certHost).addSubjectAlternativeName(certHost).build()
        val serverTls=HandshakeCertificates.Builder().heldCertificate(certificate).build()
        MockWebServer().use { server ->
            server.useHttps(serverTls.sslSocketFactory(),false);server.start()
            val builder=OkHttpClient.Builder().dns(dns("127.0.0.1")).followRedirects(false).followSslRedirects(false)
                .retryOnConnectionFailure(false).callTimeout(2,TimeUnit.SECONDS).protocols(listOf(Protocol.HTTP_1_1))
            if(trusted) {val tls=HandshakeCertificates.Builder().addTrustedCertificate(certificate.certificate).build();builder.sslSocketFactory(tls.sslSocketFactory(),tls.trustManager)}
            val client=builder.build()
            try {run(server,TrustedIapHttps(host,client,server.port),"https://$host:${server.port}/v1/qa")}
            finally {client.connectionPool.evictAll();client.dispatcher.executorService.shutdownNow()}
        }
    }
    @Test fun realTlsKeepsOriginalHostAndCredentialsAndBoundsResponse() = withServer { server,api,url ->
        server.enqueue(MockResponse().setHeader("Content-Type","application/json").setBody("{}"))
        val reply=api.execute(url,"POST","{}".toByteArray(),"auth-fixture","app-fixture")
        assertEquals(200,reply.code);assertEquals("{}",String(reply.bytes));val request=server.takeRequest()
        assertEquals("Bearer auth-fixture",request.getHeader("Authorization"));assertEquals(host+":"+server.port,request.getHeader("Host"))
        server.enqueue(MockResponse().setHeader("Content-Type","application/json").setBody("x".repeat(17000)))
        try {api.execute(url,"GET",null,"a","b");fail()} catch (_:IOException) {}
    }
    @Test fun ledgerRepairPostHasNoPayloadOrContentType() = withServer { server,api,url ->
        server.enqueue(MockResponse().setHeader("Content-Type","application/json").setBody("{}"))
        assertEquals(200,api.execute(url,"POST",null,"a","b").code)
        val request=server.takeRequest()
        assertEquals(0L,request.bodySize);assertNull(request.getHeader("Content-Type"))
        assertEquals("0",request.getHeader("Content-Length"))
    }
    @Test fun redirectsDoNotForwardTokens() = withServer { server,api,url ->
        server.enqueue(MockResponse().setResponseCode(302).setHeader("Location","https://attacker.invalid/steal"))
        val response=api.execute(url,"POST","{}".toByteArray(),"a","b")
        assertEquals(302,response.code);assertEquals(0,response.bytes.size);assertEquals(1,server.requestCount)
    }
    @Test fun postIsNotSilentlyRetriedWhenResponseIsLost() = withServer { server,api,url ->
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AFTER_REQUEST))
        server.enqueue(MockResponse().setBody("{}"))
        try {api.execute(url,"POST","{}".toByteArray(),"a","b");fail()} catch (_:IOException) {}
        assertEquals(1,server.requestCount)
    }
    @Test fun untrustedCertificateFailsBeforeHttp() = withServer(trusted=false) { server,api,url ->
        try {api.execute(url,"GET",null,"a","b");fail()} catch (_:IOException) {}
        assertEquals(0,server.requestCount)
    }
    @Test fun wrongHostnameFailsBeforeHttp() = withServer(certHost="wrong.invalid") { server,api,url ->
        try {api.execute(url,"GET",null,"a","b");fail()} catch (_:IOException) {}
        assertEquals(0,server.requestCount)
    }
    @Test fun endpointPolicyRejectsCrossHostQueryAndPlaintext() = withServer { server,api,url ->
        for (target in listOf(url.replace(host,"attacker.invalid"),url.replace("https:","http:"),url+"?uid=other",url+"#fragment")) {
            try {api.execute(target,"GET",null,"a","b");fail()} catch (_:IllegalArgumentException) {}
        }
        assertEquals(0,server.requestCount)
    }
    @Test fun odysseyV2AndV3GetUseTrustedTlsTransport() = withServer { server,api,url ->
        for (path in listOf("/v2/odyssey", "/v3/odyssey", "/v4/odyssey")) {
            server.enqueue(MockResponse().setHeader("Content-Type","application/json").setBody("{}"))
            assertEquals(200,api.execute(url.replace("/v1/qa",path),"GET",null,"auth-fixture","app-fixture").code)
            val request=server.takeRequest()
            assertEquals(path,request.path)
            assertEquals("Bearer auth-fixture",request.getHeader("Authorization"))
        }
    }
    @Test fun odysseyCommandPostKeepsBodyAndRunsOnce() = withServer { server,api,url ->
        server.enqueue(MockResponse().setHeader("Content-Type","application/json").setBody("{}"))
        val payload="{\"action\":{\"kind\":\"roll\"}}"
        assertEquals(200,api.execute(url.replace("/v1/qa","/v3/odyssey"),"POST",payload.toByteArray(),"a","b").code)
        assertEquals(payload,server.takeRequest().body.readUtf8());assertEquals(1,server.requestCount)
    }
    @Test fun odysseyPathAllowanceDoesNotOpenOtherVersionsOrSubpaths() = withServer { server,api,url ->
        for (path in listOf("/v2/wallet","/v3/wallet","/v3/odyssey/other","/v4/wallet","/v4/odyssey/other","/v3/odyssey?uid=other","/v3/odyssey#fragment","/v3/%6fdyssey")) {
            try { api.execute(url.replace("/v1/qa",path),"GET",null,"a","b");fail(path) } catch (_:IllegalArgumentException) {}
        }
        assertEquals(0,server.requestCount)
    }

}
