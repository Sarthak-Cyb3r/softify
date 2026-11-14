package com.softify.app.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Expressive Single-Line Lyric Preview banner.
 * Displays live synchronized lyric line with smooth transitions and tap gesture.
 */
@Composable
fun LyricsPreviewLine(
    currentLyric: String?,
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {}
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 24.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        AnimatedContent(
            targetState = currentLyric ?: "♪ ♪ ♪",
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "lyricLineAnim"
        ) { text ->
            Text(
                text = text,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                fontStyle = if (currentLyric == null) FontStyle.Italic else FontStyle.Normal,
                color = if (currentLyric != null) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Preview
@Composable
fun PreviewLyricsPreviewLine() {
    LyricsPreviewLine(currentLyric = "oo laalanee, sajdaa tera karoon")
}

@Preview
@Composable
fun PreviewLyricsPreviewLineInstrumental() {
    LyricsPreviewLine(currentLyric = null)
}
