package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
class OdysseyFlowContractTest {
 private val id="a".repeat(32)
 private fun cmd(action:JSONObject)=JSONObject().put("request_id",id).put("event_id","dragon-test").put("revision",0).put("action",action).toString()
 private fun snapshot()=JSONObject(javaClass.classLoader!!.getResourceAsStream("odyssey_snapshot_v1.json")!!.bufferedReader().use{it.readText()})
 @Test fun boundedArenaAndDailyActionsUseExistingJournalEnvelope(){
  for(kind in listOf("missions_all","task","arena_finish")){
   val a=JSONObject().put("kind",kind);if(kind=="task")a.put("task","gifts");if(kind=="arena_finish")a.put("trace","0".repeat(600)).put("abandon",false)
   assertNotNull(OdysseyContractV1.commandOrNull(id,cmd(a)));assertTrue(cmd(a).toByteArray().size<=1024)
  }
 }
 @Test fun rejectsForgedArenaResultsAndUnboundedInput(){
  val good=JSONObject().put("kind","arena_finish").put("trace","0").put("abandon",false)
  for(bad in listOf(JSONObject(good.toString()).put("won",true),JSONObject(good.toString()).put("trace","0".repeat(601)),JSONObject(good.toString()).put("trace","9"),JSONObject(good.toString()).put("abandon",1),JSONObject().put("kind","task").put("task","give_jade")))assertNull(OdysseyContractV1.commandOrNull(id,cmd(bad)))
 }
 @Test fun validatesArenaAndDailySnapshotWithoutBreakingLegacy(){
  val s=snapshot();assertNotNull(OdysseyContractV1.canonicalOrNull(s,"alice"))
  s.getJSONObject("state").put("daily_gifts",3).put("daily_guardians",1).put("task_claims",org.json.JSONArray("[\"gifts\"]")).put("battle",JSONObject("""{"mode":"arena","seed":917,"started_at":1800000000,"deadline":1800000180,"attack":0,"turn":0,"hits":0,"opens_at":1800000000}"""))
  assertNotNull(OdysseyContractV1.canonicalOrNull(s,"alice"));s.getJSONObject("state").getJSONObject("battle").put("seed",-1);assertNull(OdysseyContractV1.canonicalOrNull(s,"alice"))
 }
}
