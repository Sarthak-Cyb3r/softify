package com.softify.app.playback

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Equal-power audio crossfade curves.
 * Guarantees that (outVolume^2 + inVolume^2) == 1.0 at every point along the transition,
 * completely eliminating the center volume dip of linear crossfades.
 */
object CrossfadeCurve {
    /**
     * Compute equal-power fade out volume multiplier for progress alpha in [0.0, 1.0].
     * cos(alpha * PI / 2)
     */
    fun fadeOut(alpha: Float): Float {
        val clamped = alpha.coerceIn(0f, 1f)
        return cos(clamped * (PI.toFloat() / 2f))
    }

    /**
     * Compute equal-power fade in volume multiplier for progress alpha in [0.0, 1.0].
     * sin(alpha * PI / 2)
     */
    fun fadeIn(alpha: Float): Float {
        val clamped = alpha.coerceIn(0f, 1f)
        return sin(clamped * (PI.toFloat() / 2f))
    }

    /**
     * Calculate both fade out and fade in volumes simultaneously.
     * Returns Pair(outVolume, inVolume).
     */
    fun calculate(alpha: Float): Pair<Float, Float> {
        val clamped = alpha.coerceIn(0f, 1f)
        val angle = clamped * (PI.toFloat() / 2f)
        return Pair(cos(angle), sin(angle))
    }
}
