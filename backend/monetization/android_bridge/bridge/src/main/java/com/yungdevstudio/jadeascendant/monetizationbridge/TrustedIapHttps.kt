package com.yungdevstudio.jadeascendant.monetizationbridge

import okhttp3.Dns
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.dnsoverhttps.DnsOverHttps
import java.net.InetAddress
import java.net.UnknownHostException
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Fixed-service HTTPS: original hostname/SNI, platform trust, no redirects or POST retries. */
internal class TrustedIapHttps(private val host: String,
    private val client: OkHttpClient = productionClient(host), private val port: Int = 443) {
    data class Reply(val code: Int, val contentType: String, val bytes: ByteArray)
    fun execute(endpoint: String, method: String, bytes: ByteArray?, auth: String, appCheck: String): Reply {
        val url = endpoint.toHttpUrl()
        require(url.isHttps && url.host == host && url.port == port && url.username.isEmpty() && url.password.isEmpty()
            && url.fragment == null && url.query == null && url.encodedPath.startsWith("/v1/"))
        require(method in setOf("GET", "POST") && (method != "GET" || bytes == null))
        require(bytes == null || bytes.size <= 8192)
        val body = if (method == "POST") {
            if (bytes == null) ByteArray(0).toRequestBody(null)
            else bytes.toRequestBody("application/json; charset=utf-8".toMediaType())
        } else null
        val request = Request.Builder().url(url).method(method, body)
            .header("Accept", "application/json").header("Authorization", "Bearer $auth")
            .header("X-Firebase-AppCheck", appCheck).build()
        return client.newCall(request).execute().use { response ->
            // Never follow a redirect with account credentials, nor read unbounded error HTML.
            if (response.code != 200) return@use Reply(response.code, "", ByteArray(0))
            val type = response.header("Content-Type").orEmpty()
            val bodyStream = response.body ?: throw IOException("empty_reply")
            if (bodyStream.contentLength() > MAX_REPLY) throw IOException("reply_too_large")
            val data = bodyStream.byteStream().use { input ->
                val out = java.io.ByteArrayOutputStream()
                val block = ByteArray(2048)
                while (true) {
                    val n = input.read(block)
                    if (n < 0) break
                    if (out.size() + n > MAX_REPLY) throw IOException("reply_too_large")
                    out.write(block, 0, n)
                }
                out.toByteArray()
            }
            Reply(response.code, type, data)
        }
    }
    companion object {
        const val MAX_REPLY = 16384
        private const val STAGING_HOST = "jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev"
        val dnsRoute = AtomicReference("not_attempted")
        private fun baseClient(): OkHttpClient = OkHttpClient.Builder()
            .followRedirects(false).followSslRedirects(false).retryOnConnectionFailure(false)
            .connectTimeout(6, TimeUnit.SECONDS).readTimeout(10, TimeUnit.SECONDS)
            .callTimeout(25, TimeUnit.SECONDS).build()
        private fun productionClient(host: String): OkHttpClient {
            require(host == STAGING_HOST) { "unapproved_iap_host" }
            val bootstrap = baseClient().newBuilder().callTimeout(5, TimeUnit.SECONDS).build()
            fun doh(url: String, ip: ByteArray): Dns = DnsOverHttps.Builder().client(bootstrap)
                .url(url.toHttpUrl()).includeIPv6(false)
                .bootstrapDnsHosts(InetAddress.getByAddress(ip)).build()
            val primary = doh("https://cloudflare-dns.com/dns-query", byteArrayOf(1,1,1,1))
            val secondary = doh("https://dns.google/dns-query", byteArrayOf(8,8,8,8))
            return baseClient().newBuilder().dns(TrustedIapDns(host, listOf(primary, secondary), Dns.SYSTEM, dnsRoute)).build()
        }
    }
}

/** Injectable DNS boundary for tests. Service credentials are never sent to resolvers. */
internal class TrustedIapDns(private val host: String, private val encrypted: List<Dns>,
    private val system: Dns, private val route: AtomicReference<String>) : Dns {
    override fun lookup(hostname: String): List<InetAddress> {
        if (hostname != host) throw UnknownHostException("unapproved_iap_host")
        for ((index, resolver) in encrypted.withIndex()) {
            val addresses = try { resolver.lookup(hostname).filter(::publicAddress).distinct().take(4) } catch (_: Exception) { emptyList() }
            if (addresses.isNotEmpty()) { route.set(if (index == 0) "doh_primary" else "doh_secondary"); return addresses }
        }
        val fallback = try { system.lookup(hostname).filter(::publicAddress).distinct().take(4) } catch (_: Exception) { emptyList() }
        if (fallback.isNotEmpty()) { route.set("system"); return fallback }
        route.set("unavailable"); throw UnknownHostException("iap_dns_unavailable")
    }
    companion object {
        fun publicAddress(value: InetAddress): Boolean {
            val a = value.address.map { it.toInt() and 255 }
            if (a.size == 16) {
                // Global unicast only; no unique/link local, loopback or documentation range.
                return a[0] and 224 == 32 && !(a[0] == 32 && a[1] == 1 && a[2] == 13 && a[3] == 184)
            }
            if (a.size != 4) return false
            if (a[0] in listOf(0,10,127) || a[0] >= 224) return false
            if (a[0] == 100 && a[1] in 64..127 || a[0] == 169 && a[1] == 254 || a[0] == 172 && a[1] in 16..31) return false
            if (a[0] == 192 && (a[1] == 168 || a[1] == 0 && a[2] in listOf(0,2))) return false
            if (a[0] == 198 && (a[1] in listOf(18,19) || a[1] == 51 && a[2] == 100)) return false
            return !(a[0] == 203 && a[1] == 0 && a[2] == 113)
        }
    }
}
