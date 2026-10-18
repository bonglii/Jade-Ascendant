package com.yungdevstudio.jadeascendant.monetizationbridge
import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle

class JadeNotificationPermissionActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            UpdateNotificationsV1.permissionResult(this, true); finish(); return
        }
        if (state == null) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8217)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 8217) { UpdateNotificationsV1.permissionResult(this, grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED); finish() }
    }
}
