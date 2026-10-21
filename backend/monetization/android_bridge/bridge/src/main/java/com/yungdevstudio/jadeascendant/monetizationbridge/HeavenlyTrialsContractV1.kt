package com.yungdevstudio.jadeascendant.monetizationbridge
import org.json.JSONObject
import java.security.MessageDigest
/** Signed account-bound weekly event. This validates protocol, not combat truth. */
internal object HeavenlyTrialsContractV1 {
 private val id=Regex("^[a-f0-9]{32}$")
 private val week=Regex("^ht_[a-z0-9_-]{3,64}$")
 private val themes=setOf("jade_wind","scarlet_rite","starfall","froststep","sunforge")
 private fun keys(o:JSONObject)=o.keys().asSequence().toSet()
 private fun whole(v:Any?,low:Long=0,high:Long=4_102_444_800)= (v is Int || v is Long) && (v as Number).toLong() in low..high
 fun validId(value:String)=id.matches(value)
 fun commandOrNull(requestId:String,raw:String):String?=try {
  require(validId(requestId)&&raw.toByteArray().size<=1024)
  val c=JSONObject(raw);require(keys(c)==setOf("request_id","week_id","action")&&c.getString("request_id")==requestId&&week.matches(c.getString("week_id")))
  val a=c.getJSONObject("action");val kind=a.getString("kind")
  val extra=when(kind){"start","ad_intent"->setOf("tier");"finish"->setOf("session_id","won","time_ms","hits","deaths","damage");"abandon"->setOf("session_id");"claim_all","pack_reconcile"->emptySet();else->error("kind")}
  require(keys(a)==setOf("kind")+extra)
  if(a.has("tier"))require(whole(a.opt("tier"),1,3))
  if(a.has("session_id"))require(validId(a.getString("session_id")))
  if(kind=="finish"){require(a.opt("won") is Boolean&&whole(a.opt("time_ms"),0,900000)&&whole(a.opt("hits"),0,100000)&&whole(a.opt("deaths"),0,100)&&whole(a.opt("damage"),0,1000000000))}
  c.toString()
 }catch(_:Exception){null}
 private fun checkWeek(w:JSONObject){
  require(week.matches(w.getString("id"))&&w.getString("theme") in themes&&whole(w.opt("stage"),1,5)&&whole(w.opt("index")))
  require(whole(w.opt("starts_at"))&&w.getLong("ends_at")==w.getLong("starts_at")+604800)
  val r=w.getJSONObject("reward");require(keys(r)==setOf("celestial_jade","pavilion_seal","spirit_stone"))
  require(whole(r.opt("celestial_jade"),0,40)&&whole(r.opt("pavilion_seal"),0,1)&&whole(r.opt("spirit_stone"),0,600))
 }
 fun canonicalOrNull(raw:JSONObject,uid:String):String?=try {
  require(raw.toString().toByteArray().size<=24000)
  val owner=MessageDigest.getInstance("SHA-256").digest(uid.toByteArray()).joinToString(""){"%02x".format(it)}
  require(raw.getString("owner_binding")==owner&&whole(raw.opt("version"),1,1)&&whole(raw.opt("server_time"),1)&&whole(raw.opt("unlock_tier"),0,3))
  require(keys(raw)==setOf("bonus_seals","version","owner_binding","server_time","campaign","week","unlock_tier","progress","previous","previous_progress","session","ad","pack_claimed","ad_unit","ads_ready","shop_ready","pack_product"))
  require(whole(raw.opt("bonus_seals"),0,1000000)&&raw.getString("pack_product")=="heavenly_trials_support_550")
  for(k in listOf("pack_claimed","ads_ready","shop_ready"))require(raw.opt(k) is Boolean)
  val unit=raw.getString("ad_unit");require(unit.isEmpty()||Regex("^ca-app-pub-[0-9]{16}/[0-9]{10}$").matches(unit))
  for(k in listOf("week","previous"))if(!raw.isNull(k))checkWeek(raw.getJSONObject(k))
  if(!raw.isNull("campaign")){val c=raw.getJSONObject("campaign");require(Regex("^[a-z0-9_-]{3,40}$").matches(c.getString("id")));for(k in listOf("enabled","ads_enabled","shop_enabled"))require(c.opt(k) is Boolean)}
  for(k in listOf("progress","previous_progress")){val rows=raw.getJSONArray(k);require(rows.length()<=3);val seen=mutableSetOf<Int>();for(i in 0 until rows.length()){val p=rows.getJSONObject(i);require(p.getString("owner")==owner&&week.matches(p.getString("week"))&&whole(p.opt("tier"),1,3)&&seen.add(p.getInt("tier")));require(whole(p.opt("clears"),0,1000000)&&whole(p.opt("best_ms"),0,900000));for(flag in listOf("survivor","untouched","claimed","bonus"))require(whole(p.opt(flag),0,1))}}
  if(!raw.isNull("session")){val s=raw.getJSONObject("session");require(validId(s.getString("id"))&&week.matches(s.getString("week"))&&whole(s.opt("tier"),1,3)&&whole(s.opt("started_at"))&&whole(s.opt("expires_at")))}
  if(!raw.isNull("ad")){val a=raw.getJSONObject("ad");require(validId(a.getString("id"))&&week.matches(a.getString("week"))&&whole(a.opt("tier"),1,3)&&whole(a.opt("expires_at"))&&whole(a.opt("consumed_at")))}
  raw.toString()
 }catch(_:Exception){null}
}
