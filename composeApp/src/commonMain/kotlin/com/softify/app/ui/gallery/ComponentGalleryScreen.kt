package com.softify.app.ui.gallery

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.*
import com.softify.app.ui.theme.MetrolistTheme
import com.softify.app.ui.theme.SquircleShape
import kotlinx.coroutines.delay
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Debug Component Gallery Screen for Material 3 Expressive UI.
 * Validates and showcases every component across all required states:
 * idle, playing, paused, buffering, dragging, disabled, long text, and fallback.
 * Strictly no emojis or pictographic glyphs used anywhere.
 */
@Composable
fun ComponentGalleryScreen(
    onClose: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    var selectedSeed by remember { mutableStateOf(Color(0xFF6750A4)) }
    var interactiveSliderValue by remember { mutableStateOf(0.42f) }
    var interactivePlaying by remember { mutableStateOf(true) }
    var interactiveVolume by remember { mutableStateOf(0.7f) }
    var interactiveFavorite by remember { mutableStateOf(true) }

    // Fake position driver for lyrics sweep highlight testing (gallery sample data only)
    val sampleGalleryLyrics = remember {
        listOf(
            LyricLine(timeMs = 0L, text = ""), // 0.0s - 4.0s: Instrumental gap
            LyricLine(timeMs = 4000L, text = "Floating through the neon night"),
            LyricLine(timeMs = 8500L, text = "Signals fading out of sight"),
            LyricLine(timeMs = 13000L, text = "All the melodies we used to know and sing together in the quiet rain"),
            LyricLine(timeMs = 20000L, text = "Echoes in the quiet afterglow")
        )
    }
    var fakeLyricsPositionMs by remember { mutableStateOf(6200L) }
    var fakeLyricsPlaying by remember { mutableStateOf(false) }

    // Position ticker when fake playing is enabled
    LaunchedEffect(fakeLyricsPlaying) {
        while (fakeLyricsPlaying) {
            delay(50)
            fakeLyricsPositionMs = (fakeLyricsPositionMs + 50L) % 24_000L
        }
    }

    MetrolistTheme(seedColor = selectedSeed) {
        Surface(
            modifier = modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                // Header & Theme Seed Switcher
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Palette,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(24.dp)
                            )
                            Column {
                                Text(
                                    text = "M3 Expressive Gallery",
                                    fontSize = 20.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.onBackground
                                )
                                Text(
                                    text = "Multiplatform design tokens & component states",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        IconButton(
                            onClick = onClose,
                            modifier = Modifier.size(48.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Close,
                                contentDescription = "Close Gallery",
                                tint = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Horizontally scrollable HCT Dynamic Seed Color Picker Row (no wrapping)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Seed:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        val seeds = listOf(
                            "Indigo" to Color(0xFF6750A4),
                            "Emerald" to Color(0xFF006C4C),
                            "Amber" to Color(0xFF8D4F00),
                            "Rose" to Color(0xFF984061)
                        )
                        for ((name, color) in seeds) {
                            FilterChip(
                                selected = selectedSeed == color,
                                onClick = { selectedSeed = color },
                                label = {
                                    Text(
                                        text = name,
                                        fontSize = 11.sp,
                                        maxLines = 1,
                                        softWrap = false
                                    )
                                },
                                modifier = Modifier.defaultMinSize(minHeight = 48.dp)
                            )
                        }
                    }
                }

                // 1. Squiggly Waveform Slider Section
                item {
                    GallerySectionTitle("1. Squiggly Waveform Slider")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("State: Idle (0% Progress)")
                            SquigglySlider(
                                value = 0f,
                                onValueChange = {},
                                isPlaying = false
                            )

                            ComponentStateLabel("State: Playing (Animated Sine Wave)")
                            SquigglySlider(
                                value = interactiveSliderValue,
                                onValueChange = { interactiveSliderValue = it },
                                isPlaying = true
                            )

                            ComponentStateLabel("State: Paused (Flat Line)")
                            SquigglySlider(
                                value = 0.55f,
                                onValueChange = {},
                                isPlaying = false
                            )

                            ComponentStateLabel("State: Buffering (Breathing Pulse)")
                            SquigglySlider(
                                value = 0.70f,
                                onValueChange = {},
                                isPlaying = true,
                                isBuffering = true
                            )

                            ComponentStateLabel("State: Disabled")
                            SquigglySlider(
                                value = 0.35f,
                                onValueChange = {},
                                isPlaying = false,
                                enabled = false
                            )
                        }
                    }
                }

                // 2. Floating Segmented Player Dock Section
                item {
                    GallerySectionTitle("2. Floating Segmented Player Dock")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            ComponentStateLabel("State: Playing (Countdown & Spring Favorite)")
                            FloatingSegmentedPlayerDock(
                                isPlaying = interactivePlaying,
                                onTogglePlayPause = { interactivePlaying = !interactivePlaying },
                                onPrevious = {},
                                onNext = {},
                                elapsedMs = (interactiveSliderValue * 262_000).toLong(),
                                totalMs = 262_000,
                                isFavorite = interactiveFavorite,
                                onToggleFavorite = { interactiveFavorite = !interactiveFavorite }
                            )

                            ComponentStateLabel("State: Paused")
                            FloatingSegmentedPlayerDock(
                                isPlaying = false,
                                onTogglePlayPause = {},
                                onPrevious = {},
                                onNext = {},
                                elapsedMs = 45_000,
                                totalMs = 200_000,
                                isFavorite = false
                            )

                            ComponentStateLabel("State: Buffering (Proper Circular Progress Indicator)")
                            FloatingSegmentedPlayerDock(
                                isPlaying = false,
                                isBuffering = true,
                                onTogglePlayPause = {},
                                onPrevious = {},
                                onNext = {},
                                elapsedMs = 12_000,
                                totalMs = 180_000
                            )

                            ComponentStateLabel("State: Disabled (All Controls Dimmed & Non-Clickable)")
                            FloatingSegmentedPlayerDock(
                                isPlaying = false,
                                onTogglePlayPause = {},
                                onPrevious = {},
                                onNext = {},
                                elapsedMs = 0,
                                totalMs = 0,
                                enabled = false
                            )

                            ComponentStateLabel("State: Long Duration (01:24:18 / 02:45:00)")
                            FloatingSegmentedPlayerDock(
                                isPlaying = true,
                                onTogglePlayPause = {},
                                onPrevious = {},
                                onNext = {},
                                elapsedMs = 5058_000,
                                totalMs = 9900_000
                            )
                        }
                    }
                }

                // 3. Minimal Quiet Bitrate Badges Section
                item {
                    GallerySectionTitle("3. Minimal Bitrate Badges")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("Direct Stream (Standard 320 kbps AAC)")
                            BitrateBadge(
                                bitrateKbps = 320u,
                                codec = "AAC",
                                isFallback = false
                            )

                            ComponentStateLabel("With Sample Rate from Player (gallery preview)")
                            BitrateBadge(
                                bitrateKbps = 320u,
                                codec = "AAC",
                                isFallback = false,
                                sampleRateHz = 48000
                            )

                            ComponentStateLabel("YouTube Fallback (129 kbps AAC fallback)")
                            BitrateBadge(
                                bitrateKbps = 129u,
                                codec = "AAC",
                                isFallback = true
                            )

                            ComponentStateLabel("YouTube Fallback Opus (155 kbps OPUS fallback)")
                            BitrateBadge(
                                bitrateKbps = 155u,
                                codec = "OPUS",
                                isFallback = true
                            )

                            ComponentStateLabel("Disabled / Inactive State")
                            BitrateBadge(
                                bitrateKbps = 0u,
                                codec = "",
                                enabled = false
                            )
                        }
                    }
                }

                // 4. Squircle Containers Section (Scalloped removed entirely)
                item {
                    GallerySectionTitle("4. Squircle Containers")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("Continuous Curvature Squircles (14dp, 20dp, 28dp)")
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(52.dp)
                                        .background(MaterialTheme.colorScheme.primaryContainer, SquircleShape(14.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("Squircle 14dp", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                                }
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(52.dp)
                                        .background(MaterialTheme.colorScheme.secondaryContainer, SquircleShape(20.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("Squircle 20dp", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSecondaryContainer)
                                }
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(52.dp)
                                        .background(MaterialTheme.colorScheme.tertiaryContainer, SquircleShape(28.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("Squircle 28dp", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onTertiaryContainer)
                                }
                            }
                        }
                    }
                }

                // 5. Lyrics View & Sweep Highlight Section
                item {
                    GallerySectionTitle("5. Synced Lyrics & Sweep Highlight")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("Interactive Position Driver (gallery sample data)")

                            // Position & Play Controller Row
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                IconButton(
                                    onClick = { fakeLyricsPlaying = !fakeLyricsPlaying },
                                    modifier = Modifier.size(48.dp)
                                ) {
                                    Icon(
                                        imageVector = if (fakeLyricsPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                                        contentDescription = if (fakeLyricsPlaying) "Pause Sweep" else "Play Sweep",
                                        tint = MaterialTheme.colorScheme.primary
                                    )
                                }

                                val sec = fakeLyricsPositionMs / 1000f
                                val formattedSec = ((sec * 10).toInt() / 10f).toString()
                                Text(
                                    text = "${formattedSec}s / 24.0s",
                                    fontSize = 12.sp,
                                    fontFamily = FontFamily.Monospace,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )

                                Slider(
                                    value = fakeLyricsPositionMs.toFloat(),
                                    onValueChange = { fakeLyricsPositionMs = it.toLong() },
                                    valueRange = 0f..24_000f,
                                    modifier = Modifier.weight(1f)
                                )
                            }

                            // Quick Jump Buttons
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                OutlinedButton(
                                    onClick = { fakeLyricsPositionMs = 1500L },
                                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text("Instrumental (1.5s)", fontSize = 10.sp)
                                }
                                OutlinedButton(
                                    onClick = { fakeLyricsPositionMs = 4300L },
                                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text("Line Start (4.3s)", fontSize = 10.sp)
                                }
                                OutlinedButton(
                                    onClick = { fakeLyricsPositionMs = 6250L },
                                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text("Line Middle 50% (6.2s)", fontSize = 10.sp)
                                }
                                OutlinedButton(
                                    onClick = { fakeLyricsPositionMs = 8100L },
                                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text("Line End 95% (8.1s)", fontSize = 10.sp)
                                }
                            }

                            Spacer(modifier = Modifier.height(4.dp))
                            ComponentStateLabel("Single-Line Preview Banner (with Sweep)")
                            val activeLineText = sampleGalleryLyrics.lastOrNull { it.timeMs <= fakeLyricsPositionMs }?.text
                            val activeLineStart = sampleGalleryLyrics.lastOrNull { it.timeMs <= fakeLyricsPositionMs }?.timeMs ?: 0L
                            val lineIndex = sampleGalleryLyrics.indexOfLast { it.timeMs <= fakeLyricsPositionMs }
                            val nextLineStart = if (lineIndex >= 0 && lineIndex + 1 < sampleGalleryLyrics.size) sampleGalleryLyrics[lineIndex + 1].timeMs else (activeLineStart + 4000L)
                            val lineDur = (nextLineStart - activeLineStart).coerceAtLeast(500L)
                            val lineProgress = ((fakeLyricsPositionMs - activeLineStart).toFloat() / lineDur.toFloat()).coerceIn(0f, 1f)

                            LyricsPreviewLine(
                                currentLyric = if (activeLineText.isNullOrBlank()) null else activeLineText,
                                progress = lineProgress
                            )

                            Spacer(modifier = Modifier.height(4.dp))
                            ComponentStateLabel("Full Multi-Line Synced LyricsView")
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(240.dp)
                                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp))
                                    .padding(8.dp)
                            ) {
                                LyricsView(
                                    lines = sampleGalleryLyrics,
                                    currentPositionMs = fakeLyricsPositionMs,
                                    onSeekTo = { fakeLyricsPositionMs = it },
                                    contentPadding = PaddingValues(vertical = 40.dp, horizontal = 12.dp)
                                )
                            }
                        }
                    }
                }

                // 6. Volume Control Section
                item {
                    GallerySectionTitle("6. Expressive Volume Slider")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("Interactive System Volume Slider (with Mute Toggle)")
                            ExpressiveVolumeSlider(
                                volume = interactiveVolume,
                                onVolumeChange = { interactiveVolume = it }
                            )
                        }
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(30.dp))
                }
            }
        }
    }
}

@Composable
private fun GallerySectionTitle(title: String) {
    Text(
        text = title,
        fontSize = 15.sp,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(vertical = 4.dp)
    )
}

@Composable
private fun ComponentStateLabel(label: String) {
    Text(
        text = label,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Preview
@Composable
fun PreviewComponentGallery() {
    ComponentGalleryScreen()
}
