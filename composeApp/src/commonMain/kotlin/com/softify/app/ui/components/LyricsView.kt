package com.softify.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Optional word-level timing for high-precision lyric rendering.
 */
data class LyricWord(
    val startMs: Long,
    val endMs: Long,
    val text: String
)

/**
 * Lyric line data structure.
 * Supports line-level timestamps (LRCLIB format) with optional word timings for future extensions.
 */
data class LyricLine(
    val timeMs: Long,
    val text: String,
    val words: List<LyricWord>? = null
)

/**
 * Parse plain LRC timestamp string lines "[mm:ss.xx] text" into a List<LyricLine>.
 */
fun parseLrcLines(lrcContent: String): List<LyricLine> {
    val result = mutableListOf<LyricLine>()
    val lines = lrcContent.lines()
    val regex = Regex("""\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)""")

    for (line in lines) {
        val match = regex.find(line.trim()) ?: continue
        val (minStr, secStr, fracStr, lyricText) = match.destructured
        val minutes = minStr.toLongOrNull() ?: 0L
        val seconds = secStr.toLongOrNull() ?: 0L
        val ms = if (fracStr.length == 2) fracStr.toLongOrNull()?.times(10) ?: 0L
        else fracStr.toLongOrNull() ?: 0L
        val totalMs = minutes * 60_000L + seconds * 1000L + ms
        result.add(LyricLine(timeMs = totalMs, text = lyricText.trim()))
    }
    return result.sortedBy { it.timeMs }
}

/**
 * NOTE: LRCLIB provides line-level timestamps only, so this is an interpolated
 * line sweep progress based on elapsed time within the active line duration,
 * not true per-word vocal phoneme timing. The component accepts optional LyricWord
 * timings if word-level timestamps become available in the future.
 */
