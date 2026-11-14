package com.softify.app.viewmodel

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
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

    private var searchJob: Job? = null
    var onStreamReadyForPlayback: ((Track, StreamInfo) -> Unit)? = null

    init {
        refreshLibrary()
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
                println("[ViewModel] Failed to toggle like: ${e.message}")
            }
        }
    }

    fun createNewPlaylist(name: String, description: String? = null) {
        scope.launch(Dispatchers.Default) {
            try {
                createPlaylist(name, description)
                refreshLibrary()
            } catch (e: Exception) {
                println("[ViewModel] Failed to create playlist: ${e.message}")
            }
        }
    }

    fun playTrack(track: Track) {
        scope.launch {
            _activeTrack.value = track
            _isPlaying.value = true
            try {
                val stream = resolveStream(track, _qualityPreset.value)
                _activeStream.value = stream
                println("[ViewModel] Resolved stream for '${track.title}': ${stream.bitrateKbps} kbps, provider=${stream.provider}, requested_quality_met=${stream.isRequestedQuality}")
                onStreamReadyForPlayback?.invoke(track, stream)
                refreshLibrary()
            } catch (e: Exception) {
                println("[ViewModel] Failed to resolve stream for '${track.title}': ${e.message}")
                _isPlaying.value = false
            }
        }
    }

    fun togglePlayPause() {
        _isPlaying.value = !_isPlaying.value
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
}
