package com.softify.app

import com.softify.app.playback.CrossfadeCurve
import com.softify.app.playback.CrossfadePlayerActionHandler
import com.softify.app.playback.CrossfadeScheduler
import com.softify.app.playback.CrossfadeState
import com.softify.app.playback.TIME_UNSET
import com.softify.app.playback.TransitionType
import uniffi.softify_core.Track
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CrossfadeSchedulerTest {

    private fun createTrack(id: String, album: String? = null, durationMs: ULong = 180_000u): Track {
        return Track(
            id = id,
            sourceId = id,
            title = "Track $id",
            artist = "Artist $id",
            album = album,
            durationMs = durationMs,
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

        scheduler.onNextTrackPrebuffered(track1, track2)
        scheduler.onPlayerBReady()

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
    fun testPlayerBLateDelaysFadeUntilReady() {
        var currentTimeMs = 10_000L
        var secondaryStarted = false

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {}
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {
                secondaryStarted = true
            }
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

        val track1 = createTrack("1", album = "Album A", durationMs = 100_000u)
        val track2 = createTrack("2", album = "Album B", durationMs = 120_000u)

        scheduler.onNextTrackPrebuffered(track1, track2)
        // B is NOT ready yet
        assertFalse(scheduler.isPlayerBReady)

        // Position reaches crossfade threshold (remaining 4000ms <= 5000ms duration)
        scheduler.onPositionUpdate(currentPosMs = 96_000L, playerDurationMs = 100_000L, fallbackDurationMs = 100_000L)
        assertEquals(CrossfadeState.WAITING_FOR_PLAYER_B, scheduler.state)
        assertFalse(secondaryStarted)

        // Player B finishes buffering 1 second later
        currentTimeMs += 1000L
        scheduler.onPlayerBReady()

        // Fade should now immediately trigger!
        assertEquals(CrossfadeState.CROSSFADING, scheduler.state)
        assertTrue(secondaryStarted)
        assertEquals(TransitionType.CROSSFADE, scheduler.lastTransitionType)
    }

    @Test
    fun testPlayerBTimeoutFallsBackToGapless() {
        var currentTimeMs = 10_000L
        var fallbackToGaplessCalled = false

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {}
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {}
            override fun onCrossfadeCompleted(newActiveTrack: Track) {}
            override fun pauseBothPlayers() {}
            override fun resumeBothPlayers() {}
            override fun stopSecondaryPlayer() {}
            override fun fallbackToGapless(nextTrack: Track) {
                fallbackToGaplessCalled = true
            }
        }

        val scheduler = CrossfadeScheduler(
            crossfadeDurationMs = 4000L,
            timeProvider = { currentTimeMs },
            actionHandler = handler
        )

        val track1 = createTrack("1", album = "Album A", durationMs = 60_000u)
        val track2 = createTrack("2", album = "Album B", durationMs = 80_000u)

        scheduler.onNextTrackPrebuffered(track1, track2)
        // Reaches fade threshold -> enters WAITING_FOR_PLAYER_B
        scheduler.onPositionUpdate(currentPosMs = 57_000L, playerDurationMs = 60_000L, fallbackDurationMs = 60_000L)
        assertEquals(CrossfadeState.WAITING_FOR_PLAYER_B, scheduler.state)

        // Time advances to 100ms before track end, B still never became ready
        scheduler.onPositionUpdate(currentPosMs = 59_900L, playerDurationMs = 60_000L, fallbackDurationMs = 60_000L)

        // Must fallback to gapless rather than ending into dead silence
        assertTrue(fallbackToGaplessCalled)
        assertEquals(CrossfadeState.IDLE, scheduler.state)
        assertEquals(TransitionType.GAPLESS, scheduler.lastTransitionType)
    }

    @Test
    fun testUnknownDurationUsesFallbackMetadataDuration() {
        var currentTimeMs = 10_000L
        var fadeTriggered = false

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {}
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {
                fadeTriggered = true
            }
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

        val track1 = createTrack("1", album = "Album A", durationMs = 120_000u)
        val track2 = createTrack("2", album = "Album B", durationMs = 150_000u)

        scheduler.onNextTrackPrebuffered(track1, track2)
        scheduler.onPlayerBReady()

        // Pass TIME_UNSET as player duration, but valid metadata fallback duration 120_000L
        scheduler.onPositionUpdate(currentPosMs = 116_000L, playerDurationMs = TIME_UNSET, fallbackDurationMs = 120_000L)

        assertTrue(fadeTriggered)
        assertEquals(CrossfadeState.CROSSFADING, scheduler.state)
        assertTrue(scheduler.activeTrace?.isTimeUnset == true)
        assertEquals(120_000L, scheduler.activeTrace?.trackADurationMs)
    }

    @Test
    fun testSeekIntoFadeWindowTriggersCrossfadeIfReady() {
        var currentTimeMs = 10_000L
        var secondaryStarted = false

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {}
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {
                secondaryStarted = true
            }
            override fun onCrossfadeCompleted(newActiveTrack: Track) {}
            override fun pauseBothPlayers() {}
            override fun resumeBothPlayers() {}
            override fun stopSecondaryPlayer() {}
        }

        val scheduler = CrossfadeScheduler(
            crossfadeDurationMs = 6000L,
            timeProvider = { currentTimeMs },
            actionHandler = handler
        )

        val track1 = createTrack("1", album = "Album A", durationMs = 200_000u)
        val track2 = createTrack("2", album = "Album B", durationMs = 200_000u)

        scheduler.onNextTrackPrebuffered(track1, track2)
        scheduler.onPlayerBReady()

        // User jumps from 50s directly to 198s (2s left on a 6s fade window)
        scheduler.onPositionUpdate(currentPosMs = 198_000L, playerDurationMs = 200_000L, fallbackDurationMs = 200_000L)

        assertTrue(secondaryStarted)
        assertEquals(CrossfadeState.CROSSFADING, scheduler.state)
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

        val track1 = createTrack("1", album = "Album A")
        val track2 = createTrack("2", album = "Album B")

        scheduler.onNextTrackPrebuffered(track1, track2)
        scheduler.onPlayerBReady()
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

    @Test
    fun testQueueChangeCancelsArmedFade() {
        val scheduler = CrossfadeScheduler(crossfadeDurationMs = 5000L)
        val track1 = createTrack("1", album = "Album A")
        val track2 = createTrack("2", album = "Album B")

        scheduler.onNextTrackPrebuffered(track1, track2)
        assertEquals(CrossfadeState.PREBUFFERING, scheduler.state)

        scheduler.cancel("queue_modified")
        assertEquals(CrossfadeState.IDLE, scheduler.state)
        assertEquals(0f, scheduler.crossfadeProgress)
        assertEquals(1, scheduler.traces.size)
        assertEquals("queue_modified", scheduler.traces.last().notes)
    }

    @Test
    fun testRegressionZeroSilenceBetweenTrackAEndAndTrackBStart() {
        // Timeline simulator:
        // Track A duration = 100,000 ms. Crossfade = 4,000 ms.
        var timelineMs = 0L
        var trackAEndTimelineMs = -1L
        var trackBStartTimelineMs = -1L

        val handler = object : CrossfadePlayerActionHandler {
            override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {}
            override fun startSecondaryPlayback(track: Track, initialVolume: Float) {
                // Secondary player starts producing audio immediately
                trackBStartTimelineMs = timelineMs
            }
            override fun onCrossfadeCompleted(newActiveTrack: Track) {
                // Primary player ends on crossfade completion
                trackAEndTimelineMs = timelineMs
            }
            override fun pauseBothPlayers() {}
            override fun resumeBothPlayers() {}
            override fun stopSecondaryPlayer() {}
        }

        val scheduler = CrossfadeScheduler(
            crossfadeDurationMs = 4000L,
            timeProvider = { timelineMs },
            actionHandler = handler
        )

        val trackA = createTrack("A", album = "Album 1", durationMs = 100_000u)
        val trackB = createTrack("B", album = "Album 2", durationMs = 100_000u)

        scheduler.onNextTrackPrebuffered(trackA, trackB)
        scheduler.onPlayerBReady()

        // Advance to crossfade boundary (96,000 ms)
        timelineMs = 96_000L
        scheduler.onPositionUpdate(currentPosMs = 96_000L, playerDurationMs = 100_000L, fallbackDurationMs = 100_000L)

        // Crossfade triggered at 96,000 ms
        assertEquals(96_000L, trackBStartTimelineMs, "Track B must start rendering at crossfade start")

        // Advance crossfade steps
        val stepMs = 50L
        while (timelineMs < 100_000L) {
            timelineMs += stepMs
            scheduler.step()
        }

        assertEquals(100_000L, trackAEndTimelineMs, "Track A must end at crossfade completion")

        // Verify acoustic silence between A and B
        // Silence occurs if trackBStartTimelineMs > trackAEndTimelineMs
        val silenceGapMs = (trackBStartTimelineMs - trackAEndTimelineMs).coerceAtLeast(0L)
        val overlapMs = trackAEndTimelineMs - trackBStartTimelineMs

        assertEquals(0L, silenceGapMs, "Silence between Track A end and Track B start must be exactly 0 ms")
        assertEquals(4000L, overlapMs, "Track A and Track B must overlap for the entire 4000 ms crossfade window")
    }
}
