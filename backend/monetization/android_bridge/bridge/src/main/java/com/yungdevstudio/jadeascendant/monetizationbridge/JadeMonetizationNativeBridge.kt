package com.yungdevstudio.jadeascendant.monetizationbridge

import android.app.Activity
import android.view.View
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import com.google.firebase.functions.HttpsCallableOptions
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.atomic.AtomicBoolean

class JadeMonetizationNativeBridge(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val REGION = "asia-southeast2"
        private const val CALLABLE = "jadeAuthorizePurchase"
        private val purchaseToken = Regex("^[\\x21-\\x7E]{16,4096}$")
    }

    private val busy = AtomicBoolean(false)
    @Volatile private var appCheckInitialized: Boolean = false

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo(
            "purchaseAuthorityResult",
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

    @UsedByGodot
    fun authorizePurchase(purchaseTokenValue: String) {
        if (!busy.compareAndSet(false, true)) {
            emitResult(false, "BUSY", "")
            return
        }
        if (!appCheckInitialized) {
            finish(false, "APP_CHECK_NOT_READY", "")
            return
        }
        if (!purchaseToken.matches(purchaseTokenValue)) {
            finish(false, "INVALID_PURCHASE_TOKEN", "")
            return
        }

        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                finish(false, "AUTH_REQUIRED", "")
                return
            }
            if (!isAllowedPurchaseUser(user)) {
                finish(false, "AUTH_PROVIDER_UNSUPPORTED", "")
                return
            }

            val requestUid = user.uid
            val callableOptions = HttpsCallableOptions.Builder()
                .setLimitedUseAppCheckTokens(true)
                .build()
            FirebaseFunctions.getInstance(REGION)
                .getHttpsCallable(CALLABLE, callableOptions)
                .call(mapOf("purchase_token" to purchaseTokenValue))
                .addOnCompleteListener { task ->
                    val current = FirebaseAuth.getInstance().currentUser
                    if (
                        current == null ||
                        current.uid != requestUid ||
                        !isAllowedPurchaseUser(current)
                    ) {
                        finish(false, "ACCOUNT_CHANGED", "")
                        return@addOnCompleteListener
                    }

                    if (!task.isSuccessful) {
                        val exception = task.exception
                        val code = if (exception is FirebaseFunctionsException) {
                            "CALLABLE_${exception.code.name}"
                        } else {
                            "CALLABLE_UNAVAILABLE"
                        }
                        finish(false, code, "")
                        return@addOnCompleteListener
                    }

                    val grant = SecurePurchaseGrantContract.decode(task.result?.data)
                    if (grant == null) {
                        finish(false, "UNSUPPORTED_PURCHASE_GRANT", "")
                        return@addOnCompleteListener
                    }
                    finish(true, "GRANT_READY", grant.canonicalJson())
                }
        } catch (_: Exception) {
            finish(false, "NATIVE_UNAVAILABLE", "")
        }
    }

    private fun isAllowedPurchaseUser(user: FirebaseUser): Boolean {
        if (user.isAnonymous) return true
        return user.providerData.any {
            it.providerId == GoogleAuthProvider.PROVIDER_ID
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
