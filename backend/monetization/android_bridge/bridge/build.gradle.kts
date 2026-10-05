import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val bridgeName = "JadeMonetizationNativeBridge"
val bridgeNamespace = "com.yungdevstudio.jadeascendant.monetizationbridge"

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
    implementation("org.godotengine:godot:4.7.2.stable")
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    debugImplementation("com.google.firebase:firebase-appcheck-debug")
    testImplementation("junit:junit:4.13.2")
}
