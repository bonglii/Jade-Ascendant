package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
class HeavenlyTrialsContractV1Test {
 private val id="a".repeat(32)
 private fun cmd(action:String)=JSONObject().put("request_id",id).put("week_id","ht_trials-one_0").put("action",JSONObject(action)).toString()
 private fun snapshot()=JSONObject(javaClass.classLoader!!.getResourceAsStream("heavenly_trials_snapshot_v1.json")!!.bufferedReader().use{it.readText()})
 @Test fun onlyBoundedServerActions(){
  for(a in listOf("""{"kind":"start","tier":1}""","""{"kind":"claim_all"}""","""{"kind":"ad_intent","tier":3}""","""{"kind":"pack_reconcile"}"""))assertNotNull(HeavenlyTrialsContractV1.commandOrNull(id,cmd(a)))
  for(a in listOf("""{"kind":"start","tier":4}""","""{"kind":"start","tier":1.5}""","""{"kind":"claim_all","jade":500}""","""{"kind":"ad_success"}"""))assertNull(HeavenlyTrialsContractV1.commandOrNull(id,cmd(a)))
 }
 @Test fun exactRequestAndReport(){
  assertNull(HeavenlyTrialsContractV1.commandOrNull("b".repeat(32),cmd("""{"kind":"claim_all"}""")))
  val report=cmd("""{"kind":"finish","session_id":"${"c".repeat(32)}","won":true,"time_ms":30000,"hits":0,"deaths":0,"damage":100}""")
  assertNotNull(HeavenlyTrialsContractV1.commandOrNull(id,report));assertNull(HeavenlyTrialsContractV1.commandOrNull(id,report.replace("30000","-1")));assertNull(HeavenlyTrialsContractV1.commandOrNull(id," ".repeat(1025)))
 }
 @Test fun snapshotOwnerAndBudget(){
  assertNotNull(HeavenlyTrialsContractV1.canonicalOrNull(snapshot(),"alice"));assertNull(HeavenlyTrialsContractV1.canonicalOrNull(snapshot(),"bob"))
  assertNull(HeavenlyTrialsContractV1.canonicalOrNull(snapshot().put("local_grant",100),"alice"))
  val amount=snapshot();amount.getJSONObject("week").getJSONObject("reward").put("celestial_jade",41);assertNull(HeavenlyTrialsContractV1.canonicalOrNull(amount,"alice"))
 }
 @Test fun duplicateTiersAndBadAdIntent(){
  val duplicate=snapshot();duplicate.getJSONArray("progress").put(duplicate.getJSONArray("progress").getJSONObject(0));assertNull(HeavenlyTrialsContractV1.canonicalOrNull(duplicate,"alice"))
  val ad=snapshot().put("ad",JSONObject().put("id","fake").put("week","ht_trials-one_0").put("tier",1).put("expires_at",1792358400).put("consumed_at",0));assertNull(HeavenlyTrialsContractV1.canonicalOrNull(ad,"alice"))
 }
 @Test fun safeReadCachesAttestationAndWritesRemainLimited(){
  val base=IapTransportPolicy.PRODUCTION_URL
  assertTrue(EventAppCheckPolicy.cached(base+"/v1/heavenly-trials","GET",null,base));assertFalse(EventAppCheckPolicy.cached(base+"/v1/heavenly-trials","POST",cmd("""{"kind":"claim_all"}"""),base));assertFalse(EventAppCheckPolicy.cached(base+"/v1/iap/authorize-v2","GET",null,base))
 }
}
