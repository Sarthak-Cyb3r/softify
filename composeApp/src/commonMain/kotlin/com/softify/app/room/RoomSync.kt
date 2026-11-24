package com.softify.app.room

import kotlin.math.abs

enum class RoomStatus {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    UNAVAILABLE
}

enum class DriftAction {
    NONE,
    SMOOTH_SEEK,
    HARD_SEEK
}

data class RoomState(
    val code: String,
    val hostId: String,
    val isHost: Boolean,
    val participants: List<String> = emptyList(),
    val currentTrackId: String? = null,
    val hostPositionMs: Long = 0L,
    val isPlaying: Boolean = false,
    val status: RoomStatus = RoomStatus.DISCONNECTED
)

/**
 * Handles Listen-Together room drift correction and participant limits.
 */
object RoomSync {
    const val MAX_PARTICIPANTS = 6
    const val SMOOTH_SEEK_DRIFT_THRESHOLD_MS = 500L
    const val HARD_SEEK_DRIFT_THRESHOLD_MS = 2000L

    fun calculateDriftCorrection(clientPositionMs: Long, hostPositionMs: Long): DriftAction {
        val drift = abs(clientPositionMs - hostPositionMs)
        return when {
            drift <= SMOOTH_SEEK_DRIFT_THRESHOLD_MS -> DriftAction.NONE
            drift <= HARD_SEEK_DRIFT_THRESHOLD_MS -> DriftAction.SMOOTH_SEEK
            else -> DriftAction.HARD_SEEK
        }
    }

    fun canJoinRoom(currentParticipantCount: Int): Boolean {
        return currentParticipantCount < MAX_PARTICIPANTS
    }
}
