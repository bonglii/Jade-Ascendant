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
  val extra=when(kind){"sync","roll","ad_intent","missions_all"->emptySet();"task"->setOf("task");"arena_finish"->setOf("trace","abandon");"route","counter"->setOf("choice");"mission"->setOf("mission");"milestone"->setOf("milestone");"buy_dice"->setOf("pack");else->error("kind")}
  require(keys(a)==setOf("kind")+extra)
  when(kind){"task"->require(a.getString("task") in setOf("gifts","guardian"));"arena_finish"->require(a.opt("abandon") is Boolean&&Regex("^[0-8]{0,600}$").matches(a.getString("trace")));"route"->require(a.getString("choice") in setOf("safe","challenge"));"counter"->require(whole(a.opt("choice"),0,2));"mission"->require(whole(a.opt("mission"),1,5)&&a.getInt("mission") in setOf(1,3,5));"milestone"->require(whole(a.opt("milestone"),24,72)&&a.getInt("milestone") in setOf(24,48,72));"buy_dice"->require(whole(a.opt("pack"),1,5)&&a.getInt("pack") in setOf(1,5))}
  c.toString()
 }catch(_:Exception){null}
 fun canonicalOrNull(raw:JSONObject,uid:String):String?=try {
  require(raw.toString().toByteArray().size<=24000)
  val owner=MessageDigest.getInstance("SHA-256").digest(uid.toByteArray()).joinToString(""){"%02x".format(it)}
  require(whole(raw.opt("version"),1,1)&&raw.getString("owner_binding")==owner)
  require(whole(raw.opt("revision"),0,10000)&&whole(raw.opt("server_time"),1,4_102_444_800))
  require(keys(raw).all{it in setOf("version","owner_binding","event","state","revision","server_time","limits","ad_intent","jade_spent","compass_authorized","lease_seconds","purchase_bonus")})
  if(raw.has("compass_authorized"))require(raw.opt("compass_authorized") is Boolean && whole(raw.opt("lease_seconds"),60,60))
  if(raw.has("purchase_bonus")){
   val b=raw.getJSONObject("purchase_bonus")
   require(keys(b)==setOf("version","active","once_per_pack","eligible_from","claimed_total","offers"))
   require(whole(b.opt("version"),1,1)&&b.opt("active") is Boolean&&b.opt("once_per_pack")==true&&whole(b.opt("eligible_from"),0,4_102_444_800)&&whole(b.opt("claimed_total"),0,45))
   val tiers=mapOf("jade_pouch_100" to (100 to 1),"jade_satchel_550" to (550 to 3),"jade_casket_1200" to (1200 to 5),"jade_vault_2500" to (2500 to 8),"jade_treasury_6500" to (6500 to 12),"jade_ascendant_14000" to (14000 to 16))
   val offers=b.getJSONArray("offers");require(offers.length()==6);val seen=mutableSetOf<String>();var claimed=0
   for(i in 0 until offers.length()){
    val offer=offers.getJSONObject(i);require(keys(offer)==setOf("product_id","jade","dice","claimed"))
    val product=offer.getString("product_id");val tier=tiers[product]?:error("product")
    require(seen.add(product)&&whole(offer.opt("jade"),tier.first.toLong(),tier.first.toLong())&&whole(offer.opt("dice"),tier.second.toLong(),tier.second.toLong())&&offer.opt("claimed") is Boolean)
    if(offer.getBoolean("claimed"))claimed+=tier.second
   }
   require(claimed==b.getInt("claimed_total"))
  }
  val s=raw.getJSONObject("state");
  if(s.has("task_claims")){val claims=s.getJSONArray("task_claims");require(claims.length()<=2);val seen=mutableSetOf<String>();for(i in 0 until claims.length()){val id=claims.getString(i);require(id in setOf("gifts","guardian")&&seen.add(id))}}
  for(k in listOf("daily_gifts","daily_guardians"))if(s.has(k))require(whole(s.opt(k),0,152))
  if(s.has("bonus_dice"))require(whole(s.opt("bonus_dice"),0,45));require(whole(s.opt("tickets"),0,1000)&&whole(s.opt("rolls"),0,152)&&whole(s.opt("position"),0,19))
  for(k in listOf("daily_ads","daily_bought","season_bought","daily_rolls","laps","last_die"))require(whole(s.opt(k),0,1000))
  require(s.getString("pending") in setOf("","route"))
  require(s.getString("notice").length<=160 && s.opt("last_reward") is JSONObject)
  for(k in listOf("missions","milestones")){val list=s.getJSONArray(k);require(list.length()<=3);for(i in 0 until list.length()) require(whole(list.opt(i)) && list.getInt(i) in (if(k=="missions") setOf(1,3,5) else setOf(24,48,72)))}
  if(!s.isNull("battle")){val battle=s.getJSONObject("battle");if(battle.has("mode")){require(battle.getString("mode")=="arena"&&whole(battle.opt("seed"),0,2147483647)&&whole(battle.opt("started_at"),1,4_102_444_800));require(battle.getLong("deadline")==battle.getLong("started_at")+180)};require(whole(battle.opt("attack"),0,2)&&whole(battle.opt("turn"),0,2)&&whole(battle.opt("hits"),0,3)&&whole(battle.opt("opens_at"),1,4_102_444_800)&&whole(battle.opt("deadline"),1,4_102_444_800))}
  val limits=raw.getJSONObject("limits");for((key,value) in mapOf("free_daily" to 6,"ads_daily" to 2,"paid_daily" to 10,"paid_season" to 40,"max_rolls" to 152))require(whole(limits.opt(key),value.toLong(),value.toLong()))
  require(whole(limits.opt("price_one"),1,25)&&whole(limits.opt("price_five"),1,100))
  require((limits.getInt("price_one")==25&&limits.getInt("price_five")==100)||(limits.getInt("price_one")==10&&limits.getInt("price_five")==40))
  if(!raw.isNull("event")){val e=raw.getJSONObject("event");require(Regex("^[a-z0-9_-]{3,48}$").matches(e.getString("id"))&&e.getLong("ends_at")==e.getLong("starts_at")+14*86400)}
  if(raw.has("ad_intent")&&!raw.isNull("ad_intent")){val ad=raw.getJSONObject("ad_intent");require(validId(ad.getString("nonce"))&&whole(ad.opt("expires_at"),1,4_102_444_800))}
  raw.toString()
 }catch(_:Exception){null}
}
