package com.yungdevstudio.jadeascendant.cloudbridge

import android.app.Activity
import android.view.View
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Gate 4.2 QA CANDIDATE. The AAR is NOT integrated into Jade Ascendant yet.
 * A single fixed, read-only callable: no generic function name/payload/uid/token
 * parameters can cross GDScript's native boundary. No save/receipt I/O.
 */
class JadeCloudNativeBridge(godot: Godot) : GodotPlugin(godot) {
    private val busy = AtomicBoolean(false)
    @Volatile private var appCheckInitialized: Boolean = false

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("capabilitiesResult", Boolean::class.javaObjectType, String::class.java),
    )

    /** Install App Check as early as the Godot native plugin lifecycle permits. */
    override fun onMainCreate(activity: Activity?): View? {
        if (activity != null) {
            try {
                val app = FirebaseApp.initializeApp(activity)
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

    /** Not a server credential/attestation check; only local initialization. */
    @UsedByGodot
    fun isAppCheckConfigured(): Boolean = appCheckInitialized

    /** Explicit manual QA probe. Never invoked by startup, saving, gameplay or purchases. */
    @UsedByGodot
    fun requestReadOnlyCapabilities() {
        if (!busy.compareAndSet(false, true)) {
            emitResult(false, "BUSY")
            return
        }

        if (!appCheckInitialized) {
            finish(false, "APP_CHECK_NOT_READY")
            return
        }

        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null || user.isAnonymous ||
                user.providerData.none { it.providerId == GoogleAuthProvider.PROVIDER_ID }) {
                finish(false, "GOOGLE_SIGN_IN_REQUIRED")
                return
            }
            // UID remains private to native memory; never send it to the callable.
            // Check the current session again before presenting any async result.
            val requestUid = user.uid
            // Auth and App Check tokens are automatically attached by Firebase SDK.
            // No UID, purchase token, balance or caller-controlled data is submitted.
            FirebaseFunctions.getInstance("asia-southeast2")
                .getHttpsCallable("jadeCloudSaveCapabilities")
                .call(emptyMap<String, Any>())
                .addOnCompleteListener { task ->
                    val current = FirebaseAuth.getInstance().currentUser
                    if (current == null || current.isAnonymous || current.uid != requestUid ||
                        current.providerData.none { it.providerId == GoogleAuthProvider.PROVIDER_ID }) {
                        finish(false, "ACCOUNT_CHANGED")
                        return@addOnCompleteListener
                    }
                    if (!task.isSuccessful) {
                        val exception = task.exception
                        val code = if (exception is FirebaseFunctionsException) {
                            "CALLABLE_${exception.code.name}"
                        } else {
                            "CALLABLE_UNAVAILABLE"
                        }
                        finish(false, code)
                        return@addOnCompleteListener
                    }
                    val data = task.result?.data
                    if (ClosedCapabilitiesContract.accepts(data)) {
                        finish(true, "CLOUD_DISABLED_CONFIRMED")
                    } else {
                        finish(false, "UNSUPPORTED_CAPABILITIES_RESPONSE")
                    }
                }
        } catch (_: Exception) {
            // Never surface raw Firebase exceptions, email, UID, or SDK tokens.
            finish(false, "NATIVE_UNAVAILABLE")
        }
    }

    private fun finish(success: Boolean, status: String) {
        busy.set(false)
        emitResult(success, status)
    }

    private fun emitResult(success: Boolean, status: String) {
        runOnHostThread { emitSignal("capabilitiesResult", success, status) }
    }
}
