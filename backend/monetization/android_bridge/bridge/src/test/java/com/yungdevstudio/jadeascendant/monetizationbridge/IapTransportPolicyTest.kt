package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.*
import org.junit.Test

class IapTransportPolicyTest {
    private val candidate = IapTransportPolicy(false, "production-candidate", IapTransportPolicy.PRODUCTION_URL, false, true, true)
    @Test fun productionNeedsEveryIndependentCondition() {
        assertTrue(candidate.production)
        for (bad in listOf(candidate.copy(debug=true), candidate.copy(target="staging"),
            candidate.copy(url=IapTransportPolicy.STAGING_URL), candidate.copy(sandboxCredit=true),
            candidate.copy(gameplay=false), candidate.copy(candidate=false),
            candidate.copy(url=IapTransportPolicy.PRODUCTION_URL+"/"))) {
            assertFalse(bad.toString(), bad.production)
            assertFalse(bad.toString(), bad.wallet)
        }
    }
    @Test fun productionRequiresGoogleAndExactServiceHost() {
        assertFalse(candidate.allowsUser(true, false))
        assertFalse(candidate.allowsUser(true, true))
        assertFalse(candidate.allowsUser(false, false))
        assertTrue(candidate.allowsUser(false, true))
        assertTrue(candidate.allowsHost(IapTransportPolicy.PRODUCTION_HOST))
        assertFalse(candidate.allowsHost("attacker.invalid"))
        assertFalse(candidate.allowsHost(IapTransportPolicy.PRODUCTION_HOST+".attacker.invalid"))
    }
    @Test fun stagingRemainsDebugOnlyAndCannotUseProductionHost() {
        val staging = IapTransportPolicy(true,"staging",IapTransportPolicy.STAGING_URL,true,true,false)
        assertTrue(staging.wallet)
        assertTrue(staging.allowsUser(true,false))
        assertFalse(staging.allowsHost(IapTransportPolicy.PRODUCTION_HOST))
        assertFalse(staging.copy(debug=false).wallet)
        assertFalse(staging.copy(candidate=true).wallet)
        assertFalse(staging.copy(url=IapTransportPolicy.PRODUCTION_URL).wallet)
    }
    @Test fun normalReleaseAndCandidateDebugStayLocked() {
        assertFalse(IapTransportPolicy(false,"locked","https://iap-disabled.invalid",false,false,false).wallet)
        assertFalse(IapTransportPolicy(true,"locked","https://iap-disabled.invalid",false,false,false).wallet)
        val compiled = IapTransportPolicy.compiled()
        if (BuildConfig.DEBUG) assertFalse(compiled.production)
        if (compiled.production) assertFalse(compiled.staging)
        if (compiled.target == "locked") assertFalse(compiled.wallet)
    }
}
