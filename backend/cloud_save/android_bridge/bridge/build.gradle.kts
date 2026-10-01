import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val bridgeName = "JadeCloudNativeBridge"
val bridgeNamespace = "com.yungdevstudio.jadeascendant.cloudbridge"

android {
    namespace = bridgeNamespace
    compileSdk = 36

    buildFeatures { buildConfig = true }

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = bridgeName
        manifestPlaceholders["godotPluginPackageName"] = bridgeNamespace
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"$bridgeName\"")
        setProperty("archivesBaseName", bridgeName)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
    }
}

dependencies {
    // Exact engine line: does not reuse or replace existing Firebase Auth AAR.
    implementation("org.godotengine:godot:4.7.2.stable")

    // Pinned, official compatible Firebase Android set (no deprecated -ktx modules).
    // This build is isolated. App-level dependency alignment is a SEPARATE gate.
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")

    // NOT compiled into release variant; never ship debug provider in Play builds.
    debugImplementation("com.google.firebase:firebase-appcheck-debug")

    testImplementation("junit:junit:4.13.2")
}

// Gate 4.2B diagnostic ONLY: mirrors legacy Firebase addon pins alongside the
// proposed new export dependencies. Not proof of full APK/R8 compatibility.
val qaMergedFirebaseRuntime by configurations.creating {
    isCanBeResolved = true
    isCanBeConsumed = false
}

dependencies {
    add(qaMergedFirebaseRuntime.name, platform("com.google.firebase:firebase-bom:34.19.0"))
    // Exact current GodotFirebaseAndroid/export_plugin.gd dependencies.
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-auth:23.2.0")
    add(qaMergedFirebaseRuntime.name, "com.google.android.gms:play-services-auth:21.3.0")
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-firestore:25.1.4")
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-database:21.0.0")
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-storage:21.0.1")
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-analytics:22.4.0")
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-config:22.0.1")
    // Exact new export plugin dependencies (release side, NO debug provider).
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-auth:24.2.0")
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-functions:22.1.1")
    add(qaMergedFirebaseRuntime.name, "com.google.firebase:firebase-appcheck-playintegrity:19.4.1")
}
