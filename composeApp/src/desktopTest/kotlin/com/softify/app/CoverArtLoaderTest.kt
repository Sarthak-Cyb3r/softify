package com.softify.app

import com.softify.app.ui.components.CoverArtEventListener
import com.softify.app.ui.components.CoverSize
import com.softify.app.ui.components.formatCoverUrl
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class CoverArtLoaderTest {

    @Test
    fun testThumbnailUrlFormatting() {
        // 1. Google / YouTube Music CDN
        val ytmUrl = "https://lh3.googleusercontent.com/test=w544-h544-l90-rj"
        val ytmThumb = formatCoverUrl(ytmUrl, CoverSize.THUMBNAIL)
        val ytmFull = formatCoverUrl(ytmUrl, CoverSize.FULL)

        assertEquals("https://lh3.googleusercontent.com/test=w180-h180-l90-rj", ytmThumb)
        assertEquals("https://lh3.googleusercontent.com/test=w544-h544-l90-rj", ytmFull)

        // 2. Saavn CDN
        val saavnUrl = "https://c.saavncdn.com/123/Song-Title-500x500.jpg"
        val saavnThumb = formatCoverUrl(saavnUrl, CoverSize.THUMBNAIL)
        val saavnFull = formatCoverUrl(saavnUrl, CoverSize.FULL)

        assertEquals("https://c.saavncdn.com/123/Song-Title-150x150.jpg", saavnThumb)
        assertEquals("https://c.saavncdn.com/123/Song-Title-500x500.jpg", saavnFull)

        // 3. YouTube standard CDN
        val ytUrl = "https://i.ytimg.com/vi/abc123xyz/hqdefault.jpg"
        val ytThumb = formatCoverUrl(ytUrl, CoverSize.THUMBNAIL)
        val ytFull = formatCoverUrl(ytUrl, CoverSize.FULL)

        assertEquals("https://i.ytimg.com/vi/abc123xyz/mqdefault.jpg", ytThumb)
        assertEquals("https://i.ytimg.com/vi/abc123xyz/hqdefault.jpg", ytFull)
    }

    @Test
    fun testCoverArtStatsSummary() {
        val summary = CoverArtEventListener.getStatsSummary()
        assertNotNull(summary)
        assertTrue(summary.contains("Memory Hits") && summary.contains("Disk Hits"))
    }
}
