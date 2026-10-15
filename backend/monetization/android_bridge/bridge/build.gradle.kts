import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val bridgeName = "JadeMonetizationNativeBridge"
val bridgeNamespace = "com.yungdevstudio.jadeascendant.monetizationbridge"

// Explicit endpoint selection. Default inert; production candidate requires independent opt-in.
val jadeIapTarget = providers.environmentVariable("JADE_IAP_TARGET").orElse("locked").get()
require(jadeIapTarget in setOf("locked", "staging", "production-candidate")) {
    "Forbidden JADE_IAP_TARGET=$jadeIapTarget (locked, staging or production-candidate only)"
}
val jadeSandboxCredit = providers.environmentVariable("JADE_IAP_SANDBOX_CREDIT").orElse("off").get()
require(jadeSandboxCredit == "on" || jadeSandboxCredit == "off") { "Invalid JADE_IAP_SANDBOX_CREDIT" }
require(jadeSandboxCredit == "off" || jadeIapTarget == "staging") { "Sandbox credit requires staging target" }
val jadeGameplayV2 = providers.environmentVariable("JADE_IAP_GAMEPLAY_V2").orElse("off").get()
require(jadeGameplayV2 in setOf("on", "off")) { "Invalid JADE_IAP_GAMEPLAY_V2" }
val jadeProductionCandidate = providers.environmentVariable("JADE_IAP_PRODUCTION_CANDIDATE").orElse("off").get()
require(jadeProductionCandidate in setOf("on", "off")) { "Invalid JADE_IAP_PRODUCTION_CANDIDATE" }
require((jadeIapTarget == "production-candidate") == (jadeProductionCandidate == "on")) {
    "Production candidate target and independent opt-in must agree"
}
require(jadeProductionCandidate != "on" || (jadeSandboxCredit == "off" && jadeGameplayV2 == "on")) {
    "Production candidate requires gameplay V2 and forbids sandbox credit"
}
val candidateEnabled = jadeProductionCandidate == "on"
val jadeIapWorkerBaseUrl = when (jadeIapTarget) {
    "staging" -> "https://jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev"
    else -> "https://iap-disabled.invalid"
}
android {
    namespace = bridgeNamespace
    compileSdk = 36

    buildFeatures { buildConfig = true }
    // Normal release stays locked. Candidate is built separately and never installed by the staging builder.
    buildTypes {
        getByName("debug") {
            buildConfigField("boolean", "JADE_IAP_PRODUCTION_CANDIDATE_ENABLED", "false")
            // A candidate build must never produce a debug APK talking to production.
            if (candidateEnabled) {
                buildConfigField("String", "JADE_IAP_WORKER_BASE_URL", "\"https://iap-disabled.invalid\"")
                buildConfigField("String", "JADE_IAP_TARGET", "\"locked\"")
            }
            buildConfigField("boolean", "JADE_IAP_GAMEPLAY_V2_ENABLED", (jadeIapTarget == "staging" && jadeGameplayV2 == "on").toString())
            buildConfigField("boolean", "JADE_IAP_STAGING_CREDIT_ENABLED", (jadeIapTarget == "staging" && jadeSandboxCredit == "on").toString())
        }
        getByName("release") {
            buildConfigField("boolean", "JADE_IAP_PRODUCTION_CANDIDATE_ENABLED", candidateEnabled.toString())
            buildConfigField("boolean", "JADE_IAP_GAMEPLAY_V2_ENABLED", candidateEnabled.toString())
            buildConfigField("boolean", "JADE_IAP_STAGING_CREDIT_ENABLED", "false")
            val releaseUrl = if (candidateEnabled) "https://jade-ascendant-iap.jade-ascendant-studio.workers.dev" else "https://iap-disabled.invalid"
            val releaseTarget = if (candidateEnabled) "production-candidate" else "locked"
            buildConfigField("String", "JADE_IAP_WORKER_BASE_URL", "\"$releaseUrl\"")
            buildConfigField("String", "JADE_IAP_TARGET", "\"$releaseTarget\"")
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
