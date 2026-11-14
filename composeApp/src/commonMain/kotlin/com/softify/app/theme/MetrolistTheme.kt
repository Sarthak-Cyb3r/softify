package com.softify.app.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

val MetrolistShapes = Shapes(
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(20.dp),
    large = RoundedCornerShape(28.dp),
    extraLarge = RoundedCornerShape(36.dp)
)

val MetrolistTypography = Typography(
    titleLarge = Typography().titleLarge.copy(color = Color.White),
    titleMedium = Typography().titleMedium.copy(color = Color.White),
    bodyLarge = Typography().bodyLarge.copy(color = Color(0xFFE2E2E6)),
    bodyMedium = Typography().bodyMedium.copy(color = Color(0xFFC6C6CA)),
    labelSmall = Typography().labelSmall.copy(color = Color(0xFF919196))
)

@Composable
fun MetrolistTheme(
    palette: DynamicColorPalette,
    content: @Composable () -> Unit
) {
    val colorScheme = darkColorScheme(
        primary = palette.primary,
        onPrimary = palette.onPrimary,
        primaryContainer = palette.primaryContainer,
        surface = palette.surface,
        surfaceVariant = palette.surfaceVariant,
        background = palette.background,
        onSurface = Color(0xFFE6E6EA),
        onBackground = Color(0xFFF0F0F4)
    )

    MaterialTheme(
        colorScheme = colorScheme,
        shapes = MetrolistShapes,
        typography = MetrolistTypography,
        content = content
    )
}
