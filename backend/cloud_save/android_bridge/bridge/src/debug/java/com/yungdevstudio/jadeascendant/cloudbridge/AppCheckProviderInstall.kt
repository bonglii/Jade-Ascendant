package com.yungdevstudio.jadeascendant.cloudbridge

import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory

/** QA/debug variant ONLY. Never upload this AAR to Google Play production. */
internal object AppCheckProviderInstall {
    fun install(app: FirebaseApp) {
        FirebaseAppCheck.getInstance(app)
            .installAppCheckProviderFactory(DebugAppCheckProviderFactory.getInstance())
    }
}
