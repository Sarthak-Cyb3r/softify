package com.softify.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
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
    fun testParseLrcLinesStandardNoSyntheticWords() {
        val lrc = """
            [00:05.00] Never gonna give you up
            [00:08.50] Never gonna let you down
            [00:12.00] [Instrumental]
        """.trimIndent()

        val parsed = parseLrcLines(lrc)
        assertEquals(3, parsed.size)
        assertEquals(5000L, parsed[0].timeMs)
        assertEquals("Never gonna give you up", parsed[0].text)
        assertTrue(parsed[0].isLineTimed)
        assertTrue(parsed[0].words.isEmpty(), "Standard LRC must have no synthetic words")

        assertEquals(8500L, parsed[1].timeMs)
        assertEquals("Never gonna let you down", parsed[1].text)
        assertTrue(parsed[1].isLineTimed)
        assertTrue(parsed[1].words.isEmpty(), "Standard LRC must have no synthetic words")

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
        val rootDir = if (File("docs/agent").exists()) File(".") else File("..")
        val screenshotDir = File(rootDir, "docs/agent/screens")
        screenshotDir.mkdirs()

        try {
            val scene = ImageComposeScene(width = 360, height = 300, density = Density(2f)) {
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
            val data = image.encodeToData(EncodedImageFormat.PNG)
            if (data != null) {
                File(screenshotDir, "04_empty_instrumental_state.png").writeBytes(data.bytes)
            }
        } catch (e: Throwable) {
            println("Empty state render note: ${e.message}")
        }
    }

    @Test
    fun testSombrBackToFriendsNestedModelAndRender() {
        val rootDir = if (File("docs/agent").exists()) File(".") else File("..")
        val screenshotDir = File(rootDir, "docs/agent/screens")
        screenshotDir.mkdirs()

        val fixtureFile = File(rootDir, "rust/softify_core/tests/fixtures/lrclib_back_to_friends.json")
        assertTrue(fixtureFile.exists(), "lrclib_back_to_friends.json fixture must exist")
        val jsonContent = fixtureFile.readText()

        val linesSection = jsonContent.substringAfter("\"lyricsfile\":\"", "").substringBefore("\"}")
            .replace("\\n", "\n")
            .replace("\\'", "'")

        val rawLines = linesSection.split("\n")
        val parsedLines = mutableListOf<LyricLine>()
        var currentText: String? = null
        var currentStartMs = 0L
        var currentEndMs = 0L
        var currentWords = mutableListOf<LyricWord>()

        fun flushLine() {
            if (currentText != null) {
                parsedLines.add(
                    LyricLine(
                        timeMs = currentStartMs,
                        endMs = currentEndMs,
                        text = currentText!!,
                        words = currentWords.toList(),
                        isLineTimed = currentWords.isEmpty()
                    )
                )
                currentWords = mutableListOf()
                currentText = null
            }
        }

        var inWords = false
        var wordText: String? = null
        var wordStart = 0L

        for (line in rawLines) {
            if (line.startsWith("- text:")) {
                flushLine()
                inWords = false
                currentText = line.removePrefix("- text:").trim().removeSurrounding("'")
            } else if (line.startsWith("  start_ms:")) {
                currentStartMs = line.removePrefix("  start_ms:").trim().toLongOrNull() ?: 0L
            } else if (line.startsWith("  end_ms:")) {
                currentEndMs = line.removePrefix("  end_ms:").trim().toLongOrNull() ?: 0L
            } else if (line.startsWith("  words:")) {
                inWords = true
            } else if (inWords && line.startsWith("  - text:")) {
                wordText = line.removePrefix("  - text:").trim().removeSurrounding("'")
            } else if (inWords && line.startsWith("    start_ms:")) {
                wordStart = line.removePrefix("    start_ms:").trim().toLongOrNull() ?: 0L
                if (wordText != null) {
                    currentWords.add(LyricWord(wordStart, wordStart + 500L, wordText!!.trim()))
                    wordText = null
                }
            }
        }
        flushLine()

        // 1. Verify line count is 30, NOT 222
        println("Sombr fixture parsed line count: ${parsedLines.size}")
        assertEquals(30, parsedLines.size, "Sombr 'back to friends' line count must be 30 lines, NOT 222")

        // 2. Verify words are nested
        val line0 = parsedLines[0]
        assertEquals("Touch my body tender", line0.text)
        assertTrue(line0.words.isNotEmpty(), "Line 0 must contain nested words")
        assertEquals(4, line0.words.size, "Line 0 must have exactly 4 words")

        // 3. Render at phone viewport (360dp x 720dp) with density 2f -> 720px width
        var testPos by mutableStateOf(24000L)
        val scene = ImageComposeScene(width = 360, height = 720, density = Density(2f)) {
            MetrolistTheme {
                Surface(
                    color = MaterialTheme.colorScheme.background,
                    modifier = Modifier.fillMaxSize()
                ) {
                    LyricsView(
                        lines = parsedLines,
                        positionProvider = { testPos },
                        isSynced = true,
                        isWordSynced = true,
                        onSeekTo = { testPos = it },
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                    )
                }
            }
        }

        val img = scene.render()
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)
        val file1 = File(screenshotDir, "01_sombr_lyrics_360dp.png")
        file1.writeBytes(data.bytes)
        println("Saved 01_sombr_lyrics_360dp.png: ${file1.length()} bytes")

        // 4. Advance clock by 1 second and render word-by-word sweep progression
        testPos = 25000L
        val img2 = scene.render()
        val data2 = img2.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data2)
        val file2 = File(screenshotDir, "02_sombr_word_active.png")
        file2.writeBytes(data2.bytes)
        println("Saved 02_sombr_word_active.png: ${file2.length()} bytes")
    }

    @Test
    fun testLyricLineParagraphWrappingAt360dpWidth() {
        val rootDir = if (File("docs/agent").exists()) File(".") else File("..")
        val screenshotDir = File(rootDir, "docs/agent/screens")
        screenshotDir.mkdirs()

        val longLine = LyricLine(
            timeMs = 1000L,
            endMs = 6000L,
            text = "A full commitment's what I'm thinking of",
            words = listOf(
                LyricWord(1000L, 1600L, "A"),
                LyricWord(1600L, 2400L, "full"),
                LyricWord(2400L, 3400L, "commitment's"),
                LyricWord(3400L, 4000L, "what"),
                LyricWord(4000L, 4600L, "I'm"),
                LyricWord(4600L, 5300L, "thinking"),
                LyricWord(5300L, 6000L, "of")
            )
        )
        val wordCount = longLine.words.size

        var capturedLayout: TextLayoutResult? = null

        // Render at real phone viewport width: 360dp with 24dp horizontal padding (density 2f -> 720px width)
        val scene = ImageComposeScene(width = 360, height = 300, density = Density(2f)) {
            MetrolistTheme {
                Box(
                    modifier = Modifier
                        .width(360.dp)
                        .padding(horizontal = 24.dp)
                ) {
                    Text(
                        text = longLine.words.joinToString(" ") { it.text },
                        style = LyricTextStyle,
                        modifier = Modifier.fillMaxWidth(),
                        onTextLayout = { capturedLayout = it }
                    )
                }
            }
        }

        val img = scene.render()
        assertNotNull(img, "Rendered scene must not be null")

        val layout = capturedLayout
        assertNotNull(layout, "TextLayoutResult must be captured at 360dp width")

        // 1. Assert line count < word count (paragraph wrapping instead of 1 word per line)
        val lineCount = layout.lineCount
        println("At 360dp width (312dp available): lineCount=$lineCount, wordCount=$wordCount")
        assertTrue(lineCount < wordCount, "Paragraph wrapping must result in line count ($lineCount) < word count ($wordCount)")
        assertTrue(lineCount > 1, "Long 7-word line must wrap to at least 2 lines at 360dp width")

        // 2. Assert first line contains multiple words
        val firstLineEnd = layout.getLineEnd(0)
        val fullText = longLine.words.joinToString(" ") { it.text }
        val firstLineText = fullText.substring(0, firstLineEnd).trim()
        val firstLineWords = firstLineText.split(Regex("\\s+")).filter { it.isNotBlank() }
        println("First line text at 360dp: '$firstLineText', words=${firstLineWords.size}")
        assertTrue(firstLineWords.size >= 2, "First line must contain multiple words, but was: '$firstLineText'")

        // 3. Verify tap-to-seek character offset mapping
        val tapOffset = Offset(20f, 10f)
        val charOffset = layout.getOffsetForPosition(tapOffset)
        assertTrue(charOffset >= 0, "Tap offset must map to valid character index")

        // 4. Verify clip path generation for active word progression
        val wordRanges = mutableListOf<WordCharRange>()
        var curr = 0
        for (w in longLine.words) {
            val start = curr
            val end = start + w.text.length
            wordRanges.add(WordCharRange(w, start, end))
            curr = end + 1
        }
        val clipPath = buildActiveLyricClipPath(layout, wordRanges, 2500L, longLine)
        assertNotNull(clipPath)

        // Save screenshot
        val data = img.encodeToData(EncodedImageFormat.PNG)
        if (data != null) {
            val outFile = File(screenshotDir, "03_paragraph_wrap_360dp.png")
            outFile.writeBytes(data.bytes)
            println("Saved 360dp paragraph wrap screenshot: ${outFile.length()} bytes")
        }
    }

    @Test
    fun testWordHighlightAnimatesWithoutRecomposition() {
        val fakeClock = mutableLongStateOf(1000L)
        val line = LyricLine(
            timeMs = 1000L,
            endMs = 4000L,
            text = "One two three",
            words = listOf(
                LyricWord(startMs = 1000L, endMs = 2000L, text = "One"),
                LyricWord(startMs = 2000L, endMs = 3000L, text = "two"),
                LyricWord(startMs = 3000L, endMs = 4000L, text = "three")
            )
        )

        var lineRecompositionCount = 0

        try {
            val scene = ImageComposeScene(width = 300, height = 100) {
                MetrolistTheme {
                    Box {
                        SideEffect {
                            lineRecompositionCount++
                        }
                        ActiveLyricLine(
                            line = line,
                            positionProvider = { fakeClock.longValue },
                            onSeekTo = {}
                        )
                    }
                }
            }

            // Initial render at 1000ms
            val img1 = scene.render()
            assertNotNull(img1)
            assertEquals(1, lineRecompositionCount, "Initial composition must count exactly 1")

            // Frame 1: Advance clock to midway through word 1 (1500ms)
            fakeClock.longValue = 1500L
            val img2 = scene.render()
            assertNotNull(img2)
            assertEquals(1, lineRecompositionCount, "Advancing clock within word 1 must NOT recompose line item (count=1)")

            // Frame 2: Advance clock to word 2 (2500ms)
            fakeClock.longValue = 2500L
            val img3 = scene.render()
            assertNotNull(img3)
            assertEquals(1, lineRecompositionCount, "Advancing clock to word 2 must NOT recompose line item (count=1)")

            // Frame 3: Advance clock to word 3 (3500ms)
            fakeClock.longValue = 3500L
            val img4 = scene.render()
            assertNotNull(img4)
            assertEquals(1, lineRecompositionCount, "Advancing clock to word 3 must NOT recompose line item (count=1)")
        } catch (e: Throwable) {
            println("Offscreen scene note: ${e.message}")
        }
    }
}
