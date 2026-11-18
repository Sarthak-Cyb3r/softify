package com.softify.app.ui.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.AddToPlaylistBottomSheet
import com.softify.app.ui.components.AsyncCoverArt
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.Shelf
import uniffi.softify_core.Track

@Composable
fun HomeScreen(
    viewModel: PlaybackViewModel,
    onOpenSettings: () -> Unit,
    onOpenArtist: (String) -> Unit = {},
    onOpenAlbum: (String, String) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier
) {
    val shelves by viewModel.homeShelves.collectAsState()
    val quickPicks by viewModel.quickPicks.collectAsState()
    val isLoading by viewModel.isHomeLoading.collectAsState()
    val errorMessage by viewModel.homeError.collectAsState()
    val playlists by viewModel.playlists.collectAsState()

    var trackForPlaylistSheet by remember { mutableStateOf<Track?>(null) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        // Top App Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Softify",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.ExtraBold,
                    color = MaterialTheme.colorScheme.onBackground
                )
                Text(
                    text = "320 kbps Studio Fidelity",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium
                )
            }

            IconButton(
                onClick = onOpenSettings,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Settings,
                    contentDescription = "Settings",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Body Content
        when {
            isLoading && shelves.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(40.dp)
                    )
                }
            }

            errorMessage != null && shelves.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Could not load recommendations",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = errorMessage ?: "",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Button(
                            onClick = { viewModel.loadHomeExplore() },
                            shape = SquircleShape(12.dp)
                        ) {
                            Text("Retry")
                        }
                    }
                }
            }

            shelves.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "No music discovered yet",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Button(
                            onClick = { viewModel.loadHomeExplore() },
                            shape = SquircleShape(12.dp)
                        ) {
                            Text("Explore Charts")
                        }
                    }
                }
            }

            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 120.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    if (quickPicks.isNotEmpty()) {
                        item(key = "quick_picks_shelf") {
                            HomeShelfSection(
                                shelf = Shelf(
                                    id = "quick_picks",
                                    title = "Quick picks",
                                    subtitle = "Based on your taste & listening history",
                                    rule = "quick_picks",
                                    tracks = quickPicks
                                ),
                                onTrackClick = { track, _ ->
                                    viewModel.playTrack(track)
                                },
                                onStartRadio = { track -> viewModel.startRadio(track) },
                                onPlayNext = { track -> viewModel.playNext(track) },
                                onAddToQueue = { track -> viewModel.addToQueue(track) },
                                onAddToPlaylist = { track -> trackForPlaylistSheet = track },
                                onToggleLike = { track -> viewModel.toggleLikeTrack(track) },
                                onOpenArtist = onOpenArtist,
                                onOpenAlbum = onOpenAlbum
                            )
                        }
                    }

                    items(shelves) { shelf ->
                        HomeShelfSection(
                            shelf = shelf,
                            onTrackClick = { track, index ->
                                viewModel.playTrackInQueue(shelf.tracks, index)
                            },
                            onStartRadio = { track -> viewModel.startRadio(track) },
                            onPlayNext = { track -> viewModel.playNext(track) },
                            onAddToQueue = { track -> viewModel.addToQueue(track) },
                            onAddToPlaylist = { track -> trackForPlaylistSheet = track },
                            onToggleLike = { track -> viewModel.toggleLikeTrack(track) },
                            onOpenArtist = onOpenArtist,
                            onOpenAlbum = onOpenAlbum
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
            onPlaylistSelected = { playlist ->
                viewModel.addTrackToPlaylist(playlist.id, targetTrack)
            },
            onCreateNewPlaylist = { name ->
                viewModel.createNewPlaylist(name)
            }
        )
    }
}

