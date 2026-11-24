package com.softify.app

import com.softify.app.room.DriftAction
import com.softify.app.room.RoomSync
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RoomSyncTest {

    @Test
    fun testDriftCorrectionThresholds() {
        val hostPosition = 50000L

        // Under 500ms drift -> No action
        assertEquals(DriftAction.NONE, RoomSync.calculateDriftCorrection(50300L, hostPosition))
        assertEquals(DriftAction.NONE, RoomSync.calculateDriftCorrection(49700L, hostPosition))

        // 501ms to 2000ms drift -> Smooth seek
        assertEquals(DriftAction.SMOOTH_SEEK, RoomSync.calculateDriftCorrection(50800L, hostPosition))
        assertEquals(DriftAction.SMOOTH_SEEK, RoomSync.calculateDriftCorrection(48500L, hostPosition))

        // Over 2000ms drift -> Hard seek
        assertEquals(DriftAction.HARD_SEEK, RoomSync.calculateDriftCorrection(53000L, hostPosition))
        assertEquals(DriftAction.HARD_SEEK, RoomSync.calculateDriftCorrection(45000L, hostPosition))
    }

    @Test
    fun testMaxParticipantsGating() {
        assertTrue(RoomSync.canJoinRoom(currentParticipantCount = 0))
        assertTrue(RoomSync.canJoinRoom(currentParticipantCount = 5))
        assertFalse(RoomSync.canJoinRoom(currentParticipantCount = 6), "Must reject 7th participant")
        assertFalse(RoomSync.canJoinRoom(currentParticipantCount = 10))
    }
}
