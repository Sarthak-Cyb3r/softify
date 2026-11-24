package com.softify.app

import com.softify.app.telemetry.TelemetryManager
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TelemetryTest {

    @Test
    fun testTelemetryDisabledByDefault() {
        val manager = TelemetryManager(initialOptIn = false)
        assertFalse(manager.isOptIn.value)

        val recorded = manager.recordEvent("TEST_EVENT", "4.3.0")
        assertFalse(recorded, "Events must be dropped when opt-in is false")
        assertEquals(0, manager.queuedCount)
    }

    @Test
    fun testTelemetryQueueDropsWhenCapacityExceeded() {
        val manager = TelemetryManager(initialOptIn = true)
        assertTrue(manager.isOptIn.value)

        for (i in 0 until TelemetryManager.MAX_QUEUE_CAPACITY) {
            val ok = manager.recordEvent("EVENT_$i", "4.3.0")
            assertTrue(ok)
        }

        assertEquals(TelemetryManager.MAX_QUEUE_CAPACITY, manager.queuedCount)

        // 51st event must be dropped
        val dropped = manager.recordEvent("EXCESS_EVENT", "4.3.0")
        assertFalse(dropped, "Must drop events beyond max capacity")
        assertEquals(TelemetryManager.MAX_QUEUE_CAPACITY, manager.queuedCount)
    }

    @Test
    fun testTelemetryBatchInterval() {
        var time = 1000000L
        val manager = TelemetryManager(initialOptIn = true, initialLastSendTime = time)
        manager.recordEvent("EVENT_1", "4.3.0")

        assertFalse(manager.shouldFlushBatch(time))

        time += 30000L // 30s: too soon
        assertFalse(manager.shouldFlushBatch(time))

        time += 35000L // 65s: ready to flush
        assertTrue(manager.shouldFlushBatch(time))

        val drained = manager.drainBatch(time)
        assertEquals(1, drained.size)
        assertEquals(0, manager.queuedCount)
    }
}
