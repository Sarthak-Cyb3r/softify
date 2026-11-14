package com.softify.app.ui.metrolist

import androidx.compose.animation.*
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.data.PlayerManager
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette
import com.softify.app.ui.components.EqualizerView
import com.softify.app.ui.components.QueueView
import com.softify.app.ui.components.SoftifyImage
import com.softify.app.ui.components.SyncedLyricsView

@Composable
fun MetrolistPlayerSheet(
    track: Track,
    palette: DynamicColorPalette,
    isPlaying: Boolean,
    progress: Float,
    onClose: () -> Unit
) {
    val lyrics by PlayerManager.lyrics.collectAsState()
    val queue by PlayerManager.queue.collectAsState()
    val isShuffle by PlayerManager.isShuffle.collectAsState()
    val isRepeat by PlayerManager.isRepeat.collectAsState()
    val isLyricsOpen by PlayerManager.isLyricsOpen.collectAsState()
    val isQueueOpen by PlayerManager.isQueueOpen.collectAsState()
    val isEqualizerOpen by PlayerManager.isEqualizerOpen.collectAsState()

    Surface(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp)),
        color = palette.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(12.dp))

            // Drag Pill Handle
            Box(
                modifier = Modifier
                    .width(42.dp)
                    .height(5.dp)
                    .clip(RoundedCornerShape(100.dp))
                    .background(Color.White.copy(alpha = 0.25f))
                    .clickable { onClose() }
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Top Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onClose) {
                    Text(text = "▼", color = Color.White, fontSize = 18.sp)
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "PLAYING FROM PLAYLIST",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White.copy(alpha = 0.5f),
                        letterSpacing = 1.sp
                    )
                    Text(
                        text = track.album ?: "Metrolist Essentials",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = palette.primary
                    )
                }

                IconButton(onClick = { PlayerManager.toggleLike(track.id) }) {
                    Text(
                        text = if (track.isLiked) "♥" else "♡",
                        color = if (track.isLiked) palette.primary else Color.White,
                        fontSize = 22.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Body: either Lyrics, Queue, Equalizer, or Full Album Art
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
                            isAppleMusic = false
                        )
                    }
                    isQueueOpen -> {
                        QueueView(
                            queue = queue,
                            currentTrack = track,
                            palette = palette,
                            isAppleMusic = false,
                            onTrackSelect = { PlayerManager.playTrack(it) },
                            onRemoveTrack = { PlayerManager.removeTrackFromQueue(it) },
                            onClose = { PlayerManager.toggleQueue() }
                        )
                    }
                    isEqualizerOpen -> {
                        EqualizerView(
                            palette = palette,
                            isAppleMusic = false,
                            onClose = { PlayerManager.toggleEqualizer() }
                        )
                    }
                    else -> {
                        // Big 28dp Squircle Album Art with Dynamic Shadow
                        SoftifyImage(
                            url = track.coverUrl,
                            title = track.title,
                            modifier = Modifier
                                .size(310.dp)
                                .shadow(24.dp, RoundedCornerShape(28.dp), ambientColor = palette.primary, spotColor = palette.primary),
                            cornerRadius = 28.dp
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Track Info Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = track.title,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        maxLines = 1
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = track.artist,
                        fontSize = 15.sp,
                        color = palette.primary,
                        maxLines = 1
                    )
                }
            }

            Spacer(modifier = Modifier.height(18.dp))

            // Progress Slider
            Slider(
                value = progress,
                onValueChange = { PlayerManager.setProgress(it) },
                colors = SliderDefaults.colors(
                    thumbColor = palette.primary,
                    activeTrackColor = palette.primary,
                    inactiveTrackColor = Color.White.copy(alpha = 0.12f)
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
                    text = track.durationFormatted,
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }

            Spacer(modifier = Modifier.height(18.dp))

            // Transport Media Controls
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { PlayerManager.toggleShuffle() }) {
                    Text(
                        text = "🔀",
                        color = if (isShuffle) palette.primary else Color.White.copy(alpha = 0.4f),
                        fontSize = 18.sp
                    )
                }

                IconButton(onClick = { PlayerManager.previousTrack() }) {
                    Text(text = "⏮", color = Color.White, fontSize = 28.sp)
                }

                // Play / Pause Circle Button
                Box(
                    modifier = Modifier
                        .size(70.dp)
                        .clip(CircleShape)
                        .background(palette.primary)
                        .clickable { PlayerManager.togglePlayPause() },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (isPlaying) "⏸" else "▶",
                        color = palette.onPrimary,
                        fontSize = 26.sp
                    )
                }

                IconButton(onClick = { PlayerManager.nextTrack() }) {
                    Text(text = "⏭", color = Color.White, fontSize = 28.sp)
                }

                IconButton(onClick = { PlayerManager.toggleRepeat() }) {
                    Text(
                        text = "🔁",
                        color = if (isRepeat) palette.primary else Color.White.copy(alpha = 0.4f),
                        fontSize = 18.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Bottom Auxiliary Actions: Lyrics, Queue, Equalizer
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { PlayerManager.toggleLyrics() }) {
                    Text(
                        text = "🎤",
                        color = if (isLyricsOpen) palette.primary else Color.White.copy(alpha = 0.6f),
                        fontSize = 20.sp
                    )
                }

                IconButton(onClick = { PlayerManager.toggleQueue() }) {
                    Text(
                        text = "☰",
                        color = if (isQueueOpen) palette.primary else Color.White.copy(alpha = 0.6f),
                        fontSize = 22.sp
                    )
                }

                IconButton(onClick = { PlayerManager.toggleEqualizer() }) {
                    Text(
                        text = "🎚",
                        color = if (isEqualizerOpen) palette.primary else Color.White.copy(alpha = 0.6f),
                        fontSize = 20.sp
                    )
                }
            }
        }
    }
}
