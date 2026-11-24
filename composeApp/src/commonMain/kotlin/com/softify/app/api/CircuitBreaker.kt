package com.softify.app.api

import com.softify.app.util.PlaybackLogger
import kotlin.math.min
import kotlin.math.pow
import kotlin.random.Random

enum class CircuitState {
    CLOSED,
    OPEN,
    HALF_OPEN
}

/**
 * Resilient circuit breaker for edge API requests.
 * Automatically fast-fails on consecutive 429/503 errors and respects Retry-After headers.
 */
class CircuitBreaker(
    private val failureThreshold: Int = 3,
    private val baseBackoffMs: Long = 1000L,
    private val maxBackoffMs: Long = 30000L,
    private val jitterFactor: Double = 0.2,
    private val clock: () -> Long = { System.currentTimeMillis() }
) {
    private var state: CircuitState = CircuitState.CLOSED
    private var failureCount: Int = 0
    private var lastFailureTime: Long = 0L
    private var openUntilTime: Long = 0L
    private var backoffAttempt: Int = 0

    val currentState: CircuitState
        get() = synchronized(this) {
            val now = clock()
            if (state == CircuitState.OPEN && now >= openUntilTime) {
                state = CircuitState.HALF_OPEN
            }
            state
        }

    fun canExecute(): Boolean = synchronized(this) {
        val current = currentState
        when (current) {
            CircuitState.CLOSED -> true
            CircuitState.HALF_OPEN -> true
            CircuitState.OPEN -> false
        }
    }

    fun recordSuccess() = synchronized(this) {
        failureCount = 0
        backoffAttempt = 0
        state = CircuitState.CLOSED
    }

    fun recordFailure(statusCode: Int? = null, retryAfterSeconds: Long? = null) = synchronized(this) {
        val now = clock()
        failureCount++
        lastFailureTime = now

        val isRateLimitedOrUnavailable = statusCode == 429 || statusCode == 503

        if (isRateLimitedOrUnavailable || failureCount >= failureThreshold) {
            state = CircuitState.OPEN
            backoffAttempt++

            val backoffMs = if (retryAfterSeconds != null && retryAfterSeconds > 0) {
                retryAfterSeconds * 1000L
            } else {
                val exp = baseBackoffMs * (2.0.pow(min(backoffAttempt, 6).toDouble())).toLong()
                val capped = min(maxBackoffMs, exp)
                val jitter = (Random.nextDouble(-jitterFactor, jitterFactor) * capped).toLong()
                capped + jitter
            }

            openUntilTime = now + backoffMs
            PlaybackLogger.log(
                "SoftifyEdge",
                "Circuit breaker OPEN until $openUntilTime (backoff: ${backoffMs}ms, status: $statusCode)"
            )
        }
    }

    fun reset() = synchronized(this) {
        state = CircuitState.CLOSED
        failureCount = 0
        backoffAttempt = 0
        openUntilTime = 0L
    }
}
