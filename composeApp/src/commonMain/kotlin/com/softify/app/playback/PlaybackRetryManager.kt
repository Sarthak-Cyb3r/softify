package com.softify.app.playback

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class PlaybackRetryManager(
    private val scope: CoroutineScope,
    private val maxRetries: Int = 2,
    private val onLog: (String) -> Unit = {},
    private val onExhausted: (trackId: String, reason: String) -> Unit = { _, _ -> },
    private val executeRetry: suspend (sessionId: Long, attempt: Int) -> Unit
) {
    var currentSessionId: Long = 0L
        private set
    var currentTrackId: String? = null
        private set
    var retryCount: Int = 0
        private set

    private var retryJob: Job? = null

    /**
     * Starts a new session when user plays a track.
     * Cancels any pending retry and increments session generation.
     */
    fun startNewSession(trackId: String): Long {
        cancelPendingRetry("New session started for track '$trackId'")
        currentSessionId++
        currentTrackId = trackId
        retryCount = 0
        return currentSessionId
    }

    /**
     * Cancels pending retries when user pauses or stops playback.
     */
    fun onUserPauseOrStop() {
        cancelPendingRetry("User paused or stopped playback")
        currentSessionId++
    }

    /**
     * Handles playback error.
     * Returns true if a retry was scheduled, false if exhausted or ignored.
     */
    fun handlePlayerError(
        sessionId: Long,
        trackId: String,
        reason: String
    ): Boolean {
        if (sessionId != currentSessionId || trackId != currentTrackId) {
            onLog("Ignored error for stale session $sessionId (current: $currentSessionId)")
            return false
        }

        if (retryCount >= maxRetries) {
            onLog("All $maxRetries retries exhausted for '$trackId' - error: $reason")
            onExhausted(trackId, reason)
            return false
        }

        retryCount++
        val attempt = retryCount
        val backoffMs = attempt * 500L
        onLog("retry $attempt/$maxRetries for '$trackId': $reason")

        retryJob?.cancel()
        retryJob = scope.launch {
            delay(backoffMs)
            if (sessionId != currentSessionId) {
                onLog("Retry $attempt/$maxRetries cancelled: session $sessionId is stale (current: $currentSessionId)")
                return@launch
            }
            try {
                executeRetry(sessionId, attempt)
            } catch (e: Exception) {
                onLog("Retry $attempt/$maxRetries execution failed: ${e.message}")
                if (retryCount >= maxRetries) {
                    onExhausted(trackId, e.message ?: reason)
                }
            }
        }
        return true
    }

    fun cancelPendingRetry(reason: String) {
        if (retryJob?.isActive == true) {
            retryJob?.cancel()
            onLog("Pending retry cancelled: $reason")
        }
        retryJob = null
    }

    fun isRetryPending(): Boolean = retryJob?.isActive == true
}
