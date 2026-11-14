package com.softify.app

import com.softify.app.playback.PlaybackRetryManager
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class PlaybackRetryTest {

    @Test
    fun testNormalRetryBackoffAndExhaustion() = runTest {
        val executedRetries = mutableListOf<Pair<Long, Int>>()
        val logs = mutableListOf<String>()
        var exhaustedTrack: String? = null

        val manager = PlaybackRetryManager(
            scope = this,
            maxRetries = 2,
            onLog = { logs.add(it) },
            onExhausted = { trackId, _ -> exhaustedTrack = trackId },
            executeRetry = { sessionId, attempt ->
                executedRetries.add(sessionId to attempt)
            }
        )

        val session = manager.startNewSession("track-1")
        assertEquals(1L, session)
        assertEquals(0, manager.retryCount)

        // Attempt 1: backoff is 500ms
        val retried1 = manager.handlePlayerError(session, "track-1", "ERROR_CODE_IO_BAD_HTTP_STATUS 403")
        assertTrue(retried1)
        assertEquals(1, manager.retryCount)
        assertTrue(manager.isRetryPending())
        assertTrue(logs.any { it.contains("retry 1/2 for 'track-1'") })

        // Before 500ms: not executed yet
        advanceTimeBy(400)
        runCurrent()
        assertEquals(0, executedRetries.size)

        // At 500ms: executes attempt 1
        advanceTimeBy(100)
        runCurrent()
        assertEquals(1, executedRetries.size)
        assertEquals(1L to 1, executedRetries[0])

        // Attempt 2: backoff is 1000ms (attempt 2 * 500)
        val retried2 = manager.handlePlayerError(session, "track-1", "Timeout")
        assertTrue(retried2)
        assertEquals(2, manager.retryCount)
        advanceTimeBy(1000)
        runCurrent()
        assertEquals(2, executedRetries.size)
        assertEquals(1L to 2, executedRetries[1])

        // Attempt 3: max retries reached, should be rejected
        val retried3 = manager.handlePlayerError(session, "track-1", "Unrecoverable")
        assertFalse(retried3)
        assertEquals(2, manager.retryCount)
        assertEquals("track-1", exhaustedTrack)
        assertTrue(logs.any { it.contains("All 2 retries exhausted for 'track-1'") })
    }

    @Test
    fun testStaleRetryCancelledOnTrackChange() = runTest {
        val executedRetries = mutableListOf<Pair<Long, Int>>()
        val logs = mutableListOf<String>()

        val manager = PlaybackRetryManager(
            scope = this,
            maxRetries = 2,
            onLog = { logs.add(it) },
            executeRetry = { sessionId, attempt ->
                executedRetries.add(sessionId to attempt)
            }
        )

        val session1 = manager.startNewSession("track-A")
        assertEquals(1L, session1)

        // Error on track A schedules retry in 500ms
        manager.handlePlayerError(session1, "track-A", "HTTP 403")
        assertTrue(manager.isRetryPending())

        // User selects track B after 200ms
        advanceTimeBy(200)
        runCurrent()
        val session2 = manager.startNewSession("track-B")
        assertEquals(2L, session2)
        assertFalse(manager.isRetryPending())

        // Advance well past the 500ms mark of track A's scheduled retry
        advanceTimeBy(1000)
        runCurrent()

        // Track A retry must NEVER have executed
        assertEquals(0, executedRetries.size)
        assertTrue(logs.any { it.contains("Pending retry cancelled") || it.contains("New session started") })
    }

    @Test
    fun testStaleRetryCancelledOnUserPauseOrStop() = runTest {
        val executedRetries = mutableListOf<Pair<Long, Int>>()
        val logs = mutableListOf<String>()

        val manager = PlaybackRetryManager(
            scope = this,
            maxRetries = 2,
            onLog = { logs.add(it) },
            executeRetry = { sessionId, attempt ->
                executedRetries.add(sessionId to attempt)
            }
        )

        val session1 = manager.startNewSession("track-A")

        // Error on track A schedules retry in 500ms
        manager.handlePlayerError(session1, "track-A", "HTTP 403")
        assertTrue(manager.isRetryPending())

        // User pauses playback at 250ms
        advanceTimeBy(250)
        runCurrent()
        manager.onUserPauseOrStop()
        assertFalse(manager.isRetryPending())

        // Advance well past the retry delay
        advanceTimeBy(1000)
        runCurrent()

        // Track A retry must NOT execute
        assertEquals(0, executedRetries.size)
        assertTrue(logs.any { it.contains("User paused or stopped playback") })
    }
}
