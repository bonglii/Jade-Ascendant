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
