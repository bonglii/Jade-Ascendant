package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
class OdysseyContractV1Test {
 private val id="a".repeat(32)
 private fun cmd(action:String)=JSONObject().put("request_id",id).put("event_id","dragon-1").put("revision",0).put("action",JSONObject(action)).toString()
 @Test fun allowsOnlyFixedPacksAndServerActions(){
  for(action in listOf("""{"kind":"roll"}""","""{"kind":"ad_intent"}""","""{"kind":"buy_dice","pack":1}""","""{"kind":"buy_dice","pack":5}"""))assertNotNull(OdysseyContractV1.commandOrNull(id,cmd(action)))
  for(action in listOf("""{"kind":"roll","die":6}""","""{"kind":"buy_dice","pack":5,"price":0}""","""{"kind":"buy_dice","pack":2}""","""{"kind":"buy_dice","pack":1.5}""","""{"kind":"ad_success"}"""))assertNull(OdysseyContractV1.commandOrNull(id,cmd(action)))
 }
 @Test fun requestIdentityAndPayloadSizeAreBounded(){assertNull(OdysseyContractV1.commandOrNull("b".repeat(32),cmd("""{"kind":"roll"}""")));assertFalse(OdysseyContractV1.validId("../x"));assertNull(OdysseyContractV1.commandOrNull(id," ".repeat(1025)))}
 @Test fun validServerSnapshotAndMalformedInputs(){
  val stream=javaClass.classLoader!!.getResourceAsStream("odyssey_snapshot_v1.json")!!
  val snapshot=JSONObject(stream.bufferedReader().use{it.readText()})
  assertNotNull(OdysseyContractV1.canonicalOrNull(snapshot,"alice"))
  val premium=JSONObject(snapshot.toString())
  premium.getJSONObject("limits").put("price_one",10).put("price_five",40)
  assertNotNull(OdysseyContractV1.canonicalOrNull(premium,"alice"))
  premium.getJSONObject("limits").put("price_five",100)
  assertNull(OdysseyContractV1.canonicalOrNull(premium,"alice"))
  premium.getJSONObject("limits").put("price_one",10.5).put("price_five",40)
  assertNull(OdysseyContractV1.canonicalOrNull(premium,"alice"))
  assertNull(OdysseyContractV1.canonicalOrNull(snapshot,"bob"))
  assertNull(OdysseyContractV1.canonicalOrNull(JSONObject(snapshot.toString()).put("version",1.5),"alice"))
assertNull(OdysseyContractV1.canonicalOrNull(JSONObject(),"alice"));assertNull(OdysseyContractV1.canonicalOrNull(JSONObject("""{"version":1,"owner_binding":"forged"}"""),"alice"))}
}
