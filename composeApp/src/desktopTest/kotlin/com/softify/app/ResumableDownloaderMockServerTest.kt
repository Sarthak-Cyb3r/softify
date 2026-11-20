package com.softify.app

import com.softify.app.data.DatabaseGate
import com.softify.app.download.DownloadResult
import com.softify.app.download.ResumableDownloader
import com.softify.app.storage.DirectoryStorageProvider
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.BeforeClass
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.initDatabase
import java.io.File
import kotlin.test.*

class ResumableDownloaderMockServerTest {

    private lateinit var server: MockWebServer
    private lateinit var tempDir: File

    companion object {
        private lateinit var tempDbFile: File

        @BeforeClass
        @JvmStatic
        fun setUpClass() {
            val rootDir = if (File("settings.gradle.kts").exists()) File(".") else File("..")
            val debugSoDir = File(rootDir, "rust/softify_core/target/debug")
            if (debugSoDir.exists()) {
                System.setProperty("jna.library.path", debugSoDir.absolutePath)
            }
            tempDbFile = File.createTempFile("softify_mock_db", ".db")
            tempDbFile.deleteOnExit()
            initDatabase(tempDbFile.absolutePath)
            DatabaseGate.markReady()
        }
    }

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()

        tempDir = File.createTempFile("softify_mock_storage", "").apply {
            delete()
            mkdirs()
            deleteOnExit()
        }
    }

    @After
    fun tearDown() {
        server.shutdown()
        tempDir.deleteRecursively()
    }

    private fun sampleTrack(id: String): Track {
        return Track(
            id = id,
            sourceId = "src_$id",
            title = "Mock Song $id",
            artist = "Mock Artist",
            album = "Mock Album",
            durationMs = 120_000u,
            coverUrl = null,
            matchConfidence = 1.0,
            isLiked = false,
            isUnavailable = false
        )
    }

    @Test
    fun testFullDownloadAndAtomicRename() = runTest {
        val payload = ByteArray(1024) { (it % 128).toByte() }
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Length", payload.size.toString())
                .setBody(okio.Buffer().write(payload))
        )

        val storageProvider = DirectoryStorageProvider(tempDir)
        val url = server.url("/stream.m4a").toString()

        val downloader = ResumableDownloader(
            storageProvider = storageProvider,
            httpClient = OkHttpClient(),
            streamResolver = { _, _, _ ->
                StreamInfo(url, "m4a", 320u, "m4a", "saavn", true, emptyList(), null)
            }
        )

        val track = sampleTrack("t100")
        val result = downloader.download(
            track = track,
            preset = QualityPreset.HIGH,
            onProgress = { _, _ -> },
            isPausedOrCancelled = { false }
        )

        assertTrue(result is DownloadResult.Success)
        val finalFile = File(tempDir, result.finalFilename)
        assertTrue(finalFile.exists(), "Final file must exist after atomic rename")
        assertEquals(1024L, finalFile.length())
        assertFalse(File(tempDir, "${result.finalFilename}.part").exists(), ".part file must be removed")
    }

    @Test
    fun testHttpRangeResume() = runTest {
        val partSize = 256
        val remainingSize = 768
        val fullSize = partSize + remainingSize

        val safeTitle = "Mock_Song_t200"
        val finalFilename = "t200_$safeTitle.m4a"
        val partFilename = "$finalFilename.part"

        // Pre-create .part file with 256 bytes
        val initialPart = ByteArray(partSize) { 0x41 }
        File(tempDir, partFilename).writeBytes(initialPart)

        val remainingPayload = ByteArray(remainingSize) { 0x42 }
        server.enqueue(
            MockResponse()
                .setResponseCode(206)
                .setHeader("Content-Range", "bytes $partSize-${fullSize - 1}/$fullSize")
                .setHeader("Content-Length", remainingSize.toString())
                .setBody(okio.Buffer().write(remainingPayload))
        )

        val storageProvider = DirectoryStorageProvider(tempDir)
        val url = server.url("/resume.m4a").toString()

        val downloader = ResumableDownloader(
            storageProvider = storageProvider,
            httpClient = OkHttpClient(),
            streamResolver = { _, _, _ ->
                StreamInfo(url, "m4a", 320u, "m4a", "saavn", true, emptyList(), null)
            }
        )

        val track = sampleTrack("t200")
        val result = downloader.download(
            track = track,
            preset = QualityPreset.HIGH,
            onProgress = { _, _ -> },
            isPausedOrCancelled = { false }
        )

        val recordedRequest = server.takeRequest()
        val rangeHeader = recordedRequest.getHeader("Range")
        assertEquals("bytes=256-", rangeHeader, "Must send HTTP Range header with existing bytes")

        assertTrue(result is DownloadResult.Success)
        val finalFile = File(tempDir, result.finalFilename)
        assertTrue(finalFile.exists())
        assertEquals(1024L, finalFile.length())
    }

    @Test
    fun testExpiredUrl403Recovery() = runTest {
        // First URL returns 403 Forbidden
        server.enqueue(MockResponse().setResponseCode(403))

        // Second refreshed URL returns 200 OK
        val payload = ByteArray(512) { 0x33 }
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Length", payload.size.toString())
                .setBody(okio.Buffer().write(payload))
        )

        var resolveCount = 0
        val storageProvider = DirectoryStorageProvider(tempDir)

        val downloader = ResumableDownloader(
            storageProvider = storageProvider,
            httpClient = OkHttpClient(),
            streamResolver = { _, _, forceRefresh ->
                resolveCount++
                val path = if (forceRefresh) "/fresh_stream.m4a" else "/expired_stream.m4a"
                StreamInfo(server.url(path).toString(), "m4a", 320u, "m4a", "saavn", true, emptyList(), null)
            }
        )

        val track = sampleTrack("t300")
        val result = downloader.download(
            track = track,
            preset = QualityPreset.HIGH,
            onProgress = { _, _ -> },
            isPausedOrCancelled = { false }
        )

        assertTrue(result is DownloadResult.Success)
        assertEquals(2, resolveCount, "Must re-resolve stream upon 403 expiry")
        val finalFile = File(tempDir, result.finalFilename)
        assertTrue(finalFile.exists())
        assertEquals(512L, finalFile.length())
    }
}
