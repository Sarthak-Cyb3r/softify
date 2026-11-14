package com.softify.app.ui.applemusic

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
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
import com.softify.app.theme.GlassmorphicContainer
import com.softify.app.theme.ThemeMode
import com.softify.app.ui.components.SegmentedThemeToggle
import com.softify.app.ui.components.SoftifyIcons
import com.softify.app.ui.components.SoftifyImage
import com.softify.app.ui.components.TurntableVinyl

@Composable
fun AppleMusicHomeScreen(
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
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(28.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(20.dp))

            // Apple Music Header: iOS Bold Title & Theme Switcher
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Listen Now",
                        fontSize = 34.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White
                    )
                    Text(
                        text = "Apple Music • Liquid Glass",
                        fontSize = 13.sp,
                        color = Color.White.copy(alpha = 0.6f)
                    )
                }

                SegmentedThemeToggle(
                    themeMode = ThemeMode.APPLE_MUSIC,
                    accentColor = Color(0xFFFA243C),
                    onToggle = { mode ->
                        if (mode != ThemeMode.APPLE_MUSIC) onThemeToggle()
                    }
                )
            }
        }

        // Featured Vinyl Turntable Showcase
        item {
            GlassmorphicContainer(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                cornerRadius = 24
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    TurntableVinyl(
                        isPlaying = isPlaying,
                        title = currentTrack?.title ?: "Softify",
                        artist = currentTrack?.artist ?: "Apple Music",
                        modifier = Modifier.padding(bottom = 16.dp)
                    )

                    Text(
                        text = currentTrack?.title ?: "Select a song",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text(
                        text = currentTrack?.artist ?: "Apple Music Master",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                }
            }
        }

        // iOS Curated Heavy Shelf
        item {
            Text(
                text = "Top Playlists",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(14.dp))

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                items(tracks) { track ->
                    AppleMusicCard(
                        track = track,
                        onClick = { onTrackSelect(track) }
                    )
                }
            }
        }

        // Song List
        item {
            Text(
                text = "Recently Played",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        items(tracks) { track ->
            AppleMusicTrackRow(
                track = track,
                isSelected = track.id == currentTrack?.id,
                onClick = { onTrackSelect(track) }
            )
        }

        item {
            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}

@Composable
fun AppleMusicCard(
    track: Track,
    onClick: () -> Unit
) {
    GlassmorphicContainer(
        modifier = Modifier
            .width(170.dp)
            .clickable { onClick() },
        cornerRadius = 20
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            SoftifyImage(
                url = track.coverUrl,
                title = track.title,
                modifier = Modifier
                    .size(146.dp)
                    .clip(RoundedCornerShape(16.dp)),
                cornerRadius = 16.dp
            )
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = track.title,
                color = Color.White,
                fontWeight = FontWeight.Bold,
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
}

@Composable
fun AppleMusicTrackRow(
    track: Track,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    GlassmorphicContainer(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        cornerRadius = 16
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SoftifyImage(
                url = track.coverUrl,
                title = track.title,
                modifier = Modifier.size(44.dp),
                cornerRadius = 10.dp
            )

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = track.title,
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
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

            Text(
                text = track.durationFormatted,
                color = Color.White.copy(alpha = 0.45f),
                fontSize = 13.sp
            )
        }
    }
}

@Composable
fun AppleMusicMiniPlayer(
    currentTrack: Track?,
    isPlaying: Boolean,
    onPlayPause: () -> Unit,
    onExpand: () -> Unit
) {
    if (currentTrack == null) return

    GlassmorphicContainer(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onExpand() },
        cornerRadius = 24
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SoftifyImage(
                url = currentTrack.coverUrl,
                title = currentTrack.title,
                modifier = Modifier.size(44.dp),
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
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 12.sp,
                    maxLines = 1
                )
            }

            IconButton(
                onClick = onPlayPause,
                modifier = Modifier
                    .size(42.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.2f))
            ) {
                Icon(
                    imageVector = if (isPlaying) SoftifyIcons.Pause else SoftifyIcons.Play,
                    contentDescription = if (isPlaying) "Pause" else "Play",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}
