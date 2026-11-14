package com.softify.app.ui.gallery

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.*
import com.softify.app.ui.theme.MetrolistTheme
import com.softify.app.ui.theme.SquircleShape
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Debug Component Gallery Screen for Material 3 Expressive UI.
 * Validates and showcases every component across all required states:
 * idle, playing, paused, buffering, dragging, disabled, long text, and fallback.
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
                        Column {
                            Text(
                                text = "🎨 M3 Expressive Gallery",
                                fontSize = 22.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Text(
                                text = "Multiplatform design tokens & component states",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        IconButton(onClick = onClose) {
                            Text("✕", fontSize = 20.sp, color = MaterialTheme.colorScheme.onSurface)
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // HCT Dynamic Seed Color Picker Row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
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
                                label = { Text(name, fontSize = 11.sp) }
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
                            // State 1: Idle (0% progress)
                            ComponentStateLabel("State: Idle (0% Progress)")
                            SquigglySlider(
                                value = 0f,
                                onValueChange = {},
                                isPlaying = false
                            )

                            // State 2: Playing (Active sine wave with frame clock phase)
                            ComponentStateLabel("State: Playing (Animated Sine Wave)")
                            SquigglySlider(
                                value = interactiveSliderValue,
                                onValueChange = { interactiveSliderValue = it },
                                isPlaying = true
                            )

                            // State 3: Paused (Flat collapsed line)
                            ComponentStateLabel("State: Paused (Flat Line)")
                            SquigglySlider(
                                value = 0.55f,
                                onValueChange = {},
                                isPlaying = false
                            )

                            // State 4: Buffering (Pulsing wave amplitude)
                            ComponentStateLabel("State: Buffering (Breathing Pulse)")
                            SquigglySlider(
                                value = 0.70f,
                                onValueChange = {},
                                isPlaying = true,
                                isBuffering = true
                            )

                            // State 5: Disabled
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
                            // State: Interactive / Playing
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

                            // State: Paused
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

                            // State: Buffering
                            ComponentStateLabel("State: Buffering (Spinner Pill)")
                            FloatingSegmentedPlayerDock(
                                isPlaying = true,
                                isBuffering = true,
                                onTogglePlayPause = {},
                                onPrevious = {},
                                onNext = {},
                                elapsedMs = 12_000,
                                totalMs = 180_000
                            )

                            // State: Disabled
                            ComponentStateLabel("State: Disabled")
                            FloatingSegmentedPlayerDock(
                                isPlaying = false,
                                onTogglePlayPause = {},
                                onPrevious = {},
                                onNext = {},
                                elapsedMs = 0,
                                totalMs = 0,
                                enabled = false
                            )

                            // State: Long Duration (Podcast / Symphony)
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

                // 3. Bitrate & Fidelity Badges Section
                item {
                    GallerySectionTitle("3. Real Telemetry Bitrate Badges")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("Studio Master (Real 48 kHz from Player Format)")
                            BitrateBadge(
                                provider = "jiosaavn_studio_master",
                                bitrateKbps = 320u,
                                codec = "aac",
                                isFallback = false,
                                sampleRateHz = 48000
                            )

                            ComponentStateLabel("Studio Master (No Sample Rate - Real Data Only)")
                            BitrateBadge(
                                provider = "jiosaavn_studio_master",
                                bitrateKbps = 320u,
                                codec = "aac",
                                isFallback = false,
                                sampleRateHz = null
                            )

                            ComponentStateLabel("YouTube Fallback (Visible Warning Badge)")
                            BitrateBadge(
                                provider = "youtube_innertube_visionos (itag 140)",
                                bitrateKbps = 129u,
                                codec = "aac",
                                isFallback = true,
                                sampleRateHz = 44100
                            )

                            ComponentStateLabel("YouTube Fallback Opus (155 kbps itag 251)")
                            BitrateBadge(
                                provider = "youtube_innertube_android (itag 251)",
                                bitrateKbps = 155u,
                                codec = "opus",
                                isFallback = true
                            )

                            ComponentStateLabel("Disabled / Inactive State")
                            BitrateBadge(
                                provider = "unknown",
                                bitrateKbps = 0u,
                                codec = "none",
                                enabled = false
                            )
                        }
                    }
                }

                // 4. Scalloped Rosette Badges & Squircles Section
                item {
                    GallerySectionTitle("4. Scalloped Shapes & Squircle Containers")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("Parametric Scalloped Badges (12 & 8 Lobes)")
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceAround,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                ScallopedBadge(numLobes = 12, size = 64.dp) {
                                    Text("🎵", fontSize = 24.sp)
                                }
                                ScallopedBadge(numLobes = 8, size = 56.dp) {
                                    Text("★", fontSize = 20.sp, color = MaterialTheme.colorScheme.primary)
                                }
                                ScallopedBadge(numLobes = 12, size = 48.dp) {
                                    Text("320k", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                }
                                ScallopedBadge(numLobes = 16, size = 44.dp) {
                                    Text("HQ", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold)
                                }
                            }

                            Spacer(modifier = Modifier.height(4.dp))
                            ComponentStateLabel("Continuous Curvature Squircles")
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(48.dp)
                                        .background(MaterialTheme.colorScheme.primaryContainer, SquircleShape(14.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("Squircle 14dp", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                }
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(48.dp)
                                        .background(MaterialTheme.colorScheme.secondaryContainer, SquircleShape(24.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("Squircle 24dp", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }

                // 5. Lyrics Preview & Volume Controls Section
                item {
                    GallerySectionTitle("5. Lyrics Preview & Volume Control")

                    Card(
                        shape = SquircleShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            ComponentStateLabel("Active Lyric Preview (Tappable)")
                            LyricsPreviewLine(currentLyric = "oo laalanee, sajdaa tera karoon")

                            ComponentStateLabel("Instrumental / No Lyrics State")
                            LyricsPreviewLine(currentLyric = null)

                            ComponentStateLabel("Expressive Volume Slider")
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
