package com.softify.app.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.AddToPlaylistBottomSheet
import com.softify.app.ui.components.TrackItemRow
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.Playlist
import uniffi.softify_core.Track
import uniffi.softify_core.getPlaylistTracks

@Composable
fun PlaylistDetailScreen(
    playlist: Playlist?,
    smartTitle: String? = null,
    smartTracks: List<Track>? = null,
    viewModel: PlaybackViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val activeTrack by viewModel.activeTrack.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()
    val playlists by viewModel.playlists.collectAsState()

    var tracks by remember(playlist, smartTracks) {
        mutableStateOf(smartTracks ?: emptyList())
    }
    var isLoading by remember { mutableStateOf(playlist != null && smartTracks == null) }
    var trackForPlaylistSheet by remember { mutableStateOf<Track?>(null) }

    val title = smartTitle ?: playlist?.name ?: "Playlist"

    LaunchedEffect(playlist) {
        if (playlist != null && smartTracks == null) {
            isLoading = true
            try {
                tracks = getPlaylistTracks(playlist.id)
            } catch (_: Exception) {}
            isLoading = false
        }
    }

    val totalDurationMs = remember(tracks) {
        tracks.sumOf { it.durationMs.toLong() }
    }
    val totalMinutes = totalDurationMs / 60000L

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        // Top Navigation Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = onBack,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = MaterialTheme.colorScheme.onSurface
                )
            }
        }

        // Header Card with Gradient
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            shape = SquircleShape(20.dp),
            color = MaterialTheme.colorScheme.surfaceContainerHigh
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.25f),
                                MaterialTheme.colorScheme.surfaceContainerHigh
                            )
                        )
                    )
                    .padding(20.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )

                    Text(
                        text = "${tracks.size} tracks • $totalMinutes mins",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = {
                                if (tracks.isNotEmpty()) {
                                    viewModel.playTrackInQueue(tracks, 0)
                                }
                            },
                            enabled = tracks.isNotEmpty(),
                            shape = SquircleShape(12.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.PlayArrow,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Play")
                        }

                        OutlinedButton(
                            onClick = {
                                if (tracks.isNotEmpty()) {
                                    val shuffled = tracks.shuffled()
                                    viewModel.playTrackInQueue(shuffled, 0)
                                }
                            },
                            enabled = tracks.isNotEmpty(),
                            shape = SquircleShape(12.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Shuffle,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Shuffle")
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Tracks List
        when {
            isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(36.dp)
                    )
                }
            }

            tracks.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No tracks in this playlist yet",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 120.dp)
                ) {
                    itemsIndexed(tracks) { index, track ->
                        TrackItemRow(
                            track = track,
                            isActive = activeTrack?.id == track.id,
                            isPlaying = isPlaying,
                            trackNumber = index + 1,
                            onClick = { viewModel.playTrackInQueue(tracks, index) },
                            onPlayNext = { viewModel.playNext(track) },
                            onAddToQueue = { viewModel.addToQueue(track) },
                            onAddToPlaylist = { trackForPlaylistSheet = track },
                            onToggleLike = { viewModel.toggleLikeTrack(track) },
                            onRemoveFromPlaylist = if (playlist != null) {
                                {
                                    viewModel.removeTrackFromPlaylist(playlist.id, track.id)
                                    tracks = tracks.filter { it.id != track.id }
                                }
                            } else null
                        )
                    }
                }
            }
        }
    }

    trackForPlaylistSheet?.let { targetTrack ->
        AddToPlaylistBottomSheet(
            track = targetTrack,
            playlists = playlists,
            onDismissRequest = { trackForPlaylistSheet = null },
            onPlaylistSelected = { pl ->
                viewModel.addTrackToPlaylist(pl.id, targetTrack)
            },
            onCreateNewPlaylist = { name ->
                viewModel.createNewPlaylist(name)
            }
        )
    }
}
