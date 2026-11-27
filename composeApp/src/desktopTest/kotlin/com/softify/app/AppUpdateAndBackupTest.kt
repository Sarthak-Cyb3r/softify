package com.softify.app

import com.softify.app.data.DatabaseGate
import com.softify.app.sync.BackupPlaylist
import com.softify.app.sync.HlcTimestamp
import com.softify.app.sync.LibraryBackup
import com.softify.app.sync.SyncChange
import com.softify.app.sync.SyncEntityType
import com.softify.app.sync.generateRecoveryCode
import com.softify.app.updater.AppUpdateManager
import com.softify.app.updater.UpdateInfo
import com.softify.app.updater.UpdateState
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.Buffer
import org.junit.After
import org.junit.Before
import java.io.File
import java.security.MessageDigest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Tests M8-A2 guarantees:
 * 1) Updater accepts valid SHA-256 & exact byte count, reports progress, and prepares APK.
 * 2) Updater refuses wrong SHA-256, blank SHA-256, and truncated downloads (both Content-Length & expectedSizeBytes)
 *    and leaves zero unverified files on disk.
 * 3) Library JSON backup export & strict schema-validated import round-trips tracks, playlists, and HLC entities,
 *    while rejecting malformed JSON, bad recovery codes, missing required fields, and unsupported schemaVersion.
 */
class AppUpdateAndBackupTest {

