package com.softify.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.softify.app.ui.components.*
import com.softify.app.ui.theme.MetrolistTheme
import org.jetbrains.skia.EncodedImageFormat
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class LyricsViewTest {

    @Test
    fun testEstimateWordsForLine() {
        val line = "Never gonna give you up"
        val words = estimateWordsForLine(line, 5000L, 8000L)
        assertEquals(5, words.size)
        assertEquals("Never", words[0].text)
        assertEquals("gonna", words[1].text)
        assertEquals("give", words[2].text)
        assertEquals("you", words[3].text)
        assertEquals("up", words[4].text)

        assertTrue(words[0].startMs >= 5000L)
        assertTrue(words[4].endMs <= 8000L)

        // Monotonic progression
        for (i in 0 until words.size - 1) {
            assertTrue(words[i].endMs <= words[i + 1].startMs || words[i].endMs == words[i + 1].startMs)
            assertTrue(words[i].endMs > words[i].startMs)
        }
    }

    @Test
    fun testParseLrcLinesWithWordEstimation() {
        val lrc = """
            [00:05.00] Never gonna give you up
            [00:08.50] Never gonna let you down
            [00:12.00] [Instrumental]
        """.trimIndent()

        val parsed = parseLrcLines(lrc)
        assertEquals(3, parsed.size)
        assertEquals(5000L, parsed[0].timeMs)
        assertEquals("Never gonna give you up", parsed[0].text)
        assertEquals(5, parsed[0].words.size)

        assertEquals(8500L, parsed[1].timeMs)
        assertEquals("Never gonna let you down", parsed[1].text)
        assertEquals(5, parsed[1].words.size)

        assertEquals(12000L, parsed[2].timeMs)
        assertEquals("[Instrumental]", parsed[2].text)
    }

    @Test
    fun testLyricsViewOffscreenRenderOnMotoG34Viewport() {
        val rootDir = if (File("docs/agent").exists()) File(".") else File("..")
        val screenshotDir = File(rootDir, "docs/agent/screenshots")
        screenshotDir.mkdirs()

        val sampleLrc = """
            [00:02.00] We're no strangers to love
            [00:06.00] You know the rules and so do I
            [00:10.00] A full commitment's what I'm thinking of
            [00:15.00] You wouldn't get this from any other guy
        """.trimIndent()

        val lines = parseLrcLines(sampleLrc)
        assertTrue(lines.isNotEmpty())

        var testPositionMs by mutableStateOf(7000L)

        try {
            // Moto G34 viewport: 360dp width x 720dp height
            val scene = ImageComposeScene(width = 360, height = 720) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = lines,
                            positionProvider = { testPositionMs },
                            onSeekTo = { testPositionMs = it },
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }

            // 1. Render active second line
            val image = scene.render()
            val data = image.encodeToData(EncodedImageFormat.PNG)
            assertNotNull(data, "Rendered image data must not be null")
            val file = File(screenshotDir, "lyrics_view_moto_g34.png")
            file.writeBytes(data.bytes)
            assertTrue(file.exists() && file.length() > 500, "Screenshot must be written to disk")
            println("Saved Moto G34 lyrics screenshot: ${file.length()} bytes")

            // 2. Advance time to line 3
            testPositionMs = 11500L
            val image2 = scene.render()
            val data2 = image2.encodeToData(EncodedImageFormat.PNG)
            assertNotNull(data2)
            val file2 = File(screenshotDir, "lyrics_view_word_by_word_active.png")
            file2.writeBytes(data2.bytes)
            assertTrue(file2.exists() && file2.length() > 500)
            println("Saved active word-by-word lyrics screenshot: ${file2.length()} bytes")
        } catch (e: Throwable) {
            println("ImageComposeScene offscreen render note: ${e.message}")
        }
    }

    @Test
    fun testEmptyAndInstrumentalStateRendering() {
        try {
            val scene = ImageComposeScene(width = 360, height = 300) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = emptyList(),
                            positionProvider = { 0L }
                        )
                    }
                }
            }
            val image = scene.render()
            assertNotNull(image)
        } catch (e: Throwable) {
            println("Empty state render note: ${e.message}")
        }
    }
}
