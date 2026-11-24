package com.softify.app.playback

import uniffi.softify_core.Track

const val TIME_UNSET: Long = -9223372036854775807L

enum class CrossfadeState {
    IDLE,
    PREBUFFERING,
    WAITING_FOR_PLAYER_B,
    CROSSFADING,
    PAUSED_MID_FADE
}

enum class TransitionType {
    NONE,
    GAPLESS,
    CROSSFADE,
    MANUAL_SKIP_FADE,
    HARD_END
}

data class TransitionTrace(
    val transitionId: String,
    val fromTrackTitle: String,
    val toTrackTitle: String,
    var resolveStartedMs: Long = 0L,
    var resolveFinishedMs: Long = 0L,
    var playerBPreparedMs: Long = 0L,
    var playerBReadyMs: Long = 0L,
    var fadeScheduledTimeMs: Long = 0L,
    var fadeActuallyStartedMs: Long = 0L,
    var trackAEndedMs: Long = 0L,
    var trackBAudibleMs: Long = 0L,
    var trackADurationMs: Long = 0L,
    var isTimeUnset: Boolean = false,
    var transitionType: TransitionType = TransitionType.NONE,
    var notes: String = ""
) {
    fun formatSummary(): String {
        val bReadyRel = if (playerBReadyMs > 0 && fadeActuallyStartedMs > 0) {
            val diff = playerBReadyMs - fadeActuallyStartedMs
            if (diff <= 0) "ready ${-diff}ms before fade" else "ready ${diff}ms after fade"
        } else if (playerBReadyMs > 0) {
            "ready"
        } else {
            "NOT READY"
        }

        val silenceMs = if (trackAEndedMs > 0 && trackBAudibleMs > 0) {
            (trackBAudibleMs - trackAEndedMs).coerceAtLeast(0L)
        } else 0L

        val durStr = if (isTimeUnset) "TIME_UNSET (${trackADurationMs}ms fallback)" else "${trackADurationMs}ms"
        val noteSuffix = if (notes.isNotEmpty()) " [$notes]" else ""
        return "[$transitionType] '$fromTrackTitle' -> '$toTrackTitle' | Dur: $durStr | B: $bReadyRel | Silence: ${silenceMs}ms$noteSuffix"
    }
}

interface CrossfadePlayerActionHandler {
    fun setPlayerVolumes(primaryVol: Float, secondaryVol: Float)
    fun startSecondaryPlayback(track: Track, initialVolume: Float)
    fun onCrossfadeCompleted(newActiveTrack: Track)
    fun pauseBothPlayers()
    fun resumeBothPlayers()
    fun stopSecondaryPlayer()
    fun requestPrepareNextTrack(nextTrack: Track) {}
    fun fallbackToGapless(nextTrack: Track) {}
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

    var isPlayerBReady: Boolean = false
        private set

    private var fadeStartTimeMs: Long = 0L
    private var fadeElapsedBeforePauseMs: Long = 0L
    private var activeFadeDurationMs: Long = 0L
    private var isManualSkipFade: Boolean = false
    private var onManualSkipFadeComplete: (() -> Unit)? = null

    // Transition Trace Ring Buffer (last 10 transitions)
    private val _traces = mutableListOf<TransitionTrace>()
    val traces: List<TransitionTrace> get() = _traces.toList()

    var activeTrace: TransitionTrace? = null
        private set

    private var nextPrepareRequested = false
    private var traceSequence = 0L

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

    fun startNewTrace(current: Track, next: Track): TransitionTrace {
        traceSequence++
        val trace = TransitionTrace(
            transitionId = "tr_$traceSequence",
            fromTrackTitle = current.title,
            toTrackTitle = next.title,
            trackADurationMs = current.durationMs.toLong()
        )
        activeTrace = trace
        return trace
    }

    fun recordTrace(trace: TransitionTrace) {
        if (_traces.size >= 10) {
            _traces.removeAt(0)
        }
        _traces.add(trace)
    }

    fun onResolveStarted(current: Track, next: Track) {
        val trace = activeTrace ?: startNewTrace(current, next)
        trace.resolveStartedMs = timeProvider()
    }

    fun onResolveFinished(success: Boolean) {
        activeTrace?.let {
            it.resolveFinishedMs = timeProvider()
            if (!success) {
                it.notes = "resolve_failed"
            }
        }
    }

    fun onNextTrackPrebuffered(current: Track, next: Track) {
        currentTrack = current
        nextTrack = next
        isPlayerBReady = false
        val trace = activeTrace ?: startNewTrace(current, next)
        trace.playerBPreparedMs = timeProvider()
        if (state == CrossfadeState.IDLE) {
            state = CrossfadeState.PREBUFFERING
        }
    }

    fun onPlayerBReady() {
        isPlayerBReady = true
        val trace = activeTrace
        val now = timeProvider()
        trace?.playerBReadyMs = now

        // If we were waiting for Player B because scheduled fade time arrived early, trigger fade now!
        if (state == CrossfadeState.WAITING_FOR_PLAYER_B) {
            val cur = currentTrack
            val nxt = nextTrack
            if (cur != null && nxt != null) {
                trace?.notes = "fade_delayed_for_b"
                val remainingFade = activeFadeDurationMs.coerceAtLeast(1000L)
                executeStartCrossfade(cur, nxt, remainingFade)
            }
        }
    }

    fun onPlayerBAudible() {
        activeTrace?.trackBAudibleMs = timeProvider()
    }

    fun onTrackAEnded() {
        activeTrace?.trackAEndedMs = timeProvider()
    }

