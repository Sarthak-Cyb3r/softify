package com.softify.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.apple.AppleMusicNowPlaying
import com.softify.app.ui.components.QualityBadge
import com.softify.app.ui.diagnostics.DiagnosticsScreen
import com.softify.app.ui.metrolist.MetrolistNowPlaying
import com.softify.app.viewmodel.NavigationTab
import com.softify.app.viewmodel.PlaybackViewModel
import com.softify.app.viewmodel.UiStyle
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.SearchIntent
import uniffi.softify_core.Track

@Composable
fun App(viewModel: PlaybackViewModel = remember { PlaybackViewModel() }) {
    val currentTab by viewModel.currentTab.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val localSearchResults by viewModel.localSearchResults.collectAsState()
    val onlineSearchResults by viewModel.onlineSearchResults.collectAsState()
    val detectedIntent by viewModel.detectedIntent.collectAsState()
    val detectedEntity by viewModel.detectedEntity.collectAsState()
    val isSearching by viewModel.isSearching.collectAsState()
    val activeTrack by viewModel.activeTrack.collectAsState()
    val activeStream by viewModel.activeStream.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()
    val qualityPreset by viewModel.qualityPreset.collectAsState()
    val uiStyle by viewModel.uiStyle.collectAsState()

    val likedTracks by viewModel.likedTracks.collectAsState()
    val playlists by viewModel.playlists.collectAsState()
    val history by viewModel.history.collectAsState()

    var showNowPlaying by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var showDiagnostics by remember { mutableStateOf(false) }
    var showNewPlaylistDialog by remember { mutableStateOf(false) }
    var newPlaylistName by remember { mutableStateOf("") }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.snackbarEvents.collect { message ->
            snackbarHostState.showSnackbar(message)
        }
    }

    MaterialTheme(
        colorScheme = darkColorScheme(
            background = Color(0xFF0F0E17),
            surface = Color(0xFF1E1B2E),
            onBackground = Color.White,
            onSurface = Color.White
        )
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                if (showDiagnostics) {
                    DiagnosticsScreen(
                        viewModel = viewModel,
                        onClose = { showDiagnostics = false }
                    )
                } else if (showNowPlaying && activeTrack != null) {
                    Box(modifier = Modifier.fillMaxSize()) {
                        when (uiStyle) {
                            UiStyle.METROLIST -> MetrolistNowPlaying(
                                track = activeTrack,
                                streamInfo = activeStream,
                                isPlaying = isPlaying,
                                onPlayPause = { viewModel.togglePlayPause() },
                                onOpenDiagnostics = { showDiagnostics = true }
                            )
                            UiStyle.APPLE_MUSIC -> AppleMusicNowPlaying(
                                track = activeTrack,
                                streamInfo = activeStream,
                                isPlaying = isPlaying,
                                onPlayPause = { viewModel.togglePlayPause() },
                                onOpenDiagnostics = { showDiagnostics = true }
                            )
                        }

                        // Back / Collapse button
                        IconButton(
                            onClick = { showNowPlaying = false },
                            modifier = Modifier
                                .statusBarsPadding()
                                .padding(16.dp)
                                .align(Alignment.TopStart)
                        ) {
                            Text("✕", fontSize = 20.sp, color = Color.White)
                        }
                    }
                } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .statusBarsPadding()
                        .padding(horizontal = 16.dp)
                ) {
                    // Header Bar
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Softify",
                                fontSize = 26.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = Color.White
                            )
                            Text(
                                text = "320 kbps Studio Fidelity",
                                fontSize = 12.sp,
                                color = Color(0xFF34D399),
                                fontWeight = FontWeight.Medium
                            )
                        }

                        IconButton(onClick = { showSettings = !showSettings }) {
                            Text("⚙", fontSize = 24.sp, color = Color.White)
                        }
                    }

                    // Settings Panel (collapsible)
                    if (showSettings) {
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1B2E)),
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("UI Design System", fontWeight = FontWeight.Bold, color = Color.White)
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    FilterChip(
                                        selected = uiStyle == UiStyle.METROLIST,
                                        onClick = { viewModel.setUiStyle(UiStyle.METROLIST) },
                                        label = { Text("Metrolist M3") }
                                    )
                                    FilterChip(
                                        selected = uiStyle == UiStyle.APPLE_MUSIC,
                                        onClick = { viewModel.setUiStyle(UiStyle.APPLE_MUSIC) },
                                        label = { Text("Apple Music Liquid") }
                                    )
                                }

                                Spacer(modifier = Modifier.height(12.dp))
                                Text("Audio Stream Preset", fontWeight = FontWeight.Bold, color = Color.White)
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    FilterChip(
                                        selected = qualityPreset == QualityPreset.HIGH,
                                        onClick = { viewModel.setQualityPreset(QualityPreset.HIGH) },
                                        label = { Text("High (320k)") }
                                    )
                                    FilterChip(
                                        selected = qualityPreset == QualityPreset.MEDIUM,
                                        onClick = { viewModel.setQualityPreset(QualityPreset.MEDIUM) },
                                        label = { Text("Med (160k)") }
                                    )
                                    FilterChip(
                                        selected = qualityPreset == QualityPreset.LOW,
                                        onClick = { viewModel.setQualityPreset(QualityPreset.LOW) },
                                        label = { Text("Low (96k)") }
                                    )
                                }

                                Spacer(modifier = Modifier.height(14.dp))
                                Button(
                                    onClick = { showDiagnostics = true },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                                    shape = RoundedCornerShape(10.dp)
                                ) {
                                    Text("🛠 Open Playback Diagnostics", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                }
                            }
                        }
                    }

                    // Navigation Tabs: Search vs Library
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        FilterChip(
                            selected = currentTab == NavigationTab.SEARCH,
                            onClick = { viewModel.setTab(NavigationTab.SEARCH) },
                            label = { Text("🔍 Search") }
                        )
                        FilterChip(
                            selected = currentTab == NavigationTab.LIBRARY,
                            onClick = { viewModel.setTab(NavigationTab.LIBRARY) },
                            label = { Text("📚 Library (${likedTracks.size})") }
                        )
                    }

                    if (currentTab == NavigationTab.SEARCH) {
                        // Search input
                        OutlinedTextField(
                            value = searchQuery,
                            onValueChange = { viewModel.onSearchQueryChanged(it) },
                            placeholder = { Text("Search songs, artists, albums...", color = Color.Gray) },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 6.dp),
                            shape = RoundedCornerShape(14.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = Color(0xFF6EE7B7),
                                unfocusedBorderColor = Color(0xFF333333),
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White
                            ),
                            singleLine = true
                        )

                        // Intent Chip
                        if (detectedIntent != SearchIntent.GENERAL && detectedEntity != null) {
                            Text(
                                text = "🎯 Detected ${detectedIntent.name.lowercase().replaceFirstChar { it.uppercase() }}: \"$detectedEntity\"",
                                fontSize = 12.sp,
                                color = Color(0xFF6EE7B7),
                                modifier = Modifier.padding(bottom = 4.dp)
                            )
                        }

                        if (isSearching) {
                            LinearProgressIndicator(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(2.dp),
                                color = Color(0xFF6EE7B7)
                            )
                        }

                        // Search Results list
                        LazyColumn(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth(),
                            contentPadding = PaddingValues(vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            // Section: Local Library matches (FTS5)
                            if (localSearchResults.isNotEmpty()) {
                                item {
                                    Text(
                                        text = "From Your Library (Instant FTS5)",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF34D399),
                                        modifier = Modifier.padding(vertical = 4.dp)
                                    )
                                }
                                items(localSearchResults, key = { "local_${it.id}" }) { track ->
                                    TrackRowItem(
                                        track = track,
                                        isLiked = likedTracks.any { it.id == track.id },
                                        onSelect = { viewModel.playTrack(track) },
                                        onToggleLike = { viewModel.toggleLikeTrack(track) }
                                    )
                                }
                            }

                            // Section: Online Stream Results
                            if (onlineSearchResults.isNotEmpty()) {
                                item {
                                    Text(
                                        text = if (localSearchResults.isNotEmpty()) "Online Results" else "Search Results",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFFA78BFA),
                                        modifier = Modifier.padding(vertical = 4.dp)
                                    )
                                }
                                items(onlineSearchResults, key = { "online_${it.id}" }) { track ->
                                    TrackRowItem(
                                        track = track,
                                        isLiked = likedTracks.any { it.id == track.id },
                                        onSelect = { viewModel.playTrack(track) },
                                        onToggleLike = { viewModel.toggleLikeTrack(track) }
                                    )
                                }
                            }
                        }
                    } else {
                        // Library Tab Content
                        LazyColumn(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth(),
                            contentPadding = PaddingValues(vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            // Liked Songs Section
                            item {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "❤️ Liked Songs (${likedTracks.size})",
                                        fontSize = 18.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White
                                    )
                                }
                            }

                            if (likedTracks.isEmpty()) {
                                item {
                                    Text("No liked songs yet. Tap the heart on any track to save it.", color = Color.Gray, fontSize = 13.sp)
                                }
                            } else {
                                items(likedTracks, key = { "lib_liked_${it.id}" }) { track ->
                                    TrackRowItem(
                                        track = track,
                                        isLiked = true,
                                        onSelect = { viewModel.playTrack(track) },
                                        onToggleLike = { viewModel.toggleLikeTrack(track) }
                                    )
                                }
                            }

                            // Playlists Section
                            item {
                                Spacer(modifier = Modifier.height(16.dp))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "📁 Playlists (${playlists.size})",
                                        fontSize = 18.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White
                                    )
                                    Button(
                                        onClick = { showNewPlaylistDialog = true },
                                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF6EE7B7)),
                                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                                    ) {
                                        Text("+ New", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                    }
                                }
                            }

                            if (playlists.isEmpty()) {
                                item {
                                    Text("No custom playlists created yet.", color = Color.Gray, fontSize = 13.sp)
                                }
                            } else {
                                items(playlists, key = { it.id }) { pl ->
                                    Card(
                                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1B2E)),
                                        shape = RoundedCornerShape(12.dp),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Row(
                                            modifier = Modifier.padding(12.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Text("🎵", fontSize = 24.sp, modifier = Modifier.padding(end = 12.dp))
                                            Column {
                                                Text(pl.name, fontWeight = FontWeight.Bold, color = Color.White)
                                                Text("${pl.trackCount} tracks", fontSize = 12.sp, color = Color.Gray)
                                            }
                                        }
                                    }
                                }
                            }

                            // Recently Played Section
                            if (history.isNotEmpty()) {
                                item {
                                    Spacer(modifier = Modifier.height(16.dp))
                                    Text(
                                        text = "⏱️ Recently Played",
                                        fontSize = 18.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White
                                    )
                                }
                                items(history, key = { "hist_${it.id}" }) { hist ->
                                    TrackRowItem(
                                        track = hist.track,
                                        isLiked = likedTracks.any { it.id == hist.track.id },
                                        onSelect = { viewModel.playTrack(hist.track) },
                                        onToggleLike = { viewModel.toggleLikeTrack(hist.track) }
                                    )
                                }
                            }
                        }
                    }

                    // Mini-player bar (persistent when active)
                    if (activeTrack != null) {
                        Surface(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .clickable { showNowPlaying = true },
                            color = Color(0xFF1E1B2E),
                            tonalElevation = 8.dp
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = activeTrack!!.title,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Text(
                                            text = activeTrack!!.artist,
                                            fontSize = 12.sp,
                                            color = Color.LightGray,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                        if (activeStream != null) {
                                            QualityBadge(
                                                streamInfo = activeStream
                                            )
                                        }
                                    }
                                }

                                IconButton(onClick = { viewModel.togglePlayPause() }) {
                                    Text(
                                        text = if (isPlaying) "⏸" else "▶",
                                        fontSize = 20.sp,
                                        color = Color(0xFF6EE7B7)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Dialog to create new playlist
            if (showNewPlaylistDialog) {
                AlertDialog(
                    onDismissRequest = { showNewPlaylistDialog = false },
                    title = { Text("Create New Playlist", color = Color.White) },
                    text = {
                        OutlinedTextField(
                            value = newPlaylistName,
                            onValueChange = { newPlaylistName = it },
                            placeholder = { Text("Playlist name") },
                            singleLine = true
                        )
                    },
                    confirmButton = {
                        TextButton(
                            onClick = {
                                if (newPlaylistName.isNotBlank()) {
                                    viewModel.createNewPlaylist(newPlaylistName.trim())
                                    newPlaylistName = ""
                                    showNewPlaylistDialog = false
                                }
                            }
                        ) {
                            Text("Create", color = Color(0xFF6EE7B7))
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { showNewPlaylistDialog = false }) {
                            Text("Cancel", color = Color.Gray)
                        }
                    },
                    containerColor = Color(0xFF1E1B2E)
                )
            }

            // Visible Snackbar Host for Error Notifications
            SnackbarHost(
                hostState = snackbarHostState,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 16.dp)
            )
        }
    }
}
}

@Composable
private fun TrackRowItem(
    track: Track,
    isLiked: Boolean,
    onSelect: () -> Unit,
    onToggleLike: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF181528)),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = track.title,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = "${track.artist}${track.album?.let { " • $it" } ?: ""}",
                    fontSize = 12.sp,
                    color = Color.Gray,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            IconButton(onClick = onToggleLike) {
                Text(
                    text = if (isLiked) "❤️" else "🤍",
                    fontSize = 16.sp
                )
            }
        }
    }
}
