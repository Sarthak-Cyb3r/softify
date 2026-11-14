package com.softify.app

import kotlinx.coroutines.runBlocking
import org.junit.BeforeClass
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runners.MethodSorters
import uniffi.softify_core.*
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class UniFfiIntegrationTest {

    companion object {
        private lateinit var tempDbFile: File
        val sampleTrack = Track(
            id = "test_t1",
            sourceId = "src_t1",
            title = "Kesariya",
            artist = "Arijit Singh",
            album = "Brahmāstra",
            durationMs = 268000u,
            coverUrl = "https://c.saavncdn.com/test.jpg",
            matchConfidence = 1.0,
            isLiked = false,
            isUnavailable = false
        )

        @BeforeClass
        @JvmStatic
        fun setUpClass() {
            val rootDir = File(".").absoluteFile
            val debugSoDir = File(rootDir, "rust/softify_core/target/debug")
            if (debugSoDir.exists()) {
                System.setProperty("jna.library.path", debugSoDir.absolutePath)
            }
            tempDbFile = File.createTempFile("softify_uniffi_suite", ".db")
            tempDbFile.deleteOnExit()
            initDatabase(tempDbFile.absolutePath)
        }
    }

    @Test
    fun test01_initDatabase() {
        // initDatabase was called in setUpClass; verify subsequent calls succeed idempotently
        val tempDb = File.createTempFile("softify_temp_init", ".db")
        tempDb.deleteOnExit()
        val result = runCatching { initDatabase(tempDb.absolutePath) }
        assertTrue(result.isSuccess, "initDatabase must succeed")
    }

    @Test
    fun test02_saveTrackAndSearchLibrary() {
        saveTrack(sampleTrack)
        val matches = searchLibrary("kesar", 10u)
        assertTrue(matches.isNotEmpty(), "searchLibrary must find Kesariya via FTS5")
        assertEquals("test_t1", matches[0].id)
    }

    @Test
    fun test03_searchCombined() {
        runBlocking {
            saveTrack(sampleTrack)
            val res = searchCombined("Kesariya", 5u)
            assertNotNull(res)
            assertTrue(res.localTracks.any { it.id == "test_t1" }, "searchCombined must include local track")
        }
    }

    @Test
    fun test04_toggleLikeAndGetLikedTracks() {
        val liked = toggleLike("test_t1")
        assertTrue(liked, "toggleLike must return true when liking")
        val likedTracks = getLikedTracks()
        assertTrue(likedTracks.any { it.id == "test_t1" }, "getLikedTracks must contain liked track")
    }

    @Test
    fun test05_createAndGetPlaylists() {
        val playlist = createPlaylist("Suite Test Playlist", "Created during test")
        assertNotNull(playlist.id)
        assertEquals("Suite Test Playlist", playlist.name)
        val all = getPlaylists()
        assertTrue(all.any { it.id == playlist.id }, "getPlaylists must list created playlist")
    }

    @Test
    fun test06_addAndRemoveFromPlaylist() {
        val pl = createPlaylist("Membership Test Playlist", null)
        addToPlaylist(pl.id, sampleTrack.id)
        val tracks = getPlaylistTracks(pl.id)
        assertEquals(1, tracks.size)
        assertEquals("test_t1", tracks[0].id)

        removeFromPlaylist(pl.id, sampleTrack.id)
        val emptyTracks = getPlaylistTracks(pl.id)
        assertTrue(emptyTracks.isEmpty(), "Playlist should be empty after removal")
    }

    @Test
    fun test07_deletePlaylist() {
        val pl = createPlaylist("To Delete Playlist", null)
        deletePlaylist(pl.id)
        val all = getPlaylists()
        assertTrue(all.none { it.id == pl.id }, "deletePlaylist must remove playlist")
    }

    @Test
    fun test08_recordAndGetHistory() {
        recordPlay("test_t1", 0.85)
        val history = getHistory(5u)
        assertTrue(history.isNotEmpty(), "getHistory must return recorded play")
        assertEquals("test_t1", history[0].track.id)
        assertEquals(0.85, history[0].completedRatio)
    }

    @Test
    fun test09_clearHistory() {
        recordPlay("test_t1", 1.0)
        clearHistory()
        val history = getHistory(5u)
        assertTrue(history.isEmpty(), "clearHistory must wipe history")
    }

    @Test
    fun test10_refreshRemoteConfig() {
        runBlocking {
            refreshRemoteConfig(null)
        }
    }

    @Test
    fun test11_checkProvidersHealth() {
        runBlocking {
            val health = checkProvidersHealth()
            assertTrue(health.isNotEmpty(), "checkProvidersHealth must return provider statuses")
        }
    }

    @Test
    fun test12_getLyrics() {
        runBlocking {
            val lyrics = getLyrics(sampleTrack)
            assertNotNull(lyrics, "getLyrics must return lyrics object (synced or plain)")
        }
    }

    @Test
    fun test13_downloadsApiAndDeletion() {
        val downloads = getDownloads()
        assertNotNull(downloads)
        deleteDownload("test_t1")
    }

    @Test
    fun test14_tasteProfileAndRecommendationShelves() {
        updateTasteFromPlay(sampleTrack, isStream = true, isEarlySkip = false, isSave = true)
        val shelves = getRecommendationShelves()
        assertNotNull(shelves)
        assertTrue(shelves.isNotEmpty(), "getRecommendationShelves must produce shelves")
    }

    @Test
    fun test15_artistSnoozingLifecycle() {
        snoozeArtist("Arijit Singh", 30uL * 86400000uL)
        assertTrue(isArtistSnoozed("Arijit Singh"), "Artist should be snoozed")
        val snoozed = getSnoozedArtists()
        assertTrue(snoozed.contains("arijit singh"), "getSnoozedArtists must contain lowercase name")
        removeArtistSnooze("Arijit Singh")
        assertTrue(!isArtistSnoozed("Arijit Singh"), "removeArtistSnooze must unsnooze artist")
    }

    @Test
    fun test16_incognitoMode() {
        setLearningPaused(true)
        assertTrue(isLearningPaused(), "isLearningPaused should return true")
        setLearningPaused(false)
        assertTrue(!isLearningPaused(), "isLearningPaused should return false")
    }

    @Test
    fun test17_localMusicScanner() {
        val tempDir = File.createTempFile("softify_scanner_test", "dir")
        tempDir.delete()
        tempDir.mkdirs()
        tempDir.deleteOnExit()
        val result = scanLocalMusic(listOf(tempDir.absolutePath), null)
        assertNotNull(result)
        assertEquals(0u, result.scannedFiles)
    }
}
