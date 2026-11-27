package com.softify.app.playback

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.TransferListener
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uniffi.softify_core.HeaderPair
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.resolveStream

/**
 * Custom Media3 DataSource that transparently wraps HttpDataSource.
 * For googlevideo.com URLs, it enforces bounded 1 MB chunk requests to prevent HTTP 403 on open-ended ranges.
 */
class BoundedHttpDataSource(
    private val baseDataSource: HttpDataSource,
    private val chunkSize: Long = BoundedRangeHelper.DEFAULT_CHUNK_SIZE // 1 MiB bounded chunk size
) : DataSource {
    private var openedDataSpec: DataSpec? = null
    private var currentUri: Uri? = null
    private var currentPosition: Long = 0L
    private var bytesRemainingInChunk: Long = 0L
    private var remainingRequestedLength: Long = C.LENGTH_UNSET.toLong()
    private var knownTotalLength: Long = C.LENGTH_UNSET.toLong()
    private var isGoogleVideo: Boolean = false
    private var isBaseOpen: Boolean = false

    override fun addTransferListener(transferListener: TransferListener) {
        baseDataSource.addTransferListener(transferListener)
    }

    private fun updateTotalLengthFromHeaders(headers: Map<String, List<String>>) {
        val contentRange = headers.entries
            .firstOrNull { it.key.equals("Content-Range", ignoreCase = true) }
            ?.value
            ?.firstOrNull()
        val parsedTotal = BoundedRangeHelper.parseTotalLengthFromContentRange(contentRange)
        if (parsedTotal != null && parsedTotal > 0L) {
            knownTotalLength = parsedTotal
        }
    }

    private fun safeCloseBase() {
        if (isBaseOpen) {
            isBaseOpen = false
            try {
                baseDataSource.close()
            } catch (_: Exception) {
            }
        }
    }

    override fun open(dataSpec: DataSpec): Long {
        if (currentUri != dataSpec.uri) {
            knownTotalLength = C.LENGTH_UNSET.toLong()
            currentUri = dataSpec.uri
        }
        openedDataSpec = dataSpec
        currentPosition = dataSpec.position
        remainingRequestedLength = dataSpec.length
        val host = dataSpec.uri.host ?: ""
        isGoogleVideo = host.contains("googlevideo.com")

        return if (isGoogleVideo) {
            val plan = BoundedRangeHelper.computeChunkPlan(
                position = currentPosition,
                requestedLength = remainingRequestedLength,
                knownTotalLength = knownTotalLength,
                chunkSize = chunkSize
            )
            if (!plan.shouldOpen) {
                bytesRemainingInChunk = 0L
                return 0L
            }

            // Use absolute setPosition/setLength: DataSpec.subrange() adds to dataSpec.position and would double seek offsets.
            val boundedSpec = dataSpec.buildUpon()
                .setPosition(plan.requestPosition)
                .setLength(plan.requestLength)
                .build()
            try {
                val openedBytes = baseDataSource.open(boundedSpec)
                isBaseOpen = true
                updateTotalLengthFromHeaders(baseDataSource.responseHeaders)

                bytesRemainingInChunk = if (openedBytes != C.LENGTH_UNSET.toLong()) {
                    openedBytes
                } else {
                    plan.requestLength
                }

                BoundedRangeHelper.computeOpenReturnLength(
                    position = currentPosition,
                    requestedLength = dataSpec.length,
                    knownTotalLength = knownTotalLength
                )
            } catch (e: HttpDataSource.InvalidResponseCodeException) {
                updateTotalLengthFromHeaders(e.headerFields)
                if (e.responseCode == 416 && knownTotalLength > 0L && currentPosition >= knownTotalLength) {
                    PlaybackLogger.log(
                        "SoftifyPlayback",
                        "BoundedHttpDataSource.open reached exact EOF (pos=$currentPosition >= total=$knownTotalLength); returning 0 bytes cleanly"
                    )
                    isBaseOpen = false
                    bytesRemainingInChunk = 0L
                    0L
                } else {
                    throw e
                }
            }
        } else {
            val opened = baseDataSource.open(dataSpec)
            isBaseOpen = true
            opened
        }
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (!isGoogleVideo) {
            return baseDataSource.read(buffer, offset, length)
        }
        if (length == 0) {
            return 0
        }
        if (remainingRequestedLength == 0L || (knownTotalLength > 0L && currentPosition >= knownTotalLength)) {
            return C.RESULT_END_OF_INPUT
        }

        if (bytesRemainingInChunk <= 0L) {
            val spec = openedDataSpec ?: return C.RESULT_END_OF_INPUT
            val nextPlan = BoundedRangeHelper.computeChunkPlan(
                position = currentPosition,
                requestedLength = remainingRequestedLength,
                knownTotalLength = knownTotalLength,
                chunkSize = chunkSize
            )
            if (!nextPlan.shouldOpen) {
                return C.RESULT_END_OF_INPUT
            }

            try {
                safeCloseBase()
                val nextSpec = spec.buildUpon()
                    .setPosition(nextPlan.requestPosition)
                    .setLength(nextPlan.requestLength)
                    .build()
                val openedBytes = baseDataSource.open(nextSpec)
                isBaseOpen = true
                updateTotalLengthFromHeaders(baseDataSource.responseHeaders)
                bytesRemainingInChunk = if (openedBytes != C.LENGTH_UNSET.toLong()) {
                    openedBytes
                } else {
                    nextPlan.requestLength
                }
            } catch (e: Exception) {
                var responseCode: Int? = null
                var contentType: String? = null
                var cause: Throwable? = e
                while (cause != null) {
                    if (cause is HttpDataSource.InvalidResponseCodeException) {
                        responseCode = cause.responseCode
                        updateTotalLengthFromHeaders(cause.headerFields)
                        contentType = cause.headerFields["Content-Type"]?.firstOrNull()
                            ?: cause.headerFields["content-type"]?.firstOrNull()
                        break
                    }
                    cause = cause.cause
                }
                if (responseCode == 416 && knownTotalLength > 0L && currentPosition >= knownTotalLength) {
                    return C.RESULT_END_OF_INPUT
                }
                PlaybackLogger.log(
                    "SoftifyPlayback",
                    "BoundedHttpDataSource chunk error at pos=$currentPosition: status=$responseCode, contentType=$contentType, error=${e.message}"
                )
                throw e
            }
        }

        val maxInChunk = minOf(length.toLong(), bytesRemainingInChunk)
        val toRead = if (remainingRequestedLength != C.LENGTH_UNSET.toLong()) {
            minOf(maxInChunk, remainingRequestedLength).toInt()
        } else {
            maxInChunk.toInt()
        }
        if (toRead <= 0) {
            return C.RESULT_END_OF_INPUT
        }

        val readBytes = baseDataSource.read(buffer, offset, toRead)
        if (readBytes > 0) {
            currentPosition += readBytes
            bytesRemainingInChunk -= readBytes
            if (remainingRequestedLength != C.LENGTH_UNSET.toLong()) {
                remainingRequestedLength = (remainingRequestedLength - readBytes).coerceAtLeast(0L)
            }
        }
        return readBytes
    }

    override fun getUri(): Uri? = baseDataSource.uri ?: currentUri

    override fun getResponseHeaders(): Map<String, List<String>> = baseDataSource.responseHeaders

    override fun close() {
        openedDataSpec = null
        bytesRemainingInChunk = 0L
        remainingRequestedLength = C.LENGTH_UNSET.toLong()
        safeCloseBase()
    }
}

