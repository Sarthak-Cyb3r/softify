package com.softify.app

import com.softify.app.playback.LoudnessNormalizer
import com.softify.app.playback.LoudnessSource
import uniffi.softify_core.HeaderPair
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LoudnessNormalizerTest {

    private fun createDummyTrack(id: String = "test_track"): Track {
        return Track(
            id = id,
            sourceId = id,
            title = "Test Title",
            artist = "Test Artist",
            album = "Test Album",
            durationMs = 200_000u,
            coverUrl = null,
            matchConfidence = null,
            isLiked = false,
            isUnavailable = false
        )
    }

    private fun createStreamInfo(headers: List<HeaderPair> = emptyList(), provider: String = "saavn"): StreamInfo {
        return StreamInfo(
            url = "https://example.com/audio.m4a",
            container = "m4a",
            bitrateKbps = 320u,
            codec = "aac",
            provider = provider,
            isRequestedQuality = true,
            headers = headers,
            expiresAt = null
        )
    }

    @Test
    fun testSaavnStreamHasNoLoudnessChange() {
        val track = createDummyTrack()
        val stream = createStreamInfo(provider = "saavn")
        val result = LoudnessNormalizer.calculateGain(track, stream, rawLocalSetting = null)

        assertEquals(LoudnessSource.NONE, result.source)
        assertNull(result.detectedLoudnessDb)
        assertNull(result.peak)
        assertEquals(0f, result.calculatedGainDb)
        assertEquals(0f, result.appliedGainDb)
        assertEquals(1.0f, result.volumeMultiplier)
        assertEquals(0f, result.boostDb)
    }

    @Test
    fun testYouTubeLoudnessAttenuationDefault() {
        // Track is 4.5 dB louder than YouTube reference (-14 LUFS)
        val track = createDummyTrack()
        val headers = listOf(HeaderPair("X-Loudness-Db", "4.50"))
        val stream = createStreamInfo(headers = headers, provider = "youtube")

        val result = LoudnessNormalizer.calculateGain(
            track = track,
            streamInfo = stream,
            targetLufs = -14.0f,
            allowBoost = false
        )

        assertEquals(LoudnessSource.YOUTUBE, result.source)
        assertEquals(4.5f, result.detectedLoudnessDb)
        // Calculated gain = -4.5 dB
        assertEquals(-4.5f, result.calculatedGainDb)
        assertEquals(-4.5f, result.appliedGainDb)
        assertTrue(result.volumeMultiplier < 1.0f)
        assertTrue(abs(result.volumeMultiplier - 0.5956f) < 0.001f)
        assertEquals(0f, result.boostDb)
    }

    @Test
    fun testYouTubeLoudnessQuietTrackAttenuateOnlyByDefault() {
        // Track is 3.0 dB quieter than YouTube reference (-14 LUFS)
        val track = createDummyTrack()
        val headers = listOf(HeaderPair("X-Loudness-Db", "-3.00"))
        val stream = createStreamInfo(headers = headers, provider = "youtube")

        val result = LoudnessNormalizer.calculateGain(
            track = track,
            streamInfo = stream,
            targetLufs = -14.0f,
            allowBoost = false
        )

        assertEquals(LoudnessSource.YOUTUBE, result.source)
        assertEquals(-3.0f, result.detectedLoudnessDb)
        // Calculated gain = +3.0 dB, but allowBoost=false so applied gain is clamped to 0.0 dB
        assertEquals(3.0f, result.calculatedGainDb)
        assertEquals(0.0f, result.appliedGainDb)
        assertEquals(1.0f, result.volumeMultiplier)
        assertEquals(0f, result.boostDb)
    }

    @Test
    fun testYouTubeLoudnessAllowBoostCappedAtSixDb() {
        // Track is very quiet: 8.0 dB quieter than reference
        val track = createDummyTrack()
        val headers = listOf(HeaderPair("X-Loudness-Db", "-8.00"))
        val stream = createStreamInfo(headers = headers, provider = "youtube")

        val result = LoudnessNormalizer.calculateGain(
            track = track,
            streamInfo = stream,
            targetLufs = -14.0f,
            allowBoost = true
        )

        assertEquals(LoudnessSource.YOUTUBE, result.source)
        assertEquals(8.0f, result.calculatedGainDb)
        // Capped at +6.0 dB
        assertEquals(6.0f, result.appliedGainDb)
        assertEquals(6.0f, result.boostDb)
        assertTrue(result.volumeMultiplier > 1.0f)
    }

    @Test
    fun testReplayGainLocalTrackPriorityAndHeadroomLimiting() {
        val track = createDummyTrack()
        // Peak is 0.89125 (~ -1.0 dBFS), so headroom is ~ 1.0 dB
        val rawJson = """{"loudnessDb": 4.0, "peak": 0.89125, "source": "REPLAYGAIN"}"""

        // Also pass YouTube headers to ensure ReplayGain takes priority
        val headers = listOf(HeaderPair("X-Loudness-Db", "-2.00"))
        val stream = createStreamInfo(headers = headers)

        val result = LoudnessNormalizer.calculateGain(
            track = track,
            streamInfo = stream,
            rawLocalSetting = rawJson,
            targetLufs = -14.0f, // target is -14, ReplayGain ref is -18, delta = +4
            allowBoost = true
        )

        assertEquals(LoudnessSource.REPLAYGAIN, result.source)
        assertEquals(4.0f, result.detectedLoudnessDb)
        // Calculated gain = 4.0 + (-14 - (-18)) = +8.0 dB
        assertEquals(8.0f, result.calculatedGainDb)
        // Peak = 0.89125 -> Headroom is approx 1.0 dB, so applied gain is capped at ~1.0 dB instead of +6 dB
        assertTrue(result.appliedGainDb in 0.99f..1.01f)
    }

    @Test
    fun testReplayGainClippingPeakPreventsBoost() {
        val track = createDummyTrack()
        // Peak is 1.1 (already clipping)
        val rawJson = """{"loudnessDb": -2.0, "peak": 1.1, "source": "REPLAYGAIN"}"""

        val result = LoudnessNormalizer.calculateGain(
            track = track,
            streamInfo = null,
            rawLocalSetting = rawJson,
            targetLufs = -14.0f,
            allowBoost = true
        )

        assertEquals(LoudnessSource.REPLAYGAIN, result.source)
        // Calculated gain = -2.0 + 4.0 = +2.0 dB
        assertEquals(2.0f, result.calculatedGainDb)
        // Peak > 1.0 -> maxHeadroomDb is 0.0 dB
        assertEquals(0.0f, result.appliedGainDb)
        assertEquals(1.0f, result.volumeMultiplier)
    }

    @Test
    fun testTargetLufsConfigurableRangeAndClamping() {
        val track = createDummyTrack()
        val headers = listOf(HeaderPair("X-Loudness-Db", "0.00"))
        val stream = createStreamInfo(headers = headers)

        // Target -23 LUFS (EBU R128 standard)
        val ebuResult = LoudnessNormalizer.calculateGain(track, stream, targetLufs = -23.0f)
        assertEquals(-23.0f, ebuResult.targetLufs)
        // Calculated gain = (-23 - (-14)) - 0 = -9.0 dB
        assertEquals(-9.0f, ebuResult.calculatedGainDb)
        assertEquals(-9.0f, ebuResult.appliedGainDb)

        // Target clamped from -30 to -23
        val clampedLow = LoudnessNormalizer.calculateGain(track, stream, targetLufs = -30.0f)
        assertEquals(-23.0f, clampedLow.targetLufs)

        // Target clamped from 0 to -9
        val clampedHigh = LoudnessNormalizer.calculateGain(track, stream, targetLufs = 0.0f)
        assertEquals(-9.0f, clampedHigh.targetLufs)
    }

    @Test
    fun testMalformedReplayGainJsonGracefulFallback() {
        val track = createDummyTrack()
        val stream = createStreamInfo(headers = emptyList())

        val result1 = LoudnessNormalizer.calculateGain(track, stream, rawLocalSetting = "not json")
        assertEquals(LoudnessSource.NONE, result1.source)

        val result2 = LoudnessNormalizer.calculateGain(track, stream, rawLocalSetting = """{"loudnessDb": "invalid"}""")
        assertEquals(LoudnessSource.NONE, result2.source)

        val result3 = LoudnessNormalizer.calculateGain(track, stream, rawLocalSetting = "")
        assertEquals(LoudnessSource.NONE, result3.source)
    }
}
