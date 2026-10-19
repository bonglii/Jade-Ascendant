package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
import org.json.JSONArray
class OdysseyPurchaseBonusTest {
 private fun snapshot()=JSONObject(javaClass.classLoader!!.getResourceAsStream("odyssey_snapshot_v1.json")!!.bufferedReader().use{it.readText()})
 private fun bonus():JSONObject {
  val ids=listOf("jade_pouch_100","jade_satchel_550","jade_casket_1200","jade_vault_2500","jade_treasury_6500","jade_ascendant_14000")
  val jade=listOf(100,550,1200,2500,6500,14000);val dice=listOf(1,3,5,8,12,16);val offers=JSONArray()
  for(i in ids.indices)offers.put(JSONObject().put("product_id",ids[i]).put("jade",jade[i]).put("dice",dice[i]).put("claimed",false))
  return JSONObject().put("version",1).put("active",true).put("once_per_pack",true).put("eligible_from",1800000000).put("claimed_total",0).put("offers",offers)
 }
 @Test fun acceptsLegacyAndExactSixPackSnapshot(){
  assertNotNull(OdysseyContractV1.canonicalOrNull(snapshot(),"alice"))
  val s=snapshot().put("purchase_bonus",bonus());assertNotNull(OdysseyContractV1.canonicalOrNull(s,"alice"))
  s.getJSONObject("purchase_bonus").getJSONArray("offers").getJSONObject(1).put("claimed",true)
  s.getJSONObject("purchase_bonus").put("claimed_total",3);s.getJSONObject("state").put("bonus_dice",3)
  assertNotNull(OdysseyContractV1.canonicalOrNull(s,"alice"))
 }
 @Test fun rejectsForgedBonusValuesDuplicatesPricesAndOwner(){
  val mutations:List<(JSONObject)->Unit> = listOf(
   {it.put("once_per_pack",false)}, {it.put("claimed_total",45)}, {it.put("active","true")},
   {it.getJSONArray("offers").getJSONObject(0).put("dice",99)},
   {it.getJSONArray("offers").getJSONObject(0).put("jade",1)},
   {it.getJSONArray("offers").getJSONObject(1).put("product_id","jade_pouch_100")},
   {it.getJSONArray("offers").getJSONObject(0).put("price",0)},
   {it.put("offers",JSONArray())}
  )
  for(change in mutations){val b=bonus();change(b);assertNull(OdysseyContractV1.canonicalOrNull(snapshot().put("purchase_bonus",b),"alice"))}
  assertNull(OdysseyContractV1.canonicalOrNull(snapshot().put("purchase_bonus",bonus()),"bob"))
  val s=snapshot().put("purchase_bonus",bonus());s.getJSONObject("state").put("bonus_dice",46);assertNull(OdysseyContractV1.canonicalOrNull(s,"alice"))
 }
}
