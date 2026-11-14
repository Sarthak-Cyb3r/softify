package com.softify.app.ui.applemusic

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
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

@Composable
fun AppleMusicMainLayout(
    palette: DynamicColorPalette,
    tracks: List<Track>,
    currentTrack: Track?,
    isPlaying: Boolean,
    progress: Float,
    volume: Float,
    onTrackSelect: (Track) -> Unit,
    onThemeToggle: () -> Unit
) {
    val activeTab by PlayerManager.appleMusicTab.collectAsState()
    val isPlayerExpanded by PlayerManager.isPlayerExpanded.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(palette.ambientGradientStops))
    ) {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF141416).copy(alpha = 0.85f))
                ) {
                    // Apple Music Frosted Mini Player
                    currentTrack?.let { track ->
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 6.dp)
                        ) {
                            AppleMusicMiniPlayer(
                                currentTrack = track,
                                isPlaying = isPlaying,
                                onPlayPause = { PlayerManager.togglePlayPause() },
                                onExpand = { PlayerManager.setPlayerExpanded(true) }
                            )
                        }
                    }

                    // iOS Frosted Glass Tab Bar
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(64.dp)
                            .padding(horizontal = 12.dp),
                        horizontalArrangement = Arrangement.SpaceAround,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AppleMusicTab.entries.forEach { tab ->
                            val isSelected = tab == activeTab
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(12.dp))
                                    .clickable { PlayerManager.setAppleMusicTab(tab) }
                                    .padding(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Text(
                                    text = tab.icon,
                                    fontSize = 18.sp,
                                    color = if (isSelected) Color(0xFFFF2D55) else Color.White.copy(alpha = 0.5f)
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = tab.label,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isSelected) Color(0xFFFF2D55) else Color.White.copy(alpha = 0.5f)
                                )
                            }
                        }
                    }
                }
            }
        ) { paddingValues ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                when (activeTab) {
                    AppleMusicTab.LISTEN_NOW -> {
                        AppleMusicHomeScreen(
                            palette = palette,
                            tracks = tracks,
                            currentTrack = currentTrack,
                            isPlaying = isPlaying,
                            onTrackSelect = onTrackSelect,
                            onThemeToggle = onThemeToggle
                        )
                    }
                    AppleMusicTab.BROWSE -> {
                        AppleMusicBrowseScreen(
                            palette = palette,
                            tracks = tracks,
                            onTrackSelect = onTrackSelect
                        )
                    }
                    AppleMusicTab.RADIO -> {
                        AppleMusicRadioScreen(
                            palette = palette,
                            tracks = tracks,
                            onTrackSelect = onTrackSelect
                        )
                    }
                    AppleMusicTab.LIBRARY -> {
                        AppleMusicLibraryScreen(
                            palette = palette,
                            tracks = tracks,
                            onTrackSelect = onTrackSelect
                        )
                    }
                    AppleMusicTab.SEARCH -> {
                        AppleMusicSearchScreen(
                            palette = palette,
                            onTrackSelect = onTrackSelect
                        )
                    }
                }
            }
        }

        // Fullscreen Expandable Apple Music Player Sheet
        AnimatedVisibility(
            visible = isPlayerExpanded && currentTrack != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut()
        ) {
            currentTrack?.let { track ->
                AppleMusicPlayerSheet(
                    track = track,
                    palette = palette,
                    isPlaying = isPlaying,
                    progress = progress,
                    volume = volume,
                    onClose = { PlayerManager.setPlayerExpanded(false) }
                )
            }
        }
    }
}
