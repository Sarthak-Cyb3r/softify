package com.softify.app.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
 * Material 3 Expressive Floating Segmented Player Dock.
 * - Center Capsule: Countdown time display, previous, next, and morphing play/pause.
 * - Auxiliary Pills: Playback speed, sleep timer, EQ preset, and spring-popping favorite heart.
 * - Secondary Utility Bar: Lyrics, repeat, shuffle, queue, and share sheet triggers.
 */
@Composable
fun FloatingSegmentedPlayerDock(
    isPlaying: Boolean,
    onTogglePlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    elapsedMs: Long,
    totalMs: Long,
    modifier: Modifier = Modifier,
    isBuffering: Boolean = false,
    isFavorite: Boolean = false,
    onToggleFavorite: () -> Unit = {},
    speed: Float = 1.0f,
    onCycleSpeed: () -> Unit = {},
    sleepTimerLabel: String = "Off",
    onCycleSleepTimer: () -> Unit = {},
    eqPresetLabel: String = "Studio",
    onCycleEqPreset: () -> Unit = {},
    isRepeatActive: Boolean = false,
    onToggleRepeat: () -> Unit = {},
    isShuffleActive: Boolean = false,
    onToggleShuffle: () -> Unit = {},
    onOpenLyrics: () -> Unit = {},
    onOpenQueue: () -> Unit = {},
    onShareTrack: () -> Unit = {},
    enabled: Boolean = true
) {
    // Spring pop scale for favorite heart button
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
            // Speed Pill
            Surface(
                onClick = onCycleSpeed,
                enabled = enabled,
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                modifier = Modifier.height(32.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.padding(horizontal = 12.dp)
                ) {
                    Text(
                        text = "⚡ ${speed}x",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            // Sleep Timer Pill
            Surface(
                onClick = onCycleSleepTimer,
                enabled = enabled,
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                modifier = Modifier.height(32.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.padding(horizontal = 12.dp)
                ) {
                    Text(
                        text = "⏱ $sleepTimerLabel",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            // EQ Preset Pill
            Surface(
                onClick = onCycleEqPreset,
                enabled = enabled,
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                modifier = Modifier.height(32.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.padding(horizontal = 12.dp)
                ) {
                    Text(
                        text = "🎚 $eqPresetLabel",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            // Favorite Button with Spring Pop Animation
            Surface(
                onClick = {
                    if (enabled) {
                        popState = true
                        onToggleFavorite()
                    }
                },
                enabled = enabled,
                shape = CircleShape,
                color = if (isFavorite) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
                modifier = Modifier
                    .size(36.dp)
                    .scale(heartScale)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        text = if (isFavorite) "❤️" else "🤍",
                        fontSize = 14.sp
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
                .height(64.dp)
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
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "/ $totalStr",
                        fontSize = 10.sp,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                // Transport Buttons Row
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Previous
                    IconButton(
                        onClick = onPrevious,
                        enabled = enabled,
                        modifier = Modifier.size(42.dp)
                    ) {
                        Text("⏮", fontSize = 20.sp, color = if (enabled) MaterialTheme.colorScheme.onSurface else Color.Gray)
                    }

                    // Main Morphing Play/Pause Pill
                    Surface(
                        onClick = onTogglePlayPause,
                        enabled = enabled,
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary,
                        shadowElevation = 4.dp,
                        modifier = Modifier.size(50.dp)
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
                                        Text("⏸", fontSize = 20.sp, color = MaterialTheme.colorScheme.onPrimary)
                                    }
                                    else -> {
                                        Text("▶", fontSize = 20.sp, color = MaterialTheme.colorScheme.onPrimary)
                                    }
                                }
                            }
                        }
                    }

                    // Next
                    IconButton(
                        onClick = onNext,
                        enabled = enabled,
                        modifier = Modifier.size(42.dp)
                    ) {
                        Text("⏭", fontSize = 20.sp, color = if (enabled) MaterialTheme.colorScheme.onSurface else Color.Gray)
                    }
                }
            }
        }

        // 3. Secondary Utility Dock Row (Lyrics, Shuffle, Repeat, Queue, Share)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onOpenLyrics, enabled = enabled) {
                Text("💬", fontSize = 16.sp)
            }
            IconButton(onClick = onToggleShuffle, enabled = enabled) {
                val color = if (isShuffleActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                Text("🔀", fontSize = 16.sp, color = color)
            }
            IconButton(onClick = onToggleRepeat, enabled = enabled) {
                val color = if (isRepeatActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                Text("🔁", fontSize = 16.sp, color = color)
            }
            IconButton(onClick = onOpenQueue, enabled = enabled) {
                Text("📑", fontSize = 16.sp)
            }
            IconButton(onClick = onShareTrack, enabled = enabled) {
                Text("📤", fontSize = 16.sp)
            }
        }
    }
}

private fun formatTimeMs(ms: Long): String {
    val totalSecs = (ms / 1000).coerceAtLeast(0)
    val mins = totalSecs / 60
    val secs = totalSecs % 60
    return String.format("%02d:%02d", mins, secs)
}

@Preview
@Composable
fun PreviewFloatingDockPlaying() {
    FloatingSegmentedPlayerDock(
        isPlaying = true,
        onTogglePlayPause = {},
        onPrevious = {},
        onNext = {},
        elapsedMs = 124_000,
        totalMs = 262_000,
        isFavorite = true
    )
}

@Preview
@Composable
fun PreviewFloatingDockPaused() {
    FloatingSegmentedPlayerDock(
        isPlaying = false,
        onTogglePlayPause = {},
        onPrevious = {},
        onNext = {},
        elapsedMs = 45_000,
        totalMs = 180_000,
        isFavorite = false
    )
}

@Preview
@Composable
fun PreviewFloatingDockBuffering() {
    FloatingSegmentedPlayerDock(
        isPlaying = true,
        isBuffering = true,
        onTogglePlayPause = {},
        onPrevious = {},
        onNext = {},
        elapsedMs = 10_000,
        totalMs = 200_000
    )
}

@Preview
@Composable
fun PreviewFloatingDockDisabled() {
    FloatingSegmentedPlayerDock(
        isPlaying = false,
        onTogglePlayPause = {},
        onPrevious = {},
        onNext = {},
        elapsedMs = 0,
        totalMs = 0,
        enabled = false
    )
}
