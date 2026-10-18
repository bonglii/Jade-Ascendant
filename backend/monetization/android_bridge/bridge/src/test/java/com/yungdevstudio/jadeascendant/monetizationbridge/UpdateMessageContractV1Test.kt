package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
class UpdateMessageContractV1Test {
    private val now = 1792335000L
    private fun data() = mapOf("kind" to "app_update", "campaign_id" to "a".repeat(32), "version_code" to "12", "title" to "New adventure", "body" to "Update through Google Play.", "expires_at" to (now + 86400).toString())
    private fun parse(d: Map<String,String> = data(), installed: Long=11, highest: Long=0) = UpdateMessageContractV1.parse(d,installed,highest,now)
    @Test fun validNewVersion() { assertEquals(12L,parse()!!.versionCode) }
    @Test fun currentAndNewerInstallationsAreQuiet() { assertNull(parse(installed=12)); assertNull(parse(installed=99)) }
    @Test fun duplicateAndOlderCampaignsAreQuiet() { assertNull(parse(highest=12)); assertNull(parse(highest=13)); assertNotNull(parse(highest=11)) }
    @Test fun expiredAndUnboundedLifetimeRejected() { assertNull(parse(data()+mapOf("expires_at" to now.toString()))); assertNull(parse(data()+mapOf("expires_at" to (now+9*86400).toString()))) }
    @Test fun unknownFieldsCannotSupplyAUrlOrRecipient() { assertNull(parse(data()+mapOf("url" to "https://example.invalid"))); assertNull(parse(data()-"kind")); assertNull(parse(data()+mapOf("kind" to "reward"))) }
    @Test fun invalidVersionAndCampaignRejected() { for(v in listOf("0","-1","1.5","1e3","01","999999999999"))assertNull(parse(data()+mapOf("version_code" to v))); assertNull(parse(data()+mapOf("campaign_id" to "bad"))) }
    @Test fun textIsBoundedPlainText() { assertNull(parse(data()+mapOf("title" to "x".repeat(81)))); assertNull(parse(data()+mapOf("body" to "hello\nworld"))); assertNull(parse(data()+mapOf("body" to " "))); assertNotNull(parse(data()+mapOf("body" to "Update & enjoy <new> adventures"))) }
}
