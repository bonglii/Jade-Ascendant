import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val bridgeName = "JadeMonetizationNativeBridge"
val bridgeNamespace = "com.yungdevstudio.jadeascendant.monetizationbridge"

// Explicit native IAP endpoint selection. Default: inert; staging only when requested.
val jadeIapTarget = providers.environmentVariable("JADE_IAP_TARGET").orElse("locked").get()
require(jadeIapTarget == "locked" || jadeIapTarget == "staging") {
    "Forbidden JADE_IAP_TARGET=$jadeIapTarget (only locked or staging allowed)"
}
val jadeSandboxCredit = providers.environmentVariable("JADE_IAP_SANDBOX_CREDIT").orElse("off").get()
require(jadeSandboxCredit == "on" || jadeSandboxCredit == "off") { "Invalid JADE_IAP_SANDBOX_CREDIT" }
require(jadeSandboxCredit == "off" || jadeIapTarget == "staging") { "Sandbox credit requires staging target" }
val jadeGameplayV2 = providers.environmentVariable("JADE_IAP_GAMEPLAY_V2").orElse("off").get()
require(jadeGameplayV2 in setOf("on", "off")) { "Invalid JADE_IAP_GAMEPLAY_V2" }
val jadeIapWorkerBaseUrl = when (jadeIapTarget) {
    "staging" -> "https://jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev"
    else -> "https://iap-disabled.invalid"
}
android {
    namespace = bridgeNamespace
    compileSdk = 36

    buildFeatures { buildConfig = true }
    // Production/release AAR remains locked even if sandbox environment is set.
    buildTypes {
        getByName("debug") {
            buildConfigField("boolean", "JADE_IAP_GAMEPLAY_V2_ENABLED", (jadeIapTarget == "staging" && jadeGameplayV2 == "on").toString())
            buildConfigField("boolean", "JADE_IAP_STAGING_CREDIT_ENABLED", (jadeIapTarget == "staging" && jadeSandboxCredit == "on").toString())
        }
        getByName("release") {
            buildConfigField("boolean", "JADE_IAP_GAMEPLAY_V2_ENABLED", "false")
            buildConfigField("boolean", "JADE_IAP_STAGING_CREDIT_ENABLED", "false")
            buildConfigField("String", "JADE_IAP_WORKER_BASE_URL", "\"https://iap-disabled.invalid\"")
            buildConfigField("String", "JADE_IAP_TARGET", "\"locked\"")
        }
    }

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = bridgeName
        manifestPlaceholders["godotPluginPackageName"] = bridgeNamespace
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"$bridgeName\"")
        buildConfigField("String", "JADE_IAP_WORKER_BASE_URL", "\"$jadeIapWorkerBaseUrl\"")
        buildConfigField("String", "JADE_IAP_TARGET", "\"$jadeIapTarget\"")
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
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:okhttp-dnsoverhttps:4.12.0")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    testImplementation("com.squareup.okhttp3:okhttp-tls:4.12.0")
    implementation("org.godotengine:godot:4.7.2.stable")
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    debugImplementation("com.google.firebase:firebase-appcheck-debug")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
