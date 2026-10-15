package com.yungdevstudio.jadeascendant.monetizationbridge

internal data class PendingPaidPurchaseRecord(val product: String, val token: String) {
    companion object {
        val products = setOf("jade_pouch_100", "jade_satchel_550", "jade_casket_1200",
            "jade_vault_2500", "jade_treasury_6500", "jade_ascendant_14000")
        fun valid(uid: String, product: String, token: String) =
            uid.matches(Regex("^[A-Za-z0-9_-]{1,128}$")) && product in products &&
                token.matches(Regex("^[\\x21-\\x7E]{16,4096}$"))
    }
}
