package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Test

class SecurePurchaseGrantContractTest {
    private fun validGrant(): MutableMap<String, Any> = linkedMapOf(
        "purchase_contract_version" to 1L,
        "state" to "grant_ready",
        "grant_id" to ("iapv1:" + "a".repeat(64)),
        "internal_product_id" to "jade_satchel_550",
        "celestial_jade" to 550L,
    )

    @Test
    fun acceptsExactGrantAndCanonicalizesOnlySafeFields() {
        val grant = SecurePurchaseGrantContract.decode(validGrant())
        assertNotNull(grant)
        grant!!
        assertEquals("iapv1:" + "a".repeat(64), grant.grantId)
        assertEquals("jade_satchel_550", grant.internalProductId)
        assertEquals(550, grant.celestialJade)
    }

    @Test
    fun rejectsExtraKeysWrongAmountAndUnknownProduct() {
        val extra = validGrant()
        extra["purchase_token"] = "must-never-return"
        assertNull(SecurePurchaseGrantContract.decode(extra))

        val wrongAmount = validGrant()
        wrongAmount["celestial_jade"] = 551L
        assertNull(SecurePurchaseGrantContract.decode(wrongAmount))

        val unknown = validGrant()
        unknown["internal_product_id"] = "starter_support_pack"
        assertNull(SecurePurchaseGrantContract.decode(unknown))
    }

    @Test
    fun rejectsMalformedGrantIdAndNonIntegralNumbers() {
        val badId = validGrant()
        badId["grant_id"] = "iapv1:not-a-hash"
        assertNull(SecurePurchaseGrantContract.decode(badId))

        val fractionalVersion = validGrant()
        fractionalVersion["purchase_contract_version"] = 1.5
        assertNull(SecurePurchaseGrantContract.decode(fractionalVersion))

        val fractionalJade = validGrant()
        fractionalJade["celestial_jade"] = 550.5
        assertNull(SecurePurchaseGrantContract.decode(fractionalJade))
    }
}
