package com.softify.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.theme.SquircleShape
import org.jetbrains.compose.ui.tooling.preview.Preview
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import kotlin.math.PI
import kotlin.math.sin

/**
 * Material 3 Expressive Mini Player docked above the bottom navigation bar.
 * Features:
 * - Cover thumbnail with squircle clip
 * - Bold title & muted artist
 * - Minimal BitrateBadge
 * - Thin squiggly progress line along top edge
 * - Play/Pause and Next action buttons with >=48dp touch targets
 * - Tap anywhere on body opens Now Playing (or triggers callback)
 */
@Composable
fun MiniPlayer(
    track: Track?,
    streamInfo: StreamInfo?,
    isPlaying: Boolean,
    progress: Float,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (track == null) return

    val infiniteTransition = rememberInfiniteTransition(label = "MiniSquiggle")
    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "MiniPhase"
    )

    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .clickable(onClick = onClick),
        shape = SquircleShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // Thin squiggly progress line along top edge
            val primaryColor = MaterialTheme.colorScheme.primary
            val variantColor = MaterialTheme.colorScheme.surfaceVariant
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
            ) {
                val width = size.width
                val activeWidth = width * progress.coerceIn(0f, 1f)
                val midY = size.height / 2f

                if (activeWidth > 0f) {
                    val path = Path()
                    path.moveTo(0f, midY)
                    val waveLength = 24.dp.toPx()
                    val amplitude = if (isPlaying) 1.5.dp.toPx() else 0f

                    var x = 0f
                    while (x <= activeWidth) {
                        val angle = (x / waveLength) * 2f * PI.toFloat() + phase
                        val y = midY + sin(angle) * amplitude
                        path.lineTo(x, y)
                        x += 2f
                    }
                    drawPath(
                        path = path,
                        color = primaryColor,
                        style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round)
                    )
                }

                // Inactive track line
                if (activeWidth < width) {
                    drawLine(
                        color = variantColor,
                        start = androidx.compose.ui.geometry.Offset(activeWidth, midY),
                        end = androidx.compose.ui.geometry.Offset(width, midY),
                        strokeWidth = 2.dp.toPx(),
                        cap = StrokeCap.Round
                    )
                }
            }

            // Main Mini Player Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Cover Art Thumbnail
                AsyncCoverArt(
                    url = track.coverUrl,
                    size = CoverSize.FULL,
                    modifier = Modifier.size(46.dp),
                    shape = SquircleShape(10.dp)
                )

                Spacer(modifier = Modifier.width(12.dp))

                // Title, Artist, & Minimal Bitrate Badge
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = track.title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    Spacer(modifier = Modifier.height(2.dp))

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            text = track.artist,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false)
                        )

                        if (streamInfo != null) {
                            val isFallback = !streamInfo.isRequestedQuality || streamInfo.provider.contains("youtube", ignoreCase = true)
                            BitrateBadge(
                                bitrateKbps = streamInfo.bitrateKbps,
                                codec = streamInfo.codec,
                                isFallback = isFallback
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.width(8.dp))

                // Action Controls: Play/Pause and Next
                IconButton(
                    onClick = onPlayPause,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = if (isPlaying) "Pause" else "Play",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(28.dp)
                    )
                }

                IconButton(
                    onClick = onNext,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.SkipNext,
                        contentDescription = "Next Track",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(26.dp)
                    )
                }
            }
        }
    }
}

@Preview
@Composable
fun MiniPlayerPreview() {
    MaterialTheme {
        MiniPlayer(
            track = Track(
                id = "t1",
                sourceId = "t1",
                title = "Tum Hi Ho",
                artist = "Arijit Singh",
                album = "Aashiqui 2",
                durationMs = 262_000u,
                coverUrl = null,
                matchConfidence = null,
                isLiked = true,
                isUnavailable = false
            ),
            streamInfo = StreamInfo(
                url = "https://example.com/audio.m4a",
                container = "m4a",
                bitrateKbps = 320u,
                codec = "aac",
                provider = "saavn",
                isRequestedQuality = true,
                headers = emptyList(),
                expiresAt = null
            ),
            isPlaying = true,
            progress = 0.42f,
            onPlayPause = {},
            onNext = {},
            onClick = {}
        )
    }
}
