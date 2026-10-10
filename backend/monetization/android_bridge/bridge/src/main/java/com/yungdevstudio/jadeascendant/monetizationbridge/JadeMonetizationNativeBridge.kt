package com.yungdevstudio.jadeascendant.monetizationbridge

import android.app.Activity
import android.view.View
import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

/**
 * Jade Ascendant purchase verification transport (Cloudflare Worker candidate).
 * The Worker is deliberately LOCKED; this bridge never grants currency locally.
 * Do not enable paid IAP until ledger/replay/refund reviews and live device QA pass.
 */
class JadeMonetizationNativeBridge(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val PAID_PURCHASE_V2_ENDPOINT =
            "https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/iap/authorize-v2"
        // Native gate must remain false until real Play and 2-device QA pass.
        private const val PAID_PURCHASE_V2_TRANSPORT_APPROVED = false
        // This route is NOT wired into the deployed Worker yet (M8 staged only).
        private const val PAID_ENTITLEMENTS_ENDPOINT =
            "https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/wallet/entitlements"
        // Read-only transport intentionally not approved until verified D1 onboarding.
        private const val PAID_ENTITLEMENTS_TRANSPORT_APPROVED = false
        private const val PAID_WALLET_ENDPOINT =
            "https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/wallet/paid"
        private const val PAID_SUMMON_RECOVERY_PREFIX =
            "https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/wallet/summon-recovery/"
        // Deliberately requires an explicit reviewed Android build-time decision too.
        private const val PAID_SUMMON_RECOVERY_TRANSPORT_APPROVED = false
        private const val MAX_REPLY_BYTES = 16 * 1024
        private const val CONNECT_TIMEOUT_MS = 12_000
        private const val READ_TIMEOUT_MS = 25_000
        private val purchaseToken = Regex("^[\\x21-\\x7E]{16,4096}$")
    }

    private val busy = AtomicBoolean(false)
    private val paidWalletBusy = AtomicBoolean(false)
    private val recoveryBusy = AtomicBoolean(false)
    private val entitlementsBusy = AtomicBoolean(false)
    private val ioExecutor = Executors.newSingleThreadExecutor { job ->
        Thread(job, "jade-iap-cloudflare-transport").apply { isDaemon = true }
    }
    @Volatile private var appCheckInitialized: Boolean = false

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo(
            "purchaseAuthorityResult",
            Boolean::class.javaObjectType,
            String::class.java,
            String::class.java,
        ),
        SignalInfo(
            "paidPurchaseWalletCreditResult",
            Boolean::class.javaObjectType,
            String::class.java,
            String::class.java,
        ),
        SignalInfo(
            "paidWalletSnapshotResult",
            Boolean::class.javaObjectType,
            String::class.java,
            String::class.java,
        ),
        SignalInfo(
            "paidEntitlementsReadResult",
            Boolean::class.javaObjectType,
            String::class.java,
            String::class.java,
        ),
        SignalInfo(
            "paidSummonRecoveryResult",
            Boolean::class.javaObjectType,
            String::class.java,
            String::class.java,
        ),
    )

    override fun onMainCreate(activity: Activity?): View? {
        if (activity != null) {
            try {
                val app = try {
                    FirebaseApp.getInstance()
                } catch (_: Exception) {
                    FirebaseApp.initializeApp(activity)
                }
                if (app != null) {
                    AppCheckProviderInstall.install(app)
                    appCheckInitialized = true
                }
            } catch (_: Exception) {
                appCheckInitialized = false
            }
        }
        return super.onMainCreate(activity)
    }

    @UsedByGodot
    fun isSecurePurchaseTransportConfigured(): Boolean = appCheckInitialized

    /** Legacy pre-wallet route is permanently retired. Never return a local grant. */
    @UsedByGodot
    fun authorizePurchase(@Suppress("UNUSED_PARAMETER") purchaseTokenValue: String) {
        emitResult(false, "LEGACY_LOCAL_GRANT_RETIRED", "")
    }

    /**
     * M14 server-wallet credit transport. Separate build-time lock plus Godot
     * and Worker locks. No response is permitted to credit the local save.
     */
    @UsedByGodot
    fun isPaidWalletPurchaseV2TransportConfigured(): Boolean =
        appCheckInitialized && PAID_PURCHASE_V2_TRANSPORT_APPROVED

    @UsedByGodot
    fun authorizePaidWalletPurchaseV2(purchaseTokenValue: String) {
        if (!PAID_PURCHASE_V2_TRANSPORT_APPROVED) {
            emitPaidPurchaseResult(false, "PAID_PURCHASE_V2_LOCKED", "")
            return
        }
        if (!busy.compareAndSet(false, true)) {
            emitPaidPurchaseResult(false, "BUSY", "")
            return
        }
        if (!appCheckInitialized) {
            finishPaidPurchase(false, "APP_CHECK_NOT_READY", "")
            return
        }
        if (!purchaseToken.matches(purchaseTokenValue)) {
            finishPaidPurchase(false, "INVALID_PURCHASE_TOKEN", "")
            return
        }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) {
                finishPaidPurchase(false, "AUTH_REQUIRED", "")
                return
            }
            val requestUid = user.uid
            user.getIdToken(false).addOnCompleteListener authListener@{ task ->
                try {
                    val token = if (task.isSuccessful) task.result?.token else null
                    if (token.isNullOrBlank() || !isSameUser(requestUid)) {
                        finishPaidPurchase(false, "AUTH_TOKEN_UNAVAILABLE", "")
                        return@authListener
                    }
                    FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken()
                        .addOnCompleteListener appListener@{ app ->
                            try {
                                val appToken = if (app.isSuccessful) app.result?.token else null
                                if (appToken.isNullOrBlank() || !isSameUser(requestUid)) {
                                    finishPaidPurchase(false, "APP_CHECK_TOKEN_UNAVAILABLE", "")
                                    return@appListener
                                }
                                ioExecutor.execute {
                                    val outcome = paidPurchaseV2OverHttps(purchaseTokenValue, token, appToken)
                                    if (!isSameUser(requestUid)) {
                                        finishPaidPurchase(false, "ACCOUNT_CHANGED", "")
                                    } else {
                                        finishPaidPurchase(outcome.success, outcome.status, outcome.grantJson)
                                    }
                                }
                            } catch (_: Exception) {
                                finishPaidPurchase(false, "APP_CHECK_UNAVAILABLE", "")
                            }
                        }
                } catch (_: Exception) {
                    finishPaidPurchase(false, "FIREBASE_AUTH_UNAVAILABLE", "")
                }
            }
        } catch (_: Exception) {
            finishPaidPurchase(false, "NATIVE_UNAVAILABLE", "")
        }
    }

    /**
     * M8 read-only wallet query. Caller provides no UID or amount. Firebase
     * identity is checked before and after transport. Result is a DISPLAY
     * SNAPSHOT, never an authorization for local grant/debit/summon.
     */
    @UsedByGodot
    fun refreshPaidWalletSnapshot() {
        if (!paidWalletBusy.compareAndSet(false, true)) {
            emitPaidWalletResult(false, "BUSY", "")
            return
        }
        if (!appCheckInitialized) {
            finishPaidWallet(false, "APP_CHECK_NOT_READY", "")
            return
        }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) {
                finishPaidWallet(false, "AUTH_REQUIRED", "")
                return
            }
            val requestUid = user.uid
            user.getIdToken(false).addOnCompleteListener authListener@{ authTask ->
                try {
                    val idToken = if (authTask.isSuccessful) authTask.result?.token else null
                    if (idToken.isNullOrBlank() || !isSameUser(requestUid)) {
                        finishPaidWallet(false, "AUTH_TOKEN_UNAVAILABLE", "")
                        return@authListener
                    }
                    FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken()
                        .addOnCompleteListener checkListener@{ checkTask ->
                            try {
                                val appToken = if (checkTask.isSuccessful) checkTask.result?.token else null
                                if (appToken.isNullOrBlank() || !isSameUser(requestUid)) {
                                    finishPaidWallet(false, "APP_CHECK_TOKEN_UNAVAILABLE", "")
                                    return@checkListener
                                }
                                ioExecutor.execute {
                                    val outcome = paidWalletOverHttps(idToken, appToken)
                                    if (!isSameUser(requestUid)) {
                                        finishPaidWallet(false, "ACCOUNT_CHANGED", "")
                                    } else {
                                        finishPaidWallet(outcome.success, outcome.status, outcome.grantJson)
                                    }
                                }
                            } catch (_: Exception) {
                                finishPaidWallet(false, "APP_CHECK_UNAVAILABLE", "")
                            }
                        }
                } catch (_: Exception) {
                    finishPaidWallet(false, "FIREBASE_AUTH_UNAVAILABLE", "")
                }
            }
        } catch (_: Exception) {
            finishPaidWallet(false, "NATIVE_UNAVAILABLE", "")
        }
    }

    /** FastTrack: independently gated, signed read of paid item ownership. No local grant. */
    @UsedByGodot
    fun refreshPaidEntitlements() {
        if (!PAID_ENTITLEMENTS_TRANSPORT_APPROVED) {
            emitEntitlements(false, "PAID_ENTITLEMENTS_LOCKED", "")
            return
        }
        if (!entitlementsBusy.compareAndSet(false, true)) {
            emitEntitlements(false, "BUSY", "")
            return
        }
        if (!appCheckInitialized) {
            finishEntitlements(false, "APP_CHECK_NOT_READY", "")
            return
        }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) {
                finishEntitlements(false, "AUTH_REQUIRED", "")
                return
            }
            val uid = user.uid
            user.getIdToken(false).addOnCompleteListener authListener@{ task ->
                try {
                    val token = if (task.isSuccessful) task.result?.token else null
                    if (token.isNullOrBlank() || !isSameUser(uid)) {
                        finishEntitlements(false, "AUTH_TOKEN_UNAVAILABLE", "")
                        return@authListener
                    }
                    FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken()
                        .addOnCompleteListener checkListener@{ check ->
                            try {
                                val appToken = if (check.isSuccessful) check.result?.token else null
                                if (appToken.isNullOrBlank() || !isSameUser(uid)) {
                                    finishEntitlements(false, "APP_CHECK_TOKEN_UNAVAILABLE", "")
                                    return@checkListener
                                }
                                ioExecutor.execute {
                                    val outcome = paidEntitlementsOverHttps(token, appToken)
                                    if (!isSameUser(uid)) finishEntitlements(false, "ACCOUNT_CHANGED", "")
                                    else finishEntitlements(outcome.success, outcome.status, outcome.grantJson)
                                }
                            } catch (_: Exception) { finishEntitlements(false, "APP_CHECK_UNAVAILABLE", "") }
                        }
                } catch (_: Exception) { finishEntitlements(false, "FIREBASE_AUTH_UNAVAILABLE", "") }
            }
        } catch (_: Exception) { finishEntitlements(false, "NATIVE_UNAVAILABLE", "") }
    }

    private fun paidEntitlementsOverHttps(idToken: String, appToken: String): Outcome {
        var connection: HttpsURLConnection? = null
        return try {
            connection = URL(PAID_ENTITLEMENTS_ENDPOINT).openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.requestMethod = "GET"
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.useCaches = false
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("X-Firebase-AppCheck", appToken)
            val code = connection.responseCode
            if (code != 200) Outcome(false, when (code) {
                401 -> "ENTITLEMENTS_UNAUTHENTICATED"
                409 -> "ENTITLEMENTS_NOT_PROVISIONED"
                429 -> "ENTITLEMENTS_RATE_LIMITED"
                503 -> "ENTITLEMENTS_NOT_READY"
                else -> "ENTITLEMENTS_HTTP_FAILURE"
            }) else if (!connection.contentType.orEmpty().startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_ENTITLEMENTS_RESPONSE")
            } else {
                val json = JSONObject(String(connection.inputStream.use { readLimited(it) }, Charsets.UTF_8))
                val canonical = PaidEntitlementsContractRC.canonicalOrNull(json)
                if (canonical == null) Outcome(false, "INVALID_ENTITLEMENTS_RESPONSE")
                else Outcome(true, "PAID_ENTITLEMENTS_READ_ONLY", canonical)
            }
        } catch (_: Exception) { Outcome(false, "ENTITLEMENTS_NETWORK_UNAVAILABLE") }
        finally { connection?.disconnect() }
    }

    private fun finishEntitlements(success: Boolean, status: String, json: String) {
        entitlementsBusy.set(false)
        emitEntitlements(success, status, json)
    }
    private fun emitEntitlements(success: Boolean, status: String, json: String) {
        runOnHostThread { emitSignal("paidEntitlementsReadResult", success, status, json) }
    }

    /**
     * M12: reads a previously committed paid-summon result. Never commits,
     * debits, grants an item or writes local state. Gate deliberately CLOSED.
     */
    @UsedByGodot
    fun recoverPaidSummon(requestId: String) {
        if (!PAID_SUMMON_RECOVERY_TRANSPORT_APPROVED) {
            emitRecoveryResult(false, "RECOVERY_TRANSPORT_LOCKED", "")
            return
        }
        if (!PaidSummonRecoveryContractM12.validRequestId(requestId)) {
            emitRecoveryResult(false, "INVALID_REQUEST_ID", "")
            return
        }
        if (!recoveryBusy.compareAndSet(false, true)) {
            emitRecoveryResult(false, "BUSY", "")
            return
        }
        if (!appCheckInitialized) {
            finishRecovery(false, "APP_CHECK_NOT_READY", "")
            return
        }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) {
                finishRecovery(false, "AUTH_REQUIRED", "")
                return
            }
            val requestUid = user.uid
            user.getIdToken(false).addOnCompleteListener authListener@{ task ->
                try {
                    val token = if (task.isSuccessful) task.result?.token else null
                    if (token.isNullOrBlank() || !isSameUser(requestUid)) {
                        finishRecovery(false, "AUTH_TOKEN_UNAVAILABLE", "")
                        return@authListener
                    }
                    FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken()
                        .addOnCompleteListener appListener@{ app ->
                            try {
                                val appToken = if (app.isSuccessful) app.result?.token else null
                                if (appToken.isNullOrBlank() || !isSameUser(requestUid)) {
                                    finishRecovery(false, "APP_CHECK_TOKEN_UNAVAILABLE", "")
                                    return@appListener
                                }
                                ioExecutor.execute {
                                    val outcome = recoveryOverHttps(requestId, requestUid, token, appToken)
                                    if (!isSameUser(requestUid)) {
                                        finishRecovery(false, "ACCOUNT_CHANGED", "")
                                    } else {
                                        finishRecovery(outcome.success, outcome.status, outcome.grantJson)
                                    }
                                }
                            } catch (_: Exception) {
                                finishRecovery(false, "APP_CHECK_UNAVAILABLE", "")
                            }
                        }
                } catch (_: Exception) {
                    finishRecovery(false, "FIREBASE_AUTH_UNAVAILABLE", "")
                }
            }
        } catch (_: Exception) {
            finishRecovery(false, "NATIVE_UNAVAILABLE", "")
        }
    }

    private fun recoveryOverHttps(requestId: String, uid: String, idToken: String, appToken: String): Outcome {
        var connection: HttpsURLConnection? = null
        return try {
            connection = URL(PAID_SUMMON_RECOVERY_PREFIX + requestId.lowercase(java.util.Locale.ROOT))
                .openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.requestMethod = "GET"
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.useCaches = false
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("X-Firebase-AppCheck", appToken)
            val status = connection.responseCode
            if (status != 200) {
                Outcome(false, when (status) {
                    401 -> "RECOVERY_UNAUTHENTICATED"
                    403 -> "RECOVERY_FORBIDDEN"
                    404 -> "RECOVERY_NOT_FOUND"
                    429 -> "RECOVERY_RATE_LIMITED"
                    503 -> "RECOVERY_NOT_READY"
                    else -> "RECOVERY_HTTP_FAILURE"
                })
            } else if (!connection.contentType.orEmpty().startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_RECOVERY_RESPONSE")
            } else {
                val json = JSONObject(String(connection.inputStream.use { readLimited(it) }, Charsets.UTF_8))
                val canonical = PaidSummonRecoveryContractM12.canonicalOrNull(json, requestId, uid)
                if (canonical == null) Outcome(false, "INVALID_RECOVERY_RESPONSE")
                else Outcome(true, "PAID_SUMMON_RECOVERY_READ_ONLY", canonical)
            }
        } catch (_: Exception) {
            Outcome(false, "RECOVERY_NETWORK_UNAVAILABLE")
        } finally {
            connection?.disconnect()
        }
    }

    private fun paidWalletOverHttps(idToken: String, appToken: String): Outcome {
        var connection: HttpsURLConnection? = null
        return try {
            connection = URL(PAID_WALLET_ENDPOINT).openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.requestMethod = "GET"
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.useCaches = false
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("X-Firebase-AppCheck", appToken)
            val status = connection.responseCode
            if (status != 200) {
                Outcome(false, when (status) {
                    401 -> "WALLET_UNAUTHENTICATED"
                    403 -> "WALLET_FORBIDDEN"
                    429 -> "WALLET_RATE_LIMITED"
                    503 -> "WALLET_NOT_READY"
                    else -> "WALLET_HTTP_FAILURE"
                })
            } else if (!connection.contentType.orEmpty().startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_WALLET_RESPONSE")
            } else {
                val parsed = JSONObject(String(connection.inputStream.use { readLimited(it) }, Charsets.UTF_8))
                val canonical = PaidWalletViewContractM8.canonicalOrNull(parsed)
                if (canonical == null) Outcome(false, "INVALID_WALLET_RESPONSE")
                else Outcome(true, "WALLET_SNAPSHOT_READ_ONLY", canonical)
            }
        } catch (_: Exception) {
            Outcome(false, "WALLET_NETWORK_UNAVAILABLE")
        } finally {
            connection?.disconnect()
        }
    }

    private data class Outcome(val success: Boolean, val status: String, val grantJson: String = "")

    private fun paidPurchaseV2OverHttps(token: String, idToken: String, appToken: String): Outcome {
        var connection: HttpsURLConnection? = null
        return try {
            connection = URL(PAID_PURCHASE_V2_ENDPOINT).openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.requestMethod = "POST"
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.useCaches = false
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("X-Firebase-AppCheck", appToken)
            val bytes = JSONObject().put("purchase_token", token).toString().toByteArray(Charsets.UTF_8)
            connection.setFixedLengthStreamingMode(bytes.size)
            connection.outputStream.use { it.write(bytes) }
            val status = connection.responseCode
            if (status != 200) {
                Outcome(false, when (status) {
                    401 -> "WALLET_PURCHASE_UNAUTHENTICATED"
                    403 -> "WALLET_PURCHASE_FORBIDDEN"
                    409 -> "WALLET_PURCHASE_NOT_READY"
                    429 -> "WALLET_PURCHASE_RATE_LIMITED"
                    503 -> "WALLET_PURCHASE_BACKEND_LOCKED"
                    else -> "WALLET_PURCHASE_HTTP_FAILURE"
                })
            } else if (!connection.contentType.orEmpty().startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_WALLET_PURCHASE_RESPONSE")
            } else {
                val json = JSONObject(String(connection.inputStream.use { readLimited(it) }, Charsets.UTF_8))
                val canonical = PaidPurchaseReceiptContractM14.canonicalOrNull(json)
                if (canonical == null) Outcome(false, "INVALID_WALLET_PURCHASE_RESPONSE")
                else Outcome(true, "PAID_WALLET_SERVER_CREDITED", canonical)
            }
        } catch (_: Exception) {
            Outcome(false, "WALLET_PURCHASE_NETWORK_UNAVAILABLE")
        } finally {
            connection?.disconnect()
        }
    }

    private fun readLimited(stream: InputStream): ByteArray {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        var size = 0
        while (true) {
            val count = stream.read(buffer)
            if (count < 0) break
            size += count
            if (size > MAX_REPLY_BYTES) throw IllegalStateException("Response exceeds limit")
            out.write(buffer, 0, count)
        }
        return out.toByteArray()
    }

    private fun isSameUser(requestUid: String): Boolean = try {
        val current = FirebaseAuth.getInstance().currentUser
        current != null && current.uid == requestUid && isAllowedPurchaseUser(current)
    } catch (_: Exception) {
        false
    }

    private fun isAllowedPurchaseUser(user: FirebaseUser): Boolean {
        if (user.isAnonymous) return true
        return user.providerData.any { it.providerId == GoogleAuthProvider.PROVIDER_ID }
    }

    private fun finishPaidPurchase(success: Boolean, status: String, receiptJson: String) {
        busy.set(false)
        emitPaidPurchaseResult(success, status, receiptJson)
    }

    private fun emitPaidPurchaseResult(success: Boolean, status: String, receiptJson: String) {
        runOnHostThread { emitSignal("paidPurchaseWalletCreditResult", success, status, receiptJson) }
    }

    private fun finishRecovery(success: Boolean, status: String, payload: String) {
        recoveryBusy.set(false)
        emitRecoveryResult(success, status, payload)
    }

    private fun emitRecoveryResult(success: Boolean, status: String, payload: String) {
        runOnHostThread { emitSignal("paidSummonRecoveryResult", success, status, payload) }
    }

    private fun finishPaidWallet(success: Boolean, status: String, snapshotJson: String) {
        paidWalletBusy.set(false)
        emitPaidWalletResult(success, status, snapshotJson)
    }

    private fun emitPaidWalletResult(success: Boolean, status: String, snapshotJson: String) {
        runOnHostThread {
            emitSignal("paidWalletSnapshotResult", success, status, snapshotJson)
        }
    }

    private fun finish(success: Boolean, status: String, grantJson: String) {
        busy.set(false)
        emitResult(success, status, grantJson)
    }

    private fun emitResult(success: Boolean, status: String, grantJson: String) {
        runOnHostThread {
            emitSignal("purchaseAuthorityResult", success, status, grantJson)
        }
    }
}
