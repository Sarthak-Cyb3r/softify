package com.softify.app.ui.search

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.AddToPlaylistBottomSheet
import com.softify.app.ui.components.TrackItemRow
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.SearchIntent
import uniffi.softify_core.Track

@Composable
fun SearchScreen(
    viewModel: PlaybackViewModel,
    onOpenArtist: (String) -> Unit = {},
    onOpenAlbum: (String, String) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier
) {
    val query by viewModel.searchQuery.collectAsState()
    val localResults by viewModel.localSearchResults.collectAsState()
    val onlineResults by viewModel.onlineSearchResults.collectAsState()
    val recentSearches by viewModel.recentSearches.collectAsState()
    val detectedIntent by viewModel.detectedIntent.collectAsState()
    val detectedEntity by viewModel.detectedEntity.collectAsState()
    val isSearching by viewModel.isSearching.collectAsState()
    val activeTrack by viewModel.activeTrack.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()
    val playlists by viewModel.playlists.collectAsState()

    var trackForPlaylistSheet by remember { mutableStateOf<Track?>(null) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        // Search Input Bar
        OutlinedTextField(
            value = query,
            onValueChange = { viewModel.onSearchQueryChanged(it) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            placeholder = { Text("Search songs, artists, albums...") },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Filled.Search,
                    contentDescription = "Search",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            },
            trailingIcon = {
                if (query.isNotEmpty()) {
                    IconButton(
                        onClick = { viewModel.onSearchQueryChanged("") },
                        modifier = Modifier.size(48.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = "Clear search",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            },
            shape = SquircleShape(16.dp),
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                focusedBorderColor = MaterialTheme.colorScheme.primary,
                unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
            )
        )

        // Loading bar
        if (isSearching) {
            LinearProgressIndicator(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(2.dp),
                color = MaterialTheme.colorScheme.primary
            )
        }

        // Search Intent Badge (if detected)
        if (query.isNotEmpty() && detectedIntent != SearchIntent.GENERAL) {
            val intentLabel = when (detectedIntent) {
                SearchIntent.ARTIST -> "Artist intent: ${detectedEntity ?: query}"
                SearchIntent.ALBUM -> "Album intent: ${detectedEntity ?: query}"
                SearchIntent.TRACK -> "Track intent: ${detectedEntity ?: query}"
                else -> ""
            }
            if (intentLabel.isNotEmpty()) {
                Surface(
                    shape = SquircleShape(12.dp),
                    color = MaterialTheme.colorScheme.primaryContainer,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = intentLabel,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }
            }
        }

        // Body: Recent Searches vs Search Results
        if (query.trim().isEmpty()) {
            // Recent Searches Section
            if (recentSearches.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Search,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(56.dp)
                        )
                        Text(
                            text = "Find your favorite music",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "Type an artist, song title, or album",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                        )
                    }
                }
            } else {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Recent Searches",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        TextButton(
                            onClick = { viewModel.clearAllRecentSearches() },
                            modifier = Modifier.height(36.dp)
                        ) {
                            Text("Clear all", style = MaterialTheme.typography.labelMedium)
                        }
                    }

                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 120.dp)
                    ) {
                        items(recentSearches) { recentQuery ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { viewModel.onSearchQueryChanged(recentQuery) }
                                    .padding(horizontal = 20.dp, vertical = 10.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Icon(
                                        imageVector = Icons.Filled.History,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(modifier = Modifier.width(14.dp))
                                    Text(
                                        text = recentQuery,
                                        style = MaterialTheme.typography.bodyLarge,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                }

                                IconButton(
                                    onClick = { viewModel.deleteRecentSearchItem(recentQuery) },
                                    modifier = Modifier.size(48.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Filled.Close,
                                        contentDescription = "Remove",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Search Results
            val allMerged = remember(localResults, onlineResults) {
                val list = mutableListOf<Track>()
                list.addAll(localResults)
                for (onl in onlineResults) {
                    if (list.none { it.id == onl.id }) {
                        list.add(onl)
                    }
                }
                list
            }

            if (!isSearching && allMerged.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No results found for '$query'",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 120.dp)
                ) {
                    if (localResults.isNotEmpty()) {
                        item {
                            Text(
                                text = "In Your Library",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                            )
                        }
                    }

                    itemsIndexed(allMerged) { index, track ->
                        TrackItemRow(
                            track = track,
                            isActive = activeTrack?.id == track.id,
                            isPlaying = isPlaying,
                            onClick = {
                                // M3d: Tapping a track anywhere builds queue from YTM radio
                                viewModel.playTrack(track)
                            },
                            onStartRadio = { viewModel.startRadio(track) },
                            onPlayNext = { viewModel.playNext(track) },
                            onAddToQueue = { viewModel.addToQueue(track) },
                            onAddToPlaylist = { trackForPlaylistSheet = track },
                            onToggleLike = { viewModel.toggleLikeTrack(track) },
                            onOpenArtist = { onOpenArtist(track.artist) },
                            onOpenAlbum = { albumName -> onOpenAlbum(albumName, track.artist) }
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
