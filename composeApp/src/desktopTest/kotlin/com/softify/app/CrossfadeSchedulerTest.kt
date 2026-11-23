package com.softify.app

import com.softify.app.playback.CrossfadeCurve
import com.softify.app.playback.CrossfadePlayerActionHandler
import com.softify.app.playback.CrossfadeScheduler
import com.softify.app.playback.CrossfadeState
import com.softify.app.playback.TransitionType
import uniffi.softify_core.Track
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CrossfadeSchedulerTest {

    private fun createTrack(id: String, album: String? = null): Track {
        return Track(
            id = id,
            sourceId = id,
            title = "Track $id",
            artist = "Artist $id",
            album = album,
            durationMs = 180_000u,
            coverUrl = null,
            matchConfidence = null,
            isLiked = false,
            isUnavailable = false
        )
    }

    @Test
    fun testEqualPowerCurveSumIsOneAcrossAllSteps() {
        val testPoints = listOf(0.0f, 0.1f, 0.25f, 0.5f, 0.75f, 0.9f, 1.0f)
        for (alpha in testPoints) {
            val (outVol, inVol) = CrossfadeCurve.calculate(alpha)
            val powerSum = (outVol * outVol) + (inVol * inVol)
            assertTrue(
                abs(powerSum - 1.0f) < 0.0001f,
                "Power sum at alpha=$alpha must equal 1.0 (got $powerSum)"
            )
        }
    }

    @Test
    fun testDoNotCrossfadeConsecutiveAlbumTracks() {
        val scheduler = CrossfadeScheduler(
            crossfadeDurationMs = 5000L,
            skipAlbumConsecutive = true
        )

        val track1 = createTrack("1", album = "The Dark Side of the Moon")
        val track2 = createTrack("2", album = "The Dark Side of the Moon")
        val track3 = createTrack("3", album = "Wish You Were Here")

        // Consecutive tracks in the same album: should NOT crossfade
        assertFalse(scheduler.shouldCrossfade(track1, track2))

        // Tracks in different albums: SHOULD crossfade
        assertTrue(scheduler.shouldCrossfade(track2, track3))

        // If skipAlbumConsecutive is disabled: SHOULD crossfade
        scheduler.skipAlbumConsecutive = false
        assertTrue(scheduler.shouldCrossfade(track1, track2))
    }

    @Test
    fun testCrossfadeLifecycleWithMockTimeAndHandler() {
        var currentTimeMs = 10_000L
        val volumesRecorded = mutableListOf<Pair<Float, Float>>()
        var completedTrack: Track? = null

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {
                volumesRecorded.add(Pair(primaryVol, secondaryVol))
            }
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {}
            override fun onCrossfadeCompleted(newActiveTrack: Track) {
                completedTrack = newActiveTrack
            }
            override fun pauseBothPlayers() {}
            override fun resumeBothPlayers() {}
            override fun stopSecondaryPlayer() {}
        }

        val scheduler = CrossfadeScheduler(
            crossfadeDurationMs = 4000L,
            skipAlbumConsecutive = true,
            timeProvider = { currentTimeMs },
            actionHandler = handler
        )

        val track1 = createTrack("1", album = "Album A")
        val track2 = createTrack("2", album = "Album B")

        scheduler.startCrossfade(track1, track2)
        assertEquals(CrossfadeState.CROSSFADING, scheduler.state)
        assertEquals(TransitionType.CROSSFADE, scheduler.lastTransitionType)

        // Initial volumes: outVol = 1.0, inVol = 0.0
        val initial = volumesRecorded.last()
        assertEquals(1.0f, initial.first)
        assertEquals(0.0f, initial.second)

        // Advance 2000 ms (50% progress)
        currentTimeMs += 2000L
        val completedAtHalf = scheduler.step()
        assertFalse(completedAtHalf)
        assertEquals(0.5f, scheduler.crossfadeProgress)
        val mid = volumesRecorded.last()
        assertTrue(abs(mid.first - 0.7071f) < 0.01f) // cos(pi/4) = 1/sqrt(2)
        assertTrue(abs(mid.second - 0.7071f) < 0.01f) // sin(pi/4) = 1/sqrt(2)

        // Advance another 2000 ms (100% progress)
        currentTimeMs += 2000L
        val completed = scheduler.step()
        assertTrue(completed)
        assertEquals(CrossfadeState.IDLE, scheduler.state)
        assertEquals(1.0f, scheduler.crossfadeProgress)
        assertEquals("2", completedTrack?.id)
        val end = volumesRecorded.last()
        assertTrue(abs(end.first - 0.0f) < 0.001f)
        assertTrue(abs(end.second - 1.0f) < 0.001f)
    }

    @Test
    fun testMidFadePauseAndResume() {
        var currentTimeMs = 1000L
        var pausedCalled = false
        var resumedCalled = false

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {}
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {}
            override fun onCrossfadeCompleted(newActiveTrack: Track) {}
            override fun pauseBothPlayers() { pausedCalled = true }
            override fun resumeBothPlayers() { resumedCalled = true }
            override fun stopSecondaryPlayer() {}
        }

        val scheduler = CrossfadeScheduler(
            crossfadeDurationMs = 2000L,
            timeProvider = { currentTimeMs },
            actionHandler = handler
        )

        val track1 = createTrack("1")
        val track2 = createTrack("2")

        scheduler.startCrossfade(track1, track2)
        currentTimeMs += 1000L // 50%
        scheduler.step()
        assertEquals(0.5f, scheduler.crossfadeProgress)

        // User pauses
        scheduler.pause()
        assertEquals(CrossfadeState.PAUSED_MID_FADE, scheduler.state)
        assertTrue(pausedCalled)

        // 5 seconds pass while paused
        currentTimeMs += 5000L

        // User resumes
        scheduler.resume()
        assertEquals(CrossfadeState.CROSSFADING, scheduler.state)
        assertTrue(resumedCalled)

        // Advance 500 ms (should now be 75% progress, not finished!)
        currentTimeMs += 500L
        scheduler.step()
        assertEquals(0.75f, scheduler.crossfadeProgress)
    }

    @Test
    fun testManualSkipFadeThreeHundredMs() {
        var currentTimeMs = 1000L
        var skipCallbackInvoked = false

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {}
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {}
            override fun onCrossfadeCompleted(newActiveTrack: Track) {}
            override fun pauseBothPlayers() {}
            override fun resumeBothPlayers() {}
            override fun stopSecondaryPlayer() {}
        }

        val scheduler = CrossfadeScheduler(
            crossfadeDurationMs = 5000L,
            timeProvider = { currentTimeMs },
            actionHandler = handler
        )

        val track = createTrack("1")
        scheduler.startManualSkipFade(track) {
            skipCallbackInvoked = true
        }

        assertEquals(CrossfadeState.CROSSFADING, scheduler.state)
        assertEquals(TransitionType.MANUAL_SKIP_FADE, scheduler.lastTransitionType)

        currentTimeMs += 150L
        scheduler.step()
        assertEquals(0.5f, scheduler.crossfadeProgress)
        assertFalse(skipCallbackInvoked)

        currentTimeMs += 150L
        scheduler.step()
        assertEquals(1.0f, scheduler.crossfadeProgress)
        assertEquals(CrossfadeState.IDLE, scheduler.state)
        assertTrue(skipCallbackInvoked)
    }
}
