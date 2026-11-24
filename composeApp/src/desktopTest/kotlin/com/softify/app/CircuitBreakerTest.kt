package com.softify.app

import com.softify.app.api.CircuitBreaker
import com.softify.app.api.CircuitState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CircuitBreakerTest {

    @Test
    fun testCircuitStartsClosedAndCanExecute() {
        val breaker = CircuitBreaker()
        assertEquals(CircuitState.CLOSED, breaker.currentState)
        assertTrue(breaker.canExecute())
    }

    @Test
    fun testCircuitOpensImmediatelyOn429RateLimit() {
        var currentTime = 1000000L
        val breaker = CircuitBreaker(clock = { currentTime })

        // HTTP 429 with 60 second Retry-After
        breaker.recordFailure(statusCode = 429, retryAfterSeconds = 60L)

        assertEquals(CircuitState.OPEN, breaker.currentState)
        assertFalse(breaker.canExecute())

        // Fast-forward 30 seconds: still open
        currentTime += 30000L
        assertEquals(CircuitState.OPEN, breaker.currentState)
        assertFalse(breaker.canExecute())

        // Fast-forward past 60 seconds: becomes half-open to probe
        currentTime += 31000L
        assertEquals(CircuitState.HALF_OPEN, breaker.currentState)
        assertTrue(breaker.canExecute())

        // Successful probe closes breaker
        breaker.recordSuccess()
        assertEquals(CircuitState.CLOSED, breaker.currentState)
        assertTrue(breaker.canExecute())
    }

    @Test
    fun testCircuitOpensAfterConsecutiveFailures() {
        var currentTime = 2000000L
        val breaker = CircuitBreaker(failureThreshold = 3, clock = { currentTime })

        breaker.recordFailure()
        assertEquals(CircuitState.CLOSED, breaker.currentState)

        breaker.recordFailure()
        assertEquals(CircuitState.CLOSED, breaker.currentState)

        breaker.recordFailure() // 3rd failure reaches threshold
        assertEquals(CircuitState.OPEN, breaker.currentState)
        assertFalse(breaker.canExecute())
    }
}
