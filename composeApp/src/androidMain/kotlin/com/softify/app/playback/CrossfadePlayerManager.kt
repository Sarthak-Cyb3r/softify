package com.softify.app.playback

import android.content.Context
import android.media.audiofx.LoudnessEnhancer
import android.os.Handler
import android.os.Looper
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.session.MediaSession
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uniffi.softify_core.Track

class CrossfadePlayerManager(
    private val context: Context,
    private val scope: CoroutineScope,
    private val onMediaSessionPlayerChanged: (ExoPlayer) -> Unit,
    private val onTrackTransitioned: (Track) -> Unit,
    private val onTelemetryUpdated: (CrossfadeState, Float, TransitionType) -> Unit
) : CrossfadePlayerActionHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    private var playerA: ExoPlayer
    private var playerB: ExoPlayer

    var activePlayer: ExoPlayer
        private set
    var secondaryPlayer: ExoPlayer
        private set

    val scheduler = CrossfadeScheduler(
        crossfadeDurationMs = 0L,
        skipAlbumConsecutive = true,
        timeProvider = { System.currentTimeMillis() }
    )

    var currentTrack: Track? = null
        private set
    var nextTrack: Track? = null
        private set
    private var nextMediaSource: MediaSource? = null

    var activeLoudnessMultiplier: Float = 1.0f
    var secondaryLoudnessMultiplier: Float = 1.0f
    var baseVolume: Float = 1.0f
    private var activeEnhancer: LoudnessEnhancer? = null

    var onPlayerError: ((PlaybackException) -> Unit)? = null
    var onPlaybackStateChanged: ((Int) -> Unit)? = null
    var onPlayWhenReadyChanged: ((Boolean) -> Unit)? = null
    var onTracesUpdated: ((List<TransitionTrace>) -> Unit)? = null
    var onRequestNextTrackPrepare: ((Track) -> Unit)? = null

    private var fadeTickerJob: Job? = null
    private var rampJob: Job? = null
    var isGaplessEnabled: Boolean = true

    init {
        scheduler.actionHandler = this

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()

        playerA = ExoPlayer.Builder(context)
            .setAudioAttributes(audioAttributes, true)
            .build()

        playerB = ExoPlayer.Builder(context)
            .setAudioAttributes(audioAttributes, true)
            .build()

        activePlayer = playerA
        secondaryPlayer = playerB

        setupPlayerListeners(playerA, "PlayerA")
        setupPlayerListeners(playerB, "PlayerB")
    }

    private fun setupPlayerListeners(p: ExoPlayer, tag: String) {
        p.addListener(object : Player.Listener {
            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                if (p == activePlayer && reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO && mediaItem != null) {
                    val nTrack = nextTrack
                    if (nTrack != null && (nTrack.id == mediaItem.mediaId || mediaItem.mediaId.isEmpty())) {
                        PlaybackLogger.log("SoftifyPlayback", "$tag: Seamless gapless transition to '${nTrack.title}'")
                        scheduler.onTrackAEnded()
                        currentTrack = nTrack
                        nextTrack = null
                        nextMediaSource = null
                        onTelemetryUpdated(CrossfadeState.IDLE, 0f, TransitionType.GAPLESS)
                        onTracesUpdated?.invoke(scheduler.traces)
                        onTrackTransitioned(nTrack)
                    }
                }
            }

            override fun onPlaybackStateChanged(state: Int) {
                val stateName = when (state) {
                    Player.STATE_IDLE -> "IDLE"
                    Player.STATE_BUFFERING -> "BUFFERING"
                    Player.STATE_READY -> "READY"
                    Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN($state)"
                }
                PlaybackLogger.log("SoftifyPlayback", "$tag state: $stateName (pos=${p.currentPosition}ms)")

                if (p == secondaryPlayer && state == Player.STATE_READY) {
                    PlaybackLogger.log("SoftifyPlayback", "Secondary player reached STATE_READY for upcoming track")
                    scheduler.onPlayerBReady()
                    onTracesUpdated?.invoke(scheduler.traces)
                }

                if (p == activePlayer) {
                    if (state == Player.STATE_ENDED) {
                        scheduler.onTrackAEnded()
                        onTracesUpdated?.invoke(scheduler.traces)
                    }
                    onPlaybackStateChanged?.invoke(state)
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (p == secondaryPlayer && isPlaying) {
                    scheduler.onPlayerBAudible()
                    onTracesUpdated?.invoke(scheduler.traces)
                }
                if (p == activePlayer) {
                    onPlayWhenReadyChanged?.invoke(isPlaying)
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                PlaybackLogger.log("SoftifyPlayback", "$tag error: ${error.errorCodeName} - ${error.message}")
                if (p == secondaryPlayer) {
                    scheduler.cancel("secondary_player_error: ${error.errorCodeName}")
                    onTracesUpdated?.invoke(scheduler.traces)
                }
                if (p == activePlayer) {
                    onPlayerError?.invoke(error)
                }
            }
        })
    }

    fun playTrack(track: Track, mediaSource: MediaSource, startPosMs: Long = 0L) {
        cancelActiveFade()
        currentTrack = track
        nextTrack = null
        nextMediaSource = null

        activePlayer.setMediaSource(mediaSource)
        if (startPosMs > 0) {
            activePlayer.seekTo(startPosMs)
        }
        activePlayer.prepare()
        activePlayer.play()
        applySmoothLoudnessMultiplier(activeLoudnessMultiplier)
        onMediaSessionPlayerChanged(activePlayer)
        onTelemetryUpdated(CrossfadeState.IDLE, 0f, TransitionType.NONE)
        onTracesUpdated?.invoke(scheduler.traces)
    }

    fun prebufferNextTrack(track: Track, mediaSource: MediaSource) {
        nextTrack = track
        nextMediaSource = mediaSource

        val current = currentTrack ?: return
        scheduler.onNextTrackPrebuffered(current, track)
        onTracesUpdated?.invoke(scheduler.traces)

        if (scheduler.crossfadeDurationMs > 0L && scheduler.shouldCrossfade(current, track)) {
            // In crossfade mode: prepare secondary player in advance with zero initial volume
            PlaybackLogger.log("SoftifyPlayback", "Pre-buffering next track '${track.title}' on secondary player for crossfade")
            secondaryPlayer.setMediaSource(mediaSource)
            secondaryPlayer.volume = 0f
            secondaryPlayer.prepare()
            onTelemetryUpdated(CrossfadeState.PREBUFFERING, 0f, TransitionType.NONE)
        } else if (isGaplessEnabled) {
            // In gapless mode: append to activePlayer timeline for continuous playback
            PlaybackLogger.log("SoftifyPlayback", "Adding upcoming media source for '${track.title}' to active player timeline (gapless)")
            if (activePlayer.mediaItemCount <= 1) {
                activePlayer.addMediaSource(mediaSource)
            }
            onTelemetryUpdated(CrossfadeState.PREBUFFERING, 0f, TransitionType.GAPLESS)
        }
    }

    fun clearUpcoming() {
        nextTrack = null
        nextMediaSource = null
        scheduler.cancel("upcoming_cleared")
        secondaryPlayer.stop()
        secondaryPlayer.clearMediaItems()
        if (activePlayer.mediaItemCount > 1) {
            // Remove upcoming media items from timeline
            for (i in (activePlayer.mediaItemCount - 1) downTo 1) {
                activePlayer.removeMediaItem(i)
            }
        }
        onTelemetryUpdated(CrossfadeState.IDLE, 0f, TransitionType.NONE)
        onTracesUpdated?.invoke(scheduler.traces)
    }

    fun onPositionUpdate(currentPosMs: Long, playerDurationMs: Long, fallbackDurationMs: Long) {
        scheduler.onPositionUpdate(currentPosMs, playerDurationMs, fallbackDurationMs)
        if (scheduler.state == CrossfadeState.CROSSFADING && fadeTickerJob == null) {
            startFadeTicker()
        }
    }

    fun handleManualSkip(current: Track, onComplete: () -> Unit) {
        PlaybackLogger.log("SoftifyPlayback", "Manual skip: starting 300ms fade-out for '${current.title}'")
        scheduler.startManualSkipFade(current) {
            stopSecondaryPlayer()
            activePlayer.stop()
            activePlayer.clearMediaItems()
            onComplete()
        }
        onTracesUpdated?.invoke(scheduler.traces)
        startFadeTicker()
    }

    private fun startFadeTicker() {
        fadeTickerJob?.cancel()
        fadeTickerJob = scope.launch(Dispatchers.Main) {
            while (scheduler.state == CrossfadeState.CROSSFADING) {
                delay(40L)
                val completed = scheduler.step()
                onTelemetryUpdated(
                    scheduler.state,
                    scheduler.crossfadeProgress,
                    scheduler.lastTransitionType
                )
                onTracesUpdated?.invoke(scheduler.traces)
                if (completed) {
                    fadeTickerJob = null
                    break
                }
            }
        }
    }

    override fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float) {
        val outV = (baseVolume * activeLoudnessMultiplier * primaryVol).coerceIn(0f, 1f)
        val inV = (baseVolume * secondaryLoudnessMultiplier * secondaryVol).coerceIn(0f, 1f)
        activePlayer.volume = outV
        secondaryPlayer.volume = inV
    }

    override fun startSecondaryPlayback(track: Track, initialVolume: Float) {
        secondaryPlayer.volume = initialVolume
        secondaryPlayer.play()
    }

    override fun onCrossfadeCompleted(newActiveTrack: Track) {
        PlaybackLogger.log("SoftifyPlayback", "Crossfade completed; swapping player roles to '${newActiveTrack.title}'")
        activePlayer.stop()
        activePlayer.clearMediaItems()

        // Swap primary and secondary player references
        val temp = activePlayer
        activePlayer = secondaryPlayer
        secondaryPlayer = temp

        val tempMult = activeLoudnessMultiplier
        activeLoudnessMultiplier = secondaryLoudnessMultiplier
        secondaryLoudnessMultiplier = tempMult

        currentTrack = newActiveTrack
        nextTrack = null
        nextMediaSource = null

        onMediaSessionPlayerChanged(activePlayer)
        onTelemetryUpdated(CrossfadeState.IDLE, 1.0f, TransitionType.CROSSFADE)
        onTracesUpdated?.invoke(scheduler.traces)
        onTrackTransitioned(newActiveTrack)
    }

    override fun pauseBothPlayers() {
        activePlayer.pause()
        secondaryPlayer.pause()
        fadeTickerJob?.cancel()
        fadeTickerJob = null
        onTelemetryUpdated(CrossfadeState.PAUSED_MID_FADE, scheduler.crossfadeProgress, scheduler.lastTransitionType)
        onTracesUpdated?.invoke(scheduler.traces)
    }

    override fun resumeBothPlayers() {
        activePlayer.play()
        secondaryPlayer.play()
        startFadeTicker()
    }

    override fun stopSecondaryPlayer() {
        secondaryPlayer.stop()
        secondaryPlayer.clearMediaItems()
        secondaryPlayer.volume = 0f
    }

    override fun fallbackToGapless(nextTrack: Track) {
        val src = nextMediaSource ?: return
        PlaybackLogger.log("SoftifyPlayback", "Crossfade fallbackToGapless invoked for '${nextTrack.title}'")
        secondaryPlayer.stop()
        secondaryPlayer.clearMediaItems()
        if (activePlayer.mediaItemCount <= 1) {
            activePlayer.addMediaSource(src)
        }
        onTelemetryUpdated(CrossfadeState.IDLE, 0f, TransitionType.GAPLESS)
        onTracesUpdated?.invoke(scheduler.traces)
    }

    override fun requestPrepareNextTrack(nextTrack: Track) {
        onRequestNextTrackPrepare?.invoke(nextTrack)
    }

    fun applySmoothLoudnessMultiplier(targetMultiplier: Float) {
        rampJob?.cancel()
        val startVol = activePlayer.volume
        val endVol = (baseVolume * targetMultiplier).coerceIn(0f, 1f)
        activeLoudnessMultiplier = targetMultiplier

        rampJob = scope.launch(Dispatchers.Main) {
            val steps = 4
            val stepDelay = 35L // ~140ms total ramp
            for (i in 1..steps) {
                delay(stepDelay)
                val alpha = i.toFloat() / steps.toFloat()
                activePlayer.volume = startVol + (endVol - startVol) * alpha
            }
            activePlayer.volume = endVol
        }
    }

    fun applyBoost(boostDb: Float) {
        try {
            if (boostDb > 0f) {
                val enhancer = activeEnhancer ?: LoudnessEnhancer(activePlayer.audioSessionId).also {
                    activeEnhancer = it
                }
                enhancer.setTargetGain((boostDb * 100).toInt())
                enhancer.enabled = true
                PlaybackLogger.log("SoftifyPlayback", "LoudnessEnhancer enabled with target gain +${boostDb}dB")
            } else {
                activeEnhancer?.enabled = false
            }
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyPlayback", "LoudnessEnhancer warning: ${e.message}")
        }
    }

    fun cancelActiveFade() {
        fadeTickerJob?.cancel()
        fadeTickerJob = null
        scheduler.cancel("active_fade_cancelled")
        stopSecondaryPlayer()
    }

    fun release() {
        fadeTickerJob?.cancel()
        fadeTickerJob = null
        rampJob?.cancel()
        scheduler.cancel("manager_released")
        runCatching { activeEnhancer?.release() }
        playerA.release()
        playerB.release()
    }
}
