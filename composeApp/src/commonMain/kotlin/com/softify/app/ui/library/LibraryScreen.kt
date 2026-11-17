package com.softify.app.ui.library

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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

enum class LibraryFilter {
    PLAYLISTS,
    LIKED_SONGS,
    HISTORY
}

@Composable
fun LibraryScreen(
    viewModel: PlaybackViewModel,
    onOpenPlaylistDetail: (Playlist) -> Unit,
    onOpenSmartPlaylist: (title: String, tracks: List<Track>) -> Unit,
    modifier: Modifier = Modifier
) {
    val playlists by viewModel.playlists.collectAsState()
    val likedTracks by viewModel.likedTracks.collectAsState()
    val history by viewModel.history.collectAsState()
    val activeTrack by viewModel.activeTrack.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()

    val smartOnRepeat by viewModel.smartOnRepeat.collectAsState()
    val smartMostPlayed by viewModel.smartMostPlayed.collectAsState()
    val smartForgotten by viewModel.smartForgottenFavorites.collectAsState()

    var selectedFilter by remember { mutableStateOf(LibraryFilter.PLAYLISTS) }
    var showNewPlaylistDialog by remember { mutableStateOf(false) }
    var showSpotifyImportDialog by remember { mutableStateOf(false) }
    var playlistToRename by remember { mutableStateOf<Playlist?>(null) }
    var playlistToDelete by remember { mutableStateOf<Playlist?>(null) }
    var trackForPlaylistSheet by remember { mutableStateOf<Track?>(null) }

    var newPlaylistName by remember { mutableStateOf("") }
    var renamePlaylistName by remember { mutableStateOf("") }
    var spotifyImportUrl by remember { mutableStateOf("") }

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        // Library Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Your Library",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.ExtraBold,
                color = MaterialTheme.colorScheme.onBackground
            )

            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                IconButton(
                    onClick = { showSpotifyImportDialog = true },
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.CloudDownload,
                        contentDescription = "Import Spotify",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                IconButton(
                    onClick = { showNewPlaylistDialog = true },
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Add,
                        contentDescription = "New playlist",
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }

        // Smart Playlists Section (Horizontal Cards)
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "Smart Playlists",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
            )

            LazyRow(
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    SmartPlaylistCard(
                        title = "On Repeat",
                        subtitle = "${smartOnRepeat.size} tracks",
                        icon = Icons.Filled.Repeat,
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                        onClick = { onOpenSmartPlaylist("On Repeat", smartOnRepeat) }
                    )
                }

                item {
                    SmartPlaylistCard(
                        title = "Most Played",
                        subtitle = "${smartMostPlayed.size} tracks",
                        icon = Icons.Filled.TrendingUp,
                        containerColor = MaterialTheme.colorScheme.secondaryContainer,
                        contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
                        onClick = { onOpenSmartPlaylist("Most Played", smartMostPlayed) }
                    )
                }

                item {
                    SmartPlaylistCard(
                        title = "Forgotten Favorites",
                        subtitle = "${smartForgotten.size} tracks",
                        icon = Icons.Filled.FavoriteBorder,
                        containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                        contentColor = MaterialTheme.colorScheme.onTertiaryContainer,
                        onClick = { onOpenSmartPlaylist("Forgotten Favorites", smartForgotten) }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // Filter Chips Row (Downloads chip is intentionally HIDDEN per user instruction)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = selectedFilter == LibraryFilter.PLAYLISTS,
                onClick = { selectedFilter = LibraryFilter.PLAYLISTS },
                label = { Text("Playlists (${playlists.size})") },
                shape = SquircleShape(12.dp)
            )

            FilterChip(
                selected = selectedFilter == LibraryFilter.LIKED_SONGS,
                onClick = { selectedFilter = LibraryFilter.LIKED_SONGS },
                label = { Text("Liked Songs (${likedTracks.size})") },
                shape = SquircleShape(12.dp)
            )

            FilterChip(
                selected = selectedFilter == LibraryFilter.HISTORY,
                onClick = { selectedFilter = LibraryFilter.HISTORY },
                label = { Text("History") },
                shape = SquircleShape(12.dp)
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Tab Content
        when (selectedFilter) {
            LibraryFilter.PLAYLISTS -> {
                if (playlists.isEmpty()) {
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
                                text = "No playlists created yet",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Button(
                                onClick = { showNewPlaylistDialog = true },
                                shape = SquircleShape(12.dp)
                            ) {
                                Text("Create Playlist")
                            }
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 120.dp)
                    ) {
                        items(playlists) { playlist ->
                            PlaylistRowItem(
                                playlist = playlist,
                                onClick = { onOpenPlaylistDetail(playlist) },
                                onRename = {
                                    playlistToRename = playlist
                                    renamePlaylistName = playlist.name
                                },
                                onDelete = { playlistToDelete = playlist }
                            )
                        }
                    }
                }
            }

            LibraryFilter.LIKED_SONGS -> {
                if (likedTracks.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No liked tracks yet",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 120.dp)
                    ) {
                        itemsIndexed(likedTracks) { index, track ->
                            TrackItemRow(
                                track = track,
                                isActive = activeTrack?.id == track.id,
                                isPlaying = isPlaying,
                                onClick = { viewModel.playTrackInQueue(likedTracks, index) },
                                onPlayNext = { viewModel.playNext(track) },
                                onAddToQueue = { viewModel.addToQueue(track) },
                                onAddToPlaylist = { trackForPlaylistSheet = track },
                                onToggleLike = { viewModel.toggleLikeTrack(track) }
                            )
                        }
                    }
                }
            }

            LibraryFilter.HISTORY -> {
                if (history.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No listening history recorded",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    Column(modifier = Modifier.fillMaxSize()) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 20.dp, vertical = 6.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Recently played",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            TextButton(
                                onClick = { viewModel.clearListeningHistory() },
                                modifier = Modifier.height(36.dp)
                            ) {
                                Text("Clear history", style = MaterialTheme.typography.labelSmall)
                            }
                        }

                        val historyTracks = remember(history) {
                            history.mapNotNull { it.track }
                        }

                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(bottom = 120.dp)
                        ) {
                            itemsIndexed(historyTracks) { index, track ->
                                TrackItemRow(
                                    track = track,
                                    isActive = activeTrack?.id == track.id,
                                    isPlaying = isPlaying,
                                    onClick = { viewModel.playTrackInQueue(historyTracks, index) },
                                    onPlayNext = { viewModel.playNext(track) },
                                    onAddToQueue = { viewModel.addToQueue(track) },
                                    onAddToPlaylist = { trackForPlaylistSheet = track },
                                    onToggleLike = { viewModel.toggleLikeTrack(track) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Dialogs
    if (showNewPlaylistDialog) {
        AlertDialog(
            onDismissRequest = { showNewPlaylistDialog = false },
            title = { Text("New playlist") },
            text = {
                OutlinedTextField(
                    value = newPlaylistName,
                    onValueChange = { newPlaylistName = it },
                    label = { Text("Playlist name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        val trimmed = newPlaylistName.trim()
                        if (trimmed.isNotEmpty()) {
                            viewModel.createNewPlaylist(trimmed)
                            newPlaylistName = ""
                            showNewPlaylistDialog = false
                        }
                    }
                ) {
                    Text("Create")
                }
            },
            dismissButton = {
                TextButton(onClick = { showNewPlaylistDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    playlistToRename?.let { targetPlaylist ->
        AlertDialog(
            onDismissRequest = { playlistToRename = null },
            title = { Text("Rename playlist") },
            text = {
                OutlinedTextField(
                    value = renamePlaylistName,
                    onValueChange = { renamePlaylistName = it },
                    label = { Text("New name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        val trimmed = renamePlaylistName.trim()
                        if (trimmed.isNotEmpty()) {
                            viewModel.renameUserPlaylist(targetPlaylist.id, trimmed)
                            playlistToRename = null
                        }
                    }
                ) {
                    Text("Rename")
                }
            },
            dismissButton = {
                TextButton(onClick = { playlistToRename = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    playlistToDelete?.let { targetPlaylist ->
        AlertDialog(
            onDismissRequest = { playlistToDelete = null },
            title = { Text("Delete playlist?") },
            text = { Text("Are you sure you want to delete '${targetPlaylist.name}'?") },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.deleteUserPlaylist(targetPlaylist.id)
                        playlistToDelete = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { playlistToDelete = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (showSpotifyImportDialog) {
        AlertDialog(
            onDismissRequest = { showSpotifyImportDialog = false },
            title = { Text("Import Spotify Playlist") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "Paste a public Spotify playlist URL or ID (keyless import)",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(
                        value = spotifyImportUrl,
                        onValueChange = { spotifyImportUrl = it },
                        label = { Text("Spotify URL / ID") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val trimmed = spotifyImportUrl.trim()
                        if (trimmed.isNotEmpty()) {
                            viewModel.importSpotify(trimmed)
                            spotifyImportUrl = ""
                            showSpotifyImportDialog = false
                        }
                    }
                ) {
                    Text("Import")
                }
            },
            dismissButton = {
                TextButton(onClick = { showSpotifyImportDialog = false }) {
                    Text("Cancel")
                }
            }
        )
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
fun SmartPlaylistCard(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    containerColor: Color,
    contentColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .width(148.dp)
            .clickable(onClick = onClick),
        shape = SquircleShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = containerColor)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(26.dp)
            )

            Column {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = contentColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = contentColor.copy(alpha = 0.8f)
                )
            }
        }
    }
}

@Composable
fun PlaylistRowItem(
    playlist: Playlist,
    onClick: () -> Unit,
    onRename: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    var menuExpanded by remember { mutableStateOf(false) }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            shape = SquircleShape(12.dp),
            color = MaterialTheme.colorScheme.surfaceContainerHighest,
            modifier = Modifier.size(48.dp)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = Icons.Filled.QueueMusic,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
            }
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = playlist.name,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = "${playlist.trackCount} tracks",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Box {
            IconButton(
                onClick = { menuExpanded = true },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.MoreVert,
                    contentDescription = "Playlist menu",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
            }

            DropdownMenu(
                expanded = menuExpanded,
                onDismissRequest = { menuExpanded = false },
                shape = SquircleShape(12.dp),
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            ) {
                DropdownMenuItem(
                    text = { Text("Rename") },
                    leadingIcon = {
                        Icon(Icons.Filled.Edit, contentDescription = null, modifier = Modifier.size(20.dp))
                    },
                    onClick = {
                        menuExpanded = false
                        onRename()
                    }
                )

                DropdownMenuItem(
                    text = { Text("Delete", color = MaterialTheme.colorScheme.error) },
                    leadingIcon = {
                        Icon(Icons.Filled.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(20.dp))
                    },
                    onClick = {
                        menuExpanded = false
                        onDelete()
                    }
                )
            }
        }
    }
}
