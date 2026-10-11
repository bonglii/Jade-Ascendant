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
        private val PAID_PURCHASE_V2_ENDPOINT =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/iap/authorize-v2"
        // Native gate must remain false until real Play and 2-device QA pass.
        private const val PAID_PURCHASE_V2_TRANSPORT_APPROVED = false
        // This route is NOT wired into the deployed Worker yet (M8 staged only).
        private val PAID_ENTITLEMENTS_ENDPOINT =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/wallet/entitlements"
        // Read-only transport intentionally not approved until verified D1 onboarding.
        private const val PAID_ENTITLEMENTS_TRANSPORT_APPROVED = false
        private val PAID_WALLET_ENDPOINT =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/wallet/paid"
        private val PAID_SUMMON_RECOVERY_PREFIX =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/wallet/summon-recovery/"
        // Deliberately requires an explicit reviewed Android build-time decision too.
        private const val PAID_SUMMON_RECOVERY_TRANSPORT_APPROVED = false
        private val PAID_LOADOUT_ENDPOINT =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/wallet/paid-loadout"
        private val PAID_RECOVERY_INDEX_ENDPOINT =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/wallet/summon-recovery-index"
        private val PAID_VERIFIED_REPAIR_ENDPOINT =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/iap/recover-verified"
        private const val PAID_VERIFIED_REPAIR_APPROVED = false
        private const val PAID_LOADOUT_READ_APPROVED = false
        private const val PAID_LOADOUT_WRITE_APPROVED = false
        private const val RECOVERY_INDEX_READ_APPROVED = false
        private val PAID_SUMMON_ENDPOINT =
            "${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/wallet/summon"
        private const val PAID_SUMMON_TRANSPORT_APPROVED = false
        private const val MAX_REPLY_BYTES = 16 * 1024
        private const val CONNECT_TIMEOUT_MS = 12_000
        private const val READ_TIMEOUT_MS = 25_000
        private val purchaseToken = Regex("^[\\x21-\\x7E]{16,4096}$")
    }

    private val busy = AtomicBoolean(false)
    private val paidWalletBusy = AtomicBoolean(false)
    private val recoveryBusy = AtomicBoolean(false)
    private val entitlementsBusy = AtomicBoolean(false)
    private val loadoutBusyRC6 = AtomicBoolean(false)
    private val historyBusyRC6 = AtomicBoolean(false)
    private val purchaseRepairBusy = AtomicBoolean(false)
    private val paidSummonBusy = AtomicBoolean(false)
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
        SignalInfo(
            "paidLoadoutReadResult", Boolean::class.javaObjectType, String::class.java, String::class.java,
        ),
        SignalInfo(
            "paidLoadoutWriteResult", Boolean::class.javaObjectType, String::class.java, String::class.java,
        ),
        SignalInfo(
            "paidSummonHistoryIndexResult", Boolean::class.javaObjectType, String::class.java, String::class.java,
        ),
        SignalInfo(
            "paidVerifiedPurchaseRepairResult", Boolean::class.javaObjectType, String::class.java, String::class.java,
        ),
        SignalInfo(
            "paidSummonCommitResult",
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
    // Debug-only sandbox credit; all release AARs and normal builds fail closed.
    private fun sandboxCreditEnabled(): Boolean =
        BuildConfig.DEBUG &&
        BuildConfig.JADE_IAP_TARGET == "staging" &&
        BuildConfig.JADE_IAP_STAGING_CREDIT_ENABLED &&
        BuildConfig.JADE_IAP_WORKER_BASE_URL == "https://jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev"

    @UsedByGodot
    fun isSandboxIapCreditEnabled(): Boolean = sandboxCreditEnabled()

    @UsedByGodot
    fun isPaidWalletPurchaseV2TransportConfigured(): Boolean =
        appCheckInitialized && (PAID_PURCHASE_V2_TRANSPORT_APPROVED || sandboxCreditEnabled())

    @UsedByGodot
    fun authorizePaidWalletPurchaseV2(purchaseTokenValue: String) {
        if (!PAID_PURCHASE_V2_TRANSPORT_APPROVED && !sandboxCreditEnabled()) {
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

    /** RC4 paid summon: caller MUST persist the same UUID before invoking this. */
    @UsedByGodot
    fun isPaidSummonTransportConfigured(): Boolean = appCheckInitialized && PAID_SUMMON_TRANSPORT_APPROVED

    @UsedByGodot
    fun commitPaidSummon(requestId: String, pullCount: Int) {
        if (!PAID_SUMMON_TRANSPORT_APPROVED) { emitPaidSummonResult(false, "PAID_SUMMON_LOCKED", ""); return }
        if (!PaidSummonRecoveryContractM12.validRequestId(requestId) || pullCount !in setOf(1, 10)) {
            emitPaidSummonResult(false, "INVALID_SUMMON_REQUEST", ""); return
        }
        if (!paidSummonBusy.compareAndSet(false, true)) { emitPaidSummonResult(false, "BUSY", ""); return }
        if (!appCheckInitialized) { finishPaidSummon(false, "APP_CHECK_NOT_READY", ""); return }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) { finishPaidSummon(false, "AUTH_REQUIRED", ""); return }
            val uid = user.uid
            user.getIdToken(false).addOnCompleteListener authListener@{ task ->
                try {
                    val token = if (task.isSuccessful) task.result?.token else null
                    if (token.isNullOrBlank() || !isSameUser(uid)) { finishPaidSummon(false, "AUTH_TOKEN_UNAVAILABLE", ""); return@authListener }
                    FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken().addOnCompleteListener appListener@{ check ->
                        try {
                            val appToken = if (check.isSuccessful) check.result?.token else null
                            if (appToken.isNullOrBlank() || !isSameUser(uid)) {
                                finishPaidSummon(false, "APP_CHECK_TOKEN_UNAVAILABLE", ""); return@appListener
                            }
                            ioExecutor.execute {
                                val result = paidSummonOverHttps(requestId, pullCount, uid, token, appToken)
                                if (!isSameUser(uid)) finishPaidSummon(false, "ACCOUNT_CHANGED", "")
                                else finishPaidSummon(result.success, result.status, result.grantJson)
                            }
                        } catch (_: Exception) { finishPaidSummon(false, "APP_CHECK_UNAVAILABLE", "") }
                    }
                } catch (_: Exception) { finishPaidSummon(false, "FIREBASE_AUTH_UNAVAILABLE", "") }
            }
        } catch (_: Exception) { finishPaidSummon(false, "NATIVE_UNAVAILABLE", "") }
    }

    private fun paidSummonOverHttps(requestId: String, pullCount: Int, uid: String, idToken: String, appToken: String): Outcome {
        var connection: HttpsURLConnection? = null
        return try {
            connection = URL(PAID_SUMMON_ENDPOINT).openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.useCaches = false
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("X-Firebase-AppCheck", appToken)
            val body = JSONObject().put("request_id", requestId.lowercase(java.util.Locale.ROOT))
                .put("pull_count", pullCount).toString().toByteArray(Charsets.UTF_8)
            connection.setFixedLengthStreamingMode(body.size)
            connection.outputStream.use { it.write(body) }
            val status = connection.responseCode
            if (status != 200) Outcome(false, when(status) {
                400 -> "SUMMON_INVALID_ARGUMENT"
                401 -> "SUMMON_UNAUTHENTICATED"
                409 -> "SUMMON_CONFLICT_OR_RETRY"
                429 -> "SUMMON_RATE_LIMITED"
                503 -> "SUMMON_SERVER_NOT_READY"
                else -> "SUMMON_HTTP_FAILURE"
            }) else if (!connection.contentType.orEmpty().startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_SUMMON_RESPONSE")
            } else {
                val json = JSONObject(String(connection.inputStream.use { readLimited(it) }, Charsets.UTF_8))
                val safe = PaidSummonCommitContractRC4.canonicalOrNull(json, requestId, uid, pullCount)
                if (safe == null) Outcome(false, "INVALID_SUMMON_RESPONSE")
                else Outcome(true, "PAID_SUMMON_SERVER_COMMITTED", safe)
            }
        } catch (_: Exception) { Outcome(false, "SUMMON_NETWORK_UNAVAILABLE") }
        finally { connection?.disconnect() }
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

    /** RC6 only. Backend + native + Godot approval are all independently OFF. */
    @UsedByGodot
    fun isPaidLoadoutReadConfigured(): Boolean = appCheckInitialized && PAID_LOADOUT_READ_APPROVED

    @UsedByGodot
    fun refreshPaidLoadout() {
        if (!PAID_LOADOUT_READ_APPROVED) {
            emitRC6("paidLoadoutReadResult", false, "PAID_LOADOUT_READ_LOCKED", "")
            return
        }
        requestSignedRC6(PAID_LOADOUT_ENDPOINT, "GET", null, loadoutBusyRC6,
            "paidLoadoutReadResult", "PAID_LOADOUT_READ_ONLY") { json ->
            PaidLoadoutContractRC6.canonicalOrNull(json)
        }
    }

    @UsedByGodot
    fun isPaidLoadoutWriteConfigured(): Boolean = appCheckInitialized && PAID_LOADOUT_WRITE_APPROVED

    @UsedByGodot
    fun updatePaidLoadout(requestId: String, expectedLoadoutRevision: Long,
                          expectedEntitlementRevision: Long, slotsJson: String) {
        if (!PAID_LOADOUT_WRITE_APPROVED) {
            emitRC6("paidLoadoutWriteResult", false, "PAID_LOADOUT_WRITE_LOCKED", "")
            return
        }
        val body = PaidLoadoutContractRC6.commandOrNull(requestId,
            expectedLoadoutRevision, expectedEntitlementRevision, slotsJson)
        if (body == null) {
            emitRC6("paidLoadoutWriteResult", false, "INVALID_PAID_LOADOUT_COMMAND", "")
            return
        }
        requestSignedRC6(PAID_LOADOUT_ENDPOINT, "POST", body, loadoutBusyRC6,
            "paidLoadoutWriteResult", "PAID_LOADOUT_SERVER_COMMITTED") { json ->
            PaidLoadoutContractRC6.canonicalOrNull(json)
        }
    }

    @UsedByGodot
    fun refreshPaidSummonHistoryIndex() {
        if (!RECOVERY_INDEX_READ_APPROVED) {
            emitRC6("paidSummonHistoryIndexResult", false, "RECOVERY_INDEX_LOCKED", "")
            return
        }
        requestSignedRC6(PAID_RECOVERY_INDEX_ENDPOINT, "GET", null, historyBusyRC6,
            "paidSummonHistoryIndexResult", "SUMMON_RECOVERY_INDEX_READ_ONLY") { json ->
            SummonRecoveryIndexContractRC6.canonicalOrNull(json)
        }
    }

    /** Shared Firebase Auth + limited-use AppCheck verifier for all RC6 requests.
     * Remote JSON cannot mutate a local save; validated contract is emitted only
     * while the same UID is still signed in. No redirects or arbitrary URLs.
     */
    private fun requestSignedRC6(endpoint: String, method: String, body: String?,
        flag: AtomicBoolean, signal: String, completedStatus: String,
        canonical: (JSONObject) -> String?) {
        if (!flag.compareAndSet(false, true)) {
            emitRC6(signal, false, "BUSY", "")
            return
        }
        fun finish(ok: Boolean, status: String, payload: String = "") {
            flag.set(false)
            emitRC6(signal, ok, status, payload)
        }
        if (!appCheckInitialized) { finish(false, "APP_CHECK_NOT_READY"); return }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) { finish(false, "AUTH_REQUIRED"); return }
            val uid = user.uid
            user.getIdToken(false).addOnCompleteListener authListener@{ authTask ->
                try {
                    val idToken = if (authTask.isSuccessful) authTask.result?.token else null
                    if (idToken.isNullOrBlank() || !isSameUser(uid)) {
                        finish(false, "AUTH_UNAVAILABLE"); return@authListener
                    }
                    FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken()
                        .addOnCompleteListener checkListener@{ appTask ->
                            try {
                                val appToken = if (appTask.isSuccessful) appTask.result?.token else null
                                if (appToken.isNullOrBlank() || !isSameUser(uid)) {
                                    finish(false, "APP_CHECK_UNAVAILABLE"); return@checkListener
                                }
                                ioExecutor.execute {
                                    val result = requestOverHttpsRC6(endpoint, method, body, idToken, appToken, canonical)
                                    if (!isSameUser(uid)) finish(false, "ACCOUNT_CHANGED")
                                    else finish(result.success, if (result.success) completedStatus else result.status, result.grantJson)
                                }
                            } catch (_: Exception) { finish(false, "APP_CHECK_UNAVAILABLE") }
                        }
                } catch (_: Exception) { finish(false, "AUTH_UNAVAILABLE") }
            }
        } catch (_: Exception) { finish(false, "AUTH_UNAVAILABLE") }
    }

    private fun requestOverHttpsRC6(endpoint: String, method: String, body: String?,
        idToken: String, appToken: String, canonical: (JSONObject) -> String?): Outcome {
        var connection: HttpsURLConnection? = null
        return try {
            connection = URL(endpoint).openConnection() as HttpsURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.useCaches = false
            connection.requestMethod = method
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("X-Firebase-AppCheck", appToken)
            if (body != null) {
                val bytes = body.toByteArray(Charsets.UTF_8)
                if (bytes.size > 1024) return Outcome(false, "INVALID_REQUEST_SIZE")
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.setFixedLengthStreamingMode(bytes.size)
                connection.outputStream.use { it.write(bytes) }
            }
            val status = connection.responseCode
            if (status != 200) Outcome(false, when (status) {
                400 -> "INVALID_REQUEST"
                401 -> "UNAUTHENTICATED"
                409 -> "REVISION_OR_OWNERSHIP_CONFLICT"
                423 -> "ACCOUNT_HELD"
                429 -> "RATE_LIMITED"
                503 -> "BACKEND_NOT_READY"
                else -> "HTTP_UNAVAILABLE"
            })
            else if (!connection.contentType.orEmpty().startsWith("application/json", ignoreCase = true))
                Outcome(false, "INVALID_CONTENT_TYPE")
            else {
                val value = JSONObject(String(connection.inputStream.use { readLimited(it) }, Charsets.UTF_8))
                val verified = canonical(value)
                if (verified == null) Outcome(false, "INVALID_SERVER_RESPONSE")
                else Outcome(true, "SERVER_VERIFIED", verified)
            }
        } catch (_: Exception) { Outcome(false, "NETWORK_UNAVAILABLE") }
        finally { connection?.disconnect() }
    }
    private fun emitRC6(signal: String, success: Boolean, status: String, payload: String) {
        runOnHostThread { emitSignal(signal, success, status, payload) }
    }

    /** Explicitly locked server-ledger repair; does not accept raw Play tokens. */
    @UsedByGodot
    fun isVerifiedPurchaseRepairTransportConfigured(): Boolean =
        appCheckInitialized && PAID_VERIFIED_REPAIR_APPROVED

    @UsedByGodot
    fun repairVerifiedPlayPurchases() {
        if (!PAID_VERIFIED_REPAIR_APPROVED) {
            emitRC6("paidVerifiedPurchaseRepairResult", false, "PURCHASE_REPAIR_LOCKED", "")
            return
        }
        requestSignedRC6(PAID_VERIFIED_REPAIR_ENDPOINT, "POST", null, purchaseRepairBusy,
            "paidVerifiedPurchaseRepairResult", "SERVER_LEDGER_RECONCILED") { json ->
            VerifiedPurchaseRepairContract.canonicalOrNull(json)
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

    private fun finishPaidSummon(success: Boolean, status: String, payload: String) {
        paidSummonBusy.set(false)
        emitPaidSummonResult(success, status, payload)
    }
    private fun emitPaidSummonResult(success: Boolean, status: String, payload: String) {
        runOnHostThread { emitSignal("paidSummonCommitResult", success, status, payload) }
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
