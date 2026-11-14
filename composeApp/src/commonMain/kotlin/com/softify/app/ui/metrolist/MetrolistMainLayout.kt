package com.softify.app.ui.metrolist

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.data.PlayerManager
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette

@Composable
fun MetrolistMainLayout(
    palette: DynamicColorPalette,
    tracks: List<Track>,
    currentTrack: Track?,
    isPlaying: Boolean,
    progress: Float,
    onTrackSelect: (Track) -> Unit,
    onThemeToggle: () -> Unit
) {
    val activeTab by PlayerManager.metrolistTab.collectAsState()
    val isPlayerExpanded by PlayerManager.isPlayerExpanded.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
    ) {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(palette.surface.copy(alpha = 0.95f))
                ) {
                    // Mini player floating right above the navigation bar
                    currentTrack?.let { track ->
                        MetrolistMiniPlayer(
                            palette = palette,
                            currentTrack = track,
                            isPlaying = isPlaying,
                            onPlayPause = { PlayerManager.togglePlayPause() },
                            onExpand = { PlayerManager.setPlayerExpanded(true) }
                        )
                    }

                    // Material 3 Expressive Bottom Navigation Bar
                    NavigationBar(
                        containerColor = Color.Transparent,
                        contentColor = Color.White,
                        tonalElevation = 0.dp,
                        modifier = Modifier.height(68.dp)
                    ) {
                        MetrolistTab.entries.forEach { tab ->
                            val isSelected = tab == activeTab
                            NavigationBarItem(
                                selected = isSelected,
                                onClick = { PlayerManager.setMetrolistTab(tab) },
                                icon = {
                                    Text(
                                        text = tab.icon,
                                        fontSize = 18.sp
                                    )
                                },
                                label = {
                                    Text(
                                        text = tab.label,
                                        fontSize = 11.sp,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                    )
                                },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = palette.onPrimary,
                                    selectedTextColor = palette.primary,
                                    indicatorColor = palette.primaryContainer,
                                    unselectedIconColor = Color.White.copy(alpha = 0.5f),
                                    unselectedTextColor = Color.White.copy(alpha = 0.5f)
                                )
                            )
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
                    MetrolistTab.HOME -> {
                        MetrolistHomeScreen(
                            palette = palette,
                            tracks = tracks,
                            currentTrack = currentTrack,
                            isPlaying = isPlaying,
                            onTrackSelect = onTrackSelect,
                            onThemeToggle = onThemeToggle
                        )
                    }
                    MetrolistTab.SEARCH -> {
                        MetrolistSearchScreen(
                            palette = palette,
                            onTrackSelect = onTrackSelect
                        )
                    }
                    MetrolistTab.LIBRARY -> {
                        MetrolistLibraryScreen(
                            palette = palette,
                            onTrackSelect = onTrackSelect
                        )
                    }
                    MetrolistTab.SETTINGS -> {
                        MetrolistSettingsScreen(
                            palette = palette
                        )
                    }
                }
            }
        }

        // Full Screen Expandable Player BottomSheet
        AnimatedVisibility(
            visible = isPlayerExpanded && currentTrack != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut()
        ) {
            currentTrack?.let { track ->
                MetrolistPlayerSheet(
                    track = track,
                    palette = palette,
                    isPlaying = isPlaying,
                    progress = progress,
                    onClose = { PlayerManager.setPlayerExpanded(false) }
                )
            }
        }
    }
}
