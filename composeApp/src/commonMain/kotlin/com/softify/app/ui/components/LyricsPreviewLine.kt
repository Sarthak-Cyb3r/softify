package com.softify.app.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Expressive Single-Line Lyric Preview banner.
 * Displays live synchronized lyric line with smooth transitions and tap gesture.
 * When instrumental or no lyrics, renders minimal InstrumentalIndicator (no glyphs).
 */
@Composable
fun LyricsPreviewLine(
    currentLyric: String?,
    modifier: Modifier = Modifier,
    progress: Float = 0f,
    onClick: () -> Unit = {}
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 24.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        AnimatedContent(
            targetState = currentLyric,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "lyricLineAnim"
        ) { text ->
            if (text != null && text.isNotBlank()) {
                ActiveLyricLine(
                    text = text,
                    progress = progress
                )
            } else {
                InstrumentalIndicator()
            }
        }
    }
}

@Preview
@Composable
fun PreviewLyricsPreviewLine() {
    LyricsPreviewLine(
        currentLyric = "Floating through the neon night",
        progress = 0.5f
    )
}

@Preview
@Composable
fun PreviewLyricsPreviewLineInstrumental() {
    LyricsPreviewLine(currentLyric = null)
}
