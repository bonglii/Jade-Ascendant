package com.yungdevstudio.jadeascendant.monetizationbridge

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import org.json.JSONObject

internal object UpdateNotificationsV1 {
    private fun prefs(c: Context) = c.getSharedPreferences("jade_update_notifications_v1", Context.MODE_PRIVATE)
    @Volatile private var busy = false
    @Volatile private var lastKey = ""
    @Volatile private var retryAt = 0L
    @Volatile private var stage = "off"
    fun permission(c: Context): Boolean {
        val manager = c.getSystemService(NotificationManager::class.java) ?: return false
        return (Build.VERSION.SDK_INT < 33 || c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) && manager.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(UpdateMessageContractV1.CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }
    fun wanted(c: Context) = prefs(c).getBoolean("opt_in", false)
    fun markEducation(c: Context) { prefs(c).edit().putBoolean("education_shown", true).apply() }
    fun status(c: Context?): String {
        if (c == null) return "{\"supported\":false,\"stage\":\"unavailable\"}"
        sync(c)
        return JSONObject().put("supported", true).put("opt_in", wanted(c)).put("permission", permission(c)).put("education_shown", prefs(c).getBoolean("education_shown", false)).put("busy", busy).put("stage", if (wanted(c) && !permission(c)) "system_blocked" else stage).put("subscribed", wanted(c) && permission(c) && prefs(c).getBoolean("subscribed", false)).toString()
    }
    fun choose(activity: Activity, enable: Boolean) {
        markEducation(activity)
        prefs(activity).edit().putBoolean("opt_in", enable).apply()
        if (enable && Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            activity.startActivity(Intent(activity, JadeNotificationPermissionActivity::class.java))
        } else sync(activity)
        if (!enable) activity.getSystemService(NotificationManager::class.java)?.cancel(8217)
    }
    fun permissionResult(c: Context, allowed: Boolean) {
        if (!allowed) prefs(c).edit().putBoolean("opt_in", false).apply()
        sync(c)
    }
    fun openSettings(activity: Activity) {
        activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
    }
    @Synchronized fun sync(context: Context, force: Boolean = false) {
        val c = context.applicationContext
        val enabled = wanted(c) && permission(c)
        val key = enabled.toString()
        if (busy || (!force && lastKey == key && stage != "retry") || SystemClock.elapsedRealtime() < retryAt) return
        if (!enabled && !prefs(c).getBoolean("initialized", false)) { lastKey = key; stage = "off"; return }
        try {
            if (FirebaseApp.getInstance().options.projectId != "jade-ascendant") { stage = "firebase_unavailable"; retryAt = SystemClock.elapsedRealtime() + 60000; return }
            val messaging = FirebaseMessaging.getInstance()
            prefs(c).edit().putBoolean("initialized", true).apply()
            messaging.isAutoInitEnabled = enabled
            if (enabled && Build.VERSION.SDK_INT >= 26) {
                val channel = NotificationChannel(UpdateMessageContractV1.CHANNEL, "Game updates", NotificationManager.IMPORTANCE_DEFAULT)
                channel.description = "Optional Jade Ascendant release announcements"
                c.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
            }
            busy = true; stage = "connecting"
            val task = if (enabled) messaging.subscribeToTopic(UpdateMessageContractV1.TOPIC) else messaging.unsubscribeFromTopic(UpdateMessageContractV1.TOPIC)
            task.addOnCompleteListener {
                synchronized(this) {
                    busy = false; lastKey = key
                    if (it.isSuccessful) { stage = if (enabled) "ready" else "off"; prefs(c).edit().putBoolean("subscribed", enabled).apply() }
                    else { stage = "retry"; retryAt = SystemClock.elapsedRealtime() + 60000 }
                }
                if ((wanted(c) && permission(c)) != enabled) sync(c, true)
            }
        } catch (_: Exception) { busy = false; stage = "retry"; retryAt = SystemClock.elapsedRealtime() + 60000 }
    }
}
