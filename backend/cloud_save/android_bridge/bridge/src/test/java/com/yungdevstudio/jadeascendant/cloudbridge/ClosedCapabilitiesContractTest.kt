package com.yungdevstudio.jadeascendant.cloudbridge

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClosedCapabilitiesContractTest {
    private fun valid(): MutableMap<String, Any> = mutableMapOf(
        "capabilities_contract_version" to 1,
        "state" to "cloud_save_disabled",
        "cloud_write_enabled" to false,
        "cloud_restore_enabled" to false,
        "purchase_verification_enabled" to false,
        "economy_verified" to false,
        "server_revision_verified" to false,
        "server_freshness_verified" to false,
    )

    @Test fun acceptsOnlyExplicitDisabledCapabilities() {
        assertTrue(ClosedCapabilitiesContract.accepts(valid()))
        assertTrue(ClosedCapabilitiesContract.accepts(valid().apply {
            this["capabilities_contract_version"] = 1.0
        }))
    }

    @Test fun rejectsEveryEnabledFlag() {
        for (key in valid().keys.filter { it.endsWith("_enabled") || it.endsWith("_verified") }) {
            assertFalse(key, ClosedCapabilitiesContract.accepts(valid().apply { this[key] = true }))
        }
    }

    @Test fun rejectsUnknownVersionAndState() {
        assertFalse(ClosedCapabilitiesContract.accepts(valid().apply {
            this["capabilities_contract_version"] = 2
        }))
        assertFalse(ClosedCapabilitiesContract.accepts(valid().apply {
            this["capabilities_contract_version"] = 1.2
        }))
        assertFalse(ClosedCapabilitiesContract.accepts(valid().apply {
            this["state"] = "cloud_save_enabled"
        }))
    }

    @Test fun rejectsMissingExtraAndWrongTypes() {
        assertFalse(ClosedCapabilitiesContract.accepts(valid().apply { remove("state") }))
        assertFalse(ClosedCapabilitiesContract.accepts(valid().apply { this["owner_uid"] = "forged" }))
        assertFalse(ClosedCapabilitiesContract.accepts(valid().apply { this["economy_verified"] = "false" }))
        assertFalse(ClosedCapabilitiesContract.accepts(emptyMap<String, Any>()))
        assertFalse(ClosedCapabilitiesContract.accepts(null))
        assertFalse(ClosedCapabilitiesContract.accepts(listOf("forged")))
    }
}
