package com.yungdevstudio.jadeascendant.monetizationbridge
import org.json.JSONObject
import java.security.MessageDigest
/** Separate event protocol; paid summon catalog and receipt contracts stay pinned. */
internal object OdysseyContractV1 {
 private val request = Regex("^[a-f0-9]{32}$")
 private fun keys(o:JSONObject)=o.keys().asSequence().toSet()
 private fun whole(v:Any?,lo:Long=0,hi:Long=1_000_000)= (v is Int || v is Long) && (v as Number).toLong() in lo..hi
 fun validId(id:String)=request.matches(id)
 fun commandOrNull(id:String,raw:String):String?=try {
  require(validId(id)&&raw.toByteArray().size<=1024)
  val c=JSONObject(raw);require(keys(c)==setOf("event_id","request_id","revision","action"))
  require(c.getString("request_id")==id&&Regex("^[a-z0-9_-]{3,48}$").matches(c.getString("event_id")))
  require(whole(c.opt("revision"),0,10000))
  val a=c.getJSONObject("action");val kind=a.getString("kind")
  val extra=when(kind){"sync","roll","ad_intent"->emptySet();"route","counter"->setOf("choice");"mission"->setOf("mission");"milestone"->setOf("milestone");"buy_dice"->setOf("pack");else->error("kind")}
  require(keys(a)==setOf("kind")+extra)
  when(kind){"route"->require(a.getString("choice") in setOf("safe","challenge"));"counter"->require(whole(a.opt("choice"),0,2));"mission"->require(whole(a.opt("mission"),1,5)&&a.getInt("mission") in setOf(1,3,5));"milestone"->require(whole(a.opt("milestone"),24,72)&&a.getInt("milestone") in setOf(24,48,72));"buy_dice"->require(whole(a.opt("pack"),1,5)&&a.getInt("pack") in setOf(1,5))}
  c.toString()
 }catch(_:Exception){null}
 fun canonicalOrNull(raw:JSONObject,uid:String):String?=try {
  require(raw.toString().toByteArray().size<=24000)
  val owner=MessageDigest.getInstance("SHA-256").digest(uid.toByteArray()).joinToString(""){"%02x".format(it)}
  require(whole(raw.opt("version"),1,1)&&raw.getString("owner_binding")==owner)
  require(whole(raw.opt("revision"),0,10000)&&whole(raw.opt("server_time"),1,4_102_444_800))
  require(keys(raw).all{it in setOf("version","owner_binding","event","state","revision","server_time","limits","ad_intent","jade_spent","compass_authorized","lease_seconds")})
  if(raw.has("compass_authorized"))require(raw.opt("compass_authorized") is Boolean && whole(raw.opt("lease_seconds"),60,60))
  val s=raw.getJSONObject("state");require(whole(s.opt("tickets"),0,1000)&&whole(s.opt("rolls"),0,152)&&whole(s.opt("position"),0,19))
  for(k in listOf("daily_ads","daily_bought","season_bought","daily_rolls","laps","last_die"))require(whole(s.opt(k),0,1000))
  require(s.getString("pending") in setOf("","route"))
  require(s.getString("notice").length<=160 && s.opt("last_reward") is JSONObject)
  for(k in listOf("missions","milestones")){val list=s.getJSONArray(k);require(list.length()<=3);for(i in 0 until list.length()) require(whole(list.opt(i)) && list.getInt(i) in (if(k=="missions") setOf(1,3,5) else setOf(24,48,72)))}
  if(!s.isNull("battle")){val battle=s.getJSONObject("battle");require(whole(battle.opt("attack"),0,2)&&whole(battle.opt("turn"),0,2)&&whole(battle.opt("hits"),0,3)&&whole(battle.opt("opens_at"),1,4_102_444_800)&&whole(battle.opt("deadline"),1,4_102_444_800))}
  val limits=raw.getJSONObject("limits");for((key,value) in mapOf("free_daily" to 6,"ads_daily" to 2,"paid_daily" to 10,"paid_season" to 40,"max_rolls" to 152,"price_one" to 25,"price_five" to 100))require(whole(limits.opt(key),value.toLong(),value.toLong()))
  if(!raw.isNull("event")){val e=raw.getJSONObject("event");require(Regex("^[a-z0-9_-]{3,48}$").matches(e.getString("id"))&&e.getLong("ends_at")==e.getLong("starts_at")+14*86400)}
  if(raw.has("ad_intent")&&!raw.isNull("ad_intent")){val ad=raw.getJSONObject("ad_intent");require(validId(ad.getString("nonce"))&&whole(ad.opt("expires_at"),1,4_102_444_800))}
  raw.toString()
 }catch(_:Exception){null}
}
