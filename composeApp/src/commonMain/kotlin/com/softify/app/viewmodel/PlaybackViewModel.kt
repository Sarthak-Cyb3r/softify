package com.softify.app.viewmodel

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
import uniffi.softify_core.Playlist
import uniffi.softify_core.PlayHistory
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.SearchIntent
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.createPlaylist
import uniffi.softify_core.getHistory
import uniffi.softify_core.getLikedTracks
import uniffi.softify_core.getPlaylists
import uniffi.softify_core.resolveStream
import uniffi.softify_core.saveTrack
import uniffi.softify_core.searchCombined
import uniffi.softify_core.searchLibrary
import uniffi.softify_core.toggleLike

enum class UiStyle {
    METROLIST,
    APPLE_MUSIC,
}

enum class NavigationTab {
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

    private val _currentTab = MutableStateFlow(NavigationTab.SEARCH)
    val currentTab: StateFlow<NavigationTab> = _currentTab.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _localSearchResults = MutableStateFlow<List<Track>>(emptyList())
    val localSearchResults: StateFlow<List<Track>> = _localSearchResults.asStateFlow()

    private val _onlineSearchResults = MutableStateFlow<List<Track>>(emptyList())
    val onlineSearchResults: StateFlow<List<Track>> = _onlineSearchResults.asStateFlow()

    private val _detectedIntent = MutableStateFlow(SearchIntent.GENERAL)
    val detectedIntent: StateFlow<SearchIntent> = _detectedIntent.asStateFlow()

    private val _detectedEntity = MutableStateFlow<String?>(null)
    val detectedEntity: StateFlow<String?> = _detectedEntity.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    private val _activeTrack = MutableStateFlow<Track?>(null)
    val activeTrack: StateFlow<Track?> = _activeTrack.asStateFlow()

    private val _activeStream = MutableStateFlow<StreamInfo?>(null)
    val activeStream: StateFlow<StreamInfo?> = _activeStream.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _qualityPreset = MutableStateFlow(QualityPreset.HIGH)
    val qualityPreset: StateFlow<QualityPreset> = _qualityPreset.asStateFlow()

    private val _uiStyle = MutableStateFlow(UiStyle.METROLIST)
    val uiStyle: StateFlow<UiStyle> = _uiStyle.asStateFlow()

    // Library State
    private val _likedTracks = MutableStateFlow<List<Track>>(emptyList())
    val likedTracks: StateFlow<List<Track>> = _likedTracks.asStateFlow()

    private val _playlists = MutableStateFlow<List<Playlist>>(emptyList())
    val playlists: StateFlow<List<Playlist>> = _playlists.asStateFlow()

    private val _history = MutableStateFlow<List<PlayHistory>>(emptyList())
    val history: StateFlow<List<PlayHistory>> = _history.asStateFlow()

    // Snackbar event bus for user-facing errors
    private val _snackbarEvents = MutableSharedFlow<String>(extraBufferCapacity = 10)
    val snackbarEvents: SharedFlow<String> = _snackbarEvents.asSharedFlow()

    private var searchJob: Job? = null
    var onStreamReadyForPlayback: ((Track, StreamInfo) -> Unit)? = null
    var onTogglePlayPauseRequested: (() -> Unit)? = null
    var onShareText: ((String) -> Unit)? = null
    var onPlayTestUrlRequested: ((String) -> Unit)? = null

    init {
        refreshLibrary()
    }

    fun showSnackbar(message: String) {
        PlaybackLogger.log("SoftifyPlayback", "Snackbar: $message")
        _snackbarEvents.tryEmit(message)
    }

    fun setIsPlaying(playing: Boolean) {
        _isPlaying.value = playing
    }

    fun setTab(tab: NavigationTab) {
        _currentTab.value = tab
        if (tab == NavigationTab.LIBRARY) {
            refreshLibrary()
        }
    }

    fun refreshLibrary() {
        scope.launch(Dispatchers.Default) {
            try {
                _likedTracks.value = getLikedTracks()
                _playlists.value = getPlaylists()
                _history.value = getHistory(20u)
            } catch (e: Exception) {
                // Database may not be initialized yet
            }
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
            return
        }

        // 1. Instant local FTS5 search (synchronous, <10ms)
        try {
            _localSearchResults.value = searchLibrary(query, 10u)
        } catch (_: Exception) {}

        // 2. Combined async search with online queries
        searchJob = scope.launch(Dispatchers.Default) {
            _isSearching.value = true
            try {
                val combined = searchCombined(query, 25u)
                _localSearchResults.value = combined.localTracks
                _onlineSearchResults.value = combined.onlineTracks
                _detectedIntent.value = combined.intent
                _detectedEntity.value = combined.detectedEntity
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
                // Ensure track exists in DB
                saveTrack(track)
                val newLikedState = toggleLike(track.id)
                
                // Update in activeTrack if matched
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
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Failed to create playlist: ${e.message}")
            }
        }
    }

    fun playTrack(track: Track) {
        PlaybackLogger.log("SoftifyPlayback", "Tap: track '${track.title}' (${track.id}) by '${track.artist}'")
        scope.launch {
            _activeTrack.value = track
            _isPlaying.value = true
            PlaybackLogger.log("SoftifyPlayback", "Resolve start: '${track.title}' preset=${_qualityPreset.value}")
            try {
                val stream = resolveStream(track, _qualityPreset.value)
                _activeStream.value = stream
                val host = runCatching { java.net.URI(stream.url).host ?: "unknown" }.getOrDefault("unknown")
                PlaybackLogger.log(
                    "SoftifyPlayback",
                    "Resolve end: provider=${stream.provider}, bitrate=${stream.bitrateKbps}kbps, codec=${stream.codec}, is_requested_quality=${stream.isRequestedQuality}, host=$host"
                )
                
                val handler = onStreamReadyForPlayback
                if (handler != null) {
                    handler.invoke(track, stream)
                } else {
                    val errMsg = "Playback service not connected or handler missing"
                    PlaybackLogger.log("SoftifyPlayback", "ERROR: $errMsg")
                    showSnackbar(errMsg)
                }
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
            playTrack(track)
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
}
