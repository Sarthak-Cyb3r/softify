package com.softify.app

import android.app.Application
import com.softify.app.data.DatabaseGate
import com.softify.app.util.PlaybackLogger
import uniffi.softify_core.initDatabase

class SoftifyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        try {
            System.loadLibrary("softify_core")
            PlaybackLogger.log("SoftifyPlayback", "SoftifyApplication: softify_core native library loaded")
        } catch (t: Throwable) {
            PlaybackLogger.log("SoftifyPlayback", "SoftifyApplication: Failed to load softify_core: ${t.message}")
        }

        val dbPath = "${filesDir.absolutePath}/softify.db"
        try {
            initDatabase(dbPath)
            DatabaseGate.markReady()
            PlaybackLogger.log("SoftifyPlayback", "SoftifyApplication: SQLite database initialized synchronously at $dbPath")
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyPlayback", "SoftifyApplication: Database init failed: ${e.message}")
        }
    }
}
