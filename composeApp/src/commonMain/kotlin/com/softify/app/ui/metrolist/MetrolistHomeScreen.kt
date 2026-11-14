package com.softify.app.ui.metrolist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.data.PlayerManager
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette

@Composable
fun MetrolistHomeScreen(
    palette: DynamicColorPalette,
    tracks: List<Track>,
    currentTrack: Track?,
    isPlaying: Boolean,
    onTrackSelect: (Track) -> Unit,
    onThemeToggle: () -> Unit
) {
    Scaffold(
        containerColor = palette.background,
        bottomBar = {
            MetrolistMiniPlayer(
                palette = palette,
                currentTrack = currentTrack,
                isPlaying = isPlaying,
                onPlayPause = { PlayerManager.togglePlayPause() },
                onExpand = { PlayerManager.setPlayerExpanded(true) }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            item {
                Spacer(modifier = Modifier.height(16.dp))

                // Top Bar with Metrolist Pill Search & Theme Switcher
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Metrolist",
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                            color = palette.primary
                        )
                        Text(
                            text = "Material 3 • Dynamic Color",
                            fontSize = 13.sp,
                            color = Color(0xFFA6A6AA)
                        )
                    }

                    // Mode switch button
                    Button(
                        onClick = onThemeToggle,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = palette.primaryContainer,
                            contentColor = palette.primary
                        ),
                        shape = RoundedCornerShape(100.dp)
                    ) {
                        Text(
                            text = "🍎 Apple Music UI",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            // Quick Picks Shelf (Horizontal Cards with 24dp Squircles)
            item {
                Text(
                    text = "Quick Picks",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(12.dp))

                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(tracks) { track ->
                        MetrolistAlbumCard(
                            track = track,
                            palette = palette,
                            onClick = { onTrackSelect(track) }
                        )
                    }
                }
            }

            // Playlist / Library Track Rows
            item {
                Text(
                    text = "Songs in Queue",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            items(tracks) { track ->
                val isSelected = track.id == currentTrack?.id
                MetrolistTrackRow(
                    track = track,
                    isSelected = isSelected,
                    palette = palette,
                    onClick = { onTrackSelect(track) }
                )
            }

            item {
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

@Composable
fun MetrolistAlbumCard(
    track: Track,
    palette: DynamicColorPalette,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .width(160.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(palette.surface)
            .clickable { onClick() }
            .padding(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(136.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(palette.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "🎵",
                fontSize = 42.sp
            )
        }
        Spacer(modifier = Modifier.height(10.dp))
        Text(
            text = track.title,
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp,
            maxLines = 1
        )
        Text(
            text = track.artist,
            color = Color(0xFFA0A0A4),
            fontSize = 12.sp,
            maxLines = 1
        )
    }
}

@Composable
fun MetrolistTrackRow(
    track: Track,
    isSelected: Boolean,
    palette: DynamicColorPalette,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(if (isSelected) palette.primaryContainer.copy(alpha = 0.45f) else Color.Transparent)
            .clickable { onClick() }
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(46.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(if (isSelected) palette.primary else palette.surfaceVariant),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = if (isSelected) "▶" else "♫",
                color = if (isSelected) palette.onPrimary else Color.White,
                fontSize = 16.sp
            )
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = track.title,
                color = if (isSelected) palette.primary else Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 15.sp
            )
            Text(
                text = track.artist,
                color = Color(0xFFA6A6AA),
                fontSize = 13.sp
            )
        }

        Text(
            text = track.durationFormatted,
            color = Color(0xFF7E7E84),
            fontSize = 13.sp
        )
    }
}

@Composable
fun MetrolistMiniPlayer(
    palette: DynamicColorPalette,
    currentTrack: Track?,
    isPlaying: Boolean,
    onPlayPause: () -> Unit,
    onExpand: () -> Unit
) {
    if (currentTrack == null) return

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
            .clip(RoundedCornerShape(28.dp))
            .clickable { onExpand() },
        color = palette.surfaceVariant,
        shadowElevation = 16.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(palette.primary),
                contentAlignment = Alignment.Center
            ) {
                Text(text = "▶", color = palette.onPrimary, fontSize = 16.sp)
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = currentTrack.title,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
                Text(
                    text = currentTrack.artist,
                    color = palette.primary,
                    fontSize = 12.sp
                )
            }

            IconButton(
                onClick = onPlayPause,
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(palette.primaryContainer)
            ) {
                Text(
                    text = if (isPlaying) "⏸" else "▶",
                    color = palette.primary,
                    fontSize = 18.sp
                )
            }
        }
    }
}
