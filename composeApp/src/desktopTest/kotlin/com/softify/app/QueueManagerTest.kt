package com.softify.app

import com.softify.app.playback.CachedStream
import com.softify.app.playback.QueueManager
import com.softify.app.playback.RepeatMode
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class QueueManagerTest {

    private fun createTrack(id: String, title: String): Track {
        return Track(
            id = id,
            sourceId = id,
            title = title,
            artist = "Artist $id",
            album = "Album $id",
            durationMs = 180_000u,
            coverUrl = "https://example.com/$id.jpg",
            matchConfidence = null,
            isLiked = false,
            isUnavailable = false
        )
    }

    @Test
    fun testQueueOrderingAndPlaybackAdvance() {
        val testDispatcher = StandardTestDispatcher()
        val testScope = TestScope(testDispatcher)
        val manager = QueueManager(scope = testScope)

        val track1 = createTrack("1", "Song 1")
        val track2 = createTrack("2", "Song 2")
        val track3 = createTrack("3", "Song 3")

        manager.setQueue(listOf(track1, track2, track3), startIndex = 0)
        var state = manager.queueState.value

        assertEquals(3, state.tracks.size)
        assertEquals(0, state.currentIndex)
        assertEquals("Song 1", state.currentTrack?.title)
        assertEquals("Song 2", state.nextTrack?.title)
        assertNull(state.previousTrack)

        // Advance to next
        val next = manager.skipNext()
        assertEquals("Song 2", next?.title)
        state = manager.queueState.value
        assertEquals(1, state.currentIndex)
        assertEquals("Song 1", state.previousTrack?.title)
        assertEquals("Song 3", state.nextTrack?.title)

        // Advance to 3rd
        val next2 = manager.skipNext()
        assertEquals("Song 3", next2?.title)
        state = manager.queueState.value
        assertEquals(2, state.currentIndex)
        assertNull(state.nextTrack)

        // End of queue in RepeatMode.OFF
        val end = manager.skipNext()
        assertNull(end)
        assertEquals(2, manager.queueState.value.currentIndex)
    }

    @Test
    fun testPlayNextVsAddToQueue() {
        val testDispatcher = StandardTestDispatcher()
        val testScope = TestScope(testDispatcher)
        val manager = QueueManager(scope = testScope)

        val t1 = createTrack("1", "Track 1")
        val t2 = createTrack("2", "Track 2")
        val t3 = createTrack("3", "Track 3")
        manager.setQueue(listOf(t1, t2, t3), startIndex = 0)

        // Play Next: should insert right after current index (0), becoming index 1
        val priorityTrack = createTrack("vip", "Priority Track")
        manager.playNext(priorityTrack)

        var state = manager.queueState.value
        assertEquals(4, state.tracks.size)
        assertEquals(0, state.currentIndex)
        assertEquals("Priority Track", state.tracks[1].title)
        assertEquals("Track 2", state.tracks[2].title)
        assertEquals("Priority Track", state.nextTrack?.title)

        // Add to Queue: should append to end (index 4)
        val bottomTrack = createTrack("bottom", "Bottom Track")
        manager.addToQueue(bottomTrack)

        state = manager.queueState.value
        assertEquals(5, state.tracks.size)
        assertEquals("Bottom Track", state.tracks[4].title)
    }

    @Test
    fun testRepeatModesOnTrackEnded() {
        val testDispatcher = StandardTestDispatcher()
        val testScope = TestScope(testDispatcher)
        val manager = QueueManager(scope = testScope)

        val t1 = createTrack("1", "Song A")
        val t2 = createTrack("2", "Song B")
        manager.setQueue(listOf(t1, t2), startIndex = 1) // At last track

        // Mode OFF: onTrackEnded returns null at end
        val endedOff = manager.onTrackEnded()
        assertNull(endedOff)

        // Mode ALL: onTrackEnded wraps around to first track
        manager.toggleRepeatMode() // OFF -> ALL
        assertEquals(RepeatMode.ALL, manager.queueState.value.repeatMode)

        val endedAll = manager.onTrackEnded()
        assertNotNull(endedAll)
        assertEquals("Song A", endedAll.title)
        assertEquals(0, manager.queueState.value.currentIndex)

        // Mode ONE: onTrackEnded replays the same track
        manager.toggleRepeatMode() // ALL -> ONE
        assertEquals(RepeatMode.ONE, manager.queueState.value.repeatMode)

        val endedOne = manager.onTrackEnded()
        assertNotNull(endedOne)
        assertEquals("Song A", endedOne.title)
        assertEquals(0, manager.queueState.value.currentIndex)
    }

    @Test
    fun testCachedStreamExpiration() {
        var currentTime = 1000000L
        val stream = StreamInfo(
            url = "https://cdn.example.com/audio.m4a",
            container = "m4a",
            bitrateKbps = 320u,
            codec = "aac",
            provider = "saavn",
            isRequestedQuality = true,
            headers = emptyList(),
            expiresAt = 1050u // expires at epoch 1050s = 1,050,000ms
        )

        val cached = CachedStream(stream, resolvedAtMs = currentTime)
        // At 1,000,000 ms, not expired (expires at 1,050,000 - 30,000 = 1,020,000 ms)
        assertFalse(cached.isExpired(1000000L))

        // At 1,025,000 ms, within 30s buffer, so considered expired
        assertTrue(cached.isExpired(1025000L))

        // At 1,060,000 ms, past expiration
        assertTrue(cached.isExpired(1060000L))
    }
}
