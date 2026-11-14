package com.softify.app.theme

import androidx.compose.ui.graphics.Color
import kotlin.math.abs

enum class ThemeMode {
    METROLIST,
    APPLE_MUSIC
}

data class DynamicColorPalette(
    val primary: Color,
    val onPrimary: Color,
    val primaryContainer: Color,
    val surface: Color,
    val surfaceVariant: Color,
    val background: Color,
    val ambientGradientStops: List<Color>
)

object ColorExtractor {
    fun extractFromTitle(title: String, artist: String): DynamicColorPalette {
        // Deterministic high-aesthetic color synthesizer based on title/artist seed
        val hash = abs((title + artist).hashCode())
        val hue = (hash % 360).toFloat()

        val primary = Color.hsl(hue = hue, saturation = 0.72f, lightness = 0.58f)
        val primaryContainer = Color.hsl(hue = hue, saturation = 0.65f, lightness = 0.22f)
        val secondary = Color.hsl(hue = (hue + 40) % 360, saturation = 0.68f, lightness = 0.45f)
        val tertiary = Color.hsl(hue = (hue + 160) % 360, saturation = 0.60f, lightness = 0.35f)

        return DynamicColorPalette(
            primary = primary,
            onPrimary = Color.White,
            primaryContainer = primaryContainer,
            surface = Color(0xFF161618),
            surfaceVariant = Color(0xFF242428),
            background = Color(0xFF0C0C0E),
            ambientGradientStops = listOf(
                primary.copy(alpha = 0.45f),
                secondary.copy(alpha = 0.35f),
                tertiary.copy(alpha = 0.25f),
                Color(0xFF08080A)
            )
        )
    }
}