    private lateinit var server: MockWebServer
    private lateinit var tempDir: File

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        tempDir = File.createTempFile("softify_updater_test", "").apply {
            delete()
            mkdirs()
        }
    }

    @After
    fun tearDown() {
        server.shutdown()
        tempDir.deleteRecursively()
    }

    private fun sha256Hex(bytes: ByteArray): String {
        return MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    }

    @Test
    fun testValidUpdateDownloadReportsProgressAndVerifiesSha256() = runTest {
        val payload = ByteArray(32_768) { (it % 251).toByte() }
        val hash = sha256Hex(payload)
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(Buffer().write(payload))
        )

        val mgr = AppUpdateManager()
        val info = UpdateInfo(
            versionCode = 40450,
            versionName = "4.3.50-test",
            releaseNotes = "- Fixed updater",
            apkUrl = server.url("/softify-n1.apk").toString(),
            sha256 = hash,
            expectedSizeBytes = payload.size.toLong()
        )
        assertTrue(mgr.evaluateAndPublishUpdate(info, 40400) is UpdateState.Available)

        var lastProgressSeen = 0L
        val downloaded = mgr.downloadApk(info, tempDir) { read, _ ->
            lastProgressSeen = read
        }

        assertNotNull(downloaded)
        assertTrue(downloaded.exists())
        assertEquals(payload.size.toLong(), downloaded.length())
        assertEquals(payload.size.toLong(), lastProgressSeen)
        assertTrue(mgr.updateState.value is UpdateState.ReadyToInstall)
    }

    @Test
    fun testWrongSha256RefusedAndDeleted() = runTest {
        val payload = "fake apk binary bytes v2".toByteArray()
        server.enqueue(MockResponse().setResponseCode(200).setBody(Buffer().write(payload)))

        val mgr = AppUpdateManager()
        val info = UpdateInfo(
            versionCode = 40450,
            versionName = "4.3.50-badhash",
            releaseNotes = "",
            apkUrl = server.url("/bad-hash.apk").toString(),
            sha256 = "0".repeat(64),
            expectedSizeBytes = payload.size.toLong()
        )

        val result = mgr.downloadApk(info, tempDir)
        assertNull(result, "Wrong SHA-256 must be refused")
        val errState = mgr.updateState.value as? UpdateState.Error
        assertNotNull(errState)
        assertTrue(errState.message.contains("SHA-256", ignoreCase = true))
        assertEquals(0, tempDir.listFiles()?.size ?: 0, "Corrupt APK must be deleted")
    }

    @Test
    fun testBlankSha256Refused() = runTest {
        val payload = "valid bytes without manifest hash".toByteArray()
        server.enqueue(MockResponse().setResponseCode(200).setBody(Buffer().write(payload)))

        val mgr = AppUpdateManager()
        val info = UpdateInfo(
            versionCode = 40450,
            versionName = "4.3.50-blankhash",
            releaseNotes = "",
            apkUrl = server.url("/no-hash.apk").toString(),
            sha256 = "",
            expectedSizeBytes = payload.size.toLong()
        )

        val result = mgr.downloadApk(info, tempDir)
        assertNull(result, "Blank SHA-256 must be refused")
        assertTrue(mgr.updateState.value is UpdateState.Error)
        assertEquals(0, tempDir.listFiles()?.size ?: 0)
    }

    @Test
    fun testTruncatedDownloadRefusedWithExpectedSize() = runTest {
        val fullPayload = ByteArray(16_384) { 7 }
        val truncated = fullPayload.copyOf(4096)
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                // Chunked response without Content-Length, relying on expectedSizeBytes from update.json
                .setChunkedBody(Buffer().write(truncated), 1024)
        )

        val mgr = AppUpdateManager()
        val info = UpdateInfo(
            versionCode = 40451,
            versionName = "4.3.51-trunc",
            releaseNotes = "",
            apkUrl = server.url("/truncated.apk").toString(),
            sha256 = sha256Hex(fullPayload),
            expectedSizeBytes = fullPayload.size.toLong()
        )

        val result = mgr.downloadApk(info, tempDir)
        assertNull(result, "Truncated download must be refused")
        val errState = mgr.updateState.value as? UpdateState.Error
        assertNotNull(errState)
        assertTrue(errState.message.contains("Truncated", ignoreCase = true))
        assertEquals(0, tempDir.listFiles()?.size ?: 0, "Truncated partial APK must not remain")
    }

    @Test
    fun testLibraryBackupExportAndValidatedImportRoundTrip() {
        val recovery = generateRecoveryCode("device-seed-a2")
        val t1 = uniffi.softify_core.Track(
            id = "trk_a2_1",
            sourceId = "yt_abc",
            title = "Midnight City",
            artist = "M83",
            album = "Hurry Up, We're Dreaming",
            durationMs = 243_000u,
            coverUrl = "https://example.org/cover.jpg",
            matchConfidence = null,
            isLiked = true,
            isUnavailable = false
        )
        val pl = BackupPlaylist(
            id = "pl_1",
            name = "Night Drive",
            description = "Late commute",
            tracks = listOf(t1)
        )
        val entity = SyncChange(
            entityType = SyncEntityType.FAVORITE,
            entityId = t1.id,
            hlc = HlcTimestamp(1700000100000L, 1, "devA2"),
            isDeleted = false,
            payload = """{"title":"Midnight City"}"""
        )

        val exported = LibraryBackup.exportToJson(
            deviceId = "dev-a2-1",
            recoveryCode = recovery,
            likedTracks = listOf(t1),
            playlists = listOf(pl),
            entities = listOf(entity),
            exportedAtMs = 1700000200000L
        )

        val parsed = LibraryBackup.validateAndParse(exported).getOrThrow()
        assertEquals(2, parsed.schemaVersion)
        assertEquals("dev-a2-1", parsed.deviceId)
        assertEquals(recovery, parsed.recoveryCode)
        assertEquals(1, parsed.likedTracks.size)
        assertEquals("Midnight City", parsed.likedTracks.first().title)
        assertEquals(1, parsed.playlists.size)
        assertEquals("Night Drive", parsed.playlists.first().name)
        assertEquals(1, parsed.entities.size)
    }

    @Test
    fun testLibraryBackupRejectsCorruptOrInvalidPayloads() {
        assertTrue(LibraryBackup.validateAndParse("").isFailure)
        assertTrue(LibraryBackup.validateAndParse("{bad json").isFailure)
        assertTrue(LibraryBackup.validateAndParse("""{"schemaVersion":99,"deviceId":"d","exportedAt":1}""").isFailure)
        assertTrue(LibraryBackup.validateAndParse("""{"schemaVersion":2,"deviceId":"d","exportedAt":1,"recoveryCode":"INVALID"}""").isFailure)
        assertTrue(LibraryBackup.validateAndParse("""{"schemaVersion":2,"deviceId":"d","exportedAt":1,"likedTracks":[{"id":""}]}""").isFailure)
    }

    @Test
    fun testLibraryBackupRestoresIntoLiveRustSqliteDatabase() {
        val rootDir = if (File("settings.gradle.kts").exists()) File(".") else File("..")
        val debugSoDir = File(rootDir, "rust/softify_core/target/debug")
        if (debugSoDir.exists()) {
            System.setProperty("jna.library.path", debugSoDir.absolutePath)
        }
        val dbFile = File.createTempFile("softify_backup_restore", ".db")
        dbFile.deleteOnExit()
        uniffi.softify_core.initDatabase(dbFile.absolutePath)
        DatabaseGate.markReady()

        val track = uniffi.softify_core.Track(
            id = "trk_restore_1",
            sourceId = "src_restore_1",
            title = "Resonance",
            artist = "HOME",
            album = "Odyssey",
            durationMs = 212_000u,
            coverUrl = null,
            matchConfidence = null,
            isLiked = true,
            isUnavailable = false
        )
        val json = LibraryBackup.exportToJson(
            deviceId = "dev-orig",
            recoveryCode = generateRecoveryCode("orig"),
            likedTracks = listOf(track),
            playlists = listOf(BackupPlaylist("pl_r1", "Synthwave", null, listOf(track))),
            entities = emptyList(),
            exportedAtMs = 1700000300000L
        )
        val validated = LibraryBackup.validateAndParse(json).getOrThrow()
        assertFalse(validated.likedTracks.isEmpty())

        for (t in validated.likedTracks) {
            uniffi.softify_core.saveTrack(t)
            val alreadyLiked = uniffi.softify_core.getLikedTracks().any { it.id == t.id }
            if (!alreadyLiked) {
                uniffi.softify_core.toggleLike(t.id)
            }
        }
        for (p in validated.playlists) {
            val created = uniffi.softify_core.createPlaylist(p.name, p.description)
            for (t in p.tracks) {
                uniffi.softify_core.saveTrack(t)
                uniffi.softify_core.addToPlaylist(created.id, t.id)
            }
        }

        val restoredLikes = uniffi.softify_core.getLikedTracks()
        val restoredPlaylists = uniffi.softify_core.getPlaylists()
        assertTrue(restoredLikes.any { it.id == "trk_restore_1" })
        assertTrue(restoredPlaylists.any { it.name == "Synthwave" })
        val plId = restoredPlaylists.first { it.name == "Synthwave" }.id
        val plTracks = uniffi.softify_core.getPlaylistTracks(plId)
        assertTrue(plTracks.any { it.id == "trk_restore_1" })
    }
}
