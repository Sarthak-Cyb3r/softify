package com.softify.app.telemetry

import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class TelemetryEvent(
    val eventType: String,
    val timestamp: Long = System.currentTimeMillis(),
    val appVersion: String,
    val details: Map<String, String> = emptyMap()
)

/**
 * Privacy-first, strictly opt-in telemetry manager.
 * Batched, sent at most once per 60 seconds, dropped if queue > 50 events.
 */
class TelemetryManager(
    initialOptIn: Boolean = false,
    initialLastSendTime: Long = System.currentTimeMillis()
) {
    private val _isOptIn = MutableStateFlow(initialOptIn)
    val isOptIn: StateFlow<Boolean> = _isOptIn.asStateFlow()

    private val eventQueue = mutableListOf<TelemetryEvent>()
    private var lastSendTime: Long = initialLastSendTime

    companion object {
        const val MAX_QUEUE_CAPACITY = 50
        const val MIN_SEND_INTERVAL_MS = 60_000L // 60 seconds

        val SCHEMA_DESCRIPTION = """
            Privacy Disclosure - What is sent when Telemetry is enabled:
            - Event Type (e.g. APP_START, ERROR, SYNC_STATUS)
            - Timestamp (millisecond epoch)
            - App Version (e.g. 4.3.0)
            - Anonymized error code or playback state
            
            Strict Guarantees:
            - ZERO personal identifying information (PII)
            - ZERO IP address retention
            - ZERO tracking cookies or advertising IDs
            - Fully disabled when 'Local only' mode is active
        """.trimIndent()
    }

    fun setOptIn(enabled: Boolean) {
        synchronized(this) {
            _isOptIn.value = enabled
            if (!enabled) {
                eventQueue.clear()
            }
            PlaybackLogger.log("SoftifyTelemetry", "Telemetry opt-in set to: $enabled")
        }
    }

    fun recordEvent(eventType: String, appVersion: String, details: Map<String, String> = emptyMap()): Boolean {
        synchronized(this) {
            if (!_isOptIn.value) {
                return false
            }

            if (eventQueue.size >= MAX_QUEUE_CAPACITY) {
                // Drop event when buffer is full
                PlaybackLogger.log("SoftifyTelemetry", "Queue full ($MAX_QUEUE_CAPACITY), dropping event: $eventType")
                return false
            }

            eventQueue.add(TelemetryEvent(eventType, System.currentTimeMillis(), appVersion, details))
            return true
        }
    }

    fun shouldFlushBatch(now: Long = System.currentTimeMillis()): Boolean {
        synchronized(this) {
            if (!_isOptIn.value || eventQueue.isEmpty()) return false
            return now - lastSendTime >= MIN_SEND_INTERVAL_MS
        }
    }

    fun drainBatch(now: Long = System.currentTimeMillis()): List<TelemetryEvent> {
        synchronized(this) {
            if (!_isOptIn.value || eventQueue.isEmpty()) return emptyList()
            lastSendTime = now
            val batch = eventQueue.toList()
            eventQueue.clear()
            return batch
        }
    }

    val queuedCount: Int
        get() = synchronized(this) { eventQueue.size }
}
