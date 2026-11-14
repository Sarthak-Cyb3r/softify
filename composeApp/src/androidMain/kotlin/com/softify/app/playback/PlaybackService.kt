package com.softify.app.playback

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import uniffi.softify_core.HeaderPair
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.resolveStream

class PlaybackService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    lateinit var player: ExoPlayer
        private set
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var currentTrack: Track? = null
    private var currentPreset: QualityPreset = QualityPreset.HIGH
    private var currentStreamInfo: StreamInfo? = null
    private var hasRetriedCurrentTrack: Boolean = false

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

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(15000)

        val mediaSourceFactory = DefaultMediaSourceFactory(httpDataSourceFactory)

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(audioAttributes, true)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()

        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                val stateName = when (state) {
                    Player.STATE_IDLE -> "IDLE"
                    Player.STATE_BUFFERING -> "BUFFERING"
                    Player.STATE_READY -> "READY"
                    Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN($state)"
                }
                PlaybackLogger.log("SoftifyPlayback", "Player state: $stateName (playWhenReady=${player.playWhenReady}, duration=${player.duration}ms)")
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                PlaybackLogger.log("SoftifyPlayback", "Player isPlaying changed: $isPlaying")
            }

            override fun onPlayerError(error: PlaybackException) {
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
                if (track != null && !hasRetriedCurrentTrack) {
                    hasRetriedCurrentTrack = true
                    val lastPosition = player.currentPosition
                    PlaybackLogger.log("SoftifyPlayback", "Auto re-resolving stream for '${track.title}' at ${lastPosition}ms")
                    serviceScope.launch {
                        try {
                            val freshStream = resolveStream(track, currentPreset)
                            playStream(track, freshStream, lastPosition)
                        } catch (e: Exception) {
                            PlaybackLogger.log("SoftifyPlayback", "Stream auto re-resolve failed: ${e.message}")
                        }
                    }
                }
            }
        })

        mediaSession = MediaSession.Builder(this, player).build()
        PlaybackLogger.log("SoftifyPlayback", "MediaSession initialized")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        val action = intent?.action
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

    fun playStream(track: Track, streamInfo: StreamInfo, startPositionMs: Long = 0L) {
        currentTrack = track
        currentStreamInfo = streamInfo
        hasRetriedCurrentTrack = false

        val host = runCatching { Uri.parse(streamInfo.url).host ?: "unknown" }.getOrDefault("unknown")
        PlaybackLogger.log("SoftifyPlayback", "playStream: '${track.title}', host=$host, bitrate=${streamInfo.bitrateKbps}k, codec=${streamInfo.codec}")

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(15000)

        val headerMap = mutableMapOf<String, String>()
        for (h in streamInfo.headers) {
            headerMap[h.name] = h.value
        }
        if (headerMap.isNotEmpty()) {
            httpDataSourceFactory.setDefaultRequestProperties(headerMap)
            PlaybackLogger.log("SoftifyPlayback", "Applied HTTP request headers: ${headerMap.keys.joinToString()}")
        }

        val mimeType = when (streamInfo.codec.lowercase()) {
            "opus" -> MimeTypes.AUDIO_OPUS
            "mp3" -> MimeTypes.AUDIO_MPEG
            else -> MimeTypes.AUDIO_MP4
        }

        val mediaSourceFactory = DefaultMediaSourceFactory(httpDataSourceFactory)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(streamInfo.url))
            .setMediaId(track.id)
            .setMimeType(mimeType)
            .build()

        PlaybackLogger.log("SoftifyPlayback", "MediaItem built: mediaId=${track.id}, mimeType=$mimeType")

        val mediaSource = mediaSourceFactory.createMediaSource(mediaItem)
        player.setMediaSource(mediaSource)
        if (startPositionMs > 0) {
            player.seekTo(startPositionMs)
        }
        player.prepare()
        player.play()
        PlaybackLogger.log("SoftifyPlayback", "player.prepare() & player.play() invoked")

        updateForegroundNotification(track, streamInfo)
    }

    fun playDirectTestUrl(url: String) {
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
        player.setMediaSource(mediaSource)
        player.prepare()
        player.play()
        PlaybackLogger.log("SoftifyPlayback", "Direct test URL player.prepare() & player.play() invoked")

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
        instance = null
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        super.onDestroy()
    }
}
