package com.yungdevstudio.jadeascendant.cloudbridge

import android.app.Activity
import android.content.Context
import android.view.View
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/**
 * DEBUG-VARIANT-ONLY QA transport bridge.
 *
 * It exposes one zero-argument method that reads one immutable reviewed fixture
 * packaged inside the debug AAR, verifies its exact SHA-256, and emits the bytes
 * to Godot. It has no Firebase, HTTP, auth, write, restore, purchase, generic
 * route, arbitrary file path, or caller-supplied payload API.
 *
 * The class and manifest registration do not exist in the release AAR.
 */
class JadeAccountBoundTransportDebugBridge(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val PLUGIN_NAME = "JadeAccountBoundTransportDebugBridge"
        private const val ASSET_NAME = "jade_account_bound_transport_device_record.json"
        private const val ASSET_SHA256 = "00d9d9e6f7cca2302856913c486238f1781347e405bd4b8adbcb2de3d9e42b85"
        private const val MAX_BYTES = 614_400
    }

    private val busy = AtomicBoolean(false)
    @Volatile private var applicationContext: Context? = null

    override fun getPluginName() = PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo(
            "accountBoundTransportQaResult",
            Boolean::class.javaObjectType,
            String::class.java,
            String::class.java,
        ),
    )

    override fun onMainCreate(activity: Activity?): View? {
        applicationContext = activity?.applicationContext
        return super.onMainCreate(activity)
    }

    /** Manual QA only. No input crosses from GDScript into native transport. */
    @UsedByGodot
    fun requestQaAccountBoundTransport() {
        if (!BuildConfig.DEBUG) {
            emitResult(false, "DEBUG_VARIANT_REQUIRED", "")
            return
        }
        if (!busy.compareAndSet(false, true)) {
            emitResult(false, "BUSY", "")
            return
        }
        try {
            val context = applicationContext
            if (context == null) {
                finish(false, "CONTEXT_NOT_READY", "")
                return
            }
            val bytes = context.assets.open(ASSET_NAME).use { stream -> stream.readBytes() }
            if (bytes.isEmpty() || bytes.size > MAX_BYTES) {
                finish(false, "FIXTURE_SIZE_INVALID", "")
                return
            }
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(bytes)
                .joinToString("") { byte -> "%02x".format(byte) }
            if (digest != ASSET_SHA256) {
                finish(false, "FIXTURE_DIGEST_MISMATCH", "")
                return
            }
            val json = bytes.toString(Charsets.UTF_8)
            if (json.isBlank()) {
                finish(false, "FIXTURE_EMPTY", "")
                return
            }
            finish(true, "QA_TRANSPORT_FIXTURE_READY", json)
        } catch (_: Exception) {
            finish(false, "FIXTURE_READ_FAILED", "")
        }
    }

    private fun finish(success: Boolean, status: String, json: String) {
        busy.set(false)
        emitResult(success, status, json)
    }

    private fun emitResult(success: Boolean, status: String, json: String) {
        runOnHostThread {
            emitSignal("accountBoundTransportQaResult", success, status, json)
        }
    }
}
