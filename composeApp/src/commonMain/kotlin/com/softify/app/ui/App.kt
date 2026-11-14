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
import com.softify.app.ui.metrolist.MetrolistNowPlaying
import com.softify.app.viewmodel.PlaybackViewModel
import com.softify.app.viewmodel.UiStyle
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.Track

@Composable
fun App(viewModel: PlaybackViewModel = remember { PlaybackViewModel() }) {
    val searchQuery by viewModel.searchQuery.collectAsState()
    val searchResults by viewModel.searchResults.collectAsState()
    val isSearching by viewModel.isSearching.collectAsState()
    val activeTrack by viewModel.activeTrack.collectAsState()
    val activeStream by viewModel.activeStream.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()
    val qualityPreset by viewModel.qualityPreset.collectAsState()
    val uiStyle by viewModel.uiStyle.collectAsState()

    var showNowPlaying by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }

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
            if (showNowPlaying && activeTrack != null) {
                Box(modifier = Modifier.fillMaxSize()) {
                    when (uiStyle) {
                        UiStyle.METROLIST -> MetrolistNowPlaying(
                            track = activeTrack,
                            streamInfo = activeStream,
                            isPlaying = isPlaying,
                            onPlayPause = { viewModel.togglePlayPause() }
                        )
                        UiStyle.APPLE_MUSIC -> AppleMusicNowPlaying(
                            track = activeTrack,
                            streamInfo = activeStream,
                            isPlaying = isPlaying,
                            onPlayPause = { viewModel.togglePlayPause() }
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
                            }
                        }
                    }

                    // Search input
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { viewModel.onSearchQueryChanged(it) },
                        placeholder = { Text("Search songs, artists, albums...", color = Color.Gray) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        shape = RoundedCornerShape(14.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Color(0xFF6EE7B7),
                            unfocusedBorderColor = Color(0xFF333333),
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White
                        ),
                        singleLine = true
                    )

                    if (isSearching) {
                        LinearProgressIndicator(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(2.dp),
                            color = Color(0xFF6EE7B7)
                        )
                    }

                    // Results list
                    LazyColumn(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentPadding = PaddingValues(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(searchResults, key = { it.id }) { track ->
                            TrackListItem(
                                track = track,
                                isPlaying = track.id == activeTrack?.id,
                                onClick = { viewModel.playTrack(track) }
                            )
                        }
                    }

                    // MiniPlayer at bottom
                    if (activeTrack != null) {
                        MiniPlayer(
                            track = activeTrack!!,
                            streamInfo = activeStream,
                            isPlaying = isPlaying,
                            onPlayPause = { viewModel.togglePlayPause() },
                            onExpand = { showNowPlaying = true }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun TrackListItem(
    track: Track,
    isPlaying: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isPlaying) Color(0x336EE7B7) else Color(0xFF1E1B2E))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF2D2A42)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = track.title.take(1).uppercase(),
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = track.title,
                fontWeight = FontWeight.SemiBold,
                color = if (isPlaying) Color(0xFF6EE7B7) else Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = track.artist,
                fontSize = 13.sp,
                color = Color(0xFFA1A1AA),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
fun MiniPlayer(
    track: Track,
    streamInfo: uniffi.softify_core.StreamInfo?,
    isPlaying: Boolean,
    onPlayPause: () -> Unit,
    onExpand: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
            .clickable(onClick = onExpand),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF27272A)),
        shape = RoundedCornerShape(16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color(0xFF3F3F46)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = track.title.take(1).uppercase(),
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.width(10.dp))

                Column {
                    Text(
                        text = track.title,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    QualityBadge(streamInfo = streamInfo)
                }
            }

            IconButton(onClick = onPlayPause) {
                Text(
                    text = if (isPlaying) "⏸" else "▶",
                    fontSize = 20.sp,
                    color = Color.White
                )
            }
        }
    }
}