    fun onPositionUpdate(currentPosMs: Long, playerDurationMs: Long, fallbackDurationMs: Long) {
        val current = currentTrack ?: return
        val next = nextTrack

        // Handle C.TIME_UNSET or unknown/zero duration by falling back to metadata duration
        val isUnset = playerDurationMs <= 0L || playerDurationMs == TIME_UNSET
        val effectiveDurationMs = if (!isUnset) {
            playerDurationMs
        } else if (fallbackDurationMs > 0L) {
            fallbackDurationMs
        } else {
            current.durationMs.toLong()
        }

        if (effectiveDurationMs <= 0L) return

        val remainingMs = effectiveDurationMs - currentPosMs
        activeTrace?.let {
            it.trackADurationMs = effectiveDurationMs
            it.isTimeUnset = isUnset
        }

        // 1. Check if we need to request pre-resolving and preparing Player B ~30s before end
        if (remainingMs <= 30_000L && next != null && !nextPrepareRequested && state == CrossfadeState.IDLE) {
            nextPrepareRequested = true
            actionHandler?.requestPrepareNextTrack(next)
        }

        // 2. Check if we have entered the crossfade window
        if (crossfadeDurationMs > 0L && remainingMs <= crossfadeDurationMs && next != null) {
            if (shouldCrossfade(current, next)) {
                when (state) {
                    CrossfadeState.PREBUFFERING -> {
                        val trace = activeTrace ?: startNewTrace(current, next)
                        trace.fadeScheduledTimeMs = timeProvider()
                        if (isPlayerBReady) {
                            // Player B is ready ahead of time -> start crossfade cleanly!
                            executeStartCrossfade(current, next, remainingMs.coerceAtLeast(1000L))
                        } else {
                            // Player B is NOT ready yet: delay fade and wait
                            state = CrossfadeState.WAITING_FOR_PLAYER_B
                            activeFadeDurationMs = remainingMs.coerceAtLeast(1000L)
                        }
                    }
                    CrossfadeState.WAITING_FOR_PLAYER_B -> {
                        // While waiting: if remaining time drops critically low (<150ms) and B is still not ready,
                        // fall back to gapless so Player A doesn't end into silence!
                        if (remainingMs <= 150L && !isPlayerBReady) {
                            val trace = activeTrace ?: startNewTrace(current, next)
                            trace.notes = "b_late_fallback_to_gapless"
                            trace.transitionType = TransitionType.GAPLESS
                            lastTransitionType = TransitionType.GAPLESS
                            state = CrossfadeState.IDLE
                            actionHandler?.fallbackToGapless(next)
                        }
                    }
                    else -> {}
                }
            } else if (state == CrossfadeState.PREBUFFERING) {
                // Gapless fallback (e.g. consecutive album tracks or disabled)
                val trace = activeTrace ?: startNewTrace(current, next)
                trace.transitionType = TransitionType.GAPLESS
                lastTransitionType = TransitionType.GAPLESS
                state = CrossfadeState.IDLE
                actionHandler?.fallbackToGapless(next)
            }
        }
    }

    fun startCrossfade(current: Track, next: Track, customDurationMs: Long? = null) {
        val duration = customDurationMs ?: crossfadeDurationMs
        if (duration <= 0L || !shouldCrossfade(current, next)) {
            lastTransitionType = TransitionType.GAPLESS
            activeTrace?.transitionType = TransitionType.GAPLESS
            state = CrossfadeState.IDLE
            actionHandler?.fallbackToGapless(next)
            return
        }

        currentTrack = current
        nextTrack = next
        activeFadeDurationMs = duration
        val trace = activeTrace ?: startNewTrace(current, next)
        trace.fadeScheduledTimeMs = timeProvider()

        if (!isPlayerBReady) {
            state = CrossfadeState.WAITING_FOR_PLAYER_B
            return
        }

        executeStartCrossfade(current, next, duration)
    }

    private fun executeStartCrossfade(current: Track, next: Track, durationMs: Long) {
        currentTrack = current
        nextTrack = next
        activeFadeDurationMs = durationMs
        fadeStartTimeMs = timeProvider()
        fadeElapsedBeforePauseMs = 0L
        crossfadeProgress = 0f
        isManualSkipFade = false
        onManualSkipFadeComplete = null
        lastTransitionType = TransitionType.CROSSFADE
        state = CrossfadeState.CROSSFADING

        val trace = activeTrace ?: startNewTrace(current, next)
        trace.fadeActuallyStartedMs = fadeStartTimeMs
        trace.transitionType = TransitionType.CROSSFADE

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

        val trace = TransitionTrace(
            transitionId = "manual_skip_${timeProvider()}",
            fromTrackTitle = current.title,
            toTrackTitle = "(manual skip)",
            fadeScheduledTimeMs = fadeStartTimeMs,
            fadeActuallyStartedMs = fadeStartTimeMs,
            transitionType = TransitionType.MANUAL_SKIP_FADE
        )
        activeTrace = trace

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

            val trace = activeTrace
            if (trace != null) {
                trace.trackAEndedMs = timeProvider()
                recordTrace(trace)
                activeTrace = null
            }

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
                    isPlayerBReady = false
                    nextPrepareRequested = false
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

    fun cancel(reason: String = "cancelled") {
        activeTrace?.let {
            it.notes = reason
            recordTrace(it)
            activeTrace = null
        }
        state = CrossfadeState.IDLE
        crossfadeProgress = 0f
        isPlayerBReady = false
        nextPrepareRequested = false
        isManualSkipFade = false
        onManualSkipFadeComplete = null
        actionHandler?.stopSecondaryPlayer()
    }
}
