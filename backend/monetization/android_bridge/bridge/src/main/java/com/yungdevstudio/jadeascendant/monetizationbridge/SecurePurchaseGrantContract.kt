package com.yungdevstudio.jadeascendant.monetizationbridge

internal object SecurePurchaseGrantContract {
    private const val CONTRACT_VERSION = 1
    private const val STATE_GRANT_READY = "grant_ready"
    private val grantId = Regex("^iapv1:[a-f0-9]{64}$")
    private val jadeByInternalProduct = mapOf(
        "jade_pouch_100" to 100,
        "jade_satchel_550" to 550,
        "jade_casket_1200" to 1200,
        "jade_vault_2500" to 2500,
        "jade_treasury_6500" to 6500,
        "jade_ascendant_14000" to 14000,
    )

    data class VerifiedGrant(
        val grantId: String,
        val internalProductId: String,
        val celestialJade: Int,
    ) {
        fun canonicalJson(): String =
            "{\"purchase_contract_version\":1," +
                "\"state\":\"grant_ready\"," +
                "\"grant_id\":\"$grantId\"," +
                "\"internal_product_id\":\"$internalProductId\"," +
                "\"celestial_jade\":$celestialJade}"
    }

    fun decode(data: Any?): VerifiedGrant? {
        if (data !is Map<*, *>) return null
        val required = setOf(
            "purchase_contract_version",
            "state",
            "grant_id",
            "internal_product_id",
            "celestial_jade",
        )
        if (data.keys != required) return null
        val version = exactInt(data["purchase_contract_version"]) ?: return null
        if (version != CONTRACT_VERSION) return null
        if (data["state"] != STATE_GRANT_READY) return null
        val safeGrantId = data["grant_id"] as? String ?: return null
        if (!grantId.matches(safeGrantId)) return null
        val productId = data["internal_product_id"] as? String ?: return null
        val expectedJade = jadeByInternalProduct[productId] ?: return null
        val jade = exactInt(data["celestial_jade"]) ?: return null
        if (jade != expectedJade) return null
        return VerifiedGrant(safeGrantId, productId, jade)
    }

    private fun exactInt(value: Any?): Int? {
        if (value !is Number) return null
        val number = value.toDouble()
        if (!number.isFinite() || number % 1.0 != 0.0) return null
        if (number < Int.MIN_VALUE.toDouble() || number > Int.MAX_VALUE.toDouble()) return null
        return number.toInt()
    }
}
