package com.softify.app.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

val AppleMusicShapes = RoundedCornerShape(22.dp)

@Composable
fun AppleMusicTheme(
    palette: DynamicColorPalette,
    content: @Composable () -> Unit
) {
    val colorScheme = darkColorScheme(
        primary = Color.White,
        onPrimary = Color.Black,
        primaryContainer = Color.White.copy(alpha = 0.15f),
        surface = Color.Black.copy(alpha = 0.35f),
        surfaceVariant = Color.White.copy(alpha = 0.08f),
        background = Color(0xFF000000),
        onSurface = Color.White,
        onBackground = Color.White
    )

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}

@Composable
fun GlassmorphicContainer(
    modifier: Modifier = Modifier,
    cornerRadius: Int = 24,
    content: @Composable () -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius.dp)
    Box(
        modifier = modifier
            .clip(shape)
            .background(Color.White.copy(alpha = 0.08f))
            .border(
                width = 1.dp,
                brush = Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = 0.22f),
                        Color.White.copy(alpha = 0.04f)
                    )
                ),
                shape = shape
            )
    ) {
        content()
    }
}
