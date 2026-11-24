package com.softify.app

import com.softify.app.sync.HlcClock
import com.softify.app.sync.HlcTimestamp
import com.softify.app.sync.generateRecoveryCode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HlcTest {

    @Test
    fun testHlcMonotonicityUnderSameMillisecond() {
        var simulatedPhysicalTime = 1700000000000L
        val clock = HlcClock(nodeId = "nodeA", physicalClock = { simulatedPhysicalTime })

        val t1 = clock.now()
        val t2 = clock.now()
        val t3 = clock.now()

        assertEquals(1700000000000L, t1.millis)
        assertEquals(0, t1.counter)

        assertEquals(1700000000000L, t2.millis)
        assertEquals(1, t2.counter)

        assertEquals(1700000000000L, t3.millis)
        assertEquals(2, t3.counter)

        assertTrue(t1 < t2)
        assertTrue(t2 < t3)
    }

    @Test
    fun testHlcAdvancesWhenPhysicalTimeMovesForward() {
        var simulatedPhysicalTime = 1700000000000L
        val clock = HlcClock(nodeId = "nodeA", physicalClock = { simulatedPhysicalTime })

        val t1 = clock.now()
        assertEquals(0, t1.counter)

        simulatedPhysicalTime += 100L
        val t2 = clock.now()

        assertEquals(1700000000100L, t2.millis)
        assertEquals(0, t2.counter)
        assertTrue(t1 < t2)
    }

    @Test
    fun testHlcUpdateFromRemoteAhead() {
        var localTime = 1700000000000L
        val localClock = HlcClock(nodeId = "local", physicalClock = { localTime })

        val remoteHlc = HlcTimestamp(millis = 1700000050000L, counter = 5, nodeId = "remote")
        val updated = localClock.update(remoteHlc)

        assertEquals(1700000050000L, updated.millis)
        assertEquals(6, updated.counter)
        assertTrue(updated > remoteHlc)
    }

    @Test
    fun testRecoveryCodeFormatAndDeterminism() {
        val seed = "test-device-uuid-12345"
        val code1 = generateRecoveryCode(seed)
        val code2 = generateRecoveryCode(seed)

        assertEquals(code1, code2, "Recovery code must be deterministic for identical seeds")
        assertTrue(code1.startsWith("SOFT-"), "Code must start with SOFT- prefix")
        assertEquals(19, code1.length, "Code must be 19 characters (SOFT-XXXX-XXXX-XXXX)")

        val parts = code1.split("-")
        assertEquals(4, parts.size)
        assertEquals("SOFT", parts[0])
        assertEquals(4, parts[1].length)
        assertEquals(4, parts[2].length)
        assertEquals(4, parts[3].length)
    }
}
