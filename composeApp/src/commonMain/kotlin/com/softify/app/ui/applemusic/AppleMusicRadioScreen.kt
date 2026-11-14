package com.softify.app.ui.applemusic

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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

@Composable
fun AppleMusicRadioScreen(
    palette: DynamicColorPalette,
    tracks: List<Track>,
    onTrackSelect: (Track) -> Unit
) {
    val infiniteTransition = rememberInfiniteTransition()
    val wavePhase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 6.28f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        )
    )

    val stations = listOf(
        Triple("Apple Music 1", "The new music that matters now. 24/7 live.", listOf(Color(0xFFE11D48), Color(0xFFF43F5E))),
        Triple("Apple Music Hits", "Songs from the '80s, '90s, and 2000s.", listOf(Color(0xFF2563EB), Color(0xFF38BDF8))),
        Triple("Apple Music Country", "The voice of modern country music.", listOf(Color(0xFFD97706), Color(0xFFFBBF24))),
        Triple("Chillwaves Studio", "Downtempo electronic and acoustic live.", listOf(Color(0xFF7C3AED), Color(0xFFA78BFA)))
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
                text = "Radio",
                fontSize = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White
            )
            Text(
                text = "Tune in to live broadcasts, artist interviews and global charts",
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.6f)
            )
        }

        // Live Station Hero Banner
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
                                listOf(Color(0xFFE11D48).copy(alpha = 0.65f), Color.Black.copy(alpha = 0.7f))
                            )
                        )
                        .padding(24.dp)
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFFFF3B30))
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "LIVE BROADCAST",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                letterSpacing = 1.sp
                            )
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "Apple Music 1",
                            fontSize = 28.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color.White
                        )
                        Text(
                            text = "Hosted by Zane Lowe • Broadcasting live from Los Angeles",
                            fontSize = 13.sp,
                            color = Color.White.copy(alpha = 0.8f)
                        )

                        Spacer(modifier = Modifier.height(18.dp))

                        // Animated live audio frequency wave
                        Canvas(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(32.dp)
                        ) {
                            val barCount = 36
                            val barWidth = size.width / (barCount * 1.5f)
                            for (i in 0 until barCount) {
                                val sinVal = kotlin.math.sin(wavePhase + (i * 0.4f))
                                val height = ((sinVal + 1) * 0.5f * size.height).coerceAtLeast(4f)
                                drawRect(
                                    color = Color.White.copy(alpha = 0.75f),
                                    topLeft = androidx.compose.ui.geometry.Offset(i * barWidth * 1.5f, size.height - height),
                                    size = androidx.compose.ui.geometry.Size(barWidth, height)
                                )
                            }
                        }
                    }
                }
            }
        }

        // Live Stations Shelf
        item {
            Text(
                text = "Live Stations",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        items(stations) { (title, subtitle, colors) ->
            GlassmorphicContainer(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { tracks.firstOrNull()?.let { onTrackSelect(it) } },
                cornerRadius = 18
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(54.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(Brush.linearGradient(colors)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(text = "📻", fontSize = 24.sp)
                    }

                    Spacer(modifier = Modifier.width(16.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = title,
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                        Text(
                            text = subtitle,
                            color = Color.White.copy(alpha = 0.6f),
                            fontSize = 13.sp,
                            maxLines = 1
                        )
                    }

                    Text(text = "▶", color = Color.White, fontSize = 16.sp)
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}
