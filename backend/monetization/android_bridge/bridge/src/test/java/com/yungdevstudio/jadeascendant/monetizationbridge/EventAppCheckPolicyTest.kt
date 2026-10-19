package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
class EventAppCheckPolicyTest {
 @Test fun sdkCacheIsLimitedToExactFrequentEventRequests(){
  for(base in listOf(IapTransportPolicy.PRODUCTION_URL,IapTransportPolicy.STAGING_URL)){
   assertTrue(EventAppCheckPolicy.cached(base+"/v4/odyssey","GET",null,base))
   for(kind in listOf("roll","mission","task","missions_all","arena_finish","route","counter","sync","milestone"))assertTrue(EventAppCheckPolicy.cached(base+"/v4/odyssey","POST","""{"action":{"kind":"$kind"}}""",base))
  }
 }
 @Test fun paidAndUnknownPathsRetainFreshTokenPolicy(){
  val b=IapTransportPolicy.PRODUCTION_URL
  for(route in listOf("/v1/iap/authorize-v2","/v1/wallet/gameplay-v2","/v3/odyssey","/v4/odyssey/extra","/v4/odyssey?x=1"))assertFalse(EventAppCheckPolicy.cached(b+route,"GET",null,b))
  for(kind in listOf("buy_dice","ad_intent","grant",""))assertFalse(EventAppCheckPolicy.cached(b+"/v4/odyssey","POST","""{"action":{"kind":"$kind"}}""",b))
  assertFalse(EventAppCheckPolicy.cached("https://evil.invalid/v4/odyssey","GET",null,b));assertFalse(EventAppCheckPolicy.cached(b+"/v4/odyssey","GET","{}",b))
 }
}
