package com.softify.app.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.softify.app.util.PlaybackLogger
import kotlin.math.*

/**
 * Pure Kotlin Multiplatform HCT (Hue, Chroma, Tone) and CAM16/Lab color space generator.
 * Implements Material Design 3 dynamic color derivation identically on Android and Desktop JVM.
 */
data class Hct(val hue: Float, val chroma: Float, val tone: Float) {
    companion object {
        fun fromColor(color: Color): Hct {
            val argb = color.toArgb()
            val r = ((argb shr 16) and 0xFF) / 255f
            val g = ((argb shr 8) and 0xFF) / 255f
            val b = (argb and 0xFF) / 255f

            // Linearize sRGB
            val rL = if (r <= 0.04045f) r / 12.92f else ((r + 0.055f) / 1.055f).pow(2.4f)
            val gL = if (g <= 0.04045f) g / 12.92f else ((g + 0.055f) / 1.055f).pow(2.4f)
            val bL = if (b <= 0.04045f) b / 12.92f else ((b + 0.055f) / 1.055f).pow(2.4f)

            // sRGB to XYZ (D65 illuminant)
            val x = (0.41233895f * rL + 0.35762064f * gL + 0.18051042f * bL) * 100f
            val y = (0.21260000f * rL + 0.71520000f * gL + 0.07220000f * bL) * 100f
            val z = (0.01932141f * rL + 0.11916382f * gL + 0.95034478f * bL) * 100f

            // XYZ to Lab
            fun f(t: Float): Float = if (t > 0.008856f) t.pow(1f / 3f) else 7.787f * t + 16f / 116f

            val fx = f(x / 95.047f)
            val fy = f(y / 100.0f)
            val fz = f(z / 108.883f)

            val lStar = max(0f, 116f * fy - 16f)
            val aStar = 500f * (fx - fy)
            val bStar = 200f * (fy - fz)

            val chroma = sqrt(aStar * aStar + bStar * bStar)
            var hue = (atan2(bStar, aStar) * 180f / PI.toFloat())
            if (hue < 0f) hue += 360f

            return Hct(hue, chroma, lStar)
        }

        fun toColor(hue: Float, chroma: Float, tone: Float): Color {
            val clampedTone = tone.coerceIn(0f, 100f)
            val hRad = hue * PI.toFloat() / 180f
            val aStar = chroma * cos(hRad)
            val bStar = chroma * sin(hRad)

            val fy = (clampedTone + 16f) / 116f
            val fx = fy + aStar / 500f
            val fz = fy - bStar / 200f

            fun invF(t: Float): Float {
                val t3 = t * t * t
                return if (t3 > 0.008856f) t3 else (t - 16f / 116f) / 7.787f
            }

            val x = invF(fx) * 95.047f / 100f
            val y = invF(fy) * 100.0f / 100f
            val z = invF(fz) * 108.883f / 100f

            // XYZ to linear sRGB
            var rL = 3.2406f * x - 1.5372f * y - 0.4986f * z
            var gL = -0.9689f * x + 1.8758f * y + 0.0415f * z
            var bL = 0.0557f * x - 0.2040f * y + 1.0570f * z

            fun delinearize(c: Float): Float {
                val clamped = c.coerceIn(0f, 1f)
                return if (clamped <= 0.0031308f) 12.92f * clamped else 1.055f * clamped.pow(1f / 2.4f) - 0.055f
            }

            val r = (delinearize(rL) * 255f).roundToInt().coerceIn(0, 255)
            val g = (delinearize(gL) * 255f).roundToInt().coerceIn(0, 255)
            val b = (delinearize(bL) * 255f).roundToInt().coerceIn(0, 255)

            return Color(r, g, b)
        }
    }
}

class TonalPalette(val hue: Float, val chroma: Float) {
    fun tone(tone: Float): Color = Hct.toColor(hue, chroma, tone)
}

object MaterialHctGenerator {
    val DEFAULT_SEED = Color(0xFF6750A4)

