package com.softify.app.ui.applemusic

import androidx.compose.animation.*
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.data.PlayerManager
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette
import com.softify.app.ui.components.EqualizerView
import com.softify.app.ui.components.QueueView
import com.softify.app.ui.components.SoftifyIcons
import com.softify.app.ui.components.SoftifyImage
import com.softify.app.ui.components.SyncedLyricsView

@Composable
fun AppleMusicPlayerSheet(
    track: Track,
    palette: DynamicColorPalette,
    isPlaying: Boolean,
    progress: Float,
    volume: Float,
    onClose: () -> Unit
) {
    val lyrics by PlayerManager.lyrics.collectAsState()
    val queue by PlayerManager.queue.collectAsState()
    val isShuffle by PlayerManager.isShuffle.collectAsState()
    val isRepeat by PlayerManager.isRepeat.collectAsState()
    val isLyricsOpen by PlayerManager.isLyricsOpen.collectAsState()
    val isQueueOpen by PlayerManager.isQueueOpen.collectAsState()
    val isEqualizerOpen by PlayerManager.isEqualizerOpen.collectAsState()

    // Apple Music spring album scale: 1.0f when playing, 0.88f when paused
    val coverScale by animateFloatAsState(
        targetValue = if (isPlaying) 1.0f else 0.88f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        )
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(palette.ambientGradientStops))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(14.dp))

            // iOS Drag Handle
            Box(
                modifier = Modifier
                    .width(38.dp)
                    .height(5.dp)
                    .clip(RoundedCornerShape(100.dp))
                    .background(Color.White.copy(alpha = 0.35f))
                    .clickable { onClose() }
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Top Dismiss Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onClose) {
                    Icon(
                        imageVector = SoftifyIcons.ArrowDown,
                        contentDescription = "Dismiss",
                        tint = Color.White.copy(alpha = 0.8f),
                        modifier = Modifier.size(24.dp)
                    )
                }

                Text(
                    text = track.album ?: "Apple Music",
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )

                IconButton(onClick = { PlayerManager.toggleLike(track.id) }) {
                    Icon(
                        imageVector = if (track.isLiked) SoftifyIcons.HeartFilled else SoftifyIcons.HeartOutlined,
                        contentDescription = "Favorite",
                        tint = if (track.isLiked) Color(0xFFFA243C) else Color.White,
                        modifier = Modifier.size(22.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Main Content Area: Synced Lyrics, Queue, Equalizer, or Floating Cover Art
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                when {
                    isLyricsOpen -> {
                        SyncedLyricsView(
                            lyrics = lyrics,
                            activeLineIndex = 2,
                            isAppleMusic = true
                        )
                    }
                    isQueueOpen -> {
                        QueueView(
                            queue = queue,
                            currentTrack = track,
                            palette = palette,
                            isAppleMusic = true,
                            onTrackSelect = { PlayerManager.playTrack(it) },
                            onRemoveTrack = { PlayerManager.removeTrackFromQueue(it) },
                            onClose = { PlayerManager.toggleQueue() }
                        )
                    }
                    isEqualizerOpen -> {
                        EqualizerView(
                            palette = palette,
                            isAppleMusic = true,
                            onClose = { PlayerManager.toggleEqualizer() }
                        )
                    }
                    else -> {
                        // Floating 3D Artwork with Spring Scale
                        Box(
                            modifier = Modifier
                                .scale(coverScale)
                                .size(320.dp)
                                .shadow(
                                    elevation = 32.dp,
                                    shape = RoundedCornerShape(20.dp),
                                    ambientColor = palette.primary,
                                    spotColor = palette.primary
                                )
                        ) {
                            SoftifyImage(
                                url = track.coverUrl,
                                title = track.title,
                                modifier = Modifier.fillMaxSize(),
                                cornerRadius = 20.dp
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Track Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = track.title,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White,
                        maxLines = 1
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = track.artist,
                        fontSize = 17.sp,
                        color = Color.White.copy(alpha = 0.65f),
                        maxLines = 1
                    )
                }

                IconButton(
                    onClick = { /* options */ },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.15f))
                ) {
                    Icon(
                        imageVector = SoftifyIcons.MoreHorizontal,
                        contentDescription = "Options",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(18.dp))

            // iOS Time Scrubber Slider
            Slider(
                value = progress,
                onValueChange = { PlayerManager.setProgress(it) },
                colors = SliderDefaults.colors(
                    thumbColor = Color.White,
                    activeTrackColor = Color.White.copy(alpha = 0.85f),
                    inactiveTrackColor = Color.White.copy(alpha = 0.2f)
                ),
                modifier = Modifier.fillMaxWidth()
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                val elapsedSec = (track.durationMs / 1000 * progress).toLong()
                val elapsedFormatted = "${(elapsedSec / 60).toString().padStart(2, '0')}:${(elapsedSec % 60).toString().padStart(2, '0')}"
                Text(
                    text = elapsedFormatted,
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.6f)
                )
                Text(
                    text = "-${track.durationFormatted}",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // iOS Media Controls
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { PlayerManager.toggleShuffle() }) {
                    Icon(
                        imageVector = SoftifyIcons.Shuffle,
                        contentDescription = "Shuffle",
                        tint = if (isShuffle) Color(0xFFFA243C) else Color.White.copy(alpha = 0.4f),
                        modifier = Modifier.size(22.dp)
                    )
                }

                IconButton(onClick = { PlayerManager.previousTrack() }) {
                    Icon(
                        imageVector = SoftifyIcons.SkipPrevious,
                        contentDescription = "Previous",
                        tint = Color.White,
                        modifier = Modifier.size(36.dp)
                    )
                }

                // Apple Music Spring Play Button
                Box(
                    modifier = Modifier
                        .size(68.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                        .clickable { PlayerManager.togglePlayPause() },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (isPlaying) SoftifyIcons.Pause else SoftifyIcons.Play,
                        contentDescription = if (isPlaying) "Pause" else "Play",
                        tint = Color.Black,
                        modifier = Modifier.size(34.dp)
                    )
                }

                IconButton(onClick = { PlayerManager.nextTrack() }) {
                    Icon(
                        imageVector = SoftifyIcons.SkipNext,
                        contentDescription = "Next",
                        tint = Color.White,
                        modifier = Modifier.size(36.dp)
                    )
                }

                IconButton(onClick = { PlayerManager.toggleRepeat() }) {
                    Icon(
                        imageVector = SoftifyIcons.Repeat,
                        contentDescription = "Repeat",
                        tint = if (isRepeat) Color(0xFFFA243C) else Color.White.copy(alpha = 0.4f),
                        modifier = Modifier.size(22.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // iOS Volume Slider with Speaker Glyphs
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = SoftifyIcons.VolumeLow,
                    contentDescription = "Volume Low",
                    tint = Color.White.copy(alpha = 0.6f),
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Slider(
                    value = volume,
                    onValueChange = { PlayerManager.setVolume(it) },
                    colors = SliderDefaults.colors(
                        thumbColor = Color.White,
                        activeTrackColor = Color.White.copy(alpha = 0.85f),
                        inactiveTrackColor = Color.White.copy(alpha = 0.2f)
                    ),
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Icon(
                    imageVector = SoftifyIcons.VolumeHigh,
                    contentDescription = "Volume High",
                    tint = Color.White.copy(alpha = 0.6f),
                    modifier = Modifier.size(18.dp)
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Apple Music Bottom Actions: Lyrics, AirPlay, Queue, Equalizer
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(
                    onClick = { PlayerManager.toggleLyrics() },
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(if (isLyricsOpen) Color.White else Color.White.copy(alpha = 0.12f))
                ) {
                    Icon(
                        imageVector = SoftifyIcons.Lyrics,
                        contentDescription = "Lyrics",
                        tint = if (isLyricsOpen) Color.Black else Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }

                IconButton(
                    onClick = { /* AirPlay */ },
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.12f))
                ) {
                    Icon(
                        imageVector = SoftifyIcons.Airplay,
                        contentDescription = "AirPlay",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }

                IconButton(
                    onClick = { PlayerManager.toggleQueue() },
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(if (isQueueOpen) Color.White else Color.White.copy(alpha = 0.12f))
                ) {
                    Icon(
                        imageVector = SoftifyIcons.Queue,
                        contentDescription = "Queue",
                        tint = if (isQueueOpen) Color.Black else Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }

                IconButton(
                    onClick = { PlayerManager.toggleEqualizer() },
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(if (isEqualizerOpen) Color.White else Color.White.copy(alpha = 0.12f))
                ) {
                    Icon(
                        imageVector = SoftifyIcons.Equalizer,
                        contentDescription = "Equalizer",
                        tint = if (isEqualizerOpen) Color.Black else Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}
