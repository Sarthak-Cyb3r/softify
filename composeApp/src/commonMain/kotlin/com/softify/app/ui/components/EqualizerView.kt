package com.softify.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.theme.DynamicColorPalette

@Composable
fun EqualizerView(
    palette: DynamicColorPalette,
    isAppleMusic: Boolean = false,
    onClose: () -> Unit
) {
    val presets = listOf("Flat", "Bass Boost", "Vocal", "Electronic", "Rock", "Pop", "Acoustic")
    var selectedPreset by remember { mutableStateOf("Bass Boost") }

    val bandFrequencies = listOf("32Hz", "64Hz", "125Hz", "250Hz", "500Hz", "1kHz", "2kHz", "4kHz", "8kHz", "16kHz")
    var gains by remember {
        mutableStateOf(floatArrayOf(6f, 5f, 3f, 1f, 0f, 1f, 2f, 4f, 5f, 6f))
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
            .background(if (isAppleMusic) Color(0xFF1C1C1E).copy(alpha = 0.95f) else palette.surface)
            .padding(24.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Equalizer & DSP",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "10-Band Parametric Tuning",
                    fontSize = 13.sp,
                    color = if (isAppleMusic) Color.White.copy(alpha = 0.6f) else palette.primary
                )
            }

            IconButton(
                onClick = onClose,
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.12f))
            ) {
                Text(text = "✕", color = Color.White, fontSize = 14.sp)
            }
        }

        Spacer(modifier = Modifier.height(18.dp))

        // Preset Chips
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(presets) { preset ->
                val isSelected = preset == selectedPreset
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(100.dp))
                        .background(
                            when {
                                isSelected && isAppleMusic -> Color.White
                                isSelected -> palette.primary
                                else -> Color.White.copy(alpha = 0.08f)
                            }
                        )
                        .clickable {
                            selectedPreset = preset
                            gains = when (preset) {
                                "Bass Boost" -> floatArrayOf(8f, 7f, 5f, 2f, 0f, 0f, 1f, 2f, 3f, 4f)
                                "Vocal" -> floatArrayOf(-2f, -1f, 1f, 4f, 6f, 5f, 3f, 1f, 0f, -1f)
                                "Electronic" -> floatArrayOf(6f, 5f, 2f, 0f, -1f, 2f, 4f, 6f, 6f, 5f)
                                "Rock" -> floatArrayOf(5f, 3f, 1f, 0f, -1f, 1f, 3f, 5f, 6f, 6f)
                                "Pop" -> floatArrayOf(2f, 4f, 5f, 4f, 2f, 0f, 1f, 3f, 4f, 4f)
                                "Acoustic" -> floatArrayOf(4f, 3f, 2f, 1f, 2f, 3f, 3f, 4f, 4f, 3f)
                                else -> floatArrayOf(0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f)
                            }
                        }
                        .padding(horizontal = 14.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = preset,
                        color = when {
                            isSelected && isAppleMusic -> Color.Black
                            isSelected -> palette.onPrimary
                            else -> Color.White
                        },
                        fontSize = 12.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // 10-Band Sliders Bar Graph
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom
        ) {
            bandFrequencies.forEachIndexed { index, freq ->
                val gain = gains.getOrElse(index) { 0f }
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.weight(1f)
                ) {
                    Text(
                        text = "${if (gain > 0) "+" else ""}${gain.toInt()}dB",
                        fontSize = 10.sp,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Box(
                        modifier = Modifier
                            .width(18.dp)
                            .height(120.dp)
                            .clip(RoundedCornerShape(9.dp))
                            .background(Color.White.copy(alpha = 0.08f)),
                        contentAlignment = Alignment.BottomCenter
                    ) {
                        val normalizedHeight = ((gain + 12f) / 24f).coerceIn(0.05f, 1.0f)
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .fillMaxHeight(normalizedHeight)
                                .clip(RoundedCornerShape(9.dp))
                                .background(if (isAppleMusic) Color.White else palette.primary)
                        )
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = freq,
                        fontSize = 9.sp,
                        color = Color.White.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}
