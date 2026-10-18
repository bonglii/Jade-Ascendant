package com.yungdevstudio.jadeascendant.monetizationbridge

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class JadeUpdateMessagingService : FirebaseMessagingService() {
    override fun onRegistered(installationId: String) { UpdateNotificationsV1.sync(this, true) } // Never log or upload token to our server.
    override fun onMessageReceived(message: RemoteMessage) {
        if (!UpdateNotificationsV1.wanted(this) || !UpdateNotificationsV1.permission(this)) return
        val info = packageManager.getPackageInfo(packageName, 0)
        val installed = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
        val prefs = getSharedPreferences("jade_update_notifications_v1", MODE_PRIVATE)
        val notice = UpdateMessageContractV1.parse(message.data, installed, prefs.getLong("highest_shown", 0), System.currentTimeMillis() / 1000) ?: return
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + UpdateMessageContractV1.PACKAGE)).setPackage("com.android.vending")
        val destination = if (market.resolveActivity(packageManager) != null) market else Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=" + UpdateMessageContractV1.PACKAGE))
        val pending = PendingIntent.getActivity(this, 8217, destination, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, UpdateMessageContractV1.CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.jade_update_notification).setColor(0xff35bb93.toInt()).setContentTitle(notice.title).setContentText(notice.body).setStyle(Notification.BigTextStyle().bigText(notice.body)).setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(true).setCategory(Notification.CATEGORY_STATUS).build()
        try {
            val manager = getSystemService(NotificationManager::class.java) ?: return
            manager.notify(8217, notification)
            prefs.edit().putLong("highest_shown", notice.versionCode).apply()
        } catch (_: SecurityException) { /* Permission revoked while processing. */ }
    }
}
