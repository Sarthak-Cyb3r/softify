package com.softify.app.ui.details

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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.AsyncCoverArt
import com.softify.app.ui.components.TrackItemRow
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.Track

@Composable
fun ArtistDetailScreen(
    artist: String,
    viewModel: PlaybackViewModel,
    onBack: () -> Unit,
    onOpenAlbum: (String, String) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier
) {
    var tracks by remember { mutableStateOf<List<Track>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    val activeTrack by viewModel.activeTrack.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()

    LaunchedEffect(artist) {
        isLoading = true
        tracks = viewModel.fetchArtistTracks(artist)
        isLoading = false
    }

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
            Text(
                text = "Artist",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Hero Card
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
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    val firstCover = tracks.firstOrNull { !it.coverUrl.isNullOrEmpty() }?.coverUrl
                    if (!firstCover.isNullOrEmpty()) {
                        AsyncCoverArt(
                            url = firstCover,
                            contentDescription = artist,
                            modifier = Modifier
                                .size(80.dp)
                                .clip(SquircleShape(16.dp))
                        )
                    } else {
                        Surface(
                            shape = SquircleShape(16.dp),
                            color = MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.size(80.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(
                                    text = artist.take(1).uppercase(),
                                    style = MaterialTheme.typography.headlineLarge,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                            }
                        }
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = artist,
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            softWrap = false,
                            overflow = TextOverflow.Ellipsis
                        )

                        Text(
                            text = "${tracks.size} tracks available",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(
                                onClick = {
                                    if (tracks.isNotEmpty()) {
                                        viewModel.playTrackInQueue(tracks, 0)
                                    }
                                },
                                enabled = tracks.isNotEmpty(),
                                shape = SquircleShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.PlayArrow,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Play", fontSize = 13.sp)
                            }

                            OutlinedButton(
                                onClick = {
                                    if (tracks.isNotEmpty()) {
                                        viewModel.playTrackInQueue(tracks.shuffled(), 0)
                                    }
                                },
                                enabled = tracks.isNotEmpty(),
                                shape = SquircleShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.Shuffle,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Shuffle", fontSize = 13.sp)
                            }
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Tracks List
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (tracks.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No tracks found for $artist",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 120.dp)
            ) {
                itemsIndexed(tracks) { index, track ->
                    TrackItemRow(
                        track = track,
                        isActive = activeTrack?.id == track.id,
                        isPlaying = isPlaying,
                        onClick = { viewModel.playTrackInQueue(tracks, index) },
                        onPlayNext = { viewModel.playNext(track) },
                        onAddToQueue = { viewModel.addToQueue(track) },
                        onToggleLike = { viewModel.toggleLikeTrack(track) },
                        onOpenArtist = { /* Already on artist screen */ },
                        onOpenAlbum = { albumName -> onOpenAlbum(albumName, track.artist) }
                    )
                }
            }
        }
    }
}
