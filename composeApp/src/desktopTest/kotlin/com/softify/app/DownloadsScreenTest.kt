package com.softify.app

import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.softify.app.data.DatabaseGate
import com.softify.app.download.DownloadQueueManager
import com.softify.app.download.DownloadResult
import com.softify.app.download.DownloadStatus
import com.softify.app.download.ResumableDownloader
import com.softify.app.storage.DirectoryStorageProvider
import com.softify.app.ui.components.TrackItemRow
import com.softify.app.ui.downloads.DownloadsScreen
import com.softify.app.ui.theme.MetrolistTheme
import com.softify.app.viewmodel.PlaybackViewModel
import okhttp3.OkHttpClient
import org.jetbrains.skia.EncodedImageFormat
import org.junit.BeforeClass
import uniffi.softify_core.*
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class DownloadsScreenTest {

    companion object {
        private lateinit var tempDbFile: File
        private lateinit var tempStorageDir: File

        @BeforeClass
        @JvmStatic
        fun setUpClass() {
            val rootDir = File(".").absoluteFile
            val debugSoDir = File(rootDir, "rust/softify_core/target/debug")
            if (debugSoDir.exists()) {
                System.setProperty("jna.library.path", debugSoDir.absolutePath)
            }
            tempDbFile = File.createTempFile("softify_ui_test", ".db")
            tempDbFile.deleteOnExit()
            initDatabase(tempDbFile.absolutePath)
            DatabaseGate.markReady()

            tempStorageDir = File.createTempFile("softify_ui_storage", "").apply {
                delete()
                mkdirs()
                deleteOnExit()
            }
        }
    }

    private fun getScreensDir(): File {
        val rootDir = File(".").absoluteFile
        val candidate = File(rootDir, "docs/agent/screens")
        val dir = if (candidate.exists() || File(rootDir, "settings.gradle.kts").exists()) {
            candidate
        } else {
            File(rootDir.parentFile, "docs/agent/screens")
        }
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun sampleTrack(id: String, title: String, artist: String): Track {
        return Track(
            id = id,
            sourceId = "src_$id",
            title = title,
            artist = artist,
            album = "Sample Album",
            durationMs = 210_000u,
            coverUrl = null,
            matchConfidence = 1.0,
            isLiked = false,
            isUnavailable = false
        )
    }

    @Test
    fun testRenderDownloadsScreen_360dp() {
        val storageProvider = DirectoryStorageProvider(tempStorageDir, "Internal Storage")
        val dummyResolver: suspend (Track, QualityPreset, Boolean) -> StreamInfo = { _, _, _ ->
            StreamInfo("https://example.com/a.m4a", "m4a", 320u, "m4a", "saavn", true, emptyList(), null)
        }
        val downloader = ResumableDownloader(storageProvider, OkHttpClient(), dummyResolver)
        val vm = PlaybackViewModel(scope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Default))
        vm.initStorageProvider(storageProvider)

        val t1 = sampleTrack("dl_1", "Kesariya", "Arijit Singh")
        val t2 = sampleTrack("dl_2", "Espresso", "Sabrina Carpenter")
        val t3 = sampleTrack("dl_3", "back to friends", "sombr")

        vm.downloadQueueManager.enqueue(t1)
        vm.downloadQueueManager.enqueue(t2)
        vm.downloadQueueManager.enqueue(t3)

        // Seed 1 completed download
        val doneFile = File(tempStorageDir, "dl_3_back_to_friends.m4a")
        doneFile.writeText("sample audio payload")
        recordDownloadState(
            trackId = t3.id,
            relativePath = doneFile.toURI().toString(),
            containerFormat = "m4a",
            fileSizeBytes = 8400000u,
            bytesDownloaded = 8400000u,
            status = "completed",
            bitrateKbps = 320u,
            lastError = null
        )
        vm.downloadQueueManager.reconcile()

        // Viewport: 360dp x 780dp at density 2.0 = 720px x 1560px
        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            MetrolistTheme {
                Surface(
                    color = MaterialTheme.colorScheme.background,
                    modifier = Modifier.fillMaxSize()
                ) {
                    DownloadsScreen(
                        viewModel = vm,
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }

        val img = scene.render()
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)

        val outFile = File(getScreensDir(), "downloads_screen_360dp.png")
        outFile.writeBytes(data.bytes)
        assertTrue(outFile.exists())
        println("Saved downloads_screen_360dp.png (${outFile.length()} bytes)")
    }

    @Test
    fun testRenderTrackRowStates_360dp() {
        val tNormal = sampleTrack("r1", "Tum Hi Ho", "Arijit Singh")
        val tDownloading = sampleTrack("r2", "Levitating", "Dua Lipa")
        val tDownloaded = sampleTrack("r3", "Blinding Lights", "The Weeknd")

        val scene = ImageComposeScene(width = 720, height = 800, density = Density(2.0f, 1.0f)) {
            MetrolistTheme {
                Surface(
                    color = MaterialTheme.colorScheme.background,
                    modifier = Modifier.fillMaxSize()
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 8.dp, vertical = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // 1. Normal Row
                        TrackItemRow(
                            track = tNormal,
                            onClick = {},
                            onPlayNext = {},
                            onAddToQueue = {},
                            isDownloaded = false,
                            downloadProgress = null
                        )

                        // 2. Downloading Row (in-progress circular progress indicator)
                        TrackItemRow(
                            track = tDownloading,
                            onClick = {},
                            onPlayNext = {},
                            onAddToQueue = {},
                            isDownloaded = false,
                            downloadProgress = 0.65f
                        )

                        // 3. Downloaded Row (minimal vector downloaded checkmark)
                        TrackItemRow(
                            track = tDownloaded,
                            onClick = {},
                            onPlayNext = {},
                            onAddToQueue = {},
                            isDownloaded = true,
                            downloadProgress = null
                        )
                    }
                }
            }
        }

        val img = scene.render()
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)

        val outFile = File(getScreensDir(), "download_row_states_360dp.png")
        outFile.writeBytes(data.bytes)
        assertTrue(outFile.exists())
        println("Saved download_row_states_360dp.png (${outFile.length()} bytes)")
    }
}
