package com.softify.app.data

import com.softify.app.domain.models.LyricLine
import com.softify.app.domain.models.Lyrics
import com.softify.app.domain.models.Track
import com.softify.app.theme.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object PlayerManager {
    private val _themeMode = MutableStateFlow(ThemeMode.METROLIST)
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _currentTrack = MutableStateFlow<Track?>(
        Track(
            id = "demo_1",
            sourceId = "saavn_1",
            title = "Tajdar-e-Haram",
            artist = "Atif Aslam, Coke Studio",
            album = "Coke Studio Season 8",
            durationMs = 628000,
            coverUrl = "https://c.saavncdn.com/264/Coke-Studio-Season-8-Episode-1-Urdu-2015-500x500.jpg",
            isLiked = true
        )
    )
    val currentTrack: StateFlow<Track?> = _currentTrack.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _progress = MutableStateFlow(0.24f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    private val _isPlayerExpanded = MutableStateFlow(false)
    val isPlayerExpanded: StateFlow<Boolean> = _isPlayerExpanded.asStateFlow()

    private val _volume = MutableStateFlow(0.85f)
    val volume: StateFlow<Float> = _volume.asStateFlow()

    private val _queue = MutableStateFlow(
        listOf(
            Track("1", "s1", "Tajdar-e-Haram", "Atif Aslam", "Coke Studio 8", 628000, isLiked = true),
            Track("2", "s2", "Saajna", "Falak Shabir", "I, Me aur Main", 258000, isLiked = true),
            Track("3", "s3", "Tu Jaane Na", "Atif Aslam", "Ajab Prem Ki Ghazab Kahani", 341000, isLiked = true),
            Track("4", "s4", "Kun Faya Kun", "A.R. Rahman, Javed Ali", "Rockstar", 473000, isLiked = false),
            Track("5", "s5", "Ajj Din Chadheya", "Rahat Fateh Ali Khan", "Love Aaj Kal", 316000, isLiked = true)
        )
    )
    val queue: StateFlow<List<Track>> = _queue.asStateFlow()

    private val _lyrics = MutableStateFlow(
        Lyrics(
            trackId = "demo_1",
            lines = listOf(
                LyricLine(0, "Kismat mein meri chain se jeena likh de", "Destiny, write peace into my life"),
                LyricLine(12000, "Doobe na kabhi mera safeena likh de", "Ensure my vessel never sinks"),
                LyricLine(24000, "Tajdar-e-Haram, ho nigaah-e-karam", "King of the Sanctuary, cast your grace"),
                LyricLine(36000, "Hum ghareebon ke din bhi sanwar jaayenge", "Even the days of us humble ones will brighten"),
                LyricLine(50000, "Chashm-e-rahmat kusha, su-e-man be-nawa", "Open the eye of mercy toward helpless me")
            )
        )
    )
    val lyrics: StateFlow<Lyrics?> = _lyrics.asStateFlow()

    fun toggleTheme() {
        _themeMode.value = if (_themeMode.value == ThemeMode.METROLIST) {
            ThemeMode.APPLE_MUSIC
        } else {
            ThemeMode.METROLIST
        }
    }

    fun setTheme(mode: ThemeMode) {
        _themeMode.value = mode
    }

    fun playTrack(track: Track) {
        _currentTrack.value = track
        _isPlaying.value = true
        _progress.value = 0.0f
    }

    fun togglePlayPause() {
        _isPlaying.value = !_isPlaying.value
    }

    fun nextTrack() {
        val q = _queue.value
        val currentIndex = q.indexOfFirst { it.id == _currentTrack.value?.id }
        if (currentIndex != -1 && currentIndex + 1 < q.size) {
            playTrack(q[currentIndex + 1])
        }
    }

    fun previousTrack() {
        val q = _queue.value
        val currentIndex = q.indexOfFirst { it.id == _currentTrack.value?.id }
        if (currentIndex > 0) {
            playTrack(q[currentIndex - 1])
        }
    }

    fun setPlayerExpanded(expanded: Boolean) {
        _isPlayerExpanded.value = expanded
    }

    fun setProgress(prog: Float) {
        _progress.value = prog.coerceIn(0f, 1f)
    }

    fun setVolume(vol: Float) {
        _volume.value = vol.coerceIn(0f, 1f)
    }
}
