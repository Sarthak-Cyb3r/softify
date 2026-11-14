package com.softify.app

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.softify.app.data.PlayerManager
import com.softify.app.theme.*
import com.softify.app.ui.applemusic.AppleMusicHomeScreen
import com.softify.app.ui.metrolist.MetrolistHomeScreen

@Composable
fun App() {
    val themeMode by PlayerManager.themeMode.collectAsState()
    val currentTrack by PlayerManager.currentTrack.collectAsState()
    val isPlaying by PlayerManager.isPlaying.collectAsState()
    val queue by PlayerManager.queue.collectAsState()

    // Dynamic color derived from current track artwork seed
    val palette = ColorExtractor.extractFromTitle(
        title = currentTrack?.title ?: "Softify",
        artist = currentTrack?.artist ?: "Native"
    )

    Crossfade(
        targetState = themeMode,
        animationSpec = tween(durationMillis = 600)
    ) { mode ->
        when (mode) {
            ThemeMode.METROLIST -> {
                MetrolistTheme(palette = palette) {
                    MetrolistHomeScreen(
                        palette = palette,
                        tracks = queue,
                        currentTrack = currentTrack,
                        isPlaying = isPlaying,
                        onTrackSelect = { PlayerManager.playTrack(it) },
                        onThemeToggle = { PlayerManager.toggleTheme() }
                    )
                }
            }
            ThemeMode.APPLE_MUSIC -> {
                AppleMusicTheme(palette = palette) {
                    AppleMusicHomeScreen(
                        palette = palette,
                        tracks = queue,
                        currentTrack = currentTrack,
                        isPlaying = isPlaying,
                        onTrackSelect = { PlayerManager.playTrack(it) },
                        onThemeToggle = { PlayerManager.toggleTheme() }
                    )
                }
            }
        }
    }
}
