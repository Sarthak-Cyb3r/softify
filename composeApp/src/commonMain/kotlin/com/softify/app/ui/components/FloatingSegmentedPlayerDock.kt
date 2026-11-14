package com.softify.app.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.PlaylistPlay
import androidx.compose.material.icons.automirrored.filled.QueueMusic
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.theme.SquircleShape
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Floating Segmented Player Dock.
 * Features:
 * 1. Center countdown transport pill with squircle container and animated play/pause.
 * 2. Auxiliary pills for speed, sleep timer, EQ, and spring-pop favorite heart.
 * 3. Secondary utility dock: lyrics, shuffle, repeat, queue, share.
 * 4. Strict accessibility: all icons use ImageVectors with content descriptions and >= 48dp touch targets.
 * 5. In disabled state, all transport controls including play/pause are visibly dimmed and non-clickable.
 */
@Composable
fun FloatingSegmentedPlayerDock(
    isPlaying: Boolean,
    onTogglePlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    modifier: Modifier = Modifier,
    isBuffering: Boolean = false,
    elapsedMs: Long = 0L,
    totalMs: Long = 0L,
    speed: Float = 1.0f,
    onCycleSpeed: () -> Unit = {},
    sleepTimerLabel: String = "Off",
    onCycleSleepTimer: () -> Unit = {},
    eqPresetLabel: String = "Flat",
    onCycleEqPreset: () -> Unit = {},
    isFavorite: Boolean = false,
    onToggleFavorite: () -> Unit = {},
    isRepeatActive: Boolean = false,
    repeatMode: Int = 0, // 0 = off, 1 = one, 2 = all
    onToggleRepeat: () -> Unit = {},
    isShuffleActive: Boolean = false,
    onToggleShuffle: () -> Unit = {},
    onOpenLyrics: () -> Unit = {},
    onOpenQueue: () -> Unit = {},
    onShareTrack: () -> Unit = {},
    enabled: Boolean = true
) {
    var popState by remember { mutableStateOf(false) }
    val heartScale by animateFloatAsState(
        targetValue = if (popState) 1.35f else 1.0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioHighBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        finishedListener = { popState = false },
        label = "heartSpringPop"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // 1. Auxiliary Segmented Pills Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Speed Pill (>=48dp touch target)
            Surface(
                onClick = onCycleSpeed,
                enabled = enabled,
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                modifier = Modifier
                    .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                    .height(48.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.padding(horizontal = 12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Speed,
                        contentDescription = "Playback Speed",
                        modifier = Modifier.size(16.dp),
                        tint = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    )
                    Text(
                        text = "${speed}x",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    )
                }
            }

            // Sleep Timer Pill (>=48dp touch target)
            Surface(
                onClick = onCycleSleepTimer,
                enabled = enabled,
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                modifier = Modifier
                    .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                    .height(48.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.padding(horizontal = 12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Timer,
                        contentDescription = "Sleep Timer",
                        modifier = Modifier.size(16.dp),
                        tint = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    )
                    Text(
                        text = sleepTimerLabel,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    )
                }
            }

            // EQ Preset Pill (>=48dp touch target)
            Surface(
                onClick = onCycleEqPreset,
                enabled = enabled,
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                modifier = Modifier
                    .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                    .height(48.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.padding(horizontal = 12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Equalizer,
                        contentDescription = "Equalizer Preset",
                        modifier = Modifier.size(16.dp),
                        tint = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    )
                    Text(
                        text = eqPresetLabel,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    )
                }
            }

            // Favorite Button with Spring Pop Animation (>=48dp touch target)
            Surface(
                onClick = {
                    if (enabled) {
                        popState = true
                        onToggleFavorite()
                    }
                },
                enabled = enabled,
                shape = CircleShape,
                color = if (!enabled) {
                    MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.38f)
                } else if (isFavorite) {
                    MaterialTheme.colorScheme.errorContainer
                } else {
                    MaterialTheme.colorScheme.surfaceContainerHigh
                },
                modifier = Modifier
                    .size(48.dp)
                    .scale(heartScale)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = if (isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = if (isFavorite) "Remove from Favorites" else "Add to Favorites",
                        modifier = Modifier.size(22.dp),
                        tint = if (!enabled) {
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                        } else if (isFavorite) {
                            MaterialTheme.colorScheme.error
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        }
                    )
                }
            }
        }

        // 2. Primary Segmented Transport Capsule (Center Pill)
        Card(
            shape = SquircleShape(28.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHighest),
            modifier = Modifier
                .fillMaxWidth()
                .height(68.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Time Countdown Badge
                Column(
                    modifier = Modifier.padding(start = 6.dp),
                    verticalArrangement = Arrangement.Center
                ) {
                    val elapsedStr = formatTimeMs(elapsedMs)
                    val totalStr = formatTimeMs(totalMs)
                    Text(
                        text = elapsedStr,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = if (enabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primary.copy(alpha = 0.38f)
                    )
                    Text(
                        text = "/ $totalStr",
                        fontSize = 10.sp,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = if (enabled) 0.8f else 0.38f)
                    )
                }

                // Transport Buttons Row
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    // Previous Track (48dp touch target)
                    IconButton(
                        onClick = onPrevious,
                        enabled = enabled,
                        modifier = Modifier.size(48.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.SkipPrevious,
                            contentDescription = "Previous Track",
                            modifier = Modifier.size(24.dp),
                            tint = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                        )
                    }

                    // Main Morphing Play/Pause Pill (Dimmed and disabled when enabled = false)
                    Surface(
                        onClick = onTogglePlayPause,
                        enabled = enabled,
                        shape = CircleShape,
                        color = if (enabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primary.copy(alpha = 0.38f),
                        shadowElevation = if (enabled) 4.dp else 0.dp,
                        modifier = Modifier.size(52.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            AnimatedContent(targetState = isPlaying to isBuffering) { (playing, buffering) ->
                                when {
                                    buffering -> {
                                        CircularProgressIndicator(
                                            modifier = Modifier.size(24.dp),
                                            color = MaterialTheme.colorScheme.onPrimary,
                                            strokeWidth = 2.5.dp
                                        )
                                    }
                                    playing -> {
                                        Icon(
                                            imageVector = Icons.Filled.Pause,
                                            contentDescription = "Pause",
                                            modifier = Modifier.size(26.dp),
                                            tint = MaterialTheme.colorScheme.onPrimary
                                        )
                                    }
                                    else -> {
                                        Icon(
                                            imageVector = Icons.Filled.PlayArrow,
                                            contentDescription = "Play",
                                            modifier = Modifier.size(28.dp),
                                            tint = MaterialTheme.colorScheme.onPrimary
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Next Track (48dp touch target)
                    IconButton(
                        onClick = onNext,
                        enabled = enabled,
                        modifier = Modifier.size(48.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.SkipNext,
                            contentDescription = "Next Track",
                            modifier = Modifier.size(24.dp),
                            tint = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                        )
                    }
                }
            }
        }

        // 3. Secondary Utility Dock Row (Lyrics, Shuffle, Repeat, Queue, Share) with 48dp touch targets
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = onOpenLyrics,
                enabled = enabled,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.QueueMusic,
                    contentDescription = "Open Lyrics",
                    modifier = Modifier.size(20.dp),
                    tint = if (enabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                )
            }
            IconButton(
                onClick = onToggleShuffle,
                enabled = enabled,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Shuffle,
                    contentDescription = if (isShuffleActive) "Shuffle On" else "Shuffle Off",
                    modifier = Modifier.size(20.dp),
                    tint = if (!enabled) {
                        MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                    } else if (isShuffleActive) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    }
                )
            }
            IconButton(
                onClick = onToggleRepeat,
                enabled = enabled,
                modifier = Modifier.size(48.dp)
            ) {
                val icon = if (repeatMode == 1) Icons.Filled.RepeatOne else Icons.Filled.Repeat
                val desc = when (repeatMode) {
                    1 -> "Repeat One"
                    2 -> "Repeat All"
                    else -> "Repeat Off"
                }
                Icon(
                    imageVector = icon,
                    contentDescription = desc,
                    modifier = Modifier.size(20.dp),
                    tint = if (!enabled) {
                        MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                    } else if (isRepeatActive) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    }
                )
            }
            IconButton(
                onClick = onOpenQueue,
                enabled = enabled,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.PlaylistPlay,
                    contentDescription = "Open Queue",
                    modifier = Modifier.size(22.dp),
                    tint = if (enabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                )
            }
            IconButton(
                onClick = onShareTrack,
                enabled = enabled,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Share,
                    contentDescription = "Share Track",
                    modifier = Modifier.size(20.dp),
                    tint = if (enabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                )
            }
        }
    }
}

