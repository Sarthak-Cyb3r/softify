package com.softify.app

import com.softify.app.sync.*
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SyncConflictTest {

    @Test
    fun testTwoDevicesOfflineEditsConvergeToSameStateRegardlessOfSyncOrder() {
        // Device A and Device B start at baseline physical time
        var timeA = 1700000000000L
        var timeB = 1700000000000L

        val clockA = HlcClock(nodeId = "devA", physicalClock = { timeA })
        val clockB = HlcClock(nodeId = "devB", physicalClock = { timeB })

        // Device A edits playlist at t = 1000ms
        timeA += 1000L
        val changeA = SyncChange(
            entityType = SyncEntityType.PLAYLIST,
            entityId = "pl_favorites",
            hlc = clockA.now(),
            isDeleted = false,
            payload = "{\"name\":\"Chill Hits\"}"
        )

        // Device B edits the SAME playlist later at t = 2000ms
        timeB += 2000L
        val changeB = SyncChange(
            entityType = SyncEntityType.PLAYLIST,
            entityId = "pl_favorites",
            hlc = clockB.now(),
            isDeleted = false,
            payload = "{\"name\":\"Ultra Chill Hits\"}"
        )

        // Order 1: Server processes A then B
        val resolved1 = LwwResolver.resolve(changeA, changeB)
        assertEquals(changeB, resolved1, "Change B has higher HLC and must win")

        // Order 2: Server processes B then A
        val resolved2 = LwwResolver.resolve(changeB, changeA)
        assertEquals(changeB, resolved2, "Change B must win regardless of processing order")
    }

    @Test
    fun testTombstoneWinsOverEarlierModification() {
        var time = 1700000000000L
        val clock = HlcClock(nodeId = "dev1", physicalClock = { time })

        val updateChange = SyncChange(
            entityType = SyncEntityType.FAVORITE,
            entityId = "track_123",
            hlc = clock.now(),
            isDeleted = false,
            payload = "track_123"
        )

        time += 500L
        val deleteChange = SyncChange(
            entityType = SyncEntityType.FAVORITE,
            entityId = "track_123",
            hlc = clock.now(),
            isDeleted = true, // Tombstone
            payload = ""
        )

        val winningChange = LwwResolver.resolve(updateChange, deleteChange)
        assertTrue(winningChange.isDeleted, "Deletion tombstone with higher HLC must win")
    }
}
