package com.softify.app

import com.softify.app.data.DatabaseGate
import com.softify.app.download.*
import com.softify.app.playback.QueueManager
import com.softify.app.storage.DirectoryStorageProvider
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import org.junit.BeforeClass
import uniffi.softify_core.*
import java.io.File
import kotlin.test.*

@OptIn(ExperimentalCoroutinesApi::class)
class DownloadQueueManagerTest {

    companion object {
        private lateinit var tempDbFile: File
        private lateinit var tempStorageDir: File

        @BeforeClass
        @JvmStatic
        fun setUpClass() {
            val rootDir = if (File("settings.gradle.kts").exists()) File(".") else File("..")
            val debugSoDir = File(rootDir, "rust/softify_core/target/debug")
            if (debugSoDir.exists()) {
                System.setProperty("jna.library.path", debugSoDir.absolutePath)
            }
            tempDbFile = File.createTempFile("softify_dl_test", ".db")
            tempDbFile.deleteOnExit()
            initDatabase(tempDbFile.absolutePath)
            DatabaseGate.markReady()

            tempStorageDir = File.createTempFile("softify_dl_dir", "").apply {
                delete()
                mkdirs()
                deleteOnExit()
            }
        }
    }

    private fun sampleTrack(id: String, title: String): Track {
        return Track(
            id = id,
            sourceId = "src_$id",
            title = title,
            artist = "Test Artist",
            album = "Test Album",
            durationMs = 200_000u,
            coverUrl = "https://example.com/$id.jpg",
            matchConfidence = 1.0,
            isLiked = false,
            isUnavailable = false
        )
    }

    @Test
    fun testQueueStateMachineAndDeduplication() = runTest {
        val storageProvider = DirectoryStorageProvider(tempStorageDir)
        val dummyResolver: suspend (Track, QualityPreset, Boolean) -> StreamInfo = { track, _, _ ->
            StreamInfo(
                url = "https://example.com/audio.m4a",
                container = "m4a",
                bitrateKbps = 320u,
                codec = "m4a",
                provider = "saavn",
                isRequestedQuality = true,
                headers = emptyList(),
                expiresAt = null
            )
        }
        val downloader = ResumableDownloader(storageProvider, OkHttpClient(), dummyResolver)
        val queue = DownloadQueueManager(storageProvider, downloader, TestScope())

        val t1 = sampleTrack("track_1", "Song One")
        queue.enqueue(t1)

        val task1 = queue.tasks.value[t1.id]
        assertNotNull(task1)
        assertTrue(task1.status == DownloadStatus.QUEUED || task1.status == DownloadStatus.DOWNLOADING)

        // Deduplication: re-enqueuing does not create duplicate or reset
        queue.enqueue(t1)
        assertEquals(1, queue.tasks.value.size)

        // Pause
        queue.pause(t1.id)
        assertEquals(DownloadStatus.PAUSED, queue.tasks.value[t1.id]?.status)

        // Resume
        queue.resume(t1.id)
        val resumedStatus = queue.tasks.value[t1.id]?.status
        assertTrue(resumedStatus == DownloadStatus.QUEUED || resumedStatus == DownloadStatus.DOWNLOADING)

        // Cancel
        queue.cancel(t1.id)
        assertNull(queue.tasks.value[t1.id])
    }

    @Test
    fun testConcurrencyLimitSettings() = runTest {
        val storageProvider = DirectoryStorageProvider(tempStorageDir)
        val dummyResolver: suspend (Track, QualityPreset, Boolean) -> StreamInfo = { _, _, _ ->
            StreamInfo("https://example.com/a.m4a", "m4a", 320u, "m4a", "saavn", true, emptyList(), null)
        }
        val downloader = ResumableDownloader(storageProvider, OkHttpClient(), dummyResolver)
        val queue = DownloadQueueManager(storageProvider, downloader, TestScope())

        queue.setMaxConcurrent(3)
        assertEquals(3, queue.maxConcurrent.value)

        queue.setMaxConcurrent(1)
        assertEquals(1, queue.maxConcurrent.value)

        // Clamped between 1 and 3
        queue.setMaxConcurrent(10)
        assertEquals(3, queue.maxConcurrent.value)
    }

    @Test
    fun testReconcileMissingFiles() = runTest {
        val storageProvider = DirectoryStorageProvider(tempStorageDir)
        val dummyResolver: suspend (Track, QualityPreset, Boolean) -> StreamInfo = { _, _, _ ->
            StreamInfo("https://example.com/a.m4a", "m4a", 320u, "m4a", "saavn", true, emptyList(), null)
        }
        val downloader = ResumableDownloader(storageProvider, OkHttpClient(), dummyResolver)
        val queue = DownloadQueueManager(storageProvider, downloader, TestScope())

        // Insert a record into database with a file that does not exist in storage
        recordDownloadState(
            trackId = "missing_track",
            relativePath = "file:///non/existent/path/missing_track_title.m4a",
            containerFormat = "m4a",
            fileSizeBytes = 5000000u,
            bytesDownloaded = 5000000u,
            status = "completed",
            bitrateKbps = 320u,
            lastError = null
        )

        queue.reconcile()

        // Wait brief delay for IO coroutine to reconcile
        var reconciledTask: DownloadTask? = null
        for (i in 1..30) {
            Thread.sleep(50)
            reconciledTask = queue.tasks.value["missing_track"]
            if (reconciledTask?.status == DownloadStatus.FAILED) break
        }

        assertNotNull(reconciledTask)
        assertEquals(DownloadStatus.FAILED, reconciledTask.status)
        assertTrue(reconciledTask.lastError?.contains("missing") == true)
    }

    @Test
    fun testOfflinePlaybackSourceSelection() = runTest {
        val storageProvider = DirectoryStorageProvider(tempStorageDir)
        val testFile = File(tempStorageDir, "offline_t1_Test_Song.m4a")
        testFile.writeText("dummy audio content for test")

        recordDownloadState(
            trackId = "offline_t1",
            relativePath = testFile.toURI().toString(),
            containerFormat = "m4a",
            fileSizeBytes = testFile.length().toULong(),
            bytesDownloaded = testFile.length().toULong(),
            status = "completed",
            bitrateKbps = 320u,
            lastError = null
        )

        val queueManager = QueueManager()
        queueManager.localDownloadResolver = { track ->
            val download = getDownload(track.id)
            if (download != null && download.status.equals("completed", ignoreCase = true)) {
                val filename = download.relativePath.substringAfterLast('/')
                if (storageProvider.exists(filename)) {
                    StreamInfo(
                        url = storageProvider.getFileUri(filename),
                        container = download.containerFormat,
                        bitrateKbps = download.bitrateKbps,
                        codec = download.containerFormat,
                        provider = "offline",
                        isRequestedQuality = true,
                        headers = emptyList(),
                        expiresAt = null
                    )
                } else null
            } else null
        }

        val track = sampleTrack("offline_t1", "Test Song")
        val stream = queueManager.resolveTrackStream(track, QualityPreset.HIGH)

        assertEquals("offline", stream.provider)
        assertEquals(320u, stream.bitrateKbps)
        assertTrue(stream.url.contains("offline_t1_Test_Song.m4a"))
    }
}
