package com.softify.app.viewmodel

import com.softify.app.playback.QueueManager
import com.softify.app.playback.QueueState
import com.softify.app.playback.RepeatMode
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uniffi.softify_core.*

enum class UiStyle {
    METROLIST,
    APPLE_MUSIC,
}

enum class NavigationTab {
    HOME,
    SEARCH,
    LIBRARY,
}

class PlaybackViewModel(
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main)
) {
    // System Diagnostics properties
    var appVersion: String = "4.3.0-experimental"
    var osVersion: String = "Unknown OS"
    var abi: String = "Unknown ABI"
    var isNativeLibLoaded: Boolean = false
    var isMediaControllerConnected: Boolean = false

    // JankStats Telemetry
    var jankTotalFrames: Long = 0L
    var jankFramesCount: Long = 0L
    var jankPercentage: Float = 0f
    var maxFrameDurationMs: Long = 0L

    // Debug Component Gallery State
    private val _isGalleryOpen = MutableStateFlow(false)
    val isGalleryOpen: StateFlow<Boolean> = _isGalleryOpen.asStateFlow()

    fun openComponentGallery() {
        _isGalleryOpen.value = true
    }

    fun closeComponentGallery() {
        _isGalleryOpen.value = false
    }

    // Queue Manager (Single Source of Truth)
    val queueManager = QueueManager(scope = scope)
    val queueState: StateFlow<QueueState> = queueManager.queueState

    private val _currentTab = MutableStateFlow(NavigationTab.HOME)
    val currentTab: StateFlow<NavigationTab> = _currentTab.asStateFlow()

    // Home Shelves State
    private val _homeShelves = MutableStateFlow<List<Shelf>>(emptyList())
    val homeShelves: StateFlow<List<Shelf>> = _homeShelves.asStateFlow()

    private val _isHomeLoading = MutableStateFlow(false)
    val isHomeLoading: StateFlow<Boolean> = _isHomeLoading.asStateFlow()

    private val _homeError = MutableStateFlow<String?>(null)
    val homeError: StateFlow<String?> = _homeError.asStateFlow()

    // Search State
    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _localSearchResults = MutableStateFlow<List<Track>>(emptyList())
    val localSearchResults: StateFlow<List<Track>> = _localSearchResults.asStateFlow()

    private val _onlineSearchResults = MutableStateFlow<List<Track>>(emptyList())
    val onlineSearchResults: StateFlow<List<Track>> = _onlineSearchResults.asStateFlow()

    private val _recentSearches = MutableStateFlow<List<String>>(emptyList())
    val recentSearches: StateFlow<List<String>> = _recentSearches.asStateFlow()

    private val _detectedIntent = MutableStateFlow(SearchIntent.GENERAL)
    val detectedIntent: StateFlow<SearchIntent> = _detectedIntent.asStateFlow()

    private val _detectedEntity = MutableStateFlow<String?>(null)
    val detectedEntity: StateFlow<String?> = _detectedEntity.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    // Active Playback State
    private val _activeTrack = MutableStateFlow<Track?>(null)
    val activeTrack: StateFlow<Track?> = _activeTrack.asStateFlow()

    private val _activeStream = MutableStateFlow<StreamInfo?>(null)
    val activeStream: StateFlow<StreamInfo?> = _activeStream.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _playbackProgress = MutableStateFlow(0f)
    val playbackProgress: StateFlow<Float> = _playbackProgress.asStateFlow()

    private val _qualityPreset = MutableStateFlow(QualityPreset.HIGH)
    val qualityPreset: StateFlow<QualityPreset> = _qualityPreset.asStateFlow()

    private val _uiStyle = MutableStateFlow(UiStyle.METROLIST)
    val uiStyle: StateFlow<UiStyle> = _uiStyle.asStateFlow()

    private val _isIncognito = MutableStateFlow(false)
    val isIncognito: StateFlow<Boolean> = _isIncognito.asStateFlow()

    // Library State
    private val _likedTracks = MutableStateFlow<List<Track>>(emptyList())
    val likedTracks: StateFlow<List<Track>> = _likedTracks.asStateFlow()

    private val _playlists = MutableStateFlow<List<Playlist>>(emptyList())
    val playlists: StateFlow<List<Playlist>> = _playlists.asStateFlow()

    private val _history = MutableStateFlow<List<PlayHistory>>(emptyList())
    val history: StateFlow<List<PlayHistory>> = _history.asStateFlow()

    // Smart Playlists
    private val _smartOnRepeat = MutableStateFlow<List<Track>>(emptyList())
    val smartOnRepeat: StateFlow<List<Track>> = _smartOnRepeat.asStateFlow()

    private val _smartMostPlayed = MutableStateFlow<List<Track>>(emptyList())
    val smartMostPlayed: StateFlow<List<Track>> = _smartMostPlayed.asStateFlow()

    private val _smartForgottenFavorites = MutableStateFlow<List<Track>>(emptyList())
    val smartForgottenFavorites: StateFlow<List<Track>> = _smartForgottenFavorites.asStateFlow()

    // Snackbar event bus for user-facing errors
    private val _snackbarEvents = MutableSharedFlow<String>(extraBufferCapacity = 10)
    val snackbarEvents: SharedFlow<String> = _snackbarEvents.asSharedFlow()

    private var searchJob: Job? = null
    var onStreamReadyForPlayback: ((Track, StreamInfo) -> Unit)? = null
    var onTogglePlayPauseRequested: (() -> Unit)? = null
    var onShareText: ((String) -> Unit)? = null
    var onPlayTestUrlRequested: ((String) -> Unit)? = null
    var onProbeYouTubeRequested: (() -> Unit)? = null

    init {
        refreshAll()
    }

    fun showSnackbar(message: String) {
        PlaybackLogger.log("SoftifyPlayback", "Snackbar: $message")
        _snackbarEvents.tryEmit(message)
    }

    fun setIsPlaying(playing: Boolean) {
        _isPlaying.value = playing
    }

    fun setPlaybackProgress(progress: Float) {
        _playbackProgress.value = progress.coerceIn(0f, 1f)
    }

    fun setTab(tab: NavigationTab) {
        _currentTab.value = tab
        when (tab) {
            NavigationTab.HOME -> loadHomeExplore()
            NavigationTab.SEARCH -> loadRecentSearches()
            NavigationTab.LIBRARY -> refreshLibrary()
        }
    }

    fun refreshAll() {
        refreshLibrary()
        loadHomeExplore()
        loadRecentSearches()
        checkIncognitoStatus()
    }

    private fun checkIncognitoStatus() {
        scope.launch(Dispatchers.Default) {
            try {
                _isIncognito.value = isLearningPaused()
            } catch (_: Exception) {}
        }
    }

    fun toggleIncognito() {
        val next = !_isIncognito.value
        scope.launch(Dispatchers.Default) {
            try {
                setLearningPaused(next)
                _isIncognito.value = next
                val stateText = if (next) "Incognito ON (history & learning paused)" else "Incognito OFF"
                PlaybackLogger.log("SoftifyPlayback", stateText)
                showSnackbar(stateText)
            } catch (e: Exception) {
                showSnackbar("Failed to toggle incognito: ${e.message}")
            }
        }
    }

    fun refreshLibrary() {
        scope.launch(Dispatchers.Default) {
            try {
                _likedTracks.value = getLikedTracks()
                _playlists.value = getPlaylists()
                _history.value = getHistory(25u)
                loadSmartPlaylists()
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Library refresh error: ${e.message}")
            }
        }
    }

    fun loadSmartPlaylists() {
        scope.launch(Dispatchers.Default) {
            try {
                _smartOnRepeat.value = getOnRepeatTracks(null)
                _smartMostPlayed.value = getMostPlayedTracks(null)
                _smartForgottenFavorites.value = getForgottenFavoritesTracks(null)
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Smart playlists load error: ${e.message}")
            }
        }
    }

    fun loadHomeExplore() {
        _isHomeLoading.value = true
        _homeError.value = null
        scope.launch(Dispatchers.Default) {
            try {
                // Try personalized recommendation shelves first
                var shelves = runCatching { getRecommendationShelves() }.getOrDefault(emptyList())
                val hasTracks = shelves.any { it.tracks.isNotEmpty() }

                if (!hasTracks) {
                    // Fall back to explore charts / trending (fixture or online)
                    shelves = homeExplore()
                }

                _homeShelves.value = shelves
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Home explore error: ${e.message}")
                _homeError.value = e.message ?: "Failed to load explore content"
            } finally {
                _isHomeLoading.value = false
            }
        }
    }

    fun loadRecentSearches() {
        scope.launch(Dispatchers.Default) {
            try {
                _recentSearches.value = getRecentSearches(15u)
            } catch (_: Exception) {}
        }
    }

    fun deleteRecentSearchItem(query: String) {
        scope.launch(Dispatchers.Default) {
            try {
                deleteRecentSearch(query)
                loadRecentSearches()
            } catch (_: Exception) {}
        }
    }

    fun clearAllRecentSearches() {
        scope.launch(Dispatchers.Default) {
            try {
                clearRecentSearches()
                _recentSearches.value = emptyList()
            } catch (_: Exception) {}
        }
    }

    fun onSearchQueryChanged(query: String) {
        _searchQuery.value = query
        searchJob?.cancel()

        if (query.trim().isEmpty()) {
            _localSearchResults.value = emptyList()
            _onlineSearchResults.value = emptyList()
            _detectedIntent.value = SearchIntent.GENERAL
            _detectedEntity.value = null
            _isSearching.value = false
            loadRecentSearches()
            return
        }

        // 1. Instant local FTS5 search (synchronous, <10ms)
        try {
            _localSearchResults.value = searchLibrary(query, 10u)
        } catch (_: Exception) {}

        // 2. Debounced combined async search (300ms) with online queries
        searchJob = scope.launch(Dispatchers.Default) {
            kotlinx.coroutines.delay(300L)
            _isSearching.value = true
            try {
                val combined = searchCombined(query, 25u)
                _localSearchResults.value = combined.localTracks
                _onlineSearchResults.value = combined.onlineTracks
                _detectedIntent.value = combined.intent
                _detectedEntity.value = combined.detectedEntity

                // Record search query in DB (skipped if incognito in Rust core)
                runCatching { recordSearchQuery(query) }
            } catch (e: Exception) {
                // Ignore cancellation
            } finally {
                _isSearching.value = false
            }
        }
    }

    fun toggleLikeTrack(track: Track) {
        scope.launch(Dispatchers.Default) {
            try {
                saveTrack(track)
                val newLikedState = toggleLike(track.id)
                if (_activeTrack.value?.id == track.id) {
                    _activeTrack.value = _activeTrack.value?.copy(isLiked = newLikedState)
                }
                refreshLibrary()
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Failed to toggle like: ${e.message}")
            }
        }
    }

    fun createNewPlaylist(name: String, description: String? = null) {
        scope.launch(Dispatchers.Default) {
            try {
                createPlaylist(name, description)
                refreshLibrary()
                showSnackbar("Created playlist '$name'")
            } catch (e: Exception) {
                showSnackbar("Failed to create playlist: ${e.message}")
            }
        }
    }

    fun renameUserPlaylist(playlistId: String, newName: String) {
        scope.launch(Dispatchers.Default) {
            try {
                renamePlaylist(playlistId, newName)
                refreshLibrary()
                showSnackbar("Renamed playlist to '$newName'")
            } catch (e: Exception) {
                showSnackbar("Failed to rename playlist: ${e.message}")
            }
        }
    }

    fun deleteUserPlaylist(playlistId: String) {
        scope.launch(Dispatchers.Default) {
            try {
                deletePlaylist(playlistId)
                refreshLibrary()
                showSnackbar("Deleted playlist")
            } catch (e: Exception) {
                showSnackbar("Failed to delete playlist: ${e.message}")
            }
        }
    }

    fun addTrackToPlaylist(playlistId: String, track: Track) {
        scope.launch(Dispatchers.Default) {
            try {
                saveTrack(track)
                addToPlaylist(playlistId, track.id)
                refreshLibrary()
                showSnackbar("Added '${track.title}' to playlist")
            } catch (e: Exception) {
                showSnackbar("Failed to add to playlist: ${e.message}")
            }
        }
    }

    fun removeTrackFromPlaylist(playlistId: String, trackId: String) {
        scope.launch(Dispatchers.Default) {
            try {
                removeFromPlaylist(playlistId, trackId)
                refreshLibrary()
                showSnackbar("Removed track from playlist")
            } catch (e: Exception) {
                showSnackbar("Failed to remove track: ${e.message}")
            }
        }
    }

    fun importSpotify(urlOrId: String) {
        scope.launch(Dispatchers.Default) {
            showSnackbar("Importing Spotify playlist...")
            try {
                val res = importSpotifyPlaylist(urlOrId)
                refreshLibrary()
                showSnackbar("Imported '${res.playlist.name}' (${res.tracksMatched}/${res.tracksTotal} tracks matched)")
            } catch (e: Exception) {
                showSnackbar("Spotify import failed: ${e.message}")
            }
        }
    }

    fun clearListeningHistory() {
        scope.launch(Dispatchers.Default) {
            try {
                clearHistory()
                _history.value = emptyList()
                loadSmartPlaylists()
                showSnackbar("Listening history cleared")
            } catch (e: Exception) {
                showSnackbar("Failed to clear history: ${e.message}")
            }
        }
    }

    // Playback and Queue Controls
    fun playTrack(track: Track) {
        queueManager.setQueue(listOf(track), startIndex = 0)
        executePlayTrack(track)
    }

    fun playTrackInQueue(tracks: List<Track>, startIndex: Int) {
        if (tracks.isEmpty()) return
        queueManager.setQueue(tracks, startIndex)
        val target = tracks.getOrNull(startIndex) ?: return
        executePlayTrack(target)
    }

    fun playNext(track: Track) {
        queueManager.playNext(track)
        showSnackbar("Playing next: '${track.title}'")
    }

    fun addToQueue(track: Track) {
        queueManager.addToQueue(track)
        showSnackbar("Added to queue: '${track.title}'")
    }

    fun skipNext() {
        val next = queueManager.skipNext()
        if (next != null) {
            executePlayTrack(next)
        } else {
            showSnackbar("End of queue")
        }
    }

    fun skipPrevious() {
        val prev = queueManager.skipPrevious()
        if (prev != null) {
            executePlayTrack(prev)
        }
    }

    fun onTrackEnded() {
        PlaybackLogger.log("SoftifyPlayback", "onTrackEnded received in ViewModel")
        val next = queueManager.onTrackEnded()
        if (next != null) {
            executePlayTrack(next)
        } else {
            _isPlaying.value = false
            PlaybackLogger.log("SoftifyPlayback", "Queue finished; stopping playback")
        }
    }

    fun toggleRepeat() {
        val mode = queueManager.toggleRepeatMode()
        val text = when (mode) {
            RepeatMode.OFF -> "Repeat OFF"
            RepeatMode.ALL -> "Repeat ALL"
            RepeatMode.ONE -> "Repeat ONE"
        }
        showSnackbar(text)
    }

    fun toggleShuffle() {
        val isShuffle = queueManager.toggleShuffle()
        showSnackbar(if (isShuffle) "Shuffle ON" else "Shuffle OFF")
    }

    private fun executePlayTrack(track: Track) {
        PlaybackLogger.log("SoftifyPlayback", "executePlayTrack: '${track.title}' (${track.id})")
        scope.launch {
            _activeTrack.value = track
            _isPlaying.value = true
            _playbackProgress.value = 0f

            try {
                val stream = queueManager.resolveTrackStream(track, _qualityPreset.value)
                _activeStream.value = stream

                val host = runCatching { java.net.URI(stream.url).host ?: "unknown" }.getOrDefault("unknown")
                PlaybackLogger.log(
                    "SoftifyPlayback",
                    "Resolve end: provider=${stream.provider}, bitrate=${stream.bitrateKbps}kbps, codec=${stream.codec}, host=$host"
                )

                val handler = onStreamReadyForPlayback
                if (handler != null) {
                    handler.invoke(track, stream)
                } else {
                    val errMsg = "Playback service not connected or handler missing"
                    PlaybackLogger.log("SoftifyPlayback", "ERROR: $errMsg")
                    showSnackbar(errMsg)
                }

                // Pre-resolve next track in background
                queueManager.preResolveNext(_qualityPreset.value)
                refreshLibrary()
            } catch (e: Exception) {
                val errMsg = "Rust resolver error for '${track.title}': ${e.message}"
                PlaybackLogger.log("SoftifyPlayback", errMsg)
                showSnackbar("Resolve failed: ${e.message ?: "Unknown error"}")
                _isPlaying.value = false
            }
        }
    }

    fun togglePlayPause() {
        val req = onTogglePlayPauseRequested
        if (req != null) {
            req.invoke()
        } else {
            _isPlaying.value = !_isPlaying.value
        }
    }

    fun setQualityPreset(preset: QualityPreset) {
        _qualityPreset.value = preset
        val track = _activeTrack.value
        if (track != null && _isPlaying.value) {
            executePlayTrack(track)
        }
    }

    fun setUiStyle(style: UiStyle) {
        _uiStyle.value = style
    }

    // Diagnostics test actions
    fun playTestDirectUrl(url: String = "https://storage.googleapis.com/exoplayer-test-media-0/play.mp3") {
        PlaybackLogger.log("SoftifyPlayback", "Test button: 'Play test URL' tapped ($url)")
        val testTrack = Track(
            id = "direct_test_track",
            sourceId = "direct_test_track",
            title = "ExoPlayer Direct Test Audio",
            artist = "Google Cloud Storage",
            album = "Diagnostics Bypass",
            durationMs = 120_000u,
            coverUrl = null,
            matchConfidence = null,
            isLiked = false,
            isUnavailable = false
        )
        val testStream = StreamInfo(
            url = url,
            container = "mp3",
            bitrateKbps = 128u,
            codec = "mp3",
            provider = "direct_http_test (ExoPlayer sample)",
            isRequestedQuality = false,
            headers = emptyList(),
            expiresAt = null
        )
        _activeTrack.value = testTrack
        _activeStream.value = testStream
        _isPlaying.value = true

        val testReq = onPlayTestUrlRequested
        if (testReq != null) {
            testReq.invoke(url)
        } else {
            onStreamReadyForPlayback?.invoke(testTrack, testStream)
        }
    }

    fun resolveOnlyTestTrack() {
        PlaybackLogger.log("SoftifyPlayback", "Test button: 'Resolve only' tapped for 'Tum Hi Ho'")
        scope.launch {
            try {
                val fixedTrack = Track(
                    id = "s6zuKkD9",
                    sourceId = "s6zuKkD9",
                    title = "Tum Hi Ho",
                    artist = "Arijit Singh",
                    album = "Aashiqui 2",
                    durationMs = 262_000u,
                    coverUrl = null,
                    matchConfidence = null,
                    isLiked = false,
                    isUnavailable = false
                )
                PlaybackLogger.log("SoftifyPlayback", "Resolving 'Tum Hi Ho' (preset=${_qualityPreset.value})...")
                val stream = resolveStream(fixedTrack, _qualityPreset.value)
                val host = runCatching { java.net.URI(stream.url).host ?: "unknown" }.getOrDefault("unknown")
                val resultMsg = "Resolved 'Tum Hi Ho': provider=${stream.provider}, bitrate=${stream.bitrateKbps}kbps, host=$host, requested_quality_met=${stream.isRequestedQuality}"
                PlaybackLogger.log("SoftifyPlayback", resultMsg)
                showSnackbar("Resolve OK: ${stream.bitrateKbps}k via ${stream.provider} (host: $host)")
            } catch (e: Exception) {
                val errMsg = "Resolve only FAILED: ${e.message}"
                PlaybackLogger.log("SoftifyPlayback", errMsg)
                showSnackbar(errMsg)
            }
        }
    }

    fun resolveAndPlayTestTrack() {
        PlaybackLogger.log("SoftifyPlayback", "Test button: 'Resolve + play' tapped for 'Tum Hi Ho'")
        val fixedTrack = Track(
            id = "s6zuKkD9",
            sourceId = "s6zuKkD9",
            title = "Tum Hi Ho",
            artist = "Arijit Singh",
            album = "Aashiqui 2",
            durationMs = 262_000u,
            coverUrl = null,
            matchConfidence = null,
            isLiked = false,
            isUnavailable = false
        )
        playTrack(fixedTrack)
    }

    fun probeLastYouTubeUrl() {
        PlaybackLogger.log("SoftifyPlayback", "Test button: 'Probe last YouTube URL' tapped")
        val handler = onProbeYouTubeRequested
        if (handler != null) {
            handler.invoke()
        } else {
            val errMsg = "Probe handler not registered"
            PlaybackLogger.log("SoftifyPlayback", "ERROR: $errMsg")
            showSnackbar(errMsg)
        }
    }
}
