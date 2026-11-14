package com.softify.app.viewmodel

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.resolveStream
import uniffi.softify_core.searchTracks

enum class UiStyle {
    METROLIST,
    APPLE_MUSIC,
}

class PlaybackViewModel(
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main)
) {
    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _searchResults = MutableStateFlow<List<Track>>(emptyList())
    val searchResults: StateFlow<List<Track>> = _searchResults.asStateFlow()

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

    private var searchJob: Job? = null
    var onStreamReadyForPlayback: ((Track, StreamInfo) -> Unit)? = null

    fun onSearchQueryChanged(query: String) {
        _searchQuery.value = query
        searchJob?.cancel() // Cancel previous in-flight async search immediately

        if (query.trim().isEmpty()) {
            _searchResults.value = emptyList()
            _isSearching.value = false
            return
        }

        searchJob = scope.launch {
            _isSearching.value = true
            try {
                val results = searchTracks(query)
                _searchResults.value = results
            } catch (e: Exception) {
                // Ignore cancellation
            } finally {
                _isSearching.value = false
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
