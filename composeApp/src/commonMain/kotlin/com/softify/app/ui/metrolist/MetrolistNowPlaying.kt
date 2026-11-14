package com.softify.app.ui.metrolist

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.QualityBadge
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import kotlin.math.sin

@Composable
fun MetrolistNowPlaying(
    track: Track?,
    streamInfo: StreamInfo?,
    isPlaying: Boolean,
    onPlayPause: () -> Unit,
    onOpenDiagnostics: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    if (track == null) return

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF131314))
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Top bar with diagnostics bug button
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Spacer(modifier = Modifier.size(36.dp))
            Text(
                text = "NOW PLAYING • METROLIST",
                color = Color(0xFF9CA3AF),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.sp
            )
            IconButton(onClick = onOpenDiagnostics, modifier = Modifier.size(36.dp)) {
                Text("🐞", fontSize = 16.sp)
            }
        }

        // Scalloped Album Cover Artwork Container
        Box(
            modifier = Modifier
                .size(280.dp)
                .clip(RoundedCornerShape(32.dp))
                .background(Color(0xFF202124)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = track.title.take(1).uppercase(),
                fontSize = 72.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFFE2E8F0)
            )
        }

        // Track Metadata & Quality Badge
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = track.title,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = track.artist,
                fontSize = 16.sp,
                color = Color(0xFFA1A1AA),
                textAlign = TextAlign.Center,
                maxLines = 1
            )
            Spacer(modifier = Modifier.height(12.dp))
            QualityBadge(streamInfo = streamInfo)
        }

        // Metrolist Squiggly Canvas Waveform Progress
        SquigglyWaveformSlider(
            progress = 0.35f,
            modifier = Modifier
                .fillMaxWidth()
                .height(28.dp)
        )

        // Expressive Pill Dock Controls
        Row(
            modifier = Modifier
                .background(Color(0xFF27272A), RoundedCornerShape(36.dp))
                .padding(horizontal = 24.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Button(
                onClick = {},
                colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent)
            ) {
                Text("⏮", fontSize = 20.sp, color = Color.White)
            }

            IconButton(
                onClick = onPlayPause,
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFE2E8F0))
            ) {
                Text(
                    text = if (isPlaying) "⏸" else "▶",
                    fontSize = 24.sp,
                    color = Color.Black
                )
            }

            Button(
                onClick = {},
                colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent)
            ) {
                Text("⏭", fontSize = 20.sp, color = Color.White)
            }
        }
    }
}

@Composable
fun SquigglyWaveformSlider(
    progress: Float = 0.35f,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        val width = size.width
        val height = size.height
        val midY = height / 2f
        val activeWidth = width * progress

        // Squiggly active wave path
        val wavePath = Path()
        wavePath.moveTo(0f, midY)
        val wavelength = 24f
        val amplitude = 5f

        var x = 0f
        while (x <= activeWidth) {
            val y = midY + amplitude * sin(x / wavelength * 2f * Math.PI.toFloat())
            wavePath.lineTo(x, y)
            x += 2f
        }

        drawPath(
            path = wavePath,
            color = Color(0xFF6EE7B7),
            style = Stroke(width = 3.dp.toPx())
        )

        // Inactive flat rail
        drawLine(
            color = Color(0xFF3F3F46),
            start = Offset(activeWidth, midY),
            end = Offset(width, midY),
            strokeWidth = 3.dp.toPx()
        )

        // Scalloped scrub thumb
        drawCircle(
            color = Color(0xFF6EE7B7),
            radius = 6.dp.toPx(),
            center = Offset(activeWidth, midY)
        )
    }
}
