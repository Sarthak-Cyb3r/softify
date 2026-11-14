package com.softify.app

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.softify.app.data.PlayerManager
import com.softify.app.theme.*
import com.softify.app.ui.applemusic.AppleMusicMainLayout
import com.softify.app.ui.metrolist.MetrolistMainLayout

@Composable
fun App() {
    val themeMode by PlayerManager.themeMode.collectAsState()
    val currentTrack by PlayerManager.currentTrack.collectAsState()
    val isPlaying by PlayerManager.isPlaying.collectAsState()
    val progress by PlayerManager.progress.collectAsState()
    val volume by PlayerManager.volume.collectAsState()
    val queue by PlayerManager.queue.collectAsState()
    val dynamicColorEnabled by PlayerManager.dynamicColorEnabled.collectAsState()
    val oledBlackEnabled by PlayerManager.oledBlackEnabled.collectAsState()

    // Dynamic color derived from current track artwork seed
    val rawPalette = if (dynamicColorEnabled) {
        ColorExtractor.extractFromTitle(
            title = currentTrack?.title ?: "Softify",
            artist = currentTrack?.artist ?: "Native"
        )
    } else {
        ColorExtractor.extractFromTitle("Softify", "Native")
    }

    val palette = if (oledBlackEnabled) {
        rawPalette.copy(
            background = androidx.compose.ui.graphics.Color.Black,
            surface = androidx.compose.ui.graphics.Color(0xFF0A0A0A)
        )
    } else {
        rawPalette
    }

    Crossfade(
        targetState = themeMode,
        animationSpec = tween(durationMillis = 500)
    ) { mode ->
        when (mode) {
            ThemeMode.METROLIST -> {
                MetrolistTheme(palette = palette) {
                    MetrolistMainLayout(
                        palette = palette,
                        tracks = queue,
                        currentTrack = currentTrack,
                        isPlaying = isPlaying,
                        progress = progress,
                        onTrackSelect = { PlayerManager.playTrack(it) },
                        onThemeToggle = { PlayerManager.toggleTheme() }
                    )
                }
            }
            ThemeMode.APPLE_MUSIC -> {
                AppleMusicTheme(palette = palette) {
                    AppleMusicMainLayout(
                        palette = palette,
                        tracks = queue,
                        currentTrack = currentTrack,
                        isPlaying = isPlaying,
                        progress = progress,
                        volume = volume,
                        onTrackSelect = { PlayerManager.playTrack(it) },
                        onThemeToggle = { PlayerManager.toggleTheme() }
                    )
                }
            }
        }
    }
}
