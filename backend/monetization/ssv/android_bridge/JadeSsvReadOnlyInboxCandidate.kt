package com.yungdevstudio.jadeascendant.ssvinbox

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.atomic.AtomicBoolean

/**
 * M7E4E2 SOURCE-ONLY / NOT REGISTERED / NOT PACKAGED IN ANDROID.
 * No native plugin registration, no production callable registration, no grant,
 * no economy/save/receipt writes, no caller-supplied UID/token/function name.
 * This must stay disabled until server-side auth, App Check, intent issuance,
 * and authoritative delivery with local crash recovery have separate approval.
 */
class JadeSsvReadOnlyInboxCandidate(godot: Godot) : GodotPlugin(godot) {
    private val busy = AtomicBoolean(false)
    private companion object {
        const val READ_ONLY_PROBE_ENABLED = false
        const val FUNCTION_REGION = "us-central1"
        const val FIXED_CALLABLE = "jadePendingInboxEmulator" // not registered
    }
    override fun getPluginName(): String = "JadeSsvReadOnlyInboxCandidate"
    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("inboxProbeFinished", Boolean::class.javaObjectType,
            String::class.java, Int::class.javaObjectType)
    )
    private fun finish(ok: Boolean, code: String, count: Int = 0) {
        busy.set(false)
        runOnHostThread { emitSignal("inboxProbeFinished", ok, code, count) }
    }
    @UsedByGodot
    fun probeReadOnlyInbox() {
        if (!READ_ONLY_PROBE_ENABLED) {
            finish(false, "INBOX_DISABLED")
            return
        }
        if (!busy.compareAndSet(false, true)) {
            runOnHostThread { emitSignal("inboxProbeFinished", false, "BUSY", 0) }
            return
        }
        try {
            val signedIn = FirebaseAuth.getInstance().currentUser
            if (signedIn == null) {
                finish(false, "AUTH_REQUIRED")
                return
            }
            val requestedUid = signedIn.uid // private, never sent as request payload
            FirebaseAppCheck.getInstance().getAppCheckToken(false)
                .addOnCompleteListener { appCheckTask ->
                    if (!appCheckTask.isSuccessful) {
                        finish(false, "APP_CHECK_UNAVAILABLE")
                        return@addOnCompleteListener
                    }
                    val live = FirebaseAuth.getInstance().currentUser
                    if (live == null || live.uid != requestedUid) {
                        finish(false, "ACCOUNT_CHANGED")
                        return@addOnCompleteListener
                    }
                    // Firebase Functions SDK attaches verified Auth and App Check.
                    FirebaseFunctions.getInstance(FUNCTION_REGION)
                        .getHttpsCallable(FIXED_CALLABLE)
                        .call(emptyMap<String, Any>())
                        .addOnCompleteListener { result ->
                            val current = FirebaseAuth.getInstance().currentUser
                            if (current == null || current.uid != requestedUid) {
                                finish(false, "ACCOUNT_CHANGED")
                                return@addOnCompleteListener
                            }
                            if (!result.isSuccessful) {
                                val err = result.exception
                                val status = if (err is FirebaseFunctionsException)
                                    "CALLABLE_${err.code.name}"
                                else "INBOX_UNAVAILABLE"
                                finish(false, status)
                                return@addOnCompleteListener
                            }
                            val data = result.result?.data as? Map<*, *>
                            val items = data?.get("items") as? List<*>
                            val verified = data?.get("status") == "READ_ONLY_PENDING" &&
                                data["creditAllowed"] == false &&
                                data["clientAckAllowed"] == false &&
                                data["hasMore"] is Boolean && items != null &&
                                items.size <= 20 && items.all { it is Map<*, *> &&
                                    it["state"] == "PENDING_DELIVERY" }
                            if (!verified) {
                                finish(false, "UNTRUSTED_INBOX_RESPONSE")
                                return@addOnCompleteListener
                            }
                            // Counts only; no raw ID, receipt, tokens or award data to Godot.
                            finish(true, "READ_ONLY_PENDING", items!!.size)
                        }
                }
        } catch (_: Exception) {
            finish(false, "NATIVE_UNAVAILABLE")
        }
    }
}
