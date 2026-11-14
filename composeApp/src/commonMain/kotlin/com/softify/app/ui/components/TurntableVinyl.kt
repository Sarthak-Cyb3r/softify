package com.softify.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun TurntableVinyl(
    isPlaying: Boolean,
    title: String,
    artist: String,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition()
    val rotationAngle by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 8000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        )
    )

    val tonearmAngle by animateFloatAsState(
        targetValue = if (isPlaying) 28f else 0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow)
    )

    Box(
        modifier = modifier
            .size(280.dp)
            .shadow(24.dp, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        // Rotating Vinyl Record
        Box(
            modifier = Modifier
                .fillMaxSize()
                .rotate(if (isPlaying) rotationAngle else 0f)
                .clip(CircleShape)
                .background(Color(0xFF111113)),
            contentAlignment = Alignment.Center
        ) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val center = Offset(size.width / 2, size.height / 2)
                val radius = size.minDimension / 2

                // Vinyl groove rings
                for (r in 40 until radius.toInt() step 12) {
                    drawCircle(
                        color = Color.White.copy(alpha = 0.04f),
                        radius = r.toFloat(),
                        center = center,
                        style = Stroke(width = 1.2f)
                    )
                }

                // Vinyl luster reflection shine
                drawArc(
                    brush = Brush.radialGradient(
                        listOf(Color.White.copy(alpha = 0.12f), Color.Transparent),
                        center = center,
                        radius = radius
                    ),
                    startAngle = 45f,
                    sweepAngle = 40f,
                    useCenter = true
                )
                drawArc(
                    brush = Brush.radialGradient(
                        listOf(Color.White.copy(alpha = 0.12f), Color.Transparent),
                        center = center,
                        radius = radius
                    ),
                    startAngle = 225f,
                    sweepAngle = 40f,
                    useCenter = true
                )
            }

            // Center Label Squircle / Circle
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.radialGradient(
                            listOf(Color(0xFF1DB954), Color(0xFF121212))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = title.take(12),
                        color = Color.White,
                        fontSize = 11.sp
                    )
                    Text(
                        text = artist.take(10),
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 9.sp
                    )
                }
            }
        }

        // Animated Metallic Tonearm
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .rotate(tonearmAngle)
        ) {
            val pivot = Offset(size.width * 0.90f, size.height * 0.12f)
            val needleHead = Offset(size.width * 0.52f, size.height * 0.48f)

            // Tonearm base pivot
            drawCircle(color = Color(0xFFC0C0C4), radius = 12f, center = pivot)
            drawCircle(color = Color(0xFF333336), radius = 6f, center = pivot)

            // Arm rod
            drawLine(
                color = Color(0xFFE0E0E6),
                start = pivot,
                end = needleHead,
                strokeWidth = 5f,
                cap = StrokeCap.Round
            )

            // Cartridge / Stylus head
            drawCircle(color = Color(0xFF1DB954), radius = 6f, center = needleHead)
        }
    }
}
