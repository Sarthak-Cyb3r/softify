package com.softify.app.playback

import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.resolveStream

enum class RepeatMode {
    OFF,
    ALL,
    ONE,
}

data class CachedStream(
    val stream: StreamInfo,
    val resolvedAtMs: Long
) {
    fun isExpired(nowMs: Long): Boolean {
        // If stream explicitly states expiration timestamp (epoch seconds)
        val expiresAtSec = stream.expiresAt
        if (expiresAtSec != null) {
            val expiresAtMs = expiresAtSec.toLong() * 1000L
            if (nowMs >= expiresAtMs - 30_000L) {
                return true
            }
        }
        // Fallback: expire cached stream after 2 hours (Saavn/YouTube signed links expire in 2-6 hrs)
        return (nowMs - resolvedAtMs) > (2 * 3600 * 1000L)
    }
}

data class QueueState(
    val tracks: List<Track> = emptyList(),
    val currentIndex: Int = -1,
    val repeatMode: RepeatMode = RepeatMode.OFF,
    val isShuffle: Boolean = false,
    val playNextTrackIds: Set<String> = emptySet()
) {
    val currentTrack: Track?
        get() = if (currentIndex in tracks.indices) tracks[currentIndex] else null

    val nextTrack: Track?
        get() {
            if (tracks.isEmpty()) return null
            return when (repeatMode) {
                RepeatMode.ONE -> currentTrack
                RepeatMode.ALL -> {
                    val nextIdx = (currentIndex + 1) % tracks.size
                    tracks[nextIdx]
                }
                RepeatMode.OFF -> {
                    val nextIdx = currentIndex + 1
                    if (nextIdx in tracks.indices) tracks[nextIdx] else null
                }
            }
        }

    val previousTrack: Track?
        get() {
            if (tracks.isEmpty()) return null
            return when (repeatMode) {
                RepeatMode.ONE -> currentTrack
                RepeatMode.ALL -> {
                    val prevIdx = if (currentIndex <= 0) tracks.size - 1 else currentIndex - 1
                    tracks[prevIdx]
                }
                RepeatMode.OFF -> {
                    val prevIdx = currentIndex - 1
                    if (prevIdx in tracks.indices) tracks[prevIdx] else null
                }
            }
        }

    val hasNext: Boolean
        get() = nextTrack != null

    val hasPrevious: Boolean
        get() = previousTrack != null
}