    fun extractSeedFromCover(coverBytes: ByteArray?): Color {
        if (coverBytes == null || coverBytes.isEmpty()) {
            PlaybackLogger.log("SoftifyPlayback", "HCT: Seed extraction fallback to default (#6750A4)")
            return DEFAULT_SEED
        }

        return try {
            // Sample bytes across the buffer to estimate a dominant/vibrant seed
            var sumR = 0L
            var sumG = 0L
            var sumB = 0L
            var count = 0
            val step = max(1, coverBytes.size / 100)
            var i = 0
            while (i < coverBytes.size - 3) {
                val b1 = coverBytes[i].toInt() and 0xFF
                val b2 = coverBytes[i + 1].toInt() and 0xFF
                val b3 = coverBytes[i + 2].toInt() and 0xFF
                // Filter out extreme blacks and whites
                if ((b1 + b2 + b3) in 60..700) {
                    sumR += b1
                    sumG += b2
                    sumB += b3
                    count++
                }
                i += step
            }

            if (count > 0) {
                val avgR = (sumR / count).toInt().coerceIn(0, 255)
                val avgG = (sumG / count).toInt().coerceIn(0, 255)
                val avgB = (sumB / count).toInt().coerceIn(0, 255)
                val seed = Color(avgR, avgG, avgB)
                val hct = Hct.fromColor(seed)
                PlaybackLogger.log("SoftifyPlayback", "HCT: Extracted seed RGB($avgR, $avgG, $avgB) -> Hue=${hct.hue.roundToInt()}°, Chroma=${hct.chroma.roundToInt()}")
                seed
            } else {
                PlaybackLogger.log("SoftifyPlayback", "HCT: Seed extraction fallback to default (#6750A4)")
                DEFAULT_SEED
            }
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyPlayback", "HCT: Seed extraction error (${e.message}), using default")
            DEFAULT_SEED
        }
    }

    /**
     * Generates a complete Material 3 Expressive Dark ColorScheme from a seed color.
     */
    fun createExpressiveColorScheme(seed: Color = DEFAULT_SEED): ColorScheme {
        val seedHct = Hct.fromColor(seed)
        val primaryPalette = TonalPalette(seedHct.hue, max(seedHct.chroma, 48f))
        val secondaryPalette = TonalPalette(seedHct.hue, 16f)
        val tertiaryPalette = TonalPalette((seedHct.hue + 60f) % 360f, 24f)
        val neutralPalette = TonalPalette(seedHct.hue, 6f)
        val neutralVariantPalette = TonalPalette(seedHct.hue, 10f)
        val errorPalette = TonalPalette(25f, 84f)

        return darkColorScheme(
            primary = primaryPalette.tone(80f),
            onPrimary = primaryPalette.tone(20f),
            primaryContainer = primaryPalette.tone(30f),
            onPrimaryContainer = primaryPalette.tone(90f),

            secondary = secondaryPalette.tone(80f),
            onSecondary = secondaryPalette.tone(20f),
            secondaryContainer = secondaryPalette.tone(30f),
            onSecondaryContainer = secondaryPalette.tone(90f),

            tertiary = tertiaryPalette.tone(80f),
            onTertiary = tertiaryPalette.tone(20f),
            tertiaryContainer = tertiaryPalette.tone(30f),
            onTertiaryContainer = tertiaryPalette.tone(90f),

            background = neutralPalette.tone(6f),
            onBackground = neutralPalette.tone(90f),

            surface = neutralPalette.tone(8f),
            onSurface = neutralPalette.tone(90f),
            surfaceVariant = neutralVariantPalette.tone(25f),
            onSurfaceVariant = neutralVariantPalette.tone(80f),

            surfaceContainer = neutralPalette.tone(12f),
            surfaceContainerHigh = neutralPalette.tone(17f),
            surfaceContainerHighest = neutralPalette.tone(22f),

            outline = neutralVariantPalette.tone(60f),
            outlineVariant = neutralVariantPalette.tone(30f),

            error = errorPalette.tone(80f),
            onError = errorPalette.tone(20f),
            errorContainer = errorPalette.tone(30f),
            onErrorContainer = errorPalette.tone(90f)
        )
    }
}
