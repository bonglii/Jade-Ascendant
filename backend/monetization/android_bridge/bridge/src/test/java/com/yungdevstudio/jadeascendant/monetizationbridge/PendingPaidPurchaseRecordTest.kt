package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
class PendingPaidPurchaseRecordTest {
 @Test fun allSixInternalProductsAcceptBoundedEvidence() {
  assertEquals(6, PendingPaidPurchaseRecord.products.size)
  for (p in PendingPaidPurchaseRecord.products) assertTrue(PendingPaidPurchaseRecord.valid("firebase-user_1", p, "x".repeat(16)))
 }
 @Test fun unknownProductAndInvalidIdentityCannotEnterJournal() {
  assertFalse(PendingPaidPurchaseRecord.valid("uid", "jade_pouch_550", "x".repeat(16)))
  for (uid in listOf("", "../uid", "x".repeat(129), "uid\n"))
   assertFalse(PendingPaidPurchaseRecord.valid(uid, "jade_pouch_100", "x".repeat(16)))
 }
 @Test fun unboundedAndControlValuesAreNotAcceptedAsPurchaseEvidence() {
  for (token in listOf("", "x".repeat(15), "x".repeat(4097), "x".repeat(16)+"\n", " xxxxxxxxxxxxxxxx", "x".repeat(16)+"\u0000"))
   assertFalse(PendingPaidPurchaseRecord.valid("uid", "jade_pouch_100", token))
  assertTrue(PendingPaidPurchaseRecord.valid("uid", "jade_pouch_100", "x".repeat(4096)))
 }
}
