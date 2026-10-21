package com.yungdevstudio.jadeascendant.monetizationbridge
import org.json.JSONObject
/** Ordinary high-frequency event actions use the SDK cache; payment paths stay limited-use. */
internal object EventAppCheckPolicy {
 fun cached(endpoint:String,method:String,body:String?,base:String):Boolean = try {
  require(base in setOf(IapTransportPolicy.PRODUCTION_URL,IapTransportPolicy.STAGING_URL))
  require(endpoint in setOf(base+"/v4/odyssey",base+"/v1/heavenly-trials"))
  if(endpoint==base+"/v1/heavenly-trials")method=="GET"&&body==null
  else if(method=="GET")body==null else method=="POST"&&body!=null&&JSONObject(body).getJSONObject("action").getString("kind") in setOf("sync","roll","route","counter","mission","milestone","task","missions_all","arena_finish")
 }catch(_:Exception){false}
}
