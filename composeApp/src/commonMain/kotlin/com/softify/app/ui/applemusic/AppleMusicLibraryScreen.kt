package com.softify.app.ui.applemusic

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
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
import com.softify.app.ui.components.SoftifyIcons
import com.softify.app.ui.components.SoftifyImage

@Composable
fun AppleMusicLibraryScreen(
    palette: DynamicColorPalette,
    tracks: List<Track>,
    onTrackSelect: (Track) -> Unit
) {
    val librarySections = listOf(
        Pair("Playlists", SoftifyIcons.Playlist),
        Pair("Artists", SoftifyIcons.Artist),
        Pair("Albums", SoftifyIcons.Album),
        Pair("Songs", SoftifyIcons.Song),
        Pair("Made for You", SoftifyIcons.Sparkles),
        Pair("Downloaded", SoftifyIcons.Download)
    )

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                text = "Library",
                fontSize = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White
            )
        }

        // Apple Music Navigation List with Chevrons
        item {
            GlassmorphicContainer(
                modifier = Modifier.fillMaxWidth(),
                cornerRadius = 20
            ) {
                Column(modifier = Modifier.padding(vertical = 6.dp)) {
                    librarySections.forEachIndexed { index, (label, icon) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    tracks.firstOrNull()?.let { onTrackSelect(it) }
                                }
                                .padding(horizontal = 18.dp, vertical = 14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = icon,
                                    contentDescription = label,
                                    tint = Color(0xFFFA243C),
                                    modifier = Modifier.size(22.dp)
                                )
                                Spacer(modifier = Modifier.width(16.dp))
                                Text(
                                    text = label,
                                    color = Color.White,
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                            Icon(
                                imageVector = SoftifyIcons.ChevronRight,
                                contentDescription = null,
                                tint = Color.White.copy(alpha = 0.35f),
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        if (index < librarySections.size - 1) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(start = 52.dp)
                                    .height(1.dp)
                                    .background(Color.White.copy(alpha = 0.08f))
                            )
                        }
                    }
                }
            }
        }

        // Recently Added 2-Column Grid
        item {
            Text(
                text = "Recently Added",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        items(tracks.chunked(2)) { rowTracks ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                rowTracks.forEach { track ->
                    GlassmorphicContainer(
                        modifier = Modifier
                            .weight(1f)
                            .clickable { onTrackSelect(track) },
                        cornerRadius = 18
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            SoftifyImage(
                                url = track.coverUrl,
                                title = track.title,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .aspectRatio(1f),
                                cornerRadius = 14.dp
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
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 12.sp,
                                maxLines = 1
                            )
                        }
                    }
                }
                if (rowTracks.size == 1) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}