private fun formatTimeMs(timeMs: Long): String {
    val totalSeconds = (timeMs / 1000L).coerceAtLeast(0L)
    val minutes = totalSeconds / 60L
    val seconds = totalSeconds % 60L
    val secStr = if (seconds < 10) "0$seconds" else "$seconds"
    return "$minutes:$secStr"
}

@Preview
@Composable
fun FloatingSegmentedPlayerDockPlayingPreview() {
    FloatingSegmentedPlayerDock(
        isPlaying = true,
        onTogglePlayPause = {},
        onPrevious = {},
        onNext = {},
        elapsedMs = 45000L,
        totalMs = 210000L,
        isFavorite = true,
        isShuffleActive = true,
        isRepeatActive = false
    )
}

@Preview
@Composable
fun FloatingSegmentedPlayerDockBufferingPreview() {
    FloatingSegmentedPlayerDock(
        isPlaying = false,
        isBuffering = true,
        onTogglePlayPause = {},
        onPrevious = {},
        onNext = {},
        elapsedMs = 12000L,
        totalMs = 180000L
    )
}

@Preview
@Composable
fun FloatingSegmentedPlayerDockDisabledPreview() {
    FloatingSegmentedPlayerDock(
        isPlaying = false,
        enabled = false,
        onTogglePlayPause = {},
        onPrevious = {},
        onNext = {}
    )
}
