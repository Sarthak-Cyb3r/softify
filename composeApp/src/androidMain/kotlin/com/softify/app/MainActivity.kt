package com.softify.app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.softify.app.playback.PlaybackService
import com.softify.app.ui.App
import com.softify.app.util.PlaybackLogger
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.initDatabase

class MainActivity : ComponentActivity() {
    private val viewModel = PlaybackViewModel()
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var mediaController: MediaController? = null

    private val requestNotificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
            if (isGranted) {
                PlaybackLogger.log("SoftifyPlayback", "POST_NOTIFICATIONS permission GRANTED")
            } else {
                PlaybackLogger.log("SoftifyPlayback", "POST_NOTIFICATIONS permission DENIED")
                viewModel.showSnackbar("Notification permission denied; playback notification may not appear")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Populate System Diagnostics
        viewModel.appVersion = "4.3.0-experimental (40300)"
        viewModel.osVersion = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"
        viewModel.abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"

        viewModel.isNativeLibLoaded = try {
            System.loadLibrary("softify_core")
            true
        } catch (e: Throwable) {
            PlaybackLogger.log("SoftifyPlayback", "System.loadLibrary softify_core error: ${e.message}")
            false
        }

        PlaybackLogger.log(
            "SoftifyPlayback",
            "App Startup: App=${viewModel.appVersion}, OS=${viewModel.osVersion}, ABI=${viewModel.abi}, Native lib=${if (viewModel.isNativeLibLoaded) "LOADED" else "FAILED"}"
        )

        // Request runtime notification permission on Android 13+ (Android 15)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                PlaybackLogger.log("SoftifyPlayback", "Requesting POST_NOTIFICATIONS permission at runtime...")
                requestNotificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            } else {
                PlaybackLogger.log("SoftifyPlayback", "POST_NOTIFICATIONS permission already granted")
            }
        }

        // Initialize SQLite Database in app private directory
        val dbPath = "${filesDir.absolutePath}/softify.db"
        try {
            initDatabase(dbPath)
            PlaybackLogger.log("SoftifyPlayback", "Database initialized at: $dbPath")
        } catch (e: Exception) {
            val errMsg = "Database init failed: ${e.message}"
            PlaybackLogger.log("SoftifyPlayback", errMsg)
            viewModel.showSnackbar(errMsg)
        }

        // Connect ViewModel sharing callback (Android Share Sheet)
        viewModel.onShareText = { text ->
            try {
                val sendIntent = Intent().apply {
                    action = Intent.ACTION_SEND
                    putExtra(Intent.EXTRA_TEXT, text)
                    type = "text/plain"
                }
                val shareIntent = Intent.createChooser(sendIntent, "Share Softify Playback Logs")
                startActivity(shareIntent)
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyPlayback", "Share log failed: ${e.message}")
            }
        }

        // Connect ViewModel direct test URL trigger
        viewModel.onPlayTestUrlRequested = { url ->
            val service = PlaybackService.instance
            if (service != null) {
                PlaybackLogger.log("SoftifyPlayback", "Calling PlaybackService.instance.playDirectTestUrl directly")
                service.playDirectTestUrl(url)
            } else {
                PlaybackLogger.log("SoftifyPlayback", "Starting PlaybackService with ACTION_PLAY_TEST_URL")
                val intent = Intent(this, PlaybackService::class.java).apply {
                    action = PlaybackService.ACTION_PLAY_TEST_URL
                    putExtra(PlaybackService.EXTRA_STREAM_URL, url)
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                } catch (e: Exception) {
                    PlaybackLogger.log("SoftifyPlayback", "startService for test URL failed: ${e.message}")
                    viewModel.showSnackbar("Service start failed: ${e.message}")
                }
            }
        }

        // Connect ViewModel toggle play/pause
        viewModel.onTogglePlayPauseRequested = {
            val controller = mediaController
            if (controller != null) {
                if (controller.isPlaying) controller.pause() else controller.play()
            } else {
                PlaybackService.instance?.let { s ->
                    if (s.player.isPlaying) s.player.pause() else s.player.play()
                }
            }
        }

        // Connect ViewModel stream resolution to playback service
        viewModel.onStreamReadyForPlayback = { track, streamInfo ->
            val service = PlaybackService.instance
            if (service != null) {
                PlaybackLogger.log("SoftifyPlayback", "Calling PlaybackService.instance.playStream directly for '${track.title}'")
                service.playStream(track, streamInfo, 0L)
            } else {
                PlaybackLogger.log("SoftifyPlayback", "PlaybackService instance null; starting service via Intent for '${track.title}'")
                val intent = Intent(this, PlaybackService::class.java).apply {
                    action = PlaybackService.ACTION_PLAY_STREAM
                    putExtra(PlaybackService.EXTRA_TRACK_ID, track.id)
                    putExtra(PlaybackService.EXTRA_TRACK_TITLE, track.title)
                    putExtra(PlaybackService.EXTRA_TRACK_ARTIST, track.artist)
                    putExtra(PlaybackService.EXTRA_STREAM_URL, streamInfo.url)
                    putExtra(PlaybackService.EXTRA_STREAM_BITRATE, streamInfo.bitrateKbps.toInt())
                    putExtra(PlaybackService.EXTRA_STREAM_CODEC, streamInfo.codec)
                    putExtra(PlaybackService.EXTRA_STREAM_PROVIDER, streamInfo.provider)
                    val headerNames = ArrayList(streamInfo.headers.map { it.name })
                    val headerValues = ArrayList(streamInfo.headers.map { it.value })
                    putStringArrayListExtra(PlaybackService.EXTRA_HEADER_NAMES, headerNames)
                    putStringArrayListExtra(PlaybackService.EXTRA_HEADER_VALUES, headerValues)
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    PlaybackLogger.log("SoftifyPlayback", "startForegroundService called successfully for '${track.title}'")
                } catch (e: Exception) {
                    val errMsg = "startService failed: ${e.javaClass.simpleName} - ${e.message}"
                    PlaybackLogger.log("SoftifyPlayback", errMsg)
                    viewModel.showSnackbar(errMsg)
                }
            }
        }

        // Bind to Media3 PlaybackService
        PlaybackLogger.log("SoftifyPlayback", "Building MediaController async connection to PlaybackService...")
        val sessionToken = SessionToken(this, ComponentName(this, PlaybackService::class.java))
        controllerFuture = MediaController.Builder(this, sessionToken).buildAsync()
        controllerFuture?.addListener({
            try {
                mediaController = controllerFuture?.get()
                viewModel.isMediaControllerConnected = true
                PlaybackLogger.log("SoftifyPlayback", "MediaController: CONNECTED to PlaybackService")
                mediaController?.addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(state: Int) {
                        val stateName = when (state) {
                            Player.STATE_IDLE -> "IDLE"
                            Player.STATE_BUFFERING -> "BUFFERING"
                            Player.STATE_READY -> "READY"
                            Player.STATE_ENDED -> "ENDED"
                            else -> "UNKNOWN($state)"
                        }
                        PlaybackLogger.log("SoftifyPlayback", "MediaController player state: $stateName")
                    }

                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        PlaybackLogger.log("SoftifyPlayback", "MediaController isPlaying: $isPlaying")
                        viewModel.setIsPlaying(isPlaying)
                    }

                    override fun onPlayerError(error: PlaybackException) {
                        val errMsg = "Player error: ${error.errorCodeName} - ${error.message}"
                        PlaybackLogger.log("SoftifyPlayback", errMsg)
                        viewModel.showSnackbar(errMsg)
                    }
                })
            } catch (e: Exception) {
                viewModel.isMediaControllerConnected = false
                val errMsg = "MediaController connection FAILED: ${e.message}"
                PlaybackLogger.log("SoftifyPlayback", errMsg)
                viewModel.showSnackbar(errMsg)
            }
        }, ContextCompat.getMainExecutor(this))

        setContent {
            App(viewModel = viewModel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        controllerFuture?.let { MediaController.releaseFuture(it) }
    }
}
