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
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette
import com.softify.app.ui.components.SoftifyImage

@Composable
fun MetrolistHomeScreen(
    palette: DynamicColorPalette,
    tracks: List<Track>,
    currentTrack: Track?,
    isPlaying: Boolean,
    onTrackSelect: (Track) -> Unit,
    onThemeToggle: () -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(16.dp))

            // Metrolist Top Header Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Metrolist",
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Bold,
                        color = palette.primary
                    )
                    Text(
                        text = "Material 3 • Dynamic Color",
                        fontSize = 13.sp,
                        color = Color(0xFFA6A6AA)
                    )
                }

                // Theme switcher pill button
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

        // Quick Picks Shelf (24dp Squircles with play buttons)
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

        // Forgotten Favorites Shelf
        item {
            Text(
                text = "Listen Again",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(12.dp))

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(tracks.reversed()) { track ->
                    MetrolistAlbumCard(
                        track = track,
                        palette = palette,
                        onClick = { onTrackSelect(track) }
                    )
                }
            }
        }

        // Songs in Queue / Mixed For You
        item {
            Text(
                text = "Mixed for You",
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
            Spacer(modifier = Modifier.height(110.dp))
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
        SoftifyImage(
            url = track.coverUrl,
            title = track.title,
            modifier = Modifier.size(136.dp),
            cornerRadius = 20.dp
        )
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
            .padding(vertical = 10.dp, horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SoftifyImage(
            url = track.coverUrl,
            title = track.title,
            modifier = Modifier.size(46.dp),
            cornerRadius = 12.dp
        )

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = track.title,
                color = if (isSelected) palette.primary else Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 15.sp,
                maxLines = 1
            )
            Text(
                text = track.artist,
                color = Color(0xFFA6A6AA),
                fontSize = 13.sp,
                maxLines = 1
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
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(28.dp))
            .clickable { onExpand() },
        color = palette.surfaceVariant,
        shadowElevation = 16.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SoftifyImage(
                url = currentTrack.coverUrl,
                title = currentTrack.title,
                modifier = Modifier.size(44.dp),
                cornerRadius = 12.dp
            )

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = currentTrack.title,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                    maxLines = 1
                )
                Text(
                    text = currentTrack.artist,
                    color = palette.primary,
                    fontSize = 12.sp,
                    maxLines = 1
                )
            }

            IconButton(
                onClick = onPlayPause,
                modifier = Modifier
                    .size(42.dp)
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
