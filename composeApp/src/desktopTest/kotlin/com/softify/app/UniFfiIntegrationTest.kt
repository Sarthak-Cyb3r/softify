package com.softify.app

import kotlinx.coroutines.runBlocking
import org.junit.Test
import uniffi.softify_core.*
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class UniFfiIntegrationTest {

    @Test
    fun testAllPublicUniFfiApis() = runBlocking {
        // Set library path if not already set
        val rootDir = File(".").absoluteFile
        val debugSoDir = File(rootDir, "rust/softify_core/target/debug")
        if (debugSoDir.exists()) {
            System.setProperty("jna.library.path", debugSoDir.absolutePath)
        }

        // 1. initDatabase
        val tempDb = File.createTempFile("softify_test", ".db")
        tempDb.deleteOnExit()
        initDatabase(tempDb.absolutePath)

        val track = Track(
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

        // 2. saveTrack & searchLibrary
        saveTrack(track)
        val ftsMatches = searchLibrary("kesar", 10u)
        assertTrue(ftsMatches.isNotEmpty(), "FTS5 search should find Kesariya")
        assertEquals("test_t1", ftsMatches[0].id)

        // 3. toggleLike & getLikedTracks
        val liked = toggleLike("test_t1")
        assertTrue(liked, "Track should be liked")
        val likedList = getLikedTracks()
        assertEquals(1, likedList.size)
        assertEquals("test_t1", likedList[0].id)

        // 4. Playlists CRUD: create, add, get, remove, delete
        val playlist = createPlaylist("Roadtrip Mix", "Favorite roadtrip songs")
        assertNotNull(playlist.id)
        assertEquals("Roadtrip Mix", playlist.name)

        addToPlaylist(playlist.id, track.id)
        val plTracks = getPlaylistTracks(playlist.id)
        assertEquals(1, plTracks.size)
        assertEquals("test_t1", plTracks[0].id)

        val allPlaylists = getPlaylists()
        assertTrue(allPlaylists.any { it.id == playlist.id })

        removeFromPlaylist(playlist.id, track.id)
        val plTracksEmpty = getPlaylistTracks(playlist.id)
        assertTrue(plTracksEmpty.isEmpty())

        deletePlaylist(playlist.id)
        val afterDeletePl = getPlaylists()
        assertTrue(afterDeletePl.none { it.id == playlist.id })

        // 5. Play history: record, get, clear
        recordPlay("test_t1", 0.92)
        val history = getHistory(5u)
        assertEquals(1, history.size)
        assertEquals("test_t1", history[0].track.id)
        assertEquals(0.92, history[0].completedRatio)

        clearHistory()
        val emptyHistory = getHistory(5u)
        assertTrue(emptyHistory.isEmpty())

        // 6. Config & Provider Health
        refreshRemoteConfig(null)
        val health = checkProvidersHealth()
        assertTrue(health.isNotEmpty(), "Provider health list should not be empty")

        // 7. Lyrics resolution
        val lyrics = getLyrics(track)
        assertNotNull(lyrics)

        // 8. Downloads API
        val progressEvents = mutableListOf<String>()
        val callback = object : DownloadProgressCallback {
            override fun onProgress(trackId: String, bytesDownloaded: ULong, totalBytes: ULong, status: String) {
                progressEvents.add(status)
            }
        }

        // Test download record & delete APIs
        val tempDownloadDir = File.createTempFile("softify_dl", "dir")
        tempDownloadDir.delete()
        tempDownloadDir.mkdirs()

        val downloadsBefore = getDownloads()
        assertNotNull(downloadsBefore)

        deleteDownload("test_t1")

        // 9. Combined Search
        val combined = searchCombined("Kesariya", 5u)
        assertNotNull(combined)
        assertTrue(combined.localTracks.any { it.id == "test_t1" })

        // 10. Taste Profile & Recommendation Shelves (M2c)
        updateTasteFromPlay(track, isStream = true, isEarlySkip = false, isSave = true)
        val shelves = getRecommendationShelves()
        assertNotNull(shelves)
        assertTrue(shelves.isNotEmpty(), "Recommendation shelves should be generated")

        // 11. Artist Snoozing (30-day agency control)
        snoozeArtist("Arijit Singh", 30uL * 86400000uL)
        assertTrue(isArtistSnoozed("Arijit Singh"), "Artist should be snoozed")
        val snoozedArtists = getSnoozedArtists()
        assertTrue(snoozedArtists.contains("arijit singh"), "Snoozed list should contain lowercase artist")
        removeArtistSnooze("Arijit Singh")
        assertTrue(!isArtistSnoozed("Arijit Singh"), "Artist should no longer be snoozed")

        // 12. Incognito / Learning Paused Mode
        setLearningPaused(true)
        assertTrue(isLearningPaused(), "Learning should be paused")
        setLearningPaused(false)
        assertTrue(!isLearningPaused(), "Learning should be active")

        // 13. Local Music Scanner (M2c)
        val tempMusicDir = File.createTempFile("softify_music", "dir")
        tempMusicDir.delete()
        tempMusicDir.mkdirs()
        val scanRes = scanLocalMusic(listOf(tempMusicDir.absolutePath), null)
        assertNotNull(scanRes)
        assertEquals(0u, scanRes.scannedFiles)
    }
}
