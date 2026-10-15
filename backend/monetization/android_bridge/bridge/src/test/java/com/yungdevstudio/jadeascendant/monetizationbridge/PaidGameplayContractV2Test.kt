package com.yungdevstudio.jadeascendant.monetizationbridge
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.security.MessageDigest
class PaidGameplayContractV2Test {
 private val uid="paid-user"
 private val request="11111111-1111-4111-8111-111111111111"
 private val owner=MessageDigest.getInstance("SHA-256").digest(uid.toByteArray()).joinToString(""){"%02x".format(it)}
 private fun snapshot(): JSONObject = JSONObject("""{"paid_gameplay_version":2,"account_binding":"$owner","catalog_hash":"${PaidGameplayContractV2.HASH}","state":"ready","revision":1,"wallet":{"balance":1500,"revision":2},"inventory":{"cloudstep_boots":9},"stars":{"cloudstep_boots":1},"slots":{"armament":"","robe":"","bracer":"","boots":"cloudstep_boots","pendant":""},"pity":{"rare_plus":0,"epic_plus":10,"legendary":10},"wish":"","wish_guaranteed":false,"lifetime_pulls":10,"rates":{"common":6000,"rare":2900,"epic":900,"legendary":200},"lease_seconds":120}""")
 private fun read(s: JSONObject=snapshot())=JSONObject().put("snapshot",s).put("operation",JSONObject.NULL)
 private fun decode(s: JSONObject)=PaidGameplayContractV2.canonicalOrNull(s,uid,request,null)
 private fun cmd(kind: String="refine")=JSONObject().put("request_id",request).put("expected_revision",1).put("kind",kind).put("item_id","cloudstep_boots")
 @Test fun validOwnershipReadAndSameAccountOnly(){assertNotNull(decode(read()));assertNull(PaidGameplayContractV2.canonicalOrNull(read(),"other",request,null))}
 @Test fun ratesLeaseCatalogAndUnknownFieldsFailClosed(){
  assertNull(decode(read(snapshot().put("catalog_hash","0".repeat(64)))))
  assertNull(decode(read(snapshot().put("lease_seconds",121))))
  assertNull(decode(read(snapshot().put("unverified",true))))
  val s=snapshot();s.getJSONObject("rates").put("common",6001);assertNull(decode(read(s)))
 }
 @Test fun fractionalOrStringAmountsCannotBecomeBalance(){for(v in listOf<Any>(1.5,"1500",true,-1)){
  val s=snapshot();s.getJSONObject("wallet").put("balance",v);assertNull(decode(read(s)))
 }}
 @Test fun slotOwnershipAndCorrectSlotAreRequired(){
  val s=snapshot();s.getJSONObject("slots").put("armament","cloudstep_boots");assertNull(decode(read(s)))
  val missing=snapshot();missing.put("inventory",JSONObject());missing.put("stars",JSONObject());assertNull(decode(read(missing)))
 }
 @Test fun maxStarsAndMatchingCopiesAreRequired(){val s=snapshot();s.getJSONObject("stars").put("cloudstep_boots",6);assertNull(decode(read(s)))}
 @Test fun unfundedStateCannotAssertOwnedEquipment(){assertNull(decode(read(snapshot().put("state","unfunded"))))}
 @Test fun commandRejectsCallerBalanceAndUnknownItems(){
  assertNotNull(PaidGameplayContractV2.commandOrNull(request,cmd().toString()))
  assertNull(PaidGameplayContractV2.commandOrNull(request,cmd().put("balance",9999).toString()))
  assertNull(PaidGameplayContractV2.commandOrNull(request,cmd().put("item_id","fake_weapon").toString()))
  assertNull(PaidGameplayContractV2.commandOrNull(request,cmd().put("expected_revision",1.5).toString()))
 }
 @Test fun requestCorrelationAndCancellationAreStrict(){
  val c=cmd().toString();val op=JSONObject().put("request_id",request).put("kind","not_committed").put("outcome",JSONObject.NULL)
  val raw=read().put("operation",op)
  assertNotNull(PaidGameplayContractV2.canonicalOrNull(raw,uid,request,c))
  assertNull(PaidGameplayContractV2.canonicalOrNull(raw,uid,request,null))
  op.put("request_id","22222222-2222-4222-8222-222222222222")
  assertNull(PaidGameplayContractV2.canonicalOrNull(raw,uid,request,c))
 }
 @Test fun wrongSlotWishAndPullCountNeverReachTransport(){
  assertNull(PaidGameplayContractV2.commandOrNull(request,cmd("equip").put("slot","armament").toString()))
  assertNull(PaidGameplayContractV2.commandOrNull(request,cmd("wish").toString()))
  val c=JSONObject().put("request_id",request).put("kind","summon").put("expected_revision",0).put("pull_count",2)
  assertNull(PaidGameplayContractV2.commandOrNull(request,c.toString()))
 }

 private fun runCommand(kind: String="run_start")=JSONObject().put("request_id",request).put("expected_revision",1).put("kind",kind).put("run_id",request).also{if(kind=="run_start")it.put("weapon_level",0)}
 private fun runReply(c: JSONObject): JSONObject {
  val s=snapshot();val frozen=JSONObject().put("run_id",request).put("slots",JSONObject(s.getJSONObject("slots").toString())).put("stars",JSONObject(s.getJSONObject("stars").toString())).put("weapon_level",0)
  return read(s).put("operation",JSONObject().put("request_id",request).put("kind",c.getString("kind")).put("outcome",frozen))
 }
 @Test fun runCommandsHaveExactOpaqueReferenceAndNoCallerOwnership(){
  for(kind in listOf("run_start","run_resume")){
   val c=runCommand(kind);assertNotNull(PaidGameplayContractV2.commandOrNull(request,c.toString()))
   assertNull(PaidGameplayContractV2.commandOrNull(request,JSONObject(c.toString()).put("slots",JSONObject()).toString()))
   assertNull(PaidGameplayContractV2.commandOrNull(request,c.put("run_id","bad").toString()))
  }
  assertNull(PaidGameplayContractV2.commandOrNull(request,runCommand().put("weapon_level",1.5).toString()))
 }
 @Test fun runReceiptIsOwnedCorrelatedAndBounded(){
  val c=runCommand();val r=runReply(c)
  assertNotNull(PaidGameplayContractV2.canonicalOrNull(r,uid,request,c.toString()))
  val o=r.getJSONObject("operation").getJSONObject("outcome")
  o.put("run_id","22222222-2222-4222-8222-222222222222");assertNull(PaidGameplayContractV2.canonicalOrNull(r,uid,request,c.toString()))
  o.put("run_id",request);o.getJSONObject("slots").put("armament","jade_binding_chain");assertNull(PaidGameplayContractV2.canonicalOrNull(r,uid,request,c.toString()))
 }
 @Test fun restoredRunDoesNotRequireMatchingCurrentHubSelection(){
  val c=runCommand("run_resume");val r=runReply(c);val s=r.getJSONObject("snapshot")
  s.getJSONObject("slots").put("boots","");s.getJSONObject("stars").put("cloudstep_boots",2)
  assertNotNull(PaidGameplayContractV2.canonicalOrNull(r,uid,request,c.toString()))
  r.getJSONObject("operation").getJSONObject("outcome").getJSONObject("stars").put("cloudstep_boots",6)
  assertNull(PaidGameplayContractV2.canonicalOrNull(r,uid,request,c.toString()))
 }
}