@Composable
fun HomeShelfSection(
    shelf: Shelf,
    onTrackClick: (Track, Int) -> Unit,
    onPlayNext: (Track) -> Unit,
    onAddToQueue: (Track) -> Unit,
    onStartRadio: (Track) -> Unit = {},
    onAddToPlaylist: (Track) -> Unit,
    onToggleLike: (Track) -> Unit,
    onOpenArtist: (String) -> Unit = {},
    onOpenAlbum: (String, String) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier
) {
    if (shelf.tracks.isEmpty()) return

    Column(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(horizontal = 20.dp)) {
            Text(
                text = shelf.title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            if (shelf.subtitle.isNotEmpty()) {
                Text(
                    text = shelf.subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        LazyRow(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            itemsIndexed(shelf.tracks) { index, track ->
                HomeTrackCard(
                    track = track,
                    onClick = { onTrackClick(track, index) },
                    onStartRadio = { onStartRadio(track) },
                    onPlayNext = { onPlayNext(track) },
                    onAddToQueue = { onAddToQueue(track) },
                    onAddToPlaylist = { onAddToPlaylist(track) },
                    onToggleLike = { onToggleLike(track) },
                    onOpenArtist = { onOpenArtist(track.artist) },
                    onOpenAlbum = { if (!track.album.isNullOrEmpty()) onOpenAlbum(track.album!!, track.artist) }
                )
            }
        }
    }
}

@Composable
fun HomeTrackCard(
    track: Track,
    onClick: () -> Unit,
    onPlayNext: () -> Unit,
    onAddToQueue: () -> Unit,
    onStartRadio: () -> Unit = {},
    onAddToPlaylist: () -> Unit,
    onToggleLike: () -> Unit,
    onOpenArtist: () -> Unit = {},
    onOpenAlbum: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    var menuExpanded by remember { mutableStateOf(false) }

    Card(
        modifier = modifier
            .width(148.dp)
            .clickable(onClick = onClick),
        shape = SquircleShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer
        )
    ) {
        Column(modifier = Modifier.padding(8.dp)) {
            Box(modifier = Modifier.size(132.dp)) {
                AsyncCoverArt(
                    url = track.coverUrl,
                    modifier = Modifier.fillMaxSize(),
                    shape = SquircleShape(12.dp)
                )

                // Quick overflow menu button overlaid at top-end
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                ) {
                    IconButton(
                        onClick = { menuExpanded = true },
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.MoreVert,
                            contentDescription = "Options",
                            tint = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.size(18.dp)
                        )
                    }

                    DropdownMenu(
                        expanded = menuExpanded,
                        onDismissRequest = { menuExpanded = false },
                        shape = SquircleShape(12.dp),
                        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
                    ) {
                        DropdownMenuItem(
                            text = { Text("Start radio") },
                            leadingIcon = {
                                Icon(Icons.Filled.Radio, contentDescription = null, modifier = Modifier.size(20.dp))
                            },
                            onClick = {
                                menuExpanded = false
                                onStartRadio()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Play next") },
                            leadingIcon = {
                                Icon(Icons.Filled.PlaylistPlay, contentDescription = null, modifier = Modifier.size(20.dp))
                            },
                            onClick = {
                                menuExpanded = false
                                onPlayNext()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Add to queue") },
                            leadingIcon = {
                                Icon(Icons.Filled.QueueMusic, contentDescription = null, modifier = Modifier.size(20.dp))
                            },
                            onClick = {
                                menuExpanded = false
                                onAddToQueue()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Add to playlist") },
                            leadingIcon = {
                                Icon(Icons.Filled.PlaylistAdd, contentDescription = null, modifier = Modifier.size(20.dp))
                            },
                            onClick = {
                                menuExpanded = false
                                onAddToPlaylist()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text(if (track.isLiked) "Unlike" else "Like") },
                            leadingIcon = {
                                Icon(
                                    imageVector = if (track.isLiked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                                    contentDescription = null,
                                    tint = if (track.isLiked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(20.dp)
                                )
                            },
                            onClick = {
                                menuExpanded = false
                                onToggleLike()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Go to artist") },
                            leadingIcon = {
                                Icon(Icons.Filled.Person, contentDescription = null, modifier = Modifier.size(20.dp))
                            },
                            onClick = {
                                menuExpanded = false
                                onOpenArtist()
                            }
                        )
                        if (!track.album.isNullOrEmpty()) {
                            DropdownMenuItem(
                                text = { Text("Go to album") },
                                leadingIcon = {
                                    Icon(Icons.Filled.Album, contentDescription = null, modifier = Modifier.size(20.dp))
                                },
                                onClick = {
                                    menuExpanded = false
                                    onOpenAlbum()
                                }
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = track.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            Text(
                text = track.artist,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
