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

    private val iapHttps by lazy { TrustedIapHttps(URL(BuildConfig.JADE_IAP_WORKER_BASE_URL).host) }

    @UsedByGodot
    fun getIapNetworkRoute(): String = TrustedIapHttps.dnsRoute.get()

    private val busy = AtomicBoolean(false)
    private val paidWalletBusy = AtomicBoolean(false)
    private val recoveryBusy = AtomicBoolean(false)
    private val entitlementsBusy = AtomicBoolean(false)
    private val loadoutBusyRC6 = AtomicBoolean(false)
    private val historyBusyRC6 = AtomicBoolean(false)
    private val purchaseRepairBusy = AtomicBoolean(false)
    private val paidSummonBusy = AtomicBoolean(false)
    private val paidGameplayBusy = AtomicBoolean(false)
    private val odysseyBusy = AtomicBoolean(false)
    private val ioExecutor = Executors.newSingleThreadExecutor { job ->
        Thread(job, "jade-iap-cloudflare-transport").apply { isDaemon = true }
    }
    private val pendingPaid by lazy { PendingPaidPurchaseStore(FirebaseApp.getInstance().applicationContext) }
    private var updateActivity: java.lang.ref.WeakReference<Activity>? = null
    @Volatile private var appCheckInitialized: Boolean = false

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("odysseyResultV1", String::class.java, Boolean::class.javaObjectType, String::class.java, String::class.java),
        SignalInfo("paidGameplayResultV2", String::class.java, Boolean::class.javaObjectType, String::class.java, String::class.java),
        SignalInfo("paidWalletSnapshotResultV2", String::class.java, Boolean::class.javaObjectType, String::class.java, String::class.java),
        SignalInfo("paidVerifiedPurchaseRepairResultV2", String::class.java, Boolean::class.javaObjectType, String::class.java, String::class.java),
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

    @Volatile private var appCheckRetryAt: Long = 0L

    @Synchronized
    private fun appCheckReady(): Boolean {
        if (appCheckInitialized) return true
        val now = android.os.SystemClock.elapsedRealtime()
        if (now < appCheckRetryAt) return false
        appCheckRetryAt = now + 2000L
        return try {
            val app = FirebaseApp.getInstance()
            if (app.options.projectId != "jade-ascendant") false else {
                AppCheckProviderInstall.install(app)
                appCheckInitialized = true
                true
            }
        } catch (_: Exception) { false }
    }

    override fun onMainCreate(activity: Activity?): View? {
        updateActivity = activity?.let { java.lang.ref.WeakReference(it) }
        if (activity != null) {
            try {
                val app = try {
                    FirebaseApp.getInstance()
                } catch (_: Exception) {
                    FirebaseApp.initializeApp(activity)
                }
                if (app != null && app.options.projectId == "jade-ascendant") {
                    AppCheckProviderInstall.install(app)
                    appCheckInitialized = true
                }
            } catch (_: Exception) {
                appCheckInitialized = false
            }
        }
        if (activity != null) UpdateNotificationsV1.sync(activity)
        return super.onMainCreate(activity)
    }

    @UsedByGodot
    fun getUpdateNotificationStatus(): String = UpdateNotificationsV1.status(updateActivity?.get())

    @UsedByGodot
    fun setUpdateNotificationsEnabled(enabled: Boolean): Boolean {
        val activity = updateActivity?.get() ?: return false
        activity.runOnUiThread { UpdateNotificationsV1.choose(activity, enabled) }
        return true
    }

    @UsedByGodot
    fun deferUpdateNotifications() { updateActivity?.get()?.let { UpdateNotificationsV1.markEducation(it) } }

    @UsedByGodot
    fun openUpdateNotificationSettings() {
        val activity = updateActivity?.get() ?: return
        activity.runOnUiThread { UpdateNotificationsV1.openSettings(activity) }
    }

    @UsedByGodot
    fun isSecurePurchaseTransportConfigured(): Boolean = appCheckReady()

    /** Legacy pre-wallet route is permanently retired. Never return a local grant. */
    @UsedByGodot
    fun authorizePurchase(@Suppress("UNUSED_PARAMETER") purchaseTokenValue: String) {
        emitResult(false, "LEGACY_LOCAL_GRANT_RETIRED", "")
    }

    /**
     * M14 server-wallet credit transport. Separate build-time lock plus Godot
     * and Worker locks. No response is permitted to credit the local save.
     */
    private val transportPolicy get() = IapTransportPolicy.compiled()
    private fun sandboxCreditEnabled(): Boolean = transportPolicy.staging
    private fun walletTransportEnabled(): Boolean = transportPolicy.wallet

    @UsedByGodot
    fun isProductionIapCandidateEnabled(): Boolean = transportPolicy.production

    @UsedByGodot
    fun isSandboxIapCreditEnabled(): Boolean = sandboxCreditEnabled()

    @UsedByGodot
    fun isPaidWalletPurchaseV2TransportConfigured(): Boolean =
        appCheckReady() && (PAID_PURCHASE_V2_TRANSPORT_APPROVED || walletTransportEnabled())

    @UsedByGodot
    fun getPendingPaidPurchaseProductV2(): String = try {
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null || !isAllowedPurchaseUser(user)) ""
        else pendingPaid.first(user.uid)?.product ?: ""
    } catch (_: Exception) { "JOURNAL_UNAVAILABLE" }

    @UsedByGodot
    fun resumePendingPaidPurchaseV2(product: String) {
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) { emitPaidPurchaseResult(false, "AUTH_REQUIRED", ""); return }
            val record = pendingPaid.first(user.uid)
            if (record == null || record.product != product) { emitPaidPurchaseResult(false, "JOURNAL_UNAVAILABLE", ""); return }
            authorizeDurablePaidWalletPurchaseV2(product, record.token)
        } catch (_: Exception) { emitPaidPurchaseResult(false, "JOURNAL_UNAVAILABLE", "") }
    }

    @UsedByGodot
    fun authorizeDurablePaidWalletPurchaseV2(product: String, purchaseTokenValue: String) {
        authorizeWalletPurchase(product, purchaseTokenValue)
    }

    @UsedByGodot
    fun authorizePaidWalletPurchaseV2(purchaseTokenValue: String) {
        // Old callers lack product correlation: do not consume a non-durable token.
        emitPaidPurchaseResult(false, "DURABLE_CLIENT_REQUIRED", "")
    }

    private fun authorizeWalletPurchase(product: String, purchaseTokenValue: String) {
        if (!PAID_PURCHASE_V2_TRANSPORT_APPROVED && !walletTransportEnabled()) {
            emitPaidPurchaseResult(false, "PAID_PURCHASE_V2_LOCKED", ""); return
        }
        if (!busy.compareAndSet(false, true)) { emitPaidPurchaseResult(false, "BUSY", ""); return }
        val finished = AtomicBoolean(false)
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        var deadline: Runnable? = null
        fun finish(ok: Boolean, status: String, payload: String = "") {
            if (!finished.compareAndSet(false, true)) return
            deadline?.let { handler.removeCallbacks(it) }
            finishPaidPurchase(ok, status, payload)
        }
        deadline = Runnable { finish(false, "REQUEST_TIMEOUT") }
        handler.postDelayed(deadline!!, 45_000L)
        if (!appCheckReady()) { finish(false, "APP_CHECK_NOT_READY"); return }
        if (!purchaseToken.matches(purchaseTokenValue)) { finish(false, "INVALID_PURCHASE_TOKEN"); return }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) { finish(false, "AUTH_REQUIRED"); return }
            val uid = user.uid
            try { pendingPaid.save(uid, product, purchaseTokenValue) }
            catch (_: Exception) { finish(false, "JOURNAL_UNAVAILABLE"); return }
            fun authorize(forceRefresh: Boolean) {
                if (finished.get()) return
                if (!isSameUser(uid)) { finish(false, "ACCOUNT_CHANGED"); return }
                user.getIdToken(forceRefresh).addOnCompleteListener authListener@{ task ->
                    if (finished.get()) return@authListener
                    try {
                        if (!isSameUser(uid)) { finish(false, "ACCOUNT_CHANGED"); return@authListener }
                        val authToken = if (task.isSuccessful) task.result?.token else null
                        if (authToken.isNullOrBlank()) { finish(false, "AUTH_TOKEN_UNAVAILABLE"); return@authListener }
                        FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken().addOnCompleteListener appListener@{ check ->
                            if (finished.get()) return@appListener
                            try {
                                if (!isSameUser(uid)) { finish(false, "ACCOUNT_CHANGED"); return@appListener }
                                val appToken = if (check.isSuccessful) check.result?.token else null
                                if (appToken.isNullOrBlank()) { finish(false, "APP_CHECK_TOKEN_UNAVAILABLE"); return@appListener }
                                ioExecutor.execute ioTask@{
                                    if (finished.get()) return@ioTask
                                    val result = paidPurchaseV2OverHttps(purchaseTokenValue, authToken, appToken)
                                    if (!isSameUser(uid)) finish(false, "ACCOUNT_CHANGED")
                                    else if (!result.success && result.status == "WALLET_PURCHASE_UNAUTHENTICATED" && !forceRefresh)
                                        authorize(true) // one fresh Auth + App Check retry, same purchase token
                                    else {
                                        // Only a validated durable server-wallet receipt can retire retry evidence.
                                        if (result.success) {
                                            try { pendingPaid.removeConfirmed(uid, product, purchaseTokenValue) }
                                            catch (_: Exception) { /* Keep evidence; idempotent replay repairs cleanup. */ }
                                        }
                                        finish(result.success, result.status, result.grantJson)
                                    }
                                }
                            } catch (_: Exception) { finish(false, "APP_CHECK_UNAVAILABLE") }
                        }
                    } catch (_: Exception) { finish(false, "FIREBASE_AUTH_UNAVAILABLE") }
                }
            }
            authorize(false)
        } catch (_: Exception) { finish(false, "NATIVE_UNAVAILABLE") }
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
        if (!appCheckReady()) {
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
        if (!appCheckReady()) {
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
        return try {
            val response = iapHttps.execute(PAID_ENTITLEMENTS_ENDPOINT, "GET", null, idToken, appToken)
            val code = response.code
            if (code != 200) Outcome(false, when (code) {
                401 -> "ENTITLEMENTS_UNAUTHENTICATED"
                409 -> "ENTITLEMENTS_NOT_PROVISIONED"
                429 -> "ENTITLEMENTS_RATE_LIMITED"
                503 -> "ENTITLEMENTS_NOT_READY"
                else -> "ENTITLEMENTS_HTTP_FAILURE"
            }) else if (!response.contentType.startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_ENTITLEMENTS_RESPONSE")
            } else {
                val json = JSONObject(String(response.bytes, Charsets.UTF_8))
                val canonical = PaidEntitlementsContractRC.canonicalOrNull(json)
                if (canonical == null) Outcome(false, "INVALID_ENTITLEMENTS_RESPONSE")
                else Outcome(true, "PAID_ENTITLEMENTS_READ_ONLY", canonical)
            }
        } catch (_: Exception) { Outcome(false, "ENTITLEMENTS_NETWORK_UNAVAILABLE") }
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
        if (!appCheckReady()) {
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
    fun isPaidSummonTransportConfigured(): Boolean = appCheckReady() && PAID_SUMMON_TRANSPORT_APPROVED

    @UsedByGodot
    fun commitPaidSummon(requestId: String, pullCount: Int) {
        if (!PAID_SUMMON_TRANSPORT_APPROVED) { emitPaidSummonResult(false, "PAID_SUMMON_LOCKED", ""); return }
        if (!PaidSummonRecoveryContractM12.validRequestId(requestId) || pullCount !in setOf(1, 10)) {
            emitPaidSummonResult(false, "INVALID_SUMMON_REQUEST", ""); return
        }
        if (!paidSummonBusy.compareAndSet(false, true)) { emitPaidSummonResult(false, "BUSY", ""); return }
        if (!appCheckReady()) { finishPaidSummon(false, "APP_CHECK_NOT_READY", ""); return }
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
        return try {
            val body = JSONObject().put("request_id", requestId.lowercase(java.util.Locale.ROOT))
                .put("pull_count", pullCount).toString().toByteArray(Charsets.UTF_8)
            val response = iapHttps.execute(PAID_SUMMON_ENDPOINT, "POST", body, idToken, appToken)
            val status = response.code
            if (status != 200) Outcome(false, when(status) {
                400 -> "SUMMON_INVALID_ARGUMENT"
                401 -> "SUMMON_UNAUTHENTICATED"
                409 -> "SUMMON_CONFLICT_OR_RETRY"
                429 -> "SUMMON_RATE_LIMITED"
                503 -> "SUMMON_SERVER_NOT_READY"
                else -> "SUMMON_HTTP_FAILURE"
            }) else if (!response.contentType.startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_SUMMON_RESPONSE")
            } else {
                val json = JSONObject(String(response.bytes, Charsets.UTF_8))
                val safe = PaidSummonCommitContractRC4.canonicalOrNull(json, requestId, uid, pullCount)
                if (safe == null) Outcome(false, "INVALID_SUMMON_RESPONSE")
                else Outcome(true, "PAID_SUMMON_SERVER_COMMITTED", safe)
            }
        } catch (_: Exception) { Outcome(false, "SUMMON_NETWORK_UNAVAILABLE") }
    }

    private fun recoveryOverHttps(requestId: String, uid: String, idToken: String, appToken: String): Outcome {
        return try {
            val response = iapHttps.execute(PAID_SUMMON_RECOVERY_PREFIX + requestId.lowercase(java.util.Locale.ROOT), "GET", null, idToken, appToken)
            val status = response.code
            if (status != 200) {
                Outcome(false, when (status) {
                    401 -> "RECOVERY_UNAUTHENTICATED"
                    403 -> "RECOVERY_FORBIDDEN"
                    404 -> "RECOVERY_NOT_FOUND"
                    429 -> "RECOVERY_RATE_LIMITED"
                    503 -> "RECOVERY_NOT_READY"
                    else -> "RECOVERY_HTTP_FAILURE"
                })
            } else if (!response.contentType.startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_RECOVERY_RESPONSE")
            } else {
                val json = JSONObject(String(response.bytes, Charsets.UTF_8))
                val canonical = PaidSummonRecoveryContractM12.canonicalOrNull(json, requestId, uid)
                if (canonical == null) Outcome(false, "INVALID_RECOVERY_RESPONSE")
                else Outcome(true, "PAID_SUMMON_RECOVERY_READ_ONLY", canonical)
            }
        } catch (_: Exception) {
            Outcome(false, "RECOVERY_NETWORK_UNAVAILABLE")
        }
    }

    private fun paidWalletOverHttps(idToken: String, appToken: String): Outcome {
        return try {
            val response = iapHttps.execute(PAID_WALLET_ENDPOINT, "GET", null, idToken, appToken)
            val status = response.code
            if (status != 200) {
                Outcome(false, when (status) {
                    401 -> "WALLET_UNAUTHENTICATED"
                    403 -> "WALLET_FORBIDDEN"
                    429 -> "WALLET_RATE_LIMITED"
                    503 -> "WALLET_NOT_READY"
                    else -> "WALLET_HTTP_FAILURE"
                })
            } else if (!response.contentType.startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_WALLET_RESPONSE")
            } else {
                val parsed = JSONObject(String(response.bytes, Charsets.UTF_8))
                val canonical = PaidWalletViewContractM8.canonicalOrNull(parsed)
                if (canonical == null) Outcome(false, "INVALID_WALLET_RESPONSE")
                else Outcome(true, "WALLET_SNAPSHOT_READ_ONLY", canonical)
            }
        } catch (_: Exception) {
            Outcome(false, "WALLET_NETWORK_UNAVAILABLE")
        }
    }

    private data class Outcome(val success: Boolean, val status: String, val grantJson: String = "")

    private fun paidPurchaseV2OverHttps(token: String, idToken: String, appToken: String): Outcome {
        return try {
            val bytes = JSONObject().put("purchase_token", token).toString().toByteArray(Charsets.UTF_8)
            val response = iapHttps.execute(PAID_PURCHASE_V2_ENDPOINT, "POST", bytes, idToken, appToken)
            val status = response.code
            if (status != 200) {
                Outcome(false, when (status) {
                    401 -> "WALLET_PURCHASE_UNAUTHENTICATED"
                    403 -> "WALLET_PURCHASE_FORBIDDEN"
                    409 -> "WALLET_PURCHASE_NOT_READY"
                    429 -> "WALLET_PURCHASE_RATE_LIMITED"
                    503 -> "WALLET_PURCHASE_BACKEND_LOCKED"
                    else -> "WALLET_PURCHASE_HTTP_FAILURE"
                })
            } else if (!response.contentType.startsWith("application/json", ignoreCase = true)) {
                Outcome(false, "INVALID_WALLET_PURCHASE_RESPONSE")
            } else {
                val json = JSONObject(String(response.bytes, Charsets.UTF_8))
                val canonical = PaidPurchaseReceiptContractM14.canonicalOrNull(json)
                if (canonical == null) Outcome(false, "INVALID_WALLET_PURCHASE_RESPONSE")
                else Outcome(true, "PAID_WALLET_SERVER_CREDITED", canonical)
            }
        } catch (_: Exception) {
            Outcome(false, "WALLET_PURCHASE_NETWORK_UNAVAILABLE")
        }
    }

    @UsedByGodot
    fun getPaidRunContractVersionV2(): Int = 1

    @UsedByGodot
    fun isPaidGameplayV2Configured(): Boolean = appCheckReady() && walletTransportEnabled() && BuildConfig.JADE_IAP_GAMEPLAY_V2_ENABLED

    @UsedByGodot
    fun requestPaidGameplayV2(requestId: String, commandJson: String) {
        fun deny(status: String) = runOnHostThread { emitSignal("paidGameplayResultV2", requestId, false, status, "") }
        if (!PaidGameplayContractV2.validRequestId(requestId)) { deny("INVALID_REQUEST_ID"); return }
        if (!isPaidGameplayV2Configured()) { deny("PAID_GAMEPLAY_LOCKED"); return }
        val body = if (commandJson.isEmpty()) null else PaidGameplayContractV2.commandOrNull(requestId, commandJson)
        if (commandJson.isNotEmpty() && body == null) { deny("INVALID_COMMAND"); return }
        val uid = try { FirebaseAuth.getInstance().currentUser?.uid } catch (_: Exception) { null }
        if (uid == null) { deny("AUTH_REQUIRED"); return }
        requestSignedRC6("${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v1/wallet/gameplay-v2",
            if (body == null) "GET" else "POST", body, paidGameplayBusy,
            "paidGameplayResultV2", "PAID_GAMEPLAY_VERIFIED", requestId) { json ->
            PaidGameplayContractV2.canonicalOrNull(json, uid, requestId, body)
        }
    }

    @UsedByGodot
    fun requestOdysseyV1(requestId: String, commandJson: String) {
        fun deny(status: String) = runOnHostThread { emitSignal("odysseyResultV1", requestId, false, status, "") }
        if (!OdysseyContractV1.validId(requestId)) { deny("INVALID_REQUEST_ID"); return }
        if (!isPaidGameplayV2Configured()) { deny("EVENT_TRANSPORT_UNAVAILABLE"); return }
        val body = if (commandJson.isEmpty()) null else OdysseyContractV1.commandOrNull(requestId, commandJson)
        if (commandJson.isNotEmpty() && body == null) { deny("INVALID_COMMAND"); return }
        val uid = try { FirebaseAuth.getInstance().currentUser?.uid } catch (_: Exception) { null }
        if (uid == null) { deny("AUTH_REQUIRED"); return }
        requestSignedRC6("${BuildConfig.JADE_IAP_WORKER_BASE_URL}/v4/odyssey",
            if (body == null) "GET" else "POST", body, odysseyBusy,
            "odysseyResultV1", "ODYSSEY_VERIFIED", requestId) { json -> OdysseyContractV1.canonicalOrNull(json, uid) }
    }

    /** RC6 only. Backend + native + Godot approval are all independently OFF. */
    @UsedByGodot
    fun isPaidLoadoutReadConfigured(): Boolean = appCheckReady() && PAID_LOADOUT_READ_APPROVED

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
    fun isPaidLoadoutWriteConfigured(): Boolean = appCheckReady() && PAID_LOADOUT_WRITE_APPROVED

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

    /** Shared Firebase Auth + App Check. Only v4 event actions can use the SDK cache.
     * Remote JSON cannot mutate a local save; validated contract is emitted only
     * while the same UID is still signed in. No redirects or arbitrary URLs.
     */
    private fun requestSignedRC6(endpoint: String, method: String, body: String?,
        flag: AtomicBoolean, signal: String, completedStatus: String,
        requestId: String? = null, canonical: (JSONObject) -> String?) {
        fun emit(ok: Boolean, status: String, payload: String) {
            if (requestId == null) emitRC6(signal, ok, status, payload)
            else runOnHostThread { emitSignal(signal, requestId, ok, status, payload) }
        }
        if (!flag.compareAndSet(false, true)) { emit(false, "BUSY", ""); return }
        val startedAt=android.os.SystemClock.elapsedRealtime()
        val finished = AtomicBoolean(false)
        val timeoutHandler = android.os.Handler(android.os.Looper.getMainLooper())
        var timeout: Runnable? = null
        fun finish(ok: Boolean, status: String, payload: String = "") {
            if (!finished.compareAndSet(false, true)) return
            timeout?.let { timeoutHandler.removeCallbacks(it) }
            flag.set(false)
            if(endpoint==BuildConfig.JADE_IAP_WORKER_BASE_URL+"/v4/odyssey")android.util.Log.i("JadeOdyssey","total_ms=${android.os.SystemClock.elapsedRealtime()-startedAt}; cached_appcheck=${EventAppCheckPolicy.cached(endpoint,method,body,BuildConfig.JADE_IAP_WORKER_BASE_URL)}; stage=$status")
            emit(ok, status, payload)
        }
        timeout = Runnable { finish(false, "REQUEST_TIMEOUT") }
        timeoutHandler.postDelayed(timeout!!, 45_000L)
        if (!appCheckReady()) { finish(false, "APP_CHECK_NOT_READY"); return }
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || !isAllowedPurchaseUser(user)) { finish(false, "AUTH_REQUIRED"); return }
            val uid = user.uid
            fun authorize(forceRefresh: Boolean) {
                if (finished.get()) return
                if (!isSameUser(uid)) { finish(false, "ACCOUNT_CHANGED"); return }
                user.getIdToken(forceRefresh).addOnCompleteListener authListener@{ authTask ->
                    if (finished.get()) return@authListener
                    try {
                        val idToken = if (authTask.isSuccessful) authTask.result?.token else null
                        if (!isSameUser(uid)) { finish(false, "ACCOUNT_CHANGED"); return@authListener }
                        if (idToken.isNullOrBlank()) { finish(false, "AUTH_UNAVAILABLE"); return@authListener }
                        (if (EventAppCheckPolicy.cached(endpoint,method,body,BuildConfig.JADE_IAP_WORKER_BASE_URL))
                            FirebaseAppCheck.getInstance().getAppCheckToken(forceRefresh)
                         else FirebaseAppCheck.getInstance().getLimitedUseAppCheckToken())
                            .addOnCompleteListener checkListener@{ appTask ->
                                if (finished.get()) return@checkListener
                                try {
                                    val appToken = if (appTask.isSuccessful) appTask.result?.token else null
                                    if (!isSameUser(uid)) { finish(false, "ACCOUNT_CHANGED"); return@checkListener }
                                    if (appToken.isNullOrBlank()) { finish(false, "APP_CHECK_UNAVAILABLE"); return@checkListener }
                                    ioExecutor.execute ioTask@{
                                        if (finished.get()) return@ioTask
                                        val result = requestOverHttpsRC6(endpoint, method, body, idToken, appToken, canonical)
                                        if (!isSameUser(uid)) finish(false, "ACCOUNT_CHANGED")
                                        else if (!result.success && result.status == "UNAUTHENTICATED" && !forceRefresh) authorize(true)
                                        else finish(result.success, if (result.success) completedStatus else result.status, result.grantJson)
                                    }
                                } catch (_: Exception) { finish(false, "APP_CHECK_UNAVAILABLE") }
                            }
                    } catch (_: Exception) { finish(false, "AUTH_UNAVAILABLE") }
                }
            }
            authorize(false)
        } catch (_: Exception) { finish(false, "AUTH_UNAVAILABLE") }
    }


    private fun requestOverHttpsRC6(endpoint: String, method: String, body: String?,
        idToken: String, appToken: String, canonical: (JSONObject) -> String?): Outcome {
        return try {
            if (body != null && body.toByteArray(Charsets.UTF_8).size > 1024) return Outcome(false, "INVALID_REQUEST_SIZE")
            val response = iapHttps.execute(endpoint, method, body?.toByteArray(Charsets.UTF_8), idToken, appToken)
            val status = response.code
            if (status != 200) Outcome(false, when (status) {
                400 -> "INVALID_REQUEST"
                401 -> "UNAUTHENTICATED"
                403 -> "FORBIDDEN"
                409 -> "REVISION_OR_OWNERSHIP_CONFLICT"
                423 -> "ACCOUNT_HELD"
                429 -> "RATE_LIMITED"
                503 -> "BACKEND_NOT_READY"
                else -> "HTTP_UNAVAILABLE"
            })
            else if (!response.contentType.startsWith("application/json", ignoreCase = true))
                Outcome(false, "INVALID_CONTENT_TYPE")
            else {
                val value = JSONObject(String(response.bytes, Charsets.UTF_8))
                val verified = canonical(value)
                if (verified == null) Outcome(false, "INVALID_SERVER_RESPONSE")
                else Outcome(true, "SERVER_VERIFIED", verified)
            }
        } catch (_: IllegalArgumentException) { Outcome(false, "ENDPOINT_POLICY_REJECTED") }
        catch (_: Exception) { Outcome(false, "NETWORK_UNAVAILABLE") }
    }
    private fun emitRC6(signal: String, success: Boolean, status: String, payload: String) {
        runOnHostThread { emitSignal(signal, success, status, payload) }
    }

    /** Explicitly locked server-ledger repair; does not accept raw Play tokens. */
    @UsedByGodot
    fun isVerifiedPurchaseRepairTransportConfigured(): Boolean =
        appCheckReady() && PAID_VERIFIED_REPAIR_APPROVED

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

    /** Correlated reads/repair: staging debug or explicit production candidate only. */
    @UsedByGodot
    fun isPaidWalletRecoveryReadConfigured(): Boolean = appCheckReady() && walletTransportEnabled()

    @UsedByGodot
    fun refreshPaidWalletSnapshotV2(requestId: String) {
        if (!recoveryRequestAllowed(requestId, "paidWalletSnapshotResultV2")) return
        requestSignedRC6(PAID_WALLET_ENDPOINT, "GET", null, paidWalletBusy,
            "paidWalletSnapshotResultV2", "WALLET_SNAPSHOT_READ_ONLY", requestId) { json ->
            PaidWalletViewContractM8.canonicalOrNull(json)
        }
    }

    @UsedByGodot
    fun repairVerifiedPlayPurchasesV2(requestId: String) {
        if (!recoveryRequestAllowed(requestId, "paidVerifiedPurchaseRepairResultV2")) return
        requestSignedRC6(PAID_VERIFIED_REPAIR_ENDPOINT, "POST", null, purchaseRepairBusy,
            "paidVerifiedPurchaseRepairResultV2", "SERVER_LEDGER_RECONCILED", requestId) { json ->
            VerifiedPurchaseRepairContract.canonicalOrNull(json)
        }
    }

    private fun recoveryRequestAllowed(requestId: String, signal: String): Boolean {
        val valid = requestId.matches(Regex("^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$"))
        val allowed = valid && isPaidWalletRecoveryReadConfigured()
        if (!allowed) runOnHostThread { emitSignal(signal, requestId, false,
            if (!valid) "INVALID_REQUEST_ID" else "TESTER_RECOVERY_LOCKED", "") }
        return allowed
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
        return transportPolicy.allowsUser(user.isAnonymous,
            user.providerData.any { it.providerId == GoogleAuthProvider.PROVIDER_ID })
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
