package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ForegroundReadDispatcherTest {
    private val base = IapTransportPolicy.PRODUCTION_URL

    @Test fun onlyExactAuthenticatedReadRoutesUseTheReadLane() {
        for (root in listOf(base, IapTransportPolicy.STAGING_URL)) {
            for (route in listOf("/v1/wallet/gameplay-v2", "/v4/odyssey", "/v1/heavenly-trials")) {
                assertTrue(ForegroundReadDispatcher.isForegroundRead(root + route, "GET", null, root))
                assertFalse(ForegroundReadDispatcher.isForegroundRead(root + route, "POST", "{}", root))
                assertFalse(ForegroundReadDispatcher.isForegroundRead(root + route, "GET", "", root))
                assertFalse(ForegroundReadDispatcher.isForegroundRead(root + route + "?extra=1", "GET", null, root))
            }
        }
        for (route in listOf("/v1/iap/authorize-v2", "/v1/iap/recover-verified", "/v1/wallet/paid", "/v3/odyssey"))
            assertFalse(ForegroundReadDispatcher.isForegroundRead(base + route, "GET", null, base))
        assertFalse(ForegroundReadDispatcher.isForegroundRead("https://untrusted.invalid/v4/odyssey", "GET", null, base))
        assertFalse(ForegroundReadDispatcher.isForegroundRead("https://untrusted.invalid/v4/odyssey", "GET", null, "https://untrusted.invalid"))
    }

    @Test fun paidAndEventsReadWhileAnOrderedRequestIsStillBlocked() {
        val ordered = Executors.newSingleThreadExecutor()
        val reads = Executors.newFixedThreadPool(3)
        val blocked = CountDownLatch(1)
        val release = CountDownLatch(1)
        val done = CountDownLatch(3)
        try {
            val lanes = ForegroundReadDispatcher(ordered, reads)
            lanes.execute("$base/v1/wallet/gameplay-v2", "POST", "{}", base) {
                blocked.countDown(); release.await(5, TimeUnit.SECONDS)
            }
            assertTrue(blocked.await(2, TimeUnit.SECONDS))
            for (route in listOf("/v1/wallet/gameplay-v2", "/v4/odyssey", "/v1/heavenly-trials"))
                lanes.execute(base + route, "GET", null, base) { done.countDown() }
            assertTrue("All three reads must start without releasing the ordered request", done.await(2, TimeUnit.SECONDS))
            assertEquals(1L, release.count)
        } finally { release.countDown(); ordered.shutdownNow(); reads.shutdownNow() }
    }

    @Test fun mutationsRetainTheExistingOrderedLane() {
        val ordered = Executors.newSingleThreadExecutor()
        val reads = Executors.newFixedThreadPool(3)
        val blocked = CountDownLatch(1)
        val release = CountDownLatch(1)
        val mutationDone = CountDownLatch(1)
        try {
            val lanes = ForegroundReadDispatcher(ordered, reads)
            ordered.execute { blocked.countDown(); release.await(5, TimeUnit.SECONDS) }
            assertTrue(blocked.await(2, TimeUnit.SECONDS))
            lanes.execute("$base/v4/odyssey", "POST", "{\"action\":{\"kind\":\"roll\"}}", base) { mutationDone.countDown() }
            assertFalse("Mutation must stay queued until earlier ordered IO is released", mutationDone.await(100, TimeUnit.MILLISECONDS))
            release.countDown(); assertTrue(mutationDone.await(2, TimeUnit.SECONDS))
        } finally { release.countDown(); ordered.shutdownNow(); reads.shutdownNow() }
    }
}
