package com.yungdevstudio.jadeascendant.monetizationbridge
import org.junit.Assert.*
import org.junit.Test
class PendingPaidPurchaseRecordTest {
 @Test fun existingSixAndDedicatedTrialsProductAcceptBoundedEvidence() {
  assertEquals(setOf("jade_pouch_100","jade_satchel_550","jade_casket_1200","jade_vault_2500","jade_treasury_6500","jade_ascendant_14000","heavenly_trials_support_550"), PendingPaidPurchaseRecord.products)
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
