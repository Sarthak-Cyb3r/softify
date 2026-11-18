package com.softify.app.viewmodel

import com.softify.app.playback.QueueManager
import com.softify.app.playback.QueueState
import com.softify.app.playback.RepeatMode
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
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

    // Quick picks State
    private val _quickPicks = MutableStateFlow<List<Track>>(emptyList())
    val quickPicks: StateFlow<List<Track>> = _quickPicks.asStateFlow()

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
    var onSeekToRequested: ((Long) -> Unit)? = null
    var onShareText: ((String) -> Unit)? = null
    var onPlayTestUrlRequested: ((String) -> Unit)? = null
    var onProbeYouTubeRequested: (() -> Unit)? = null

    // Player & Sheet Expanded States (M3c)
    private val _isNowPlayingExpanded = MutableStateFlow(false)
    val isNowPlayingExpanded: StateFlow<Boolean> = _isNowPlayingExpanded.asStateFlow()

    private val _isQueueSheetOpen = MutableStateFlow(false)
    val isQueueSheetOpen: StateFlow<Boolean> = _isQueueSheetOpen.asStateFlow()

    // Lyrics State
    private val _lyrics = MutableStateFlow<SyncedLyrics?>(null)
    val lyrics: StateFlow<SyncedLyrics?> = _lyrics.asStateFlow()

    private val _isLyricsLoading = MutableStateFlow(false)
    val isLyricsLoading: StateFlow<Boolean> = _isLyricsLoading.asStateFlow()

    private val _showLyricsInPlayer = MutableStateFlow(false)
    val showLyricsInPlayer: StateFlow<Boolean> = _showLyricsInPlayer.asStateFlow()

    // High Precision Time Tracking
    private val _currentPositionMs = MutableStateFlow(0L)
    val currentPositionMs: StateFlow<Long> = _currentPositionMs.asStateFlow()

    private val _durationMs = MutableStateFlow(0L)
    val durationMs: StateFlow<Long> = _durationMs.asStateFlow()

    init {
        queueManager.onNeedContinuation = { seedId, token ->
            fetchRadioContinuation(seedId, token)
        }
        refreshAll()
    }

    fun openNowPlaying() {
        _isNowPlayingExpanded.value = true
    }

    fun closeNowPlaying() {
        _isNowPlayingExpanded.value = false
    }

    fun openQueueSheet() {
        _isQueueSheetOpen.value = true
    }

    fun closeQueueSheet() {
        _isQueueSheetOpen.value = false
    }

    fun toggleLyricsView() {
        val next = !_showLyricsInPlayer.value
        PlaybackLogger.log("SoftifyPlayback", "toggleLyricsView: nextState=$next, activeTrack=${_activeTrack.value?.title}")
        _showLyricsInPlayer.value = next
        if (next && _lyrics.value == null && !_isLyricsLoading.value) {
            PlaybackLogger.log("SoftifyPlayback", "toggleLyricsView: lyrics null, triggering loadLyricsForActiveTrack()")
            loadLyricsForActiveTrack()
        }
    }

    fun moveQueueItem(fromIndex: Int, toIndex: Int) {
        queueManager.move(fromIndex, toIndex)
    }

    fun removeQueueItem(index: Int) {
        queueManager.removeAt(index)
    }

    fun playQueueIndex(index: Int) {
        val track = queueManager.jumpTo(index)
        if (track != null) {
            executePlayTrack(track)
        }
    }

    fun seekTo(positionMs: Long) {
        _currentPositionMs.value = positionMs
        val dur = _durationMs.value
        if (dur > 0L) {
            _playbackProgress.value = (positionMs.toFloat() / dur.toFloat()).coerceIn(0f, 1f)
        }
        onSeekToRequested?.invoke(positionMs)
    }

    fun setPlaybackPosition(progress: Float, positionMs: Long = 0L, durationMs: Long = 0L) {
        _playbackProgress.value = progress.coerceIn(0f, 1f)
        if (positionMs > 0L) _currentPositionMs.value = positionMs
        if (durationMs > 0L) _durationMs.value = durationMs
    }

    suspend fun fetchArtistTracks(artist: String): List<Track> {
        return runCatching { getArtistTracks(artist, 50u) }.getOrDefault(emptyList())
    }

    suspend fun fetchAlbumTracks(album: String, artist: String): List<Track> {
        return runCatching { getAlbumTracks(album, artist, 50u) }.getOrDefault(emptyList())
    }

    fun loadLyricsForActiveTrack() {
        val track = _activeTrack.value
        if (track == null) {
            PlaybackLogger.log("SoftifyPlayback", "loadLyricsForActiveTrack: activeTrack is null")
            return
        }
        PlaybackLogger.log("SoftifyPlayback", "loadLyricsForActiveTrack: starting fetch for '${track.title}' by '${track.artist}'")
        scope.launch(Dispatchers.Default) {
            _isLyricsLoading.value = true
            try {
                val res = getLyrics(track)
                _lyrics.value = res
                PlaybackLogger.log(
                    "SoftifyPlayback",
                    "Loaded lyrics for '${track.title}': isSynced=${res.isSynced}, isWordSynced=${res.isWordSynced}, linesCount=${res.lines.size}, hasPlainText=${!res.plainText.isNullOrBlank()}"
                )
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Failed to load lyrics for '${track.title}': ${e.message}")
                _lyrics.value = null
            } finally {
                _isLyricsLoading.value = false
            }
        }
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
            NavigationTab.LIBRARY -> {
                refreshLibrary()
                if (_playlists.value.filter { it.isImported }.any { it.matchedCount < it.trackCount }) {
                    pollMatchingProgress()
                }
            }
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
                val nowMs = System.currentTimeMillis().toULong()
                _smartOnRepeat.value = getOnRepeatTracks(nowMs, 50u)
                _smartMostPlayed.value = getMostPlayedTracks(nowMs, 50u)
                _smartForgottenFavorites.value = getForgottenFavoritesTracks(nowMs, 50u)
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

                try {
                    val picks = getQuickPicks(limit = 10u)
                    _quickPicks.value = picks
                } catch (e: Exception) {
                    PlaybackLogger.log("SoftifyPlayback", "Quick picks error: ${e.message}")
                }
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

                // Prefetch artwork for search results immediately
                val searchCovers = (combined.localTracks + combined.onlineTracks).mapNotNull { it.coverUrl }
                com.softify.app.ui.components.CoverArtLoader.prefetchIfInitialized(searchCovers, com.softify.app.ui.components.CoverSize.THUMBNAIL)

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

    private var matchPollJob: kotlinx.coroutines.Job? = null

    fun pollMatchingProgress() {
        matchPollJob?.cancel()
        matchPollJob = scope.launch(Dispatchers.Default) {
            var anyUnmatched = true
            var attempts = 0
            while (anyUnmatched && attempts < 60) {
                delay(1500)
                refreshLibrary()
                val pls = _playlists.value
                val imported = pls.filter { it.isImported }
                anyUnmatched = imported.any { it.matchedCount < it.trackCount }
                attempts++
            }
        }
    }

    fun importSpotify(urlOrId: String) {
        scope.launch(Dispatchers.Default) {
            showSnackbar("Importing Spotify playlist...")
            try {
                val res = importSpotifyPlaylist(urlOrId)
                refreshLibrary()
                showSnackbar("Imported '${res.playlist.name}' (${res.totalTracks} tracks). Matching in background...")
                pollMatchingProgress()
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
        startRadioForTrack(track)
    }

    fun startRadio(track: Track) {
        playTrack(track)
        showSnackbar("Starting radio for '${track.title}'")
    }

    private fun startRadioForTrack(track: Track) {
        scope.launch(Dispatchers.Default) {
            try {
                val seedVid = if (track.sourceId.startsWith("ytm_")) {
                    track.sourceId.removePrefix("ytm_")
                } else if (track.id.startsWith("ytm_")) {
                    track.id.removePrefix("ytm_")
                } else {
                    val searchResults = runCatching { searchTracks("${track.title} ${track.artist}") }.getOrDefault(emptyList())
                    val matched = searchResults.firstOrNull()?.sourceId?.removePrefix("ytm_")
                    matched ?: track.id
                }

                PlaybackLogger.log("SoftifyPlayback", "Starting radio for seed videoId: $seedVid")
                val radioRes = getRadioTracks(seedTrackId = seedVid, continuation = null)
                queueManager.setRadioQueue(track, radioRes.tracks, radioRes.continuation)
                PlaybackLogger.log("SoftifyPlayback", "Radio queue initialized with ${radioRes.tracks.size} tracks")

                // Prefetch artwork for candidate radio tracks immediately
                val radioCovers = radioRes.tracks.mapNotNull { it.coverUrl }
                com.softify.app.ui.components.CoverArtLoader.prefetchIfInitialized(radioCovers, com.softify.app.ui.components.CoverSize.THUMBNAIL)
                prefetchUpcomingQueueArt()
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Radio build failed for '${track.title}': ${e.message}")
            }
        }
    }

    private fun fetchRadioContinuation(seedId: String, token: String?) {
        scope.launch(Dispatchers.Default) {
            try {
                PlaybackLogger.log("SoftifyPlayback", "Fetching radio continuation for seed $seedId...")
                val res = getRadioTracks(seedTrackId = seedId, continuation = token)
                queueManager.appendRadioTracks(res.tracks, res.continuation)
                PlaybackLogger.log("SoftifyPlayback", "Radio continuation fetched: ${res.tracks.size} tracks added")

                // Prefetch continuation artwork
                val contCovers = res.tracks.mapNotNull { it.coverUrl }
                com.softify.app.ui.components.CoverArtLoader.prefetchIfInitialized(contCovers, com.softify.app.ui.components.CoverSize.THUMBNAIL)
                prefetchUpcomingQueueArt()
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Radio continuation failed: ${e.message}")
                queueManager.isFetchingContinuation = false
            }
        }
    }

    private fun prefetchUpcomingQueueArt() {
        val qState = queueManager.queueState.value
        val upcoming = if (qState.currentIndex in qState.tracks.indices) {
            qState.tracks.drop(qState.currentIndex + 1).take(5)
        } else {
            qState.tracks.take(5)
        }
        val upcomingUrls = upcoming.mapNotNull { it.coverUrl }
        com.softify.app.ui.components.CoverArtLoader.prefetchIfInitialized(upcomingUrls, com.softify.app.ui.components.CoverSize.THUMBNAIL)
        val firstCover = upcomingUrls.firstOrNull()
        if (firstCover != null) {
            com.softify.app.ui.components.CoverArtLoader.prefetchIfInitialized(listOf(firstCover), com.softify.app.ui.components.CoverSize.FULL)
        }
    }

    fun playTrackInQueue(tracks: List<Track>, startIndex: Int) {
        if (tracks.isEmpty()) return
        queueManager.setQueue(tracks, startIndex)
        val target = tracks.getOrNull(startIndex) ?: return
        executePlayTrack(target)
        prefetchUpcomingQueueArt()
    }

    fun playNext(track: Track) {
        queueManager.playNext(track)
        showSnackbar("Playing next: '${track.title}'")
        prefetchUpcomingQueueArt()
    }

    fun addToQueue(track: Track) {
        queueManager.addToQueue(track)
        showSnackbar("Added to queue: '${track.title}'")
        prefetchUpcomingQueueArt()
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
            _currentPositionMs.value = 0L
            _durationMs.value = track.durationMs.toLong()
            _lyrics.value = null
            loadLyricsForActiveTrack()

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
