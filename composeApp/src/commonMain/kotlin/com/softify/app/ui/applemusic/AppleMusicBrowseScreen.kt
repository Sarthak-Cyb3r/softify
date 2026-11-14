package com.softify.app.ui.applemusic

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette
import com.softify.app.theme.GlassmorphicContainer
import com.softify.app.ui.components.SoftifyImage

@Composable
fun AppleMusicBrowseScreen(
    palette: DynamicColorPalette,
    tracks: List<Track>,
    onTrackSelect: (Track) -> Unit
) {
    val moods = listOf(
        Pair("Spatial Audio", listOf(Color(0xFF6B21A8), Color(0xFF3B82F6))),
        Pair("City Charts", listOf(Color(0xFFDC2626), Color(0xFFF97316))),
        Pair("New Music Daily", listOf(Color(0xFF059669), Color(0xFF10B981))),
        Pair("Chill & Acoustic", listOf(Color(0xFF4338CA), Color(0xFF6366F1))),
        Pair("Bollywood Hits", listOf(Color(0xFFB45309), Color(0xFFF59E0B))),
        Pair("Workout Pump", listOf(Color(0xFFBE185D), Color(0xFFEC4899)))
    )

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(26.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                text = "Browse",
                fontSize = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White
            )
            Text(
                text = "Explore new releases, spatial charts and curated sounds",
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.6f)
            )
        }

        // Featured Hero Banner
        item {
            GlassmorphicContainer(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { tracks.firstOrNull()?.let { onTrackSelect(it) } },
                cornerRadius = 24
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.linearGradient(
                                listOf(
                                    palette.primary.copy(alpha = 0.5f),
                                    Color.Black.copy(alpha = 0.6f)
                                )
                            )
                        )
                        .padding(24.dp)
                ) {
                    Column {
                        Text(
                            text = "EXCLUSIVE PREMIERE",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White.copy(alpha = 0.7f),
                            letterSpacing = 1.sp
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Coke Studio High-Fidelity Master",
                            fontSize = 24.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Listen in Lossless 24-bit 96kHz High-Resolution Audio",
                            fontSize = 13.sp,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                }
            }
        }

        // New Tracks Shelf
        item {
            Text(
                text = "New Releases",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(14.dp))

            LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                items(tracks) { track ->
                    AppleMusicCard(
                        track = track,
                        onClick = { onTrackSelect(track) }
                    )
                }
            }
        }

        // Moods & Categories Grid (2 Columns)
        item {
            Text(
                text = "Moods & Activities",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        items(moods.chunked(2)) { pair ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                pair.forEach { (name, colors) ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(100.dp)
                            .clip(RoundedCornerShape(18.dp))
                            .background(Brush.linearGradient(colors))
                            .clickable { tracks.firstOrNull()?.let { onTrackSelect(it) } }
                            .padding(16.dp),
                        contentAlignment = Alignment.BottomStart
                    ) {
                        Text(
                            text = name,
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}
