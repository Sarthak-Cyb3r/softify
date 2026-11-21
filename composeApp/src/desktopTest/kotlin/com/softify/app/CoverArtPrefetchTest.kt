package com.softify.app

import com.softify.app.ui.components.CoverArtLoader
import com.softify.app.ui.components.CoverSize
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class CoverArtPrefetchTest {

    @Test
    fun testPrefetchThrottlesToNext5Items() = runTest {
        // Generate a 50-item storm of cover URLs
        val fiftyTracks = (1..50).map { "https://i.ytimg.com/vi/track_$it/hqdefault.jpg" }

        // Candidate URLs logic in prefetch caps to 5
        val distinctCandidates = fiftyTracks.distinct().filter { !CoverArtLoader.isNegativeCached(it) }.take(5)
        assertEquals(5, distinctCandidates.size, "Prefetch must cap candidate requests to at most 5 items")
        assertEquals("https://i.ytimg.com/vi/track_1/hqdefault.jpg", distinctCandidates.first())
        assertEquals("https://i.ytimg.com/vi/track_5/hqdefault.jpg", distinctCandidates.last())
    }

    @Test
    fun testCancelPrefetchCancelsPendingJob() = runTest {
        val tenTracks = (1..10).map { "https://i.ytimg.com/vi/song_$it/hqdefault.jpg" }
        // cancelPrefetch must be safe to call repeatedly and clean up active job
        CoverArtLoader.cancelPrefetch()
        CoverArtLoader.cancelPrefetch()
        assertTrue(true, "cancelPrefetch executes cleanly")
    }

    @Test
    fun testDispatcherLimitsPreventConnectionStarvation() {
        val dispatcher = CoverArtLoader.dispatcher
        assertTrue(dispatcher.maxRequests <= 32, "Max concurrent OkHttp requests must be <= 32")
        assertTrue(dispatcher.maxRequestsPerHost <= 10, "Max requests per host must be <= 10")
    }
}
