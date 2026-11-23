package com.softify.app.playback

import uniffi.softify_core.Track

enum class CrossfadeState {
    IDLE,
    PREBUFFERING,
    CROSSFADING,
    PAUSED_MID_FADE
}

enum class TransitionType {
    NONE,
    GAPLESS,
    CROSSFADE,
    MANUAL_SKIP_FADE
}

interface CrossfadePlayerActionHandler {
    fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float)
    fun startSecondaryPlayback(track: Track, initialVolume: Float)
    fun onCrossfadeCompleted(newActiveTrack: Track)
    fun pauseBothPlayers()
    fun resumeBothPlayers()
    fun stopSecondaryPlayer()
}

class CrossfadeScheduler(
    var crossfadeDurationMs: Long = 0L,
    var skipAlbumConsecutive: Boolean = true,
    private val timeProvider: () -> Long = { System.currentTimeMillis() },
    var actionHandler: CrossfadePlayerActionHandler? = null
) {
    var state: CrossfadeState = CrossfadeState.IDLE
        private set

    var currentTrack: Track? = null
        private set
    var nextTrack: Track? = null
        private set

    var crossfadeProgress: Float = 0f
        private set

    var lastTransitionType: TransitionType = TransitionType.NONE
        private set

    private var fadeStartTimeMs: Long = 0L
    private var fadeElapsedBeforePauseMs: Long = 0L
    private var activeFadeDurationMs: Long = 0L
    private var isManualSkipFade: Boolean = false
    private var onManualSkipFadeComplete: (() -> Unit)? = null

    fun shouldCrossfade(current: Track?, next: Track?): Boolean {
        if (crossfadeDurationMs <= 0L) return false
        if (current == null || next == null) return false
        if (skipAlbumConsecutive) {
            val album1 = current.album?.trim()
            val album2 = next.album?.trim()
            if (!album1.isNullOrEmpty() && !album2.isNullOrEmpty() && album1.equals(album2, ignoreCase = true)) {
                return false
            }
        }
        return true
    }

    fun onNextTrackPrebuffered(current: Track, next: Track) {
        currentTrack = current
        nextTrack = next
        if (state == CrossfadeState.IDLE) {
            state = CrossfadeState.PREBUFFERING
        }
    }

    fun startCrossfade(current: Track, next: Track, customDurationMs: Long? = null) {
        val duration = customDurationMs ?: crossfadeDurationMs
        if (duration <= 0L || !shouldCrossfade(current, next)) {
            lastTransitionType = TransitionType.GAPLESS
            state = CrossfadeState.IDLE
            return
        }

        currentTrack = current
        nextTrack = next
        activeFadeDurationMs = duration
        fadeStartTimeMs = timeProvider()
        fadeElapsedBeforePauseMs = 0L
        crossfadeProgress = 0f
        isManualSkipFade = false
        onManualSkipFadeComplete = null
        lastTransitionType = TransitionType.CROSSFADE
        state = CrossfadeState.CROSSFADING

        val (outVol, inVol) = CrossfadeCurve.calculate(0f)
        actionHandler?.startSecondaryPlayback(next, inVol)
        actionHandler?.setPlayerVolumes(outVol, inVol)
    }

    fun startManualSkipFade(current: Track, onFadeComplete: () -> Unit) {
        currentTrack = current
        nextTrack = null
        activeFadeDurationMs = 300L
        fadeStartTimeMs = timeProvider()
        fadeElapsedBeforePauseMs = 0L
        crossfadeProgress = 0f
        isManualSkipFade = true
        onManualSkipFadeComplete = onFadeComplete
        lastTransitionType = TransitionType.MANUAL_SKIP_FADE
        state = CrossfadeState.CROSSFADING

        val (outVol, _) = CrossfadeCurve.calculate(0f)
        actionHandler?.setPlayerVolumes(outVol, 0f)
    }

    /**
     * Step the fade progress based on timeProvider.
     * Returns true if crossfade or skip fade completed on this step.
     */
    fun step(): Boolean {
        if (state != CrossfadeState.CROSSFADING) return false

        val elapsed = (timeProvider() - fadeStartTimeMs) + fadeElapsedBeforePauseMs
        val duration = activeFadeDurationMs.coerceAtLeast(1L)
        val progress = (elapsed.toFloat() / duration.toFloat()).coerceIn(0f, 1f)
        crossfadeProgress = progress

        val (outVol, inVol) = CrossfadeCurve.calculate(progress)
        if (isManualSkipFade) {
            actionHandler?.setPlayerVolumes(outVol, 0f)
        } else {
            actionHandler?.setPlayerVolumes(outVol, inVol)
        }

        if (progress >= 1.0f) {
            state = CrossfadeState.IDLE
            crossfadeProgress = 1.0f

            if (isManualSkipFade) {
                actionHandler?.stopSecondaryPlayer()
                val cb = onManualSkipFadeComplete
                onManualSkipFadeComplete = null
                cb?.invoke()
            } else {
                val completedTrack = nextTrack
                if (completedTrack != null) {
                    currentTrack = completedTrack
                    nextTrack = null
                    actionHandler?.onCrossfadeCompleted(completedTrack)
                } else {
                    actionHandler?.stopSecondaryPlayer()
                }
            }
            return true
        }
        return false
    }

    fun pause() {
        if (state == CrossfadeState.CROSSFADING) {
            fadeElapsedBeforePauseMs += (timeProvider() - fadeStartTimeMs)
            state = CrossfadeState.PAUSED_MID_FADE
            actionHandler?.pauseBothPlayers()
        }
    }

    fun resume() {
        if (state == CrossfadeState.PAUSED_MID_FADE) {
            fadeStartTimeMs = timeProvider()
            state = CrossfadeState.CROSSFADING
            actionHandler?.resumeBothPlayers()
        }
    }

    fun cancel() {
        state = CrossfadeState.IDLE
        crossfadeProgress = 0f
        isManualSkipFade = false
        onManualSkipFadeComplete = null
        actionHandler?.stopSecondaryPlayer()
    }
}
