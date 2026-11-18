package com.softify.app.data

import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.CompletableDeferred

/**
 * Gate ensuring Rust database calls wait until initDatabase has completed.
 * Prevents startup race conditions between ViewModel initialization and SQLite setup.
 */
object DatabaseGate {
    private val readyDeferred = CompletableDeferred<Unit>()

    val isReady: Boolean
        get() = readyDeferred.isCompleted

    fun markReady() {
        if (!readyDeferred.isCompleted) {
            readyDeferred.complete(Unit)
            PlaybackLogger.log("SoftifyPlayback", "DatabaseGate: SQLite database marked READY")
        }
    }

    suspend fun awaitReady() {
        if (!readyDeferred.isCompleted) {
            PlaybackLogger.log("SoftifyPlayback", "DatabaseGate: Awaiting database initialization...")
            readyDeferred.await()
            PlaybackLogger.log("SoftifyPlayback", "DatabaseGate: Database ready signal received, proceeding.")
        }
    }
}
