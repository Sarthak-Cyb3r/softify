package com.softify.app.playback

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.resolveStream

class PlaybackService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private lateinit var player: ExoPlayer
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var currentTrack: Track? = null
    private var currentPreset: QualityPreset = QualityPreset.HIGH
    private var currentStreamInfo: StreamInfo? = null
    private var hasRetriedCurrentTrack: Boolean = false

    companion object {
        const val CHANNEL_ID = "softify_playback_channel"
        const val NOTIFICATION_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(8000)
            .setReadTimeoutMs(8000)

        val mediaSourceFactory = DefaultMediaSourceFactory(httpDataSourceFactory)

        player = ExoPlayer.Builder(this)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()

        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                val track = currentTrack
                if (track != null && !hasRetriedCurrentTrack) {
                    hasRetriedCurrentTrack = true
                    val lastPosition = player.currentPosition
                    println("[Media3] Stream playback error (${error.errorCodeName}). Auto re-resolving stream for '${track.title}' at ${lastPosition}ms")
                    
                    serviceScope.launch {
                        try {
                            val freshStream = resolveStream(track, currentPreset)
                            playStream(track, freshStream, lastPosition)
                        } catch (e: Exception) {
                            println("[Media3] Stream re-resolve failed: ${e.message}")
                        }
                    }
                }
            }
        })

        mediaSession = MediaSession.Builder(this, player).build()
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

    fun playStream(track: Track, streamInfo: StreamInfo, startPositionMs: Long = 0L) {
        currentTrack = track
        currentStreamInfo = streamInfo
        hasRetriedCurrentTrack = false

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(8000)
            .setReadTimeoutMs(8000)

        val headerMap = mutableMapOf<String, String>()
        for (h in streamInfo.headers) {
            headerMap[h.name] = h.value
        }
        if (headerMap.isNotEmpty()) {
            httpDataSourceFactory.setDefaultRequestProperties(headerMap)
        }

        val mediaSourceFactory = DefaultMediaSourceFactory(httpDataSourceFactory)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(streamInfo.url))
            .setMediaId(track.id)
            .build()

        val mediaSource = mediaSourceFactory.createMediaSource(mediaItem)
        player.setMediaSource(mediaSource)
        if (startPositionMs > 0) {
            player.seekTo(startPositionMs)
        }
        player.prepare()
        player.play()

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(track.title)
            .setContentText("${track.artist} • ${streamInfo.bitrateKbps} kbps ${streamInfo.codec.uppercase()}")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        super.onDestroy()
    }
}
