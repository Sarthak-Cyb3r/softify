package com.softify.app.ui.metrolist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import com.softify.app.data.PlayerManager
import com.softify.app.theme.DynamicColorPalette
import com.softify.app.theme.ThemeMode
import com.softify.app.ui.components.SegmentedThemeToggle
import com.softify.app.ui.components.SoftifyIcons

@Composable
fun MetrolistSettingsScreen(
    palette: DynamicColorPalette
) {
    val themeMode by PlayerManager.themeMode.collectAsState()
    val dynamicColorEnabled by PlayerManager.dynamicColorEnabled.collectAsState()
    val oledBlackEnabled by PlayerManager.oledBlackEnabled.collectAsState()
    val audioQuality by PlayerManager.audioQuality.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Settings",
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        // Appearance Section
        item {
            Text(
                text = "Appearance & Interface",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = palette.primary
            )
            Spacer(modifier = Modifier.height(10.dp))

            Surface(
                shape = RoundedCornerShape(20.dp),
                color = palette.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // UI Mode Selector
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Design Language",
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 15.sp
                            )
                            Text(
                                text = if (themeMode == ThemeMode.METROLIST) "Metrolist (Material 3)" else "Apple Music (Liquid Glass)",
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 13.sp
                            )
                        }

                        SegmentedThemeToggle(
                            themeMode = themeMode,
                            accentColor = palette.primary,
                            onToggle = { mode ->
                                if (mode != themeMode) PlayerManager.toggleTheme()
                            }
                        )
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = Color.White.copy(alpha = 0.08f))

                    // Dynamic Color Toggle
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Dynamic Color Palette",
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 15.sp
                            )
                            Text(
                                text = "Extract UI color from active album art",
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 13.sp
                            )
                        }

                        Switch(
                            checked = dynamicColorEnabled,
                            onCheckedChange = { PlayerManager.toggleDynamicColor() },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = palette.onPrimary,
                                checkedTrackColor = palette.primary
                            )
                        )
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = Color.White.copy(alpha = 0.08f))

                    // OLED Black
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Pure OLED Black",
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 15.sp
                            )
                            Text(
                                text = "Pitch-black background for OLED displays",
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 13.sp
                            )
                        }

                        Switch(
                            checked = oledBlackEnabled,
                            onCheckedChange = { PlayerManager.toggleOledBlack() },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = palette.onPrimary,
                                checkedTrackColor = palette.primary
                            )
                        )
                    }
                }
            }
        }

        // Audio & Playback Section
        item {
            Text(
                text = "Audio & Processing",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = palette.primary
            )
            Spacer(modifier = Modifier.height(10.dp))

            Surface(
                shape = RoundedCornerShape(20.dp),
                color = palette.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Audio Quality
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Audio Quality",
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 15.sp
                            )
                            Text(
                                text = audioQuality,
                                color = palette.primary,
                                fontSize = 13.sp
                            )
                        }

                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            listOf("320k", "256k", "160k").forEach { q ->
                                val isSelected = audioQuality.contains(q)
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(if (isSelected) palette.primary else Color.White.copy(alpha = 0.08f))
                                    .clickable {
                                        PlayerManager.setAudioQuality(
                                            when (q) {
                                                "320k" -> "Lossless (320kbps FLAC)"
                                                "256k" -> "High (256kbps AAC)"
                                                else -> "Standard (160kbps MP3)"
                                            }
                                        )
                                    }
                                    .padding(horizontal = 10.dp, vertical = 6.dp)
                                ) {
                                    Text(
                                        text = q,
                                        fontSize = 12.sp,
                                        color = if (isSelected) palette.onPrimary else Color.White,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = Color.White.copy(alpha = 0.08f))

                    // Equalizer Launch
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { PlayerManager.toggleEqualizer() }
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Equalizer & Sound Effects",
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 15.sp
                            )
                            Text(
                                text = "10-Band Parametric DSP Tuning",
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 13.sp
                            )
                        }

                        Surface(
                            shape = RoundedCornerShape(100.dp),
                            color = palette.primaryContainer.copy(alpha = 0.5f)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(
                                    imageVector = SoftifyIcons.Equalizer,
                                    contentDescription = null,
                                    tint = palette.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                                Text(text = "Open DSP", color = palette.primary, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                        }
                    }
                }
            }
        }

        // About Section
        item {
            Text(
                text = "About",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = palette.primary
            )
            Spacer(modifier = Modifier.height(10.dp))

            Surface(
                shape = RoundedCornerShape(20.dp),
                color = palette.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Text(
                        text = "Softify v4.0.3",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Zero Dart • Kotlin Compose Multiplatform & Native Rust Engine",
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 13.sp
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "Dual UI/UX: Metrolist (Material 3 Expressive) & Apple Music (Liquid Glass Frosted Overlays) with real-time dynamic artwork color extraction.",
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 12.sp
                    )
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}
