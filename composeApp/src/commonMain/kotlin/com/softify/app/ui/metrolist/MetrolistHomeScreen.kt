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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import com.softify.app.ui.components.SegmentedThemeToggle
import com.softify.app.ui.components.SoftifyIcons
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
    val themeMode by PlayerManager.themeMode.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(16.dp))

            // Metrolist Top Bar: Greeting & Segmented Theme Switcher
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Good afternoon",
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text(
                        text = "Metrolist • Dynamic Material 3",
                        fontSize = 12.sp,
                        color = palette.primary,
                        fontWeight = FontWeight.Medium
                    )
                }

                SegmentedThemeToggle(
                    themeMode = themeMode,
                    accentColor = palette.primary,
                    onToggle = { PlayerManager.setTheme(it) }
                )
            }
        }

        // Quick Picks Shelf
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Bottom
            ) {
                Column {
                    Text(
                        text = "START RADIO FROM A SONG",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White.copy(alpha = 0.5f),
                        letterSpacing = 1.sp
                    )
                    Text(
                        text = "Quick picks",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

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

        // Forgotten Favorites / Listen Again
        item {
            Column {
                Text(
                    text = "SIMILAR TO YOUR FAVORITES",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White.copy(alpha = 0.5f),
                    letterSpacing = 1.sp
                )
                Text(
                    text = "Forgotten favorites",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

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

        // Mixed For You
        item {
            Text(
                text = "Mixed for you",
                fontSize = 22.sp,
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
                onClick = { onTrackSelect(track) },
                onLikeToggle = { PlayerManager.toggleLike(track.id) }
            )
        }

        item {
            Spacer(modifier = Modifier.height(120.dp))
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
            .width(156.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(palette.surface)
            .clickable { onClick() }
            .padding(10.dp)
    ) {
        Box(
            modifier = Modifier
                .size(136.dp)
                .clip(RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.BottomEnd
        ) {
            SoftifyImage(
                url = track.coverUrl,
                title = track.title,
                modifier = Modifier.fillMaxSize(),
                cornerRadius = 14.dp
            )

            // Play icon badge overlay
            Box(
                modifier = Modifier
                    .padding(8.dp)
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(palette.primary),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = SoftifyIcons.Play,
                    contentDescription = "Play",
                    tint = palette.onPrimary,
                    modifier = Modifier.size(20.dp)
                )
            }
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
            color = Color.White.copy(alpha = 0.6f),
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
    onClick: () -> Unit,
    onLikeToggle: () -> Unit = { PlayerManager.toggleLike(track.id) }
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(if (isSelected) palette.primaryContainer.copy(alpha = 0.45f) else Color.Transparent)
            .clickable { onClick() }
            .padding(vertical = 8.dp, horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SoftifyImage(
            url = track.coverUrl,
            title = track.title,
            modifier = Modifier.size(48.dp),
            cornerRadius = 10.dp
        )

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = track.title,
                color = if (isSelected) palette.primary else Color.White,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.SemiBold,
                fontSize = 15.sp,
                maxLines = 1
            )
            Text(
                text = track.artist,
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 13.sp,
                maxLines = 1
            )
        }

        IconButton(onClick = onLikeToggle) {
            Icon(
                imageVector = if (track.isLiked) SoftifyIcons.HeartFilled else SoftifyIcons.HeartOutlined,
                contentDescription = "Favorite",
                tint = if (track.isLiked) palette.primary else Color.White.copy(alpha = 0.4f),
                modifier = Modifier.size(20.dp)
            )
        }

        Text(
            text = track.durationFormatted,
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 12.sp,
            modifier = Modifier.padding(start = 4.dp, end = 4.dp)
        )
    }
}

@Composable
fun MetrolistMiniPlayer(
    palette: DynamicColorPalette,
    currentTrack: Track?,
    isPlaying: Boolean,
    progress: Float,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onExpand: () -> Unit
) {
    if (currentTrack == null) return

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(20.dp))
            .clickable { onExpand() },
        color = palette.surfaceVariant,
        shadowElevation = 8.dp
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                SoftifyImage(
                    url = currentTrack.coverUrl,
                    title = currentTrack.title,
                    modifier = Modifier.size(46.dp),
                    cornerRadius = 10.dp
                )

                Spacer(modifier = Modifier.width(14.dp))

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
                    Icon(
                        imageVector = if (isPlaying) SoftifyIcons.Pause else SoftifyIcons.Play,
                        contentDescription = "Play/Pause",
                        tint = palette.primary,
                        modifier = Modifier.size(22.dp)
                    )
                }

                Spacer(modifier = Modifier.width(4.dp))

                IconButton(
                    onClick = onNext,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = SoftifyIcons.SkipNext,
                        contentDescription = "Next",
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(22.dp)
                    )
                }
            }

            // Integrated Linear Progress Bar across the bottom of the mini player
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(2.5.dp),
                color = palette.primary,
                trackColor = Color.White.copy(alpha = 0.08f)
            )
        }
    }
}
