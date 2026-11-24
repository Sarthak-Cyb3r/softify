package com.softify.app.util

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PlaybackLogger {
    private val logLines = mutableListOf<String>()
    private val _logsFlow = MutableStateFlow<List<String>>(emptyList())
    val logsFlow: StateFlow<List<String>> = _logsFlow.asStateFlow()

    private val timeFormat = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)
    private var transitionTracesProvider: (() -> String)? = null

    fun setTransitionTracesProvider(provider: () -> String) {
        transitionTracesProvider = provider
    }

    fun log(tag: String = "SoftifyPlayback", message: String) {
        val timeStr = timeFormat.format(Date())
        val entry = "[$timeStr] [$tag] $message"
        println(entry)
        synchronized(this) {
            logLines.add(entry)
            if (logLines.size > 300) {
                logLines.removeAt(0)
            }
            _logsFlow.value = logLines.toList()
        }
    }

    fun getAllLogs(): String = synchronized(this) {
        val tracesSection = transitionTracesProvider?.invoke()?.let {
            "=== TRANSITION TRACES ===\n$it\n\n=== PLAYBACK LOGS ===\n"
        } ?: ""
        tracesSection + logLines.joinToString("\n")
    }

    fun clear() = synchronized(this) {
        logLines.clear()
        _logsFlow.value = emptyList()
    }
}
