package com.softify.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import com.softify.app.playback.PlaybackService
import com.softify.app.ui.App
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.initDatabase

class MainActivity : ComponentActivity() {
    private val viewModel = PlaybackViewModel()
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var mediaController: MediaController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize SQLite Database in app private directory
        val dbPath = "${filesDir.absolutePath}/softify.db"
        try {
            initDatabase(dbPath)
        } catch (e: Exception) {
            println("[MainActivity] Database init failed: ${e.message}")
        }

        // Bind to Media3 PlaybackService
        val sessionToken = SessionToken(this, ComponentName(this, PlaybackService::class.java))
        controllerFuture = MediaController.Builder(this, sessionToken).buildAsync()
        controllerFuture?.addListener({
            mediaController = controllerFuture?.get()
        }, MoreExecutors.directExecutor())

        // Connect ViewModel stream resolution to playback service
        viewModel.onStreamReadyForPlayback = { track, streamInfo ->
            val intent = Intent(this, PlaybackService::class.java).apply {
                putExtra("track_id", track.id)
                putExtra("stream_url", streamInfo.url)
            }
            startService(intent)
        }

        setContent {
            App(viewModel = viewModel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        controllerFuture?.let { MediaController.releaseFuture(it) }
    }
}