class QueueManager(
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default),
    private val timeProvider: () -> Long = { System.currentTimeMillis() }
) {
    private val _queueState = MutableStateFlow(QueueState())
    val queueState: StateFlow<QueueState> = _queueState.asStateFlow()

    private val cachedStreams = mutableMapOf<String, CachedStream>()

    var isRadioMode: Boolean = false
        private set
    var radioSeedId: String? = null
        private set
    var radioContinuationToken: String? = null
        private set
    var isFetchingContinuation: Boolean = false

    var onNeedContinuation: ((seedId: String, token: String?) -> Unit)? = null

    var localDownloadResolver: (suspend (Track) -> StreamInfo?)? = null

    fun setQueue(tracks: List<Track>, startIndex: Int = 0) {
        isRadioMode = false
        radioSeedId = null
        radioContinuationToken = null
        isFetchingContinuation = false
        val validIndex = if (tracks.isEmpty()) -1 else startIndex.coerceIn(0, tracks.size - 1)
        _queueState.value = _queueState.value.copy(
            tracks = tracks,
            currentIndex = validIndex
        )
        PlaybackLogger.log(
            "SoftifyPlayback",
            "QueueManager: setQueue with ${tracks.size} tracks, startIndex=$validIndex"
        )
    }

    fun setRadioQueue(seedTrack: Track, radioTracks: List<Track>, continuation: String?) {
        isRadioMode = true
        radioSeedId = seedTrack.id
        radioContinuationToken = continuation
        isFetchingContinuation = false
        val deduplicated = radioTracks.filter { it.id != seedTrack.id }
        val combined = listOf(seedTrack) + deduplicated
        _queueState.value = _queueState.value.copy(
            tracks = combined,
            currentIndex = 0,
            playNextTrackIds = emptySet()
        )
        PlaybackLogger.log(
            "SoftifyPlayback",
            "QueueManager: setRadioQueue with seed '${seedTrack.title}' + ${deduplicated.size} radio tracks, continuation=$continuation"
        )
    }

    fun appendRadioTracks(newTracks: List<Track>, continuation: String?) {
        val current = _queueState.value
        val existingIds = current.tracks.map { it.id }.toSet()
        val filtered = newTracks.filter { it.id !in existingIds }
        radioContinuationToken = continuation
        isFetchingContinuation = false
        if (filtered.isEmpty()) {
            return
        }
        val updated = current.tracks + filtered
        _queueState.value = current.copy(tracks = updated)
        PlaybackLogger.log(
            "SoftifyPlayback",
            "QueueManager: appendRadioTracks added ${filtered.size} tracks (total=${updated.size}), next continuation=$continuation"
        )
    }

    fun checkContinuationThreshold() {
        if (!isRadioMode || isFetchingContinuation) return
        val current = _queueState.value
        val remaining = current.tracks.size - current.currentIndex - 1
        if (remaining <= 5) {
            val seed = radioSeedId ?: return
            val token = radioContinuationToken ?: return
            isFetchingContinuation = true
            PlaybackLogger.log(
                "SoftifyPlayback",
                "QueueManager: remaining upcoming tracks ($remaining) <= 5; triggering radio continuation..."
            )
            onNeedContinuation?.invoke(seed, token)
        }
    }

    fun playNext(track: Track) {
        val current = _queueState.value
        val list = current.tracks.toMutableList()
        val insertIndex = if (current.currentIndex in list.indices) {
            current.currentIndex + 1
        } else {
            0
        }
        list.add(insertIndex, track)
        val newIndex = if (current.currentIndex == -1) 0 else current.currentIndex
        _queueState.value = current.copy(
            tracks = list,
            currentIndex = newIndex,
            playNextTrackIds = current.playNextTrackIds + track.id
        )
        PlaybackLogger.log(
            "SoftifyPlayback",
            "QueueManager: playNext '${track.title}', inserted at index $insertIndex"
        )
    }

    fun addToQueue(track: Track) {
        val current = _queueState.value
        val list = current.tracks.toMutableList()
        list.add(track)
        val newIndex = if (current.currentIndex == -1) 0 else current.currentIndex
        _queueState.value = current.copy(
            tracks = list,
            currentIndex = newIndex,
            playNextTrackIds = current.playNextTrackIds - track.id
        )
        PlaybackLogger.log(
            "SoftifyPlayback",
            "QueueManager: addToQueue '${track.title}', total tracks=${list.size}"
        )
    }

    fun removeAt(index: Int) {
        val current = _queueState.value
        if (index !in current.tracks.indices) return
        val list = current.tracks.toMutableList()
        val removed = list.removeAt(index)
        val newIndex = when {
            list.isEmpty() -> -1
            current.currentIndex > index -> current.currentIndex - 1
            current.currentIndex == index -> index.coerceAtMost(list.size - 1)
            else -> current.currentIndex
        }
        _queueState.value = current.copy(
            tracks = list,
            currentIndex = newIndex,
            playNextTrackIds = current.playNextTrackIds - removed.id
        )
    }

    fun move(fromIndex: Int, toIndex: Int) {
        val current = _queueState.value
        if (fromIndex !in current.tracks.indices || toIndex !in current.tracks.indices || fromIndex == toIndex) return
        val list = current.tracks.toMutableList()
        val item = list.removeAt(fromIndex)
        list.add(toIndex, item)
        val newCurrentIndex = when {
            current.currentIndex == fromIndex -> toIndex
            fromIndex < current.currentIndex && toIndex >= current.currentIndex -> current.currentIndex - 1
            fromIndex > current.currentIndex && toIndex <= current.currentIndex -> current.currentIndex + 1
            else -> current.currentIndex
        }
        _queueState.value = current.copy(tracks = list, currentIndex = newCurrentIndex)
    }

    fun jumpTo(index: Int): Track? {
        val current = _queueState.value
        if (index !in current.tracks.indices) return null
        _queueState.value = current.copy(currentIndex = index)
        val track = current.tracks[index]
        PlaybackLogger.log("SoftifyPlayback", "QueueManager: jumpTo index $index: '${track.title}'")
        checkContinuationThreshold()
        return track
    }

    fun clear() {
        _queueState.value = _queueState.value.copy(tracks = emptyList(), currentIndex = -1)
        cachedStreams.clear()
        PlaybackLogger.log("SoftifyPlayback", "QueueManager: queue cleared")
    }

    fun toggleRepeatMode(): RepeatMode {
        val next = when (_queueState.value.repeatMode) {
            RepeatMode.OFF -> RepeatMode.ALL
            RepeatMode.ALL -> RepeatMode.ONE
            RepeatMode.ONE -> RepeatMode.OFF
        }
        _queueState.value = _queueState.value.copy(repeatMode = next)
        PlaybackLogger.log("SoftifyPlayback", "QueueManager: repeatMode set to $next")
        return next
    }

    fun toggleShuffle(): Boolean {
        val next = !_queueState.value.isShuffle
        _queueState.value = _queueState.value.copy(isShuffle = next)
        PlaybackLogger.log("SoftifyPlayback", "QueueManager: isShuffle set to $next")
        return next
    }

    fun skipNext(): Track? {
        val current = _queueState.value
        if (current.tracks.isEmpty()) return null

        val nextIndex = when (current.repeatMode) {
            RepeatMode.ONE -> current.currentIndex
            RepeatMode.ALL -> (current.currentIndex + 1) % current.tracks.size
            RepeatMode.OFF -> {
                val idx = current.currentIndex + 1
                if (idx < current.tracks.size) idx else null
            }
        }

        return if (nextIndex != null && nextIndex in current.tracks.indices) {
            _queueState.value = current.copy(currentIndex = nextIndex)
            val track = current.tracks[nextIndex]
            PlaybackLogger.log("SoftifyPlayback", "QueueManager: skipNext to index $nextIndex: '${track.title}'")
            checkContinuationThreshold()
            track
        } else {
            PlaybackLogger.log("SoftifyPlayback", "QueueManager: skipNext reached end of queue")
            null
        }
    }

    fun skipPrevious(): Track? {
        val current = _queueState.value
        if (current.tracks.isEmpty()) return null

        val prevIndex = when (current.repeatMode) {
            RepeatMode.ONE -> current.currentIndex
            RepeatMode.ALL -> if (current.currentIndex <= 0) current.tracks.size - 1 else current.currentIndex - 1
            RepeatMode.OFF -> {
                val idx = current.currentIndex - 1
                if (idx >= 0) idx else null
            }
        }

        return if (prevIndex != null && prevIndex in current.tracks.indices) {
            _queueState.value = current.copy(currentIndex = prevIndex)
            val track = current.tracks[prevIndex]
            PlaybackLogger.log("SoftifyPlayback", "QueueManager: skipPrevious to index $prevIndex: '${track.title}'")
            track
        } else {
            PlaybackLogger.log("SoftifyPlayback", "QueueManager: skipPrevious at start of queue")
            null
        }
    }

    fun onTrackEnded(): Track? {
        val current = _queueState.value
        if (current.tracks.isEmpty()) return null

        val nextIndex = when (current.repeatMode) {
            RepeatMode.ONE -> current.currentIndex
            RepeatMode.ALL -> (current.currentIndex + 1) % current.tracks.size
            RepeatMode.OFF -> {
                val idx = current.currentIndex + 1
                if (idx < current.tracks.size) idx else null
            }
        }

        return if (nextIndex != null && nextIndex in current.tracks.indices) {
            _queueState.value = current.copy(currentIndex = nextIndex)
            val track = current.tracks[nextIndex]
            PlaybackLogger.log("SoftifyPlayback", "QueueManager: onTrackEnded auto-advancing to '${track.title}'")
            checkContinuationThreshold()
            track
        } else {
            PlaybackLogger.log("SoftifyPlayback", "QueueManager: onTrackEnded reached end of queue")
            null
        }
    }

    suspend fun resolveTrackStream(
        track: Track,
        preset: QualityPreset,
        forceRefresh: Boolean = false
    ): StreamInfo {
        if (!forceRefresh) {
            val local = runCatching { localDownloadResolver?.invoke(track) }.getOrNull()
            if (local != null) {
                PlaybackLogger.log(
                    "SoftifyPlayback",
                    "QueueManager: Using local download for '${track.title}' (codec=${local.codec}, bitrate=${local.bitrateKbps}k)"
                )
                return local
            }
        }

        val nowMs = timeProvider()
        val cached = cachedStreams[track.id]
        if (!forceRefresh && cached != null && !cached.isExpired(nowMs)) {
            PlaybackLogger.log(
                "SoftifyPlayback",
                "QueueManager: Using valid cached stream for '${track.title}' (provider=${cached.stream.provider})"
            )
            return cached.stream
        }

        PlaybackLogger.log(
            "SoftifyPlayback",
            "QueueManager: Lazy resolving stream for '${track.title}' (preset=$preset, forceRefresh=$forceRefresh)"
        )
        val stream = resolveStream(track, preset)
        cachedStreams[track.id] = CachedStream(stream, nowMs)
        return stream
    }

    fun invalidateStream(trackId: String) {
        cachedStreams.remove(trackId)
        PlaybackLogger.log("SoftifyPlayback", "QueueManager: Invalidated cached stream for trackId $trackId")
    }

    fun preResolveNext(preset: QualityPreset) {
        val next = _queueState.value.nextTrack ?: return
        val nowMs = timeProvider()
        val cached = cachedStreams[next.id]
        if (cached != null && !cached.isExpired(nowMs)) {
            return
        }

        scope.launch {
            try {
                PlaybackLogger.log("SoftifyPlayback", "QueueManager: Pre-resolving upcoming track '${next.title}'...")
                val stream = resolveStream(next, preset)
                cachedStreams[next.id] = CachedStream(stream, timeProvider())
                PlaybackLogger.log("SoftifyPlayback", "QueueManager: Pre-resolved upcoming track '${next.title}' OK")
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "QueueManager: Pre-resolve failed for '${next.title}': ${e.message}")
            }
        }
    }
}
