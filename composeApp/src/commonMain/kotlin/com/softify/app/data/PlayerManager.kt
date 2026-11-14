package com.softify.app.data

import com.softify.app.domain.models.LyricLine
import com.softify.app.domain.models.Lyrics
import com.softify.app.domain.models.Playlist
import com.softify.app.domain.models.Track
import com.softify.app.theme.ThemeMode
import com.softify.app.ui.applemusic.AppleMusicTab
import com.softify.app.ui.metrolist.MetrolistTab
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object PlayerManager {
    private val _themeMode = MutableStateFlow(ThemeMode.METROLIST)
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _metrolistTab = MutableStateFlow(MetrolistTab.HOME)
    val metrolistTab: StateFlow<MetrolistTab> = _metrolistTab.asStateFlow()

    private val _appleMusicTab = MutableStateFlow(AppleMusicTab.LISTEN_NOW)
    val appleMusicTab: StateFlow<AppleMusicTab> = _appleMusicTab.asStateFlow()

    private val _allTracks = listOf(
        Track(
            id = "demo_1",
            sourceId = "saavn_1",
            title = "Tajdar-e-Haram",
            artist = "Atif Aslam, Coke Studio",
            album = "Coke Studio Season 8",
            durationMs = 628000,
            coverUrl = "https://c.saavncdn.com/264/Coke-Studio-Season-8-Episode-1-Urdu-2015-500x500.jpg",
            isLiked = true
        ),
        Track(
            id = "demo_2",
            sourceId = "saavn_2",
            title = "Saajna",
            artist = "Falak Shabir",
            album = "I, Me aur Main",
            durationMs = 258000,
            coverUrl = "https://c.saavncdn.com/835/I-Me-Aur-Main-Hindi-2013-500x500.jpg",
            isLiked = true
        ),
        Track(
            id = "demo_3",
            sourceId = "saavn_3",
            title = "Tu Jaane Na",
            artist = "Atif Aslam",
            album = "Ajab Prem Ki Ghazab Kahani",
            durationMs = 341000,
            coverUrl = "https://c.saavncdn.com/492/Ajab-Prem-Ki-Ghazab-Kahani-Hindi-2009-500x500.jpg",
            isLiked = true
        ),
        Track(
            id = "demo_4",
            sourceId = "saavn_4",
            title = "Kun Faya Kun",
            artist = "A.R. Rahman, Javed Ali, Mohit Chauhan",
            album = "Rockstar",
            durationMs = 473000,
            coverUrl = "https://c.saavncdn.com/393/Rockstar-Hindi-2011-500x500.jpg",
            isLiked = false
        ),
        Track(
            id = "demo_5",
            sourceId = "saavn_5",
            title = "Ajj Din Chadheya",
            artist = "Rahat Fateh Ali Khan",
            album = "Love Aaj Kal",
            durationMs = 316000,
            coverUrl = "https://c.saavncdn.com/512/Love-Aaj-Kal-Hindi-2009-500x500.jpg",
            isLiked = true
        ),
        Track(
            id = "demo_6",
            sourceId = "saavn_6",
            title = "Tum Hi Ho",
            artist = "Arijit Singh",
            album = "Aashiqui 2",
            durationMs = 262000,
            coverUrl = "https://c.saavncdn.com/023/Aashiqui-2-Hindi-2013-500x500.jpg",
            isLiked = true
        ),
        Track(
            id = "demo_7",
            sourceId = "saavn_7",
            title = "Starboy",
            artist = "The Weeknd, Daft Punk",
            album = "Starboy",
            durationMs = 230000,
            coverUrl = "https://upload.wikimedia.org/wikipedia/en/3/39/The_Weeknd_-_Starboy.png",
            isLiked = false
        ),
        Track(
            id = "demo_8",
            sourceId = "saavn_8",
            title = "Blinding Lights",
            artist = "The Weeknd",
            album = "After Hours",
            durationMs = 200000,
            coverUrl = "https://upload.wikimedia.org/wikipedia/en/e/e6/The_Weeknd_-_Blinding_Lights.png",
            isLiked = true
        )
    )

    private val _currentTrack = MutableStateFlow<Track?>(_allTracks[0])
    val currentTrack: StateFlow<Track?> = _currentTrack.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _progress = MutableStateFlow(0.24f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    private val _isPlayerExpanded = MutableStateFlow(false)
    val isPlayerExpanded: StateFlow<Boolean> = _isPlayerExpanded.asStateFlow()

    private val _isLyricsOpen = MutableStateFlow(false)
    val isLyricsOpen: StateFlow<Boolean> = _isLyricsOpen.asStateFlow()

    private val _isQueueOpen = MutableStateFlow(false)
    val isQueueOpen: StateFlow<Boolean> = _isQueueOpen.asStateFlow()

    private val _isEqualizerOpen = MutableStateFlow(false)
    val isEqualizerOpen: StateFlow<Boolean> = _isEqualizerOpen.asStateFlow()

    private val _volume = MutableStateFlow(0.85f)
    val volume: StateFlow<Float> = _volume.asStateFlow()

    private val _isShuffle = MutableStateFlow(false)
    val isShuffle: StateFlow<Boolean> = _isShuffle.asStateFlow()

    private val _isRepeat = MutableStateFlow(false)
    val isRepeat: StateFlow<Boolean> = _isRepeat.asStateFlow()

    private val _dynamicColorEnabled = MutableStateFlow(true)
    val dynamicColorEnabled: StateFlow<Boolean> = _dynamicColorEnabled.asStateFlow()

    private val _oledBlackEnabled = MutableStateFlow(false)
    val oledBlackEnabled: StateFlow<Boolean> = _oledBlackEnabled.asStateFlow()

    private val _audioQuality = MutableStateFlow("Lossless (320kbps FLAC)")
    val audioQuality: StateFlow<String> = _audioQuality.asStateFlow()

    private val _queue = MutableStateFlow(_allTracks)
    val queue: StateFlow<List<Track>> = _queue.asStateFlow()

    private val _playlists = MutableStateFlow(
        listOf(
            Playlist("p1", "Coke Studio Best", "Sufi and folk masterpieces curated in high fidelity", null, 18, "Softify"),
            Playlist("p2", "Late Night Lo-Fi & Chill", "Gentle beats and acoustic melodies", null, 34, "Apple Music"),
            Playlist("p3", "Bollywood Nostalgia 2000s", "Golden era Hindi melodies", null, 42, "Metrolist"),
            Playlist("p4", "Workout Energizer", "140+ BPM high tempo tracks", null, 25, "Softify")
        )
    )
    val playlists: StateFlow<List<Playlist>> = _playlists.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _searchResults = MutableStateFlow<List<Track>>(_allTracks)
    val searchResults: StateFlow<List<Track>> = _searchResults.asStateFlow()

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

    fun setMetrolistTab(tab: MetrolistTab) {
        _metrolistTab.value = tab
    }

    fun setAppleMusicTab(tab: AppleMusicTab) {
        _appleMusicTab.value = tab
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
        } else if (_isRepeat.value && q.isNotEmpty()) {
            playTrack(q[0])
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
        if (!expanded) {
            _isLyricsOpen.value = false
            _isQueueOpen.value = false
            _isEqualizerOpen.value = false
        }
    }

    fun toggleLyrics() {
        _isLyricsOpen.value = !_isLyricsOpen.value
        if (_isLyricsOpen.value) {
            _isQueueOpen.value = false
            _isEqualizerOpen.value = false
        }
    }

    fun toggleQueue() {
        _isQueueOpen.value = !_isQueueOpen.value
        if (_isQueueOpen.value) {
            _isLyricsOpen.value = false
            _isEqualizerOpen.value = false
        }
    }

    fun toggleEqualizer() {
        _isEqualizerOpen.value = !_isEqualizerOpen.value
        if (_isEqualizerOpen.value) {
            _isLyricsOpen.value = false
            _isQueueOpen.value = false
        }
    }

    fun toggleShuffle() {
        _isShuffle.value = !_isShuffle.value
    }

    fun toggleRepeat() {
        _isRepeat.value = !_isRepeat.value
    }

    fun toggleDynamicColor() {
        _dynamicColorEnabled.value = !_dynamicColorEnabled.value
    }

    fun toggleOledBlack() {
        _oledBlackEnabled.value = !_oledBlackEnabled.value
    }

    fun setAudioQuality(quality: String) {
        _audioQuality.value = quality
    }

    fun toggleLike(trackId: String) {
        val update = { list: List<Track> ->
            list.map { if (it.id == trackId) it.copy(isLiked = !it.isLiked) else it }
        }
        _queue.value = update(_queue.value)
        if (_currentTrack.value?.id == trackId) {
            _currentTrack.value = _currentTrack.value?.let { it.copy(isLiked = !it.isLiked) }
        }
    }

    fun removeTrackFromQueue(index: Int) {
        val q = _queue.value.toMutableList()
        if (index in q.indices) {
            q.removeAt(index)
            _queue.value = q
        }
    }

    fun setProgress(prog: Float) {
        _progress.value = prog.coerceIn(0f, 1f)
    }

    fun setVolume(vol: Float) {
        _volume.value = vol.coerceIn(0f, 1f)
    }

    fun search(query: String) {
        _searchQuery.value = query
        if (query.isBlank()) {
            _searchResults.value = _allTracks
        } else {
            _searchResults.value = _allTracks.filter {
                it.title.contains(query, ignoreCase = true) ||
                it.artist.contains(query, ignoreCase = true) ||
                (it.album?.contains(query, ignoreCase = true) == true)
            }
        }
    }
}