@Composable
fun LyricsView(
    lines: List<LyricLine>,
    currentPositionMs: Long,
    modifier: Modifier = Modifier,
    isSynced: Boolean = true,
    onSeekTo: (Long) -> Unit = {},
    contentPadding: PaddingValues = PaddingValues(vertical = 120.dp, horizontal = 24.dp)
) {
    if (lines.isEmpty()) {
        Box(
            modifier = modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            InstrumentalIndicator()
        }
        return
    }

    if (!isSynced) {
        // Plain (unsynced) lyrics: readable scrollable list without shine or dimming
        LazyColumn(
            modifier = modifier.fillMaxSize(),
            contentPadding = contentPadding,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            itemsIndexed(lines) { _, line ->
                Text(
                    text = line.text,
                    style = MaterialTheme.typography.bodyLarge.copy(
                        fontSize = 18.sp,
                        color = MaterialTheme.colorScheme.onSurface,
                        textAlign = TextAlign.Start
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
        return
    }

    // Synced lyrics: find active line index
    val activeIndex = remember(lines, currentPositionMs) {
        var idx = -1
        for (i in lines.indices) {
            if (lines[i].timeMs <= currentPositionMs) {
                idx = i
            } else {
                break
            }
        }
        idx
    }

    val listState = rememberLazyListState()

    // Smooth auto-scroll to keep active line centered
    LaunchedEffect(activeIndex) {
        if (activeIndex in lines.indices) {
            listState.animateScrollToItem(
                index = activeIndex,
                scrollOffset = -150
            )
        }
    }

    LazyColumn(
        state = listState,
        modifier = modifier.fillMaxSize(),
        contentPadding = contentPadding,
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        itemsIndexed(lines) { index, line ->
            val isActive = (index == activeIndex)
            val isPast = (index < activeIndex)

            // Interpolated line sweep progress for active line
            val progress = if (isActive) {
                val nextStartMs = if (index + 1 < lines.size) lines[index + 1].timeMs else (line.timeMs + 4000L)
                val durationMs = (nextStartMs - line.timeMs).coerceAtLeast(500L) // guard <0.5s duration
                val elapsed = (currentPositionMs - line.timeMs).coerceAtLeast(0L)
                (elapsed.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
            } else if (isPast) {
                1f
            } else {
                0f
            }

            // Animated scale & alpha transitions for smooth focus shift
            val animatedScale by animateFloatAsState(
                targetValue = if (isActive) 1.05f else 0.94f,
                animationSpec = spring(stiffness = Spring.StiffnessMediumLow),
                label = "lyricScale"
            )

            val animatedAlpha by animateFloatAsState(
                targetValue = if (isActive) 1.0f else if (isPast) 0.40f else 0.45f,
                animationSpec = tween(durationMillis = 300),
                label = "lyricAlpha"
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .scale(animatedScale)
                    .alpha(animatedAlpha)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        onSeekTo(line.timeMs)
                    }
                    .padding(vertical = 4.dp)
            ) {
                if (isActive) {
                    ActiveLyricLine(
                        text = line.text,
                        progress = progress
                    )
                } else {
                    Text(
                        text = line.text,
                        style = MaterialTheme.typography.headlineSmall.copy(
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    )
                }
            }
        }
    }
}

/**
 * Active lyric line with gradient shine sweep highlight.
 * Uses Brush gradient with graphicsLayer and BlendMode.SrcIn to avoid per-frame text re-layout.
 */
@Composable
fun ActiveLyricLine(
    text: String,
    progress: Float,
    modifier: Modifier = Modifier
) {
    val primaryColor = MaterialTheme.colorScheme.primary
    val onSurfaceColor = MaterialTheme.colorScheme.onSurface
    val aheadColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)
            .drawWithContent {
                // 1. Draw base text content (generates the alpha mask)
                drawContent()

                // 2. Draw sweep highlight gradient using BlendMode.SrcIn
                val w = size.width.coerceAtLeast(1f)
                val clampedP = progress.coerceIn(0f, 1f)
                val sweepX = w * clampedP

                // Soft bright edge moving along the line
                val edgePx = 28.dp.toPx()
                val edgeFraction = (edgePx / w).coerceIn(0.01f, 0.25f)

                val startEdge = (clampedP - edgeFraction).coerceAtLeast(0f)
                val center = clampedP
                val endEdge = (clampedP + edgeFraction).coerceAtMost(1f)

                val sweepBrush = if (center <= 0.001f) {
                    Brush.horizontalGradient(listOf(aheadColor, aheadColor))
                } else if (center >= 0.999f) {
                    Brush.horizontalGradient(listOf(onSurfaceColor, onSurfaceColor))
                } else {
                    Brush.horizontalGradient(
                        0.0f to onSurfaceColor,
                        startEdge to onSurfaceColor,
                        center to primaryColor,
                        endEdge to aheadColor,
                        1.0f to aheadColor
                    )
                }

                drawRect(
                    brush = sweepBrush,
                    blendMode = BlendMode.SrcIn
                )
            }
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.headlineMedium.copy(
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = onSurfaceColor
            )
        )
    }
}

/**
 * Minimal instrumental indicator with pulsing Canvas dots (no emoji/glyph characters).
 */
@Composable
fun InstrumentalIndicator(
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "instrumentalDots")
    val dotAlpha1 by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dot1"
    )
    val dotAlpha2 by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, delayMillis = 200, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dot2"
    )
    val dotAlpha3 by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, delayMillis = 400, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dot3"
    )

    val dotColor = MaterialTheme.colorScheme.primary

    Row(
        modifier = modifier.padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = "Instrumental",
            style = MaterialTheme.typography.bodyMedium.copy(
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
            )
        )
        Canvas(modifier = Modifier.size(width = 32.dp, height = 12.dp)) {
            val radius = 2.5.dp.toPx()
            drawCircle(
                color = dotColor.copy(alpha = dotAlpha1),
                radius = radius,
                center = Offset(4.dp.toPx(), size.height / 2f)
            )
            drawCircle(
                color = dotColor.copy(alpha = dotAlpha2),
                radius = radius,
                center = Offset(16.dp.toPx(), size.height / 2f)
            )
            drawCircle(
                color = dotColor.copy(alpha = dotAlpha3),
                radius = radius,
                center = Offset(28.dp.toPx(), size.height / 2f)
            )
        }
    }
}

@Preview
@Composable
fun PreviewActiveLyricLine() {
    ActiveLyricLine(
        text = "Floating through the neon night",
        progress = 0.55f
    )
}

@Preview
@Composable
fun PreviewInstrumentalIndicator() {
    InstrumentalIndicator()
}
