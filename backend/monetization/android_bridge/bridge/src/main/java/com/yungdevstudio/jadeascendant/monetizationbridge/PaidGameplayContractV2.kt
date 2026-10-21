package com.yungdevstudio.jadeascendant.monetizationbridge
import org.json.JSONObject
import java.security.MessageDigest
/** Strict network boundary. Amounts/outcomes never come from the command caller. */
internal object PaidGameplayContractV2 {
 const val HASH = "16cfc8c6171f52bb60dfc76eb756769f6e13ce7122d87bec531bb46d75c8565a"
 private val uuid = Regex("^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$")
 private val slots = setOf("armament","robe","bracer","boots","pendant")
 private val items = mapOf(
  "ascendant_heart" to Pair("pendant","legendary"),
  "bamboo_weave_robe" to Pair("robe","rare"),
  "celestial_aegis_boots" to Pair("boots","legendary"),
  "celestial_aegis_bracer" to Pair("bracer","legendary"),
  "celestial_aegis_pendant" to Pair("pendant","legendary"),
  "celestial_aegis_robe" to Pair("robe","legendary"),
  "celestial_returning_glaive" to Pair("armament","legendary"),
  "cinnabar_moon_saber" to Pair("armament","epic"),
  "cloudstep_boots" to Pair("boots","common"),
  "cloudtreader_boots" to Pair("boots","legendary"),
  "dawn_meridian_robe" to Pair("robe","legendary"),
  "earthseal_bracer" to Pair("bracer","rare"),
  "frost_lotus_boots" to Pair("boots","epic"),
  "frost_lotus_bracer" to Pair("bracer","epic"),
  "frost_lotus_pendant" to Pair("pendant","epic"),
  "frost_lotus_robe" to Pair("robe","epic"),
  "glassmoon_robe" to Pair("robe","epic"),
  "golden_core_pendant" to Pair("pendant","legendary"),
  "guardian_jade_pendant" to Pair("pendant","rare"),
  "jade_binding_chain" to Pair("armament","legendary"),
  "jade_edge_bracer" to Pair("bracer","rare"),
  "jade_guard_bracer" to Pair("bracer","common"),
  "mirror_edge_bracer" to Pair("bracer","rare"),
  "mirror_heart_pendant" to Pair("pendant","epic"),
  "miststride_boots" to Pair("boots","rare"),
  "mistveil_jian" to Pair("armament","rare"),
  "moonthread_robe" to Pair("robe","rare"),
  "mountain_ward_jian" to Pair("armament","rare"),
  "nine_heavens_star_sword" to Pair("armament","legendary"),
  "phoenix_war_fan" to Pair("armament","epic"),
  "qi_reservoir_pendant" to Pair("pendant","rare"),
  "reflection_bracer" to Pair("bracer","epic"),
  "rootstep_boots" to Pair("boots","rare"),
  "shadowstep_boots" to Pair("boots","epic"),
  "shrine_seal_pendant" to Pair("pendant","epic"),
  "silent_ripple_boots" to Pair("boots","epic"),
  "solar_edict_bracer" to Pair("bracer","legendary"),
  "sovereign_mantle" to Pair("robe","legendary"),
  "spirit_jade_pendant" to Pair("pendant","common"),
  "spirit_seal_fan" to Pair("armament","rare"),
  "starstep_boots" to Pair("boots","epic"),
  "stillwater_mirror_blade" to Pair("armament","epic"),
  "stone_meridian_robe" to Pair("robe","rare"),
  "stormcall_bracer" to Pair("bracer","epic"),
  "sunfire_dragon_jian" to Pair("armament","legendary"),
  "sunstride_boots" to Pair("boots","legendary"),
  "sword_heart_pendant" to Pair("pendant","epic"),
  "tribulation_bracer" to Pair("bracer","legendary"),
  "verdant_qi_robe" to Pair("robe","common"),
  "vermilion_verdict_boots" to Pair("boots","legendary"),
  "vermilion_verdict_bracer" to Pair("bracer","legendary"),
  "vermilion_verdict_pendant" to Pair("pendant","legendary"),
  "vermilion_verdict_robe" to Pair("robe","legendary"),
  "void_piercer_spear" to Pair("armament","legendary"),
  "wanderer_jade_jian" to Pair("armament","common"),
  "ward_keeper_robe" to Pair("robe","epic")
 )
 private fun keys(o: JSONObject) = o.keys().asSequence().toSet()
 private fun exact(o: JSONObject, vararg names: String) = keys(o) == names.toSet()
 private fun whole(v: Any?, lo: Long = 0L, hi: Long = 1_000_000_000L): Boolean =
  (v is Int || v is Long) && (v as Number).toLong() in lo..hi
 private fun pity(o: JSONObject) = exact(o,"rare_plus","epic_plus","legendary") &&
  whole(o.opt("rare_plus"),0,9) && whole(o.opt("epic_plus"),0,29) && whole(o.opt("legendary"),0,49)
 fun validRequestId(id: String) = uuid.matches(id)
 fun commandOrNull(id: String, raw: String): String? = try {
  require(uuid.matches(id) && raw.toByteArray(Charsets.UTF_8).size <= 1024)
  val c=JSONObject(raw); val kind=c.getString("kind")
  val extra=when(kind){"initialize"->emptySet();"summon","seal_summon"->setOf("pull_count");"equip"->setOf("slot","item_id");"refine","wish"->setOf("item_id");"run_start"->setOf("run_id","weapon_level");"run_resume"->setOf("run_id");else->error("kind")}
  require(keys(c)==setOf("request_id","expected_revision","kind")+extra && c.getString("request_id")==id)
  require(whole(c.opt("expected_revision"),0,9_007_199_254_740_989L))
  if("run_id" in extra) require(c.opt("run_id") is String && uuid.matches(c.getString("run_id")))
  if(kind=="run_start") require(whole(c.opt("weapon_level"),0,50))
  if(kind=="initialize") require(c.getLong("expected_revision")==0L)
  if(kind=="summon"||kind=="seal_summon") require(whole(c.opt("pull_count"),1,10) && c.getInt("pull_count") in (if(kind=="seal_summon") setOf(1) else setOf(1,10)))
  if("item_id" in extra){val item=c.getString("item_id");require(item=="" || item in items)
   if(kind=="refine") require(item in items)
   if(kind=="wish") require(item=="" || items[item]?.second=="legendary")
   if(kind=="equip") require(c.getString("slot") in slots && (item=="" || items[item]?.first==c.getString("slot")))
  }
  c.toString()
 } catch (_: Exception){null}
 fun canonicalOrNull(raw: JSONObject, uid: String, requestId: String, command: String?): String? = try {
  require(exact(raw,"snapshot","operation"))
  val s=raw.getJSONObject("snapshot")
  require(exact(s,"paid_gameplay_version","account_binding","catalog_hash","state","revision","wallet","inventory","stars","slots","pity","wish","wish_guaranteed","lifetime_pulls","rates","lease_seconds"))
  val owner=MessageDigest.getInstance("SHA-256").digest(uid.toByteArray(Charsets.UTF_8)).joinToString(""){"%02x".format(it)}
  require(whole(s.opt("paid_gameplay_version"),2,2) && s.getString("account_binding")==owner && s.getString("catalog_hash")==HASH)
  require(s.getString("state") in setOf("ready","unfunded","initialize_required"))
  require(whole(s.opt("revision"),0,9_007_199_254_740_990L))
  val w=s.getJSONObject("wallet");require(exact(w,"balance","revision") && whole(w.opt("balance"),0,9_007_199_254_740_991L) && whole(w.opt("revision"),0,9_007_199_254_740_991L))
  val inv=s.getJSONObject("inventory");val stars=s.getJSONObject("stars");require(keys(inv).size<=56 && keys(inv)==keys(stars))
  for(id in keys(inv)) require(id in items && whole(inv.opt(id),1) && whole(stars.opt(id),1,5))
  val equipped=s.getJSONObject("slots");require(keys(equipped)==slots)
  for(slot in slots){val id=equipped.getString(slot);require(id=="" || (inv.has(id) && items[id]?.first==slot))}
  require(pity(s.getJSONObject("pity")) && whole(s.opt("lifetime_pulls")))
  val wish=s.getString("wish");require(wish=="" || items[wish]?.second=="legendary")
  require(s.opt("wish_guaranteed") is Boolean && (!s.getBoolean("wish_guaranteed") || wish!=""))
  val rates=s.getJSONObject("rates");require(exact(rates,"common","rare","epic","legendary"))
  for((key,n) in mapOf("common" to 6000L,"rare" to 2900L,"epic" to 900L,"legendary" to 200L)) require(whole(rates.opt(key),n,n))
  require(whole(s.opt("lease_seconds"),120,120))
  if(s.getString("state")!="ready") require(inv.length()==0 && s.getLong("revision")==0L && slots.all{equipped.getString(it)==""})
  if(command==null) require(raw.isNull("operation")) else {
   val c=JSONObject(command);val op=raw.getJSONObject("operation")
   require(exact(op,"request_id","kind","outcome") && op.getString("request_id")==requestId)
   val kind=op.getString("kind");require(kind==c.getString("kind") || kind=="not_committed")
   if(kind=="summon"||kind=="seal_summon"){
    val o=op.getJSONObject("outcome");require(exact(o,"pull_count","results","next_pity") && whole(o.opt("pull_count"),1,10) && o.getInt("pull_count")==c.getInt("pull_count"))
    require(pity(o.getJSONObject("next_pity")))
    val list=o.getJSONArray("results");require(list.length()==o.getInt("pull_count"))
    for(i in 0 until list.length()){
     val item=list.getJSONObject(i);require(exact(item,"item_id","rarity","duplicate","duplicate_shards","hard_legendary_pity","wish_hit","wish_fate_activated","wish_fate_consumed"))
     val id=item.getString("item_id");require(id in items && items[id]?.second==item.getString("rarity") && whole(item.opt("duplicate_shards"),0,0))
     for(flag in listOf("duplicate","hard_legendary_pity","wish_hit","wish_fate_activated","wish_fate_consumed")) require(item.opt(flag) is Boolean)
    }
   }else if(kind=="run_start" || kind=="run_resume"){
    val r=op.getJSONObject("outcome");require(exact(r,"run_id","slots","stars","weapon_level") && r.getString("run_id")==c.getString("run_id"))
    val rs=r.getJSONObject("slots");val rt=r.getJSONObject("stars");require(keys(rs)==slots)
    val ids=slots.map{rs.getString(it)}.filter{it!=""}.toSet();require(keys(rt)==ids)
    for(slot in slots){val id=rs.getString(slot);require(id=="" || (inv.has(id) && items[id]?.first==slot && whole(rt.opt(id),1,5)))}
    val arm=rs.getString("armament");require(whole(r.opt("weapon_level"),if(arm=="")0L else 1L,if(arm=="")0L else rt.getLong(arm)*10))
    if(kind=="run_start") require(r.getLong("weapon_level")==c.getLong("weapon_level"))
   }else require(op.isNull("outcome"))
  }
  raw.toString()
 }catch(_:Exception){null}
}
