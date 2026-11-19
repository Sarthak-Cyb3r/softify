package com.softify.app

import com.softify.app.ui.components.CoverArtEventListener
import com.softify.app.ui.components.CoverSize
import com.softify.app.ui.components.artworkCacheCandidates
import com.softify.app.ui.components.bucketedArtworkUrl
import com.softify.app.ui.components.formatCoverUrl
import com.softify.app.ui.components.videoArtworkFallbackUrl
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class CoverArtLoaderTest {

    @Test
    fun testThumbnailUrlFormatting() {
        // 1. Google / YouTube Music CDN discrete sizing buckets (256, 544, 1200, 2400)
        val ytmUrl = "https://lh3.googleusercontent.com/test=w544-h544-l90-rj"
        val ytmThumb = formatCoverUrl(ytmUrl, CoverSize.THUMBNAIL)
        val ytmShelf = formatCoverUrl(ytmUrl, CoverSize.SHELF)
        val ytmFull = formatCoverUrl(ytmUrl, CoverSize.FULL)
        val ytmMax = formatCoverUrl(ytmUrl, CoverSize.MAX)

        assertEquals("https://lh3.googleusercontent.com/test=w256-h256-l90-rj", ytmThumb)
        assertEquals("https://lh3.googleusercontent.com/test=w544-h544-l90-rj", ytmShelf)
        assertEquals("https://lh3.googleusercontent.com/test=w1200-h1200-l90-rj", ytmFull)
        assertEquals("https://lh3.googleusercontent.com/test=w2400-h2400-l90-rj", ytmMax)

        // 2. Saavn CDN: preserved untouched to avoid 404s from unsupported dimension rewrites
        val saavnUrl = "https://c.saavncdn.com/123/Song-Title-500x500.jpg"
        val saavnThumb = formatCoverUrl(saavnUrl, CoverSize.THUMBNAIL)
        val saavnFull = formatCoverUrl(saavnUrl, CoverSize.FULL)

        assertEquals("https://c.saavncdn.com/123/Song-Title-500x500.jpg", saavnThumb)
        assertEquals("https://c.saavncdn.com/123/Song-Title-500x500.jpg", saavnFull)

        // 3. YouTube standard CDN: mqdefault (<=320px) vs maxresdefault (>320px)
        val ytUrl = "https://i.ytimg.com/vi/abc123xyz/hqdefault.jpg"
        val ytThumb = formatCoverUrl(ytUrl, CoverSize.THUMBNAIL)
        val ytFull = formatCoverUrl(ytUrl, CoverSize.FULL)

        assertEquals("https://i.ytimg.com/vi/abc123xyz/mqdefault.jpg", ytThumb)
        assertEquals("https://i.ytimg.com/vi/abc123xyz/maxresdefault.jpg", ytFull)
    }

    @Test
    fun testYouTube404FallbackChain() {
        val maxresUrl = "https://i.ytimg.com/vi/abc123xyz/maxresdefault.jpg"
        val fallback = videoArtworkFallbackUrl(maxresUrl)
        assertEquals("https://i.ytimg.com/vi/abc123xyz/mqdefault.jpg", fallback)

        val nonMaxresUrl = "https://i.ytimg.com/vi/abc123xyz/mqdefault.jpg"
        assertEquals(null, videoArtworkFallbackUrl(nonMaxresUrl))
    }

    @Test
    fun testCrossSizeCacheCandidates() {
        val ytmUrl = "https://lh3.googleusercontent.com/test=w544-h544-l90-rj"
        val candidates = artworkCacheCandidates(ytmUrl, 544)
        assertTrue(candidates.isNotEmpty())
        assertEquals("https://lh3.googleusercontent.com/test=w544-h544-l90-rj", candidates[0])
        assertTrue(candidates.contains("https://lh3.googleusercontent.com/test=w1200-h1200-l90-rj"))
        assertTrue(candidates.contains("https://lh3.googleusercontent.com/test=w256-h256-l90-rj"))
    }

    @Test
    fun testCoverArtStatsSummary() {
        val summary = CoverArtEventListener.getStatsSummary()
        assertNotNull(summary)
        assertTrue(summary.contains("Memory Hits") && summary.contains("Disk Hits"))
    }

    @Test
    fun testNegativeCacheLifecycle() {
        val test404Url = "https://c.saavncdn.com/dead/not_found_123.jpg"
        assertTrue(!com.softify.app.ui.components.CoverArtLoader.isNegativeCached(test404Url))
        com.softify.app.ui.components.CoverArtLoader.recordNegativeCache(test404Url)
        assertTrue(com.softify.app.ui.components.CoverArtLoader.isNegativeCached(test404Url))
    }
}
