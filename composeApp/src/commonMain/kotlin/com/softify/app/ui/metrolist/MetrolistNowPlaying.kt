package com.softify.app.ui.metrolist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.playback.RepeatMode
import com.softify.app.ui.components.*
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track

@Composable
fun MetrolistNowPlaying(
    viewModel: PlaybackViewModel,
    onCollapse: () -> Unit,
    onOpenDiagnostics: () -> Unit = {},
    onOpenArtist: (String) -> Unit = {},
    onOpenAlbum: (String, String) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier
) {
    val track by viewModel.activeTrack.collectAsState()
    val streamInfo by viewModel.activeStream.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()
    val playbackProgress by viewModel.playbackProgress.collectAsState()
    val currentPositionMs by viewModel.currentPositionMs.collectAsState()
    val durationMs by viewModel.durationMs.collectAsState()
    val queueState by viewModel.queueState.collectAsState()
    val lyrics by viewModel.lyrics.collectAsState()
    val isLyricsLoading by viewModel.isLyricsLoading.collectAsState()
    val showLyricsInPlayer by viewModel.showLyricsInPlayer.collectAsState()

    if (track == null) return

    val currentTrack = track!!
    val effectiveDurationMs = if (durationMs > 0L) durationMs else currentTrack.durationMs.toLong()
    val effectivePositionMs = (playbackProgress * effectiveDurationMs).toLong()

    // Swipe down to collapse detection
    var dragAccumulator by remember { mutableStateOf(0f) }
    val dragModifier = Modifier.draggable(
        state = rememberDraggableState { delta ->
            dragAccumulator += delta
            if (dragAccumulator > 60f) {
                onCollapse()
                dragAccumulator = 0f
            }
        },
        orientation = Orientation.Vertical,
        onDragStopped = { dragAccumulator = 0f }
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
            .then(dragModifier)
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 24.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // 1. Top Bar: Collapse chevron, title, lyrics toggle, diagnostics
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = onCollapse,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.KeyboardArrowDown,
                    contentDescription = "Collapse",
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(30.dp)
                )
            }

            Text(
                text = "NOW PLAYING",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.2.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(
                    onClick = { viewModel.toggleLyricsView() },
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Lyrics,
                        contentDescription = "Lyrics",
                        tint = if (showLyricsInPlayer) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(22.dp)
                    )
                }

                IconButton(
                    onClick = onOpenDiagnostics,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.BugReport,
                        contentDescription = "Diagnostics",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        // 2. Center Content: Large Squircle Artwork OR Synced Lyrics
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            contentAlignment = Alignment.Center
        ) {
            if (showLyricsInPlayer) {
                // Synced Lyrics View with shine effect & tap to seek
                if (isLyricsLoading) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                    }
                } else {
                    val lyricLines = remember(lyrics) {
                        lyrics?.lines?.map { l ->
                            LyricLine(timeMs = l.timestampMs.toLong(), text = l.text)
                        } ?: emptyList()
                    }

                    LyricsView(
                        lines = lyricLines,
                        currentPositionMs = effectivePositionMs,
                        isSynced = lyrics?.isSynced ?: false,
                        onSeekTo = { seekMs -> viewModel.seekTo(seekMs) },
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 40.dp, horizontal = 12.dp)
                    )
                }
            } else {
                // Standard Large Squircle Artwork View
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    AsyncCoverArt(
                        coverUrl = currentTrack.coverUrl,
                        contentDescription = currentTrack.title,
                        modifier = Modifier
                            .size(280.dp)
                            .clip(SquircleShape(32.dp))
                    )

                    Spacer(modifier = Modifier.height(24.dp))

                    // Track Metadata & Navigation to Artist/Album
                    Text(
                        text = currentTrack.title,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onSurface,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        softWrap = false,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth(0.9f)
                    )

                    Spacer(modifier = Modifier.height(4.dp))

                    Text(
                        text = currentTrack.artist,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        softWrap = false,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .clickable { onOpenArtist(currentTrack.artist) }
                            .padding(vertical = 2.dp, horizontal = 8.dp)
                    )

                    if (!currentTrack.album.isNullOrEmpty()) {
                        Text(
                            text = currentTrack.album!!,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                            softWrap = false,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier
                                .clickable { onOpenAlbum(currentTrack.album!!, currentTrack.artist) }
                                .padding(vertical = 2.dp, horizontal = 8.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Minimal Bitrate Badge
                    BitrateBadge(streamInfo = streamInfo)
                }
            }
        }

        // 3. Progress Section with Squiggly Waveform Slider & Timestamps
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SquigglySlider(
                value = playbackProgress,
                onValueChange = { frac ->
                    val seekMs = (frac * effectiveDurationMs).toLong()
                    viewModel.seekTo(seekMs)
                },
                isPlaying = isPlaying,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(32.dp)
            )

            // Timestamps: Elapsed & Remaining
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                val elapsedSec = (effectivePositionMs / 1000L).coerceAtLeast(0L)
                val remainingSec = ((effectiveDurationMs - effectivePositionMs) / 1000L).coerceAtLeast(0L)

                Text(
                    text = "${elapsedSec / 60}:${(elapsedSec % 60).toString().padStart(2, '0')}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(
                    text = "-${remainingSec / 60}:${(remainingSec % 60).toString().padStart(2, '0')}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // 4. Transport Controls Dock: Shuffle, Prev, Play/Pause, Next, Repeat
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Shuffle Button
            IconButton(
                onClick = { viewModel.toggleShuffle() },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Shuffle,
                    contentDescription = "Shuffle",
                    tint = if (queueState.isShuffle) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp)
                )
            }

            // Skip Previous
            IconButton(
                onClick = { viewModel.skipPrevious() },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.SkipPrevious,
                    contentDescription = "Previous track",
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(32.dp)
                )
            }

            // Hero Play/Pause Button
            Surface(
                shape = SquircleShape(20.dp),
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .size(68.dp)
                    .clip(SquircleShape(20.dp))
                    .clickable { viewModel.togglePlayPause() }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = if (isPlaying) "Pause" else "Play",
                        tint = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.size(36.dp)
                    )
                }
            }

            // Skip Next
            IconButton(
                onClick = { viewModel.skipNext() },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.SkipNext,
                    contentDescription = "Next track",
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(32.dp)
                )
            }

            // Repeat Button (OFF, ALL, ONE)
            IconButton(
                onClick = { viewModel.toggleRepeat() },
                modifier = Modifier.size(48.dp)
            ) {
                val repeatIcon = if (queueState.repeatMode == RepeatMode.ONE) Icons.Filled.RepeatOne else Icons.Filled.Repeat
                val repeatTint = if (queueState.repeatMode != RepeatMode.OFF) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                Icon(
                    imageVector = repeatIcon,
                    contentDescription = "Repeat",
                    tint = repeatTint,
                    modifier = Modifier.size(24.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // 5. Bottom Secondary Bar: Like Button, Lyrics preview/switch, Queue sheet trigger
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = { viewModel.toggleLikeTrack(currentTrack) },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = if (currentTrack.isLiked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = "Favorite",
                    tint = if (currentTrack.isLiked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp)
                )
            }

            Surface(
                shape = SquircleShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHighest,
                modifier = Modifier.clickable { viewModel.toggleLyricsView() }
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Notes,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = if (showLyricsInPlayer) "Show Cover" else "Lyrics",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            IconButton(
                onClick = { viewModel.openQueueSheet() },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.QueueMusic,
                    contentDescription = "Open queue",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
    }
}
