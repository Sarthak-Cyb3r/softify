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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.data.PlayerManager
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette
import com.softify.app.theme.GlassmorphicContainer
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
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(palette.ambientGradientStops)
            )
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp)
        ) {
            item {
                Spacer(modifier = Modifier.height(24.dp))

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

                    Button(
                        onClick = onThemeToggle,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.White.copy(alpha = 0.15f),
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(100.dp)
                    ) {
                        Text(
                            text = "⚡ Metrolist UI",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            // Featured Vinyl Showcase
            item {
                GlassmorphicContainer(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp)
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
                            text = currentTrack?.artist ?: "Apple Music iOS Studio",
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
            items(tracks) { track ->
                AppleMusicTrackRow(
                    track = track,
                    isSelected = track.id == currentTrack?.id,
                    onClick = { onTrackSelect(track) }
                )
            }

            item {
                Spacer(modifier = Modifier.height(110.dp))
            }
        }

        // Apple Music Bottom Frosted Glass Player
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            AppleMusicMiniPlayer(
                currentTrack = currentTrack,
                isPlaying = isPlaying,
                onPlayPause = { PlayerManager.togglePlayPause() }
            )
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
            .width(180.dp)
            .clickable { onClick() }
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Box(
                modifier = Modifier
                    .size(152.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Color.White.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Text(text = "🍎", fontSize = 48.sp)
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = track.title,
                color = Color.White,
                fontWeight = FontWeight.Bold,
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
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(42.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (isSelected) Color.White else Color.White.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = if (isSelected) "▶" else "♪",
                    color = if (isSelected) Color.Black else Color.White,
                    fontSize = 16.sp
                )
            }

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = track.title,
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp
                )
                Text(
                    text = track.artist,
                    color = Color.White.copy(alpha = 0.6f),
                    fontSize = 13.sp
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
    onPlayPause: () -> Unit
) {
    if (currentTrack == null) return

    GlassmorphicContainer(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 28
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .clip(CircleShape)
                    .background(Color.White),
                contentAlignment = Alignment.Center
            ) {
                Text(text = "▶", color = Color.Black, fontSize = 16.sp)
            }

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = currentTrack.title,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp
                )
                Text(
                    text = currentTrack.artist,
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 13.sp
                )
            }

            Button(
                onClick = onPlayPause,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White.copy(alpha = 0.2f),
                    contentColor = Color.White
                ),
                shape = CircleShape,
                modifier = Modifier.size(44.dp)
            ) {
                Text(
                    text = if (isPlaying) "⏸" else "▶",
                    fontSize = 16.sp
                )
            }
        }
    }
}
