package com.yungdevstudio.jadeascendant.cloudbridge

import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory

/** Release variant: never references Firebase's debug provider. */
internal object AppCheckProviderInstall {
    fun install(app: FirebaseApp) {
        FirebaseAppCheck.getInstance(app)
            .installAppCheckProviderFactory(PlayIntegrityAppCheckProviderFactory.getInstance())
    }
}
