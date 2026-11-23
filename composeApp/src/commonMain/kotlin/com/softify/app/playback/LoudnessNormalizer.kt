package com.softify.app.playback

import kotlin.math.log10
import kotlin.math.min
import kotlin.math.pow
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track

enum class LoudnessSource {
    REPLAYGAIN,
    YOUTUBE,
    NONE
}

data class LoudnessResult(
    val source: LoudnessSource,
    val detectedLoudnessDb: Float?,
    val peak: Float?,
    val targetLufs: Float,
    val calculatedGainDb: Float,
    val appliedGainDb: Float,
    val volumeMultiplier: Float,
    val boostDb: Float
)

object LoudnessNormalizer {
    const val DEFAULT_TARGET_LUFS = -14.0f
    const val MIN_TARGET_LUFS = -23.0f
    const val MAX_TARGET_LUFS = -9.0f
    const val MAX_BOOST_DB = 6.0f
    const val YOUTUBE_REFERENCE_LUFS = -14.0f
    const val REPLAYGAIN_REFERENCE_LUFS = -18.0f

    private val gainRegex = Regex(""""loudnessDb"\s*:\s*([+-]?[0-9]*\.?[0-9]+)""")
    private val peakRegex = Regex(""""peak"\s*:\s*([+-]?[0-9]*\.?[0-9]+)""")

    fun parseReplayGainJson(jsonStr: String?): Pair<Float?, Float?> {
        if (jsonStr.isNullOrBlank()) return Pair(null, null)
        val gain = gainRegex.find(jsonStr)?.groupValues?.get(1)?.toFloatOrNull()
        val peak = peakRegex.find(jsonStr)?.groupValues?.get(1)?.toFloatOrNull()
        val cleanGain = if (gain != null && !gain.isNaN() && !gain.isInfinite()) gain else null
        val cleanPeak = if (peak != null && !peak.isNaN() && !peak.isInfinite() && peak > 0f) peak else null
        return Pair(cleanGain, cleanPeak)
    }

    /**
     * Compute loudness normalization result according to M4b specifications.
     *
     * @param track The track being played
     * @param streamInfo The resolved stream info (may contain YouTube headers)
     * @param rawLocalSetting Optional JSON string from SQLite settings for local tracks ("loudness_<trackId>")
     * @param targetLufs User target loudness level (-23.0f to -9.0f, default -14.0f)
     * @param allowBoost Whether to allow positive gain boost (capped at +6 dB and limited by peak headroom)
     */
    fun calculateGain(
        track: Track?,
        streamInfo: StreamInfo?,
        rawLocalSetting: String? = null,
        targetLufs: Float = DEFAULT_TARGET_LUFS,
        allowBoost: Boolean = false
    ): LoudnessResult {
        val clampedTarget = targetLufs.coerceIn(MIN_TARGET_LUFS, MAX_TARGET_LUFS)

        // 1. Priority: Local ReplayGain tags in SQLite settings
        val (rgGain, rgPeak) = parseReplayGainJson(rawLocalSetting)
        if (rgGain != null) {
            // ReplayGain baseline is -18 LUFS.
            // Delta dB = trackGainDb + (targetLufs - (-18))
            val calculatedGain = rgGain + (clampedTarget - REPLAYGAIN_REFERENCE_LUFS)
            val appliedGain = computeAppliedGain(calculatedGain, rgPeak, allowBoost)
            val multiplier = 10.0.pow((appliedGain / 20.0).toDouble()).toFloat()
            val boostDb = if (appliedGain > 0f) appliedGain else 0f

            return LoudnessResult(
                source = LoudnessSource.REPLAYGAIN,
                detectedLoudnessDb = rgGain,
                peak = rgPeak,
                targetLufs = clampedTarget,
                calculatedGainDb = calculatedGain,
                appliedGainDb = appliedGain,
                volumeMultiplier = multiplier,
                boostDb = boostDb
            )
        }

        // 2. Priority: YouTube player response headers (X-Loudness-Db)
        if (streamInfo != null) {
            val headerLoudness = streamInfo.headers.firstOrNull {
                it.name.equals("X-Loudness-Db", ignoreCase = true)
            }?.value?.toFloatOrNull()

            if (headerLoudness != null && !headerLoudness.isNaN() && !headerLoudness.isInfinite()) {
                // YouTube baseline reference is -14 LUFS.
                // headerLoudness is positive if louder than -14 LUFS, negative if quieter.
                // Delta dB = (targetLufs + 14.0f) - headerLoudness
                val calculatedGain = (clampedTarget - YOUTUBE_REFERENCE_LUFS) - headerLoudness
                val appliedGain = computeAppliedGain(calculatedGain, peak = null, allowBoost = allowBoost)
                val multiplier = 10.0.pow((appliedGain / 20.0).toDouble()).toFloat()
                val boostDb = if (appliedGain > 0f) appliedGain else 0f

                return LoudnessResult(
                    source = LoudnessSource.YOUTUBE,
                    detectedLoudnessDb = headerLoudness,
                    peak = null,
                    targetLufs = clampedTarget,
                    calculatedGainDb = calculatedGain,
                    appliedGainDb = appliedGain,
                    volumeMultiplier = multiplier,
                    boostDb = boostDb
                )
            }
        }

        // 3. Fallback: Saavn or unknown streams have no loudness info; gain = 0 dB, multiplier = 1.0f
        return LoudnessResult(
            source = LoudnessSource.NONE,
            detectedLoudnessDb = null,
            peak = null,
            targetLufs = clampedTarget,
            calculatedGainDb = 0f,
            appliedGainDb = 0f,
            volumeMultiplier = 1.0f,
            boostDb = 0f
        )
    }

    private fun computeAppliedGain(
        calculatedGainDb: Float,
        peak: Float?,
        allowBoost: Boolean
    ): Float {
        if (!allowBoost) {
            // Attenuate-only by default (gain <= 0 dB)
            return min(0f, calculatedGainDb)
        }

        if (calculatedGainDb <= 0f) {
            return calculatedGainDb
        }

        var maxHeadroomDb = MAX_BOOST_DB
        if (peak != null && peak > 0f) {
            // Headroom in dB = -20 * log10(peak)
            val headroom = (-20.0 * log10(peak.toDouble())).toFloat()
            maxHeadroomDb = if (headroom in 0f..MAX_BOOST_DB) {
                headroom
            } else if (headroom < 0f) {
                0f
            } else {
                MAX_BOOST_DB
            }
        }

        return min(calculatedGainDb, maxHeadroomDb)
    }
}
