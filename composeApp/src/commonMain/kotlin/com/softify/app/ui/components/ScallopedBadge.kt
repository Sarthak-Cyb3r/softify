package com.softify.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.theme.ScallopedBadgeShape
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Material 3 Expressive Scalloped Rosette Badge.
 * Uses parametric trochoid curve for avatars, logo badges, and playlist markers.
 */
@Composable
fun ScallopedBadge(
    modifier: Modifier = Modifier,
    numLobes: Int = 12,
    size: Dp = 48.dp,
    containerColor: Color = MaterialTheme.colorScheme.primaryContainer,
    borderColor: Color = MaterialTheme.colorScheme.primary,
    borderWidth: Dp = 1.5.dp,
    content: @Composable () -> Unit
) {
    val shape = ScallopedBadgeShape(numLobes = numLobes)

    Box(
        modifier = modifier
            .size(size)
            .clip(shape)
            .background(containerColor)
            .border(borderWidth, borderColor, shape),
        contentAlignment = Alignment.Center
    ) {
        content()
    }
}

@Preview
@Composable
fun PreviewScallopedBadge12Lobes() {
    ScallopedBadge(numLobes = 12, size = 64.dp) {
        Text("🎵", fontSize = 24.sp)
    }
}

@Preview
@Composable
fun PreviewScallopedBadge8Lobes() {
    ScallopedBadge(numLobes = 8, size = 56.dp) {
        Text("★", fontSize = 22.sp, color = MaterialTheme.colorScheme.primary)
    }
}

@Preview
@Composable
fun PreviewScallopedBadgeText() {
    ScallopedBadge(numLobes = 12, size = 52.dp) {
        Text("320k", fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}
