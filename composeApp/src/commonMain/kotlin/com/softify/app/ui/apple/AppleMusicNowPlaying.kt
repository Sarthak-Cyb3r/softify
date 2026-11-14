package com.softify.app.ui.apple

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.QualityBadge
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track

@Composable
fun AppleMusicNowPlaying(
    track: Track?,
    streamInfo: StreamInfo?,
    isPlaying: Boolean,
    onPlayPause: () -> Unit,
    onOpenDiagnostics: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    if (track == null) return

    val liquidGlassBg = Brush.verticalGradient(
        colors = listOf(Color(0xFF1E1B2E), Color(0xFF0F0E17))
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(liquidGlassBg)
            .padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Drag Pill & Diagnostics Bug icon
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Spacer(modifier = Modifier.size(36.dp))
            Box(
                modifier = Modifier
                    .width(36.dp)
                    .height(4.dp)
                    .background(Color(0x44FFFFFF), RoundedCornerShape(2.dp))
            )
            IconButton(onClick = onOpenDiagnostics, modifier = Modifier.size(48.dp)) {
                Icon(
                    imageVector = Icons.Filled.BugReport,
                    contentDescription = "Diagnostics",
                    modifier = Modifier.size(20.dp),
                    tint = Color.LightGray
                )
            }
        }

        // Apple Music Vinyl Acrylic Artwork Card
        Box(
            modifier = Modifier
                .size(290.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(Color(0x33FFFFFF))
                .border(
                    1.dp,
                    Brush.verticalGradient(
                        listOf(Color(0x66FFFFFF), Color(0x11FFFFFF))
                    ),
                    RoundedCornerShape(20.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = track.title.take(1).uppercase(),
                fontSize = 80.sp,
                fontWeight = FontWeight.Light,
                color = Color.White
            )
        }

        // Title, Artist, & Quality Badge
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.Start
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = track.title,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = track.artist,
                        fontSize = 18.sp,
                        color = Color(0x99FFFFFF),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))
            QualityBadge(streamInfo = streamInfo)
        }

        // Apple Music Glass Progress Slider
        Column(modifier = Modifier.fillMaxWidth()) {
            Slider(
                value = 0.35f,
                onValueChange = {},
                colors = SliderDefaults.colors(
                    thumbColor = Color.White,
                    activeTrackColor = Color.White,
                    inactiveTrackColor = Color(0x33FFFFFF)
                )
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("1:12", fontSize = 12.sp, color = Color(0x88FFFFFF))
                Text("-2:28", fontSize = 12.sp, color = Color(0x88FFFFFF))
            }
        }

        // Liquid Glass Transport Controls
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = {}) {
                Text("⏮", fontSize = 28.sp, color = Color.White)
            }

            IconButton(
                onClick = onPlayPause,
                modifier = Modifier
                    .size(68.dp)
                    .clip(CircleShape)
                    .background(Color(0x22FFFFFF))
                    .border(1.dp, Color(0x44FFFFFF), CircleShape)
            ) {
                Text(
                    text = if (isPlaying) "⏸" else "▶",
                    fontSize = 32.sp,
                    color = Color.White
                )
            }

            IconButton(onClick = {}) {
                Text("⏭", fontSize = 28.sp, color = Color.White)
            }
        }
    }
}