class BoundedHttpDataSourceFactory(
    private val baseFactory: HttpDataSource.Factory
) : DataSource.Factory {
    override fun createDataSource(): DataSource {
        return BoundedHttpDataSource(baseFactory.createDataSource())
    }
}

class PlaybackService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    lateinit var crossfadePlayerManager: CrossfadePlayerManager
        private set

    val player: ExoPlayer
        get() = crossfadePlayerManager.activePlayer

    var onTrackAutoTransitioned: ((Track) -> Unit)? = null
    var onTelemetryUpdated: ((CrossfadeState, Float, TransitionType) -> Unit)? = null
    var onTracesUpdated: ((List<TransitionTrace>) -> Unit)? = null
    var onRequestNextTrackPrepare: ((Track) -> Unit)? = null
    var onFatalPlaybackError: ((String) -> Unit)? = null

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private lateinit var retryManager: PlaybackRetryManager
    private var currentSessionId: Long = 0L
    private var currentTrack: Track? = null
    private var currentPreset: QualityPreset = QualityPreset.HIGH
    private var currentStreamInfo: StreamInfo? = null
    private var lastPlaybackPositionMs: Long = 0L
    private var silentRecoveriesForSession: Int = 0
    private var isServiceDestroyed: Boolean = false

    companion object {
        const val CHANNEL_ID = "softify_playback_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_PLAY_STREAM = "com.softify.app.action.PLAY_STREAM"
        const val ACTION_PLAY_TEST_URL = "com.softify.app.action.PLAY_TEST_URL"

        const val EXTRA_TRACK_ID = "extra_track_id"
        const val EXTRA_TRACK_TITLE = "extra_track_title"
        const val EXTRA_TRACK_ARTIST = "extra_track_artist"
        const val EXTRA_STREAM_URL = "extra_stream_url"
        const val EXTRA_STREAM_BITRATE = "extra_stream_bitrate"
        const val EXTRA_STREAM_CODEC = "extra_stream_codec"
        const val EXTRA_STREAM_PROVIDER = "extra_stream_provider"
        const val EXTRA_HEADER_NAMES = "extra_header_names"
        const val EXTRA_HEADER_VALUES = "extra_header_values"

        var instance: PlaybackService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        PlaybackLogger.log("SoftifyPlayback", "PlaybackService onCreate")
        createNotificationChannel()

        retryManager = PlaybackRetryManager(
            scope = serviceScope,
            maxRetries = 2,
            onLog = { msg -> PlaybackLogger.log("SoftifyPlayback", msg) },
            onExhausted = { trackId, reason ->
                PlaybackLogger.log("SoftifyPlayback", "All 2 retries exhausted for '$trackId' ($reason)")
                if (!isServiceDestroyed) {
                    onFatalPlaybackError?.invoke("Player error: $reason")
                }
            },
            executeRetry = { sessionId, attempt ->
                val track = currentTrack ?: return@PlaybackRetryManager
                val lastPos = player.currentPosition
                PlaybackLogger.log("SoftifyPlayback", "Executing retry $attempt/2: re-resolving fresh stream for '${track.title}' at ${lastPos}ms (session $sessionId)")
                try {
                    val freshStream = resolveStream(track, currentPreset)
                    playStream(track, freshStream, lastPos, sessionId)
                } catch (e: Exception) {
                    PlaybackLogger.log("SoftifyPlayback", "Retry $attempt/2 resolve error: ${e.message}")
                }
            }
        )

        crossfadePlayerManager = CrossfadePlayerManager(
            context = this,
            scope = serviceScope,
            onMediaSessionPlayerChanged = { newPlayer ->
                mediaSession?.setPlayer(newPlayer)
            },
            onTrackTransitioned = { newTrack ->
                currentTrack = newTrack
                val sInfo = currentStreamInfo
                if (sInfo != null) {
                    updateForegroundNotification(newTrack, sInfo)
                }
                onTrackAutoTransitioned?.invoke(newTrack)
            },
            onTelemetryUpdated = { state, progress, type ->
                onTelemetryUpdated?.invoke(state, progress, type)
            }
        )

        crossfadePlayerManager.onTracesUpdated = { traces ->
            onTracesUpdated?.invoke(traces)
        }

        crossfadePlayerManager.onRequestNextTrackPrepare = { nextTrack ->
            onRequestNextTrackPrepare?.invoke(nextTrack)
        }

        crossfadePlayerManager.onPlaybackStateChanged = { state ->
            if (state == Player.STATE_READY) {
                silentRecoveriesForSession = 0
            }
            if (player.currentPosition > 0L) {
                lastPlaybackPositionMs = player.currentPosition
            }
        }

        crossfadePlayerManager.onPlayWhenReadyChanged = { playWhenReady ->
            if (!playWhenReady) {
                PlaybackLogger.log("SoftifyPlayback", "User/System paused playback; cancelling pending retries")
                retryManager.onUserPauseOrStop()
            }
        }

        crossfadePlayerManager.onPlayerError = { error ->
            handlePlayerError(error)
        }

        mediaSession = MediaSession.Builder(this, crossfadePlayerManager.activePlayer).build()
        startPositionTracking()
        PlaybackLogger.log("SoftifyPlayback", "MediaSession initialized")
    }

    private fun handlePlayerError(error: PlaybackException) {
        if (isServiceDestroyed) return

        var httpStatus: Int? = null
        var cause: Throwable? = error.cause
        while (cause != null) {
            if (cause is HttpDataSource.InvalidResponseCodeException) {
                httpStatus = cause.responseCode
                break
            }
            cause = cause.cause
        }
        val httpMsg = if (httpStatus != null) " (HTTP status: $httpStatus)" else ""
        val errorMsg = "onPlayerError: ${error.errorCodeName}$httpMsg - ${error.message}"
        PlaybackLogger.log("SoftifyPlayback", errorMsg)

        val track = currentTrack
        val streamUrl = currentStreamInfo?.url ?: ""
        val isLocalDownload = streamUrl.startsWith("content://") || streamUrl.startsWith("file://") || currentStreamInfo?.provider == "local"

        if (isLocalDownload && track != null) {
            PlaybackLogger.log("SoftifyPlayback", "Local download unreadable for '${track.title}' (${error.errorCodeName}): marking as needs repair and falling back to streaming silently")
            serviceScope.launch {
                try {
                    uniffi.softify_core.markDownloadRepair(track.id, "Local playback error: ${error.errorCodeName}")
                    val freshStream = resolveStream(track, currentPreset)
                    if (!isServiceDestroyed) {
                        playStream(track, freshStream, 0L, currentSessionId)
                    }
                } catch (e: Exception) {
                    PlaybackLogger.log("SoftifyPlayback", "Fallback to stream failed: ${e.message}")
                    if (!isServiceDestroyed) {
                        onFatalPlaybackError?.invoke("Player error: ${error.errorCodeName}$httpMsg")
                    }
                }
            }
            return
        }

        val isContainerOrHttpRecoverable = (httpStatus == 403 || httpStatus == 410 || httpStatus == 416) ||
            error.errorCode == PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED ||
            error.errorCode == PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS

        if (isContainerOrHttpRecoverable && track != null && silentRecoveriesForSession < 2) {
            silentRecoveriesForSession++
            val resumePos = maxOf(lastPlaybackPositionMs, player.currentPosition).coerceAtLeast(0L)
            PlaybackLogger.log(
                "SoftifyPlayback",
                "Mid-stream recoverable error ($httpStatus) for '${track.title}' at ${resumePos}ms (attempt $silentRecoveriesForSession/2); auto-refreshing stream silently"
            )
            serviceScope.launch {
                try {
                    val freshStream = resolveStream(track, currentPreset)
                    if (!isServiceDestroyed) {
                        playStream(track, freshStream, resumePos, currentSessionId)
                    }
                } catch (e: Exception) {
                    PlaybackLogger.log("SoftifyPlayback", "Auto-refresh stream failed: ${e.message}")
                    if (!isServiceDestroyed) {
                        retryManager.handlePlayerError(currentSessionId, track.id, "${error.errorCodeName}$httpMsg")
                    }
                }
            }
            return
        }

        if (track != null) {
            retryManager.handlePlayerError(currentSessionId, track.id, "${error.errorCodeName}$httpMsg")
        } else {
            onFatalPlaybackError?.invoke("Player error: ${error.errorCodeName}$httpMsg")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        val action = intent?.action
        if (action == null) {
            PlaybackLogger.log("SoftifyPlayback", "PlaybackService onStartCommand with null action; ignoring")
            return START_NOT_STICKY
        }
        PlaybackLogger.log("SoftifyPlayback", "PlaybackService onStartCommand: action=$action")

        when (action) {
            ACTION_PLAY_STREAM -> {
                val trackId = intent.getStringExtra(EXTRA_TRACK_ID) ?: ""
                val trackTitle = intent.getStringExtra(EXTRA_TRACK_TITLE) ?: "Unknown Track"
                val trackArtist = intent.getStringExtra(EXTRA_TRACK_ARTIST) ?: "Unknown Artist"
                val streamUrl = intent.getStringExtra(EXTRA_STREAM_URL)
                val bitrate = intent.getIntExtra(EXTRA_STREAM_BITRATE, 320)
                val codec = intent.getStringExtra(EXTRA_STREAM_CODEC) ?: "aac"
                val provider = intent.getStringExtra(EXTRA_STREAM_PROVIDER) ?: "Unknown"

                val headerNames = intent.getStringArrayListExtra(EXTRA_HEADER_NAMES) ?: arrayListOf()
                val headerValues = intent.getStringArrayListExtra(EXTRA_HEADER_VALUES) ?: arrayListOf()
                val headers = headerNames.zip(headerValues).map { HeaderPair(it.first, it.second) }

                if (streamUrl != null) {
                    val track = Track(
                        id = trackId,
                        sourceId = trackId,
                        title = trackTitle,
                        artist = trackArtist,
                        album = null,
                        durationMs = 0u,
                        coverUrl = null,
                        matchConfidence = null,
                        isLiked = false,
                        isUnavailable = false
                    )
                    val streamInfo = StreamInfo(
                        url = streamUrl,
                        container = "m4a",
                        bitrateKbps = bitrate.toUInt(),
                        codec = codec,
                        provider = provider,
                        isRequestedQuality = bitrate >= 320,
                        headers = headers,
                        expiresAt = null
                    )
                    playStream(track, streamInfo, 0L)
                } else {
                    PlaybackLogger.log("SoftifyPlayback", "ERROR: onStartCommand received null stream_url")
                }
            }
            ACTION_PLAY_TEST_URL -> {
                val testUrl = intent.getStringExtra(EXTRA_STREAM_URL) ?: "https://storage.googleapis.com/exoplayer-test-media-0/play.mp3"
                playDirectTestUrl(testUrl)
            }
        }
        return START_NOT_STICKY
    }

    fun createMediaSource(streamInfo: StreamInfo, track: Track): MediaSource {
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(15000)

        val headerMap = mutableMapOf<String, String>()
        var userAgentHeader: String? = null
        for (h in streamInfo.headers) {
            headerMap[h.name] = h.value
            if (h.name.equals("User-Agent", ignoreCase = true)) {
                userAgentHeader = h.value
            }
        }
        if (userAgentHeader != null) {
            httpDataSourceFactory.setUserAgent(userAgentHeader)
        }
        if (headerMap.isNotEmpty()) {
            httpDataSourceFactory.setDefaultRequestProperties(headerMap)
            PlaybackLogger.log("SoftifyPlayback", "Applied HTTP request headers: ${headerMap.keys.joinToString()} (UA: ${userAgentHeader ?: "default"})")
        }

        val mimeType = when (streamInfo.codec.lowercase()) {
            "opus" -> MimeTypes.AUDIO_OPUS
            "mp3" -> MimeTypes.AUDIO_MPEG
            else -> MimeTypes.AUDIO_MP4
        }

        val boundedHttpFactory = BoundedHttpDataSourceFactory(httpDataSourceFactory)
        val defaultDataSourceFactory = DefaultDataSource.Factory(this, boundedHttpFactory)
        val mediaSourceFactory = DefaultMediaSourceFactory(defaultDataSourceFactory)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(streamInfo.url))
            .setMediaId(track.id)
            .setMimeType(mimeType)
            .build()

        PlaybackLogger.log("SoftifyPlayback", "MediaItem built: mediaId=${track.id}, mimeType=$mimeType")
        return mediaSourceFactory.createMediaSource(mediaItem)
    }

    fun playStream(
        track: Track,
        streamInfo: StreamInfo,
        startPositionMs: Long = 0L,
        targetSessionId: Long? = null,
        loudnessResult: LoudnessResult? = null
    ) {
        if (isServiceDestroyed) return
        if (Looper.myLooper() != Looper.getMainLooper()) {
            Handler(Looper.getMainLooper()).post {
                playStream(track, streamInfo, startPositionMs, targetSessionId, loudnessResult)
            }
            return
        }
        if (targetSessionId == null) {
            silentRecoveriesForSession = 0
        }
        val sessionId = targetSessionId ?: retryManager.startNewSession(track.id)
        currentSessionId = sessionId
        currentTrack = track
        currentStreamInfo = streamInfo

        val host = runCatching { Uri.parse(streamInfo.url).host ?: "unknown" }.getOrDefault("unknown")
        PlaybackLogger.log("SoftifyPlayback", "playStream: '${track.title}' (session $sessionId), host=$host, bitrate=${streamInfo.bitrateKbps}k, codec=${streamInfo.codec}")

        val mediaSource = createMediaSource(streamInfo, track)
        if (loudnessResult != null) {
            crossfadePlayerManager.applySmoothLoudnessMultiplier(loudnessResult.volumeMultiplier)
            crossfadePlayerManager.applyBoost(loudnessResult.boostDb)
        }
        crossfadePlayerManager.playTrack(track, mediaSource, startPositionMs)
        PlaybackLogger.log("SoftifyPlayback", "crossfadePlayerManager.playTrack invoked for '${track.title}'")

        updateForegroundNotification(track, streamInfo)
    }

    fun prebufferNextTrack(track: Track, streamInfo: StreamInfo, loudnessResult: LoudnessResult? = null) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            Handler(Looper.getMainLooper()).post {
                prebufferNextTrack(track, streamInfo, loudnessResult)
            }
            return
        }
        if (loudnessResult != null) {
            crossfadePlayerManager.secondaryLoudnessMultiplier = loudnessResult.volumeMultiplier
        }
        val mediaSource = createMediaSource(streamInfo, track)
        crossfadePlayerManager.prebufferNextTrack(track, mediaSource)
    }

    fun clearUpcoming() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            Handler(Looper.getMainLooper()).post { clearUpcoming() }
            return
        }
        crossfadePlayerManager.clearUpcoming()
    }

    fun setCrossfadeConfig(durationMs: Long, skipAlbum: Boolean) {
        crossfadePlayerManager.scheduler.crossfadeDurationMs = durationMs
        crossfadePlayerManager.scheduler.skipAlbumConsecutive = skipAlbum
    }

    fun setGaplessEnabled(enabled: Boolean) {
        crossfadePlayerManager.isGaplessEnabled = enabled
    }

    fun updateActiveLoudness(loudness: LoudnessResult?) {
        if (loudness != null) {
            crossfadePlayerManager.applySmoothLoudnessMultiplier(loudness.volumeMultiplier)
            crossfadePlayerManager.applyBoost(loudness.boostDb)
        } else {
            crossfadePlayerManager.applySmoothLoudnessMultiplier(1.0f)
            crossfadePlayerManager.applyBoost(0f)
        }
    }

    private var positionTrackingJob: Job? = null

    private fun startPositionTracking() {
        positionTrackingJob?.cancel()
        positionTrackingJob = serviceScope.launch(Dispatchers.Main) {
            while (true) {
                val p = crossfadePlayerManager.activePlayer
                if (p.isPlaying) {
                    val cur = p.currentPosition
                    val dur = p.duration
                    val fallbackDur = currentTrack?.durationMs?.toLong() ?: 0L
                    crossfadePlayerManager.onPositionUpdate(cur, dur, fallbackDur)
                }
                delay(40L)
            }
        }
    }

    fun checkCrossfade() {
        val cur = crossfadePlayerManager.activePlayer.currentPosition
        val dur = crossfadePlayerManager.activePlayer.duration
        val fallbackDur = currentTrack?.durationMs?.toLong() ?: 0L
        crossfadePlayerManager.onPositionUpdate(cur, dur, fallbackDur)
    }

    fun handleManualSkip(current: Track, onComplete: () -> Unit) {
        crossfadePlayerManager.handleManualSkip(current, onComplete)
    }

    fun playDirectTestUrl(url: String) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            Handler(Looper.getMainLooper()).post {
                playDirectTestUrl(url)
            }
            return
        }
        retryManager.onUserPauseOrStop()
        PlaybackLogger.log("SoftifyPlayback", "playDirectTestUrl: url=$url")
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(15000)

        val mediaSourceFactory = DefaultMediaSourceFactory(httpDataSourceFactory)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMediaId("direct_test_url")
            .setMimeType(MimeTypes.AUDIO_MPEG)
            .build()

        PlaybackLogger.log("SoftifyPlayback", "MediaItem built for direct test URL")
        val mediaSource = mediaSourceFactory.createMediaSource(mediaItem)
        val dummyTrack = Track(
            id = "direct_test",
            sourceId = "direct_test",
            title = "ExoPlayer Direct Test Stream",
            artist = "Google Cloud Storage",
            album = "Diagnostics Bypass",
            durationMs = 120_000u,
            coverUrl = null,
            matchConfidence = null,
            isLiked = false,
            isUnavailable = false
        )
        crossfadePlayerManager.playTrack(dummyTrack, mediaSource)
        PlaybackLogger.log("SoftifyPlayback", "Direct test URL crossfadePlayerManager.playTrack invoked")
        val dummyStream = StreamInfo(
            url = url,
            container = "mp3",
            bitrateKbps = 128u,
            codec = "mp3",
            provider = "direct_http_test",
            isRequestedQuality = false,
            headers = emptyList(),
            expiresAt = null
        )
        updateForegroundNotification(dummyTrack, dummyStream)
    }

    private fun updateForegroundNotification(track: Track, streamInfo: StreamInfo) {
        try {
            val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(track.title)
                .setContentText("${track.artist} • ${streamInfo.bitrateKbps} kbps ${streamInfo.codec.uppercase()}")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setOngoing(true)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            PlaybackLogger.log("SoftifyPlayback", "Foreground notification posted with MEDIA_PLAYBACK type")
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyPlayback", "Foreground notification warning: ${e.javaClass.simpleName} - ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Softify Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Foreground playback controls and media notifications"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onDestroy() {
        PlaybackLogger.log("SoftifyPlayback", "PlaybackService onDestroy")
        isServiceDestroyed = true
        positionTrackingJob?.cancel()
        positionTrackingJob = null
        retryManager.onUserPauseOrStop()
        serviceScope.cancel()
        instance = null
        mediaSession?.run {
            release()
            mediaSession = null
        }
        crossfadePlayerManager.release()
        super.onDestroy()
    }
}
