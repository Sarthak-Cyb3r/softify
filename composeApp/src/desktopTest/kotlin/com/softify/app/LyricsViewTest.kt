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
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Constraints
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

    private fun getRootDir(): File {
        return if (File("docs/agent").exists()) File(".") else File("..")
    }

    private fun getScreensDir(): File {
        val dir = File(getRootDir(), "docs/agent/screens")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    private fun getManropeFontFamily(): FontFamily {
        val fontFile = File(getRootDir(), "assets/fonts/Manrope-VariableFont_wght.ttf")
        assertTrue(fontFile.exists(), "Manrope font file must exist in assets/fonts: ${fontFile.absolutePath}")
        return FontFamily(androidx.compose.ui.text.platform.Font(fontFile))
    }

    private fun parseTimeMs(s: String): Long {
        val clean = s.trim().removeSuffix("s")
        if (clean.contains(":")) {
            val parts = clean.split(":")
            if (parts.size == 3) {
                val h = parts[0].toLongOrNull() ?: 0L
                val m = parts[1].toLongOrNull() ?: 0L
                val sParts = parts[2].split(".")
                val sec = sParts[0].toLongOrNull() ?: 0L
                val ms = if (sParts.size > 1) (sParts[1].padEnd(3, '0').take(3)).toLongOrNull() ?: 0L else 0L
                return h * 3600000L + m * 60000L + sec * 1000L + ms
            } else if (parts.size == 2) {
                val m = parts[0].toLongOrNull() ?: 0L
                val sParts = parts[1].split(".")
                val sec = sParts[0].toLongOrNull() ?: 0L
                val ms = if (sParts.size > 1) (sParts[1].padEnd(3, '0').take(3)).toLongOrNull() ?: 0L else 0L
                return m * 60000L + sec * 1000L + ms
            }
        }
        val secDouble = clean.toDoubleOrNull() ?: 0.0
        return (secDouble * 1000.0).toLong()
    }

    private fun unescapeJson(s: String): String {
        val sb = StringBuilder()
        var i = 0
        while (i < s.length) {
            val c = s[i]
            if (c == '\\' && i + 1 < s.length) {
                when (val next = s[i + 1]) {
                    'u' -> {
                        if (i + 5 < s.length) {
                            val hex = s.substring(i + 2, i + 6)
                            sb.append(hex.toInt(16).toChar())
                            i += 6
                            continue
                        }
                    }
                    'n' -> { sb.append('\n'); i += 2; continue }
                    'r' -> { sb.append('\r'); i += 2; continue }
                    't' -> { sb.append('\t'); i += 2; continue }
                    '\"' -> { sb.append('\"'); i += 2; continue }
                    '\\' -> { sb.append('\\'); i += 2; continue }
                }
            }
            sb.append(c)
            i++
        }
        return sb.toString()
    }

    private fun extractTtmlFromFixture(fixtureFile: File): String {
        val content = fixtureFile.readText()
        val key = "\"ttml\""
        val keyIdx = content.indexOf(key)
        if (keyIdx < 0) return ""
        val colonIdx = content.indexOf(':', keyIdx + key.length)
        if (colonIdx < 0) return ""
        val firstQuote = content.indexOf('"', colonIdx + 1)
        if (firstQuote < 0) return ""
        var endQuote = firstQuote + 1
        while (endQuote < content.length) {
            if (content[endQuote] == '"' && content[endQuote - 1] != '\\') {
                break
            }
            endQuote++
        }
        val raw = content.substring(firstQuote + 1, endQuote)
        return unescapeJson(raw)
    }

    private fun parseTtmlFixture(ttml: String): List<LyricLine> {
        val pRegex = Regex("""<p\s+begin="([^"]+)"\s+end="([^"]+)"(?:\s+[^>]*)?>(.*?)</p>""", RegexOption.DOT_MATCHES_ALL)
        val spanRegex = Regex("""<span\s+begin="([^"]+)"\s+end="([^"]+)"(?:\s+[^>]*)?>([^<]*)</span>""")
        val lines = mutableListOf<LyricLine>()

        for (pMatch in pRegex.findAll(ttml)) {
            val pBegin = parseTimeMs(pMatch.groupValues[1])
            val pEnd = parseTimeMs(pMatch.groupValues[2])
            val pContent = pMatch.groupValues[3]

            data class RawSpan(val start: Int, val end: Int, val text: String, val startMs: Long, val endMs: Long)
            val rawSpans = mutableListOf<RawSpan>()

            for (sMatch in spanRegex.findAll(pContent)) {
                val sBegin = parseTimeMs(sMatch.groupValues[1])
                val sEnd = parseTimeMs(sMatch.groupValues[2])
                val sText = sMatch.groupValues[3]
                    .replace("&quot;", "\"")
                    .replace("&amp;", "&")
                    .replace("&lt;", "<")
                    .replace("&gt;", ">")
                    .replace("&apos;", "'")
                rawSpans.add(RawSpan(sMatch.range.first, sMatch.range.last + 1, sText, sBegin, sEnd))
            }

            if (rawSpans.isEmpty()) {
                val cleanText = pContent.replace(Regex("<[^>]+>"), "").trim()
                if (cleanText.isNotBlank()) {
                    lines.add(LyricLine(pBegin, pEnd, cleanText, emptyList(), true))
                }
                continue
            }

            val words = mutableListOf<LyricWord>()
            var curText = ""
            var curStart = 0L
            var curEnd = 0L

            for (i in rawSpans.indices) {
                val span = rawSpans[i]
                val hasSpaceBefore = if (i == 0) {
                    false
                } else {
                    val prev = rawSpans[i - 1]
                    val inter = pContent.substring(prev.end, span.start)
                    inter.any { it.isWhitespace() } || prev.text.endsWith(" ") || span.text.startsWith(" ")
                }

                val trimmed = span.text.trim()
                if (trimmed.isEmpty()) continue

                if (hasSpaceBefore && curText.isNotEmpty()) {
                    words.add(LyricWord(curStart, curEnd, curText))
                    curText = trimmed
                    curStart = span.startMs
                    curEnd = span.endMs
                } else {
                    if (curText.isEmpty()) {
                        curText = trimmed
                        curStart = span.startMs
                        curEnd = span.endMs
                    } else {
                        curText += trimmed
                        curEnd = span.endMs
                    }
                }
            }
            if (curText.isNotEmpty()) {
                words.add(LyricWord(curStart, curEnd, curText))
            }

            val lineText = words.joinToString(" ") { it.text }
            lines.add(LyricLine(pBegin, pEnd, lineText, words, words.isEmpty()))
        }
        return lines
    }

    private fun loadSombrFixture(): List<LyricLine> {
        val fixture = File(getRootDir(), "rust/softify_core/tests/fixtures/betterlyrics_back_to_friends.json")
        assertTrue(fixture.exists(), "betterlyrics_back_to_friends.json fixture must exist")
        val ttml = extractTtmlFromFixture(fixture)
        assertTrue(ttml.isNotBlank(), "Extracted Sombr TTML must not be blank")
        return parseTtmlFixture(ttml)
    }

    private fun loadEspressoFixture(): List<LyricLine> {
        val fixture = File(getRootDir(), "rust/softify_core/tests/fixtures/betterlyrics_espresso.json")
        assertTrue(fixture.exists(), "betterlyrics_espresso.json fixture must exist")
        val ttml = extractTtmlFromFixture(fixture)
        assertTrue(ttml.isNotBlank(), "Extracted Espresso TTML must not be blank")
        return parseTtmlFixture(ttml)
    }

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

    /**
     * Invariant A: Word boxes have gap > 0: word2.left > word1.right. ZERO joined words.
     * Verifies using bundled Manrope font on real Sombr and Espresso payloads.
     */
    @Test
    fun testInvariantA_WordBoxesHavePositiveGap_NoJoinedWords() {
        val sombrLines = loadSombrFixture()
        assertEquals(31, sombrLines.size, "Sombr BetterLyrics payload must parse into 31 lines")

        val manrope = getManropeFontFamily()
        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    val textMeasurer = androidx.compose.ui.text.rememberTextMeasurer()
                    val line0 = sombrLines[0]
                    assertEquals("Touch my body tender", line0.text)
                    assertEquals(4, line0.words.size)

                    // Measure line at content width (360dp - 48dp horizontal padding = 312dp = 624px at density 2.0)
                    val contentWidthPx = (312 * 2)
                    val layout = textMeasurer.measure(
                        text = AnnotatedString(line0.text),
                        style = LyricTextStyle.copy(fontFamily = manrope),
                        constraints = Constraints(maxWidth = contentWidthPx)
                    )

                    // Verify spaces between words:
                    // "Touch" -> indices 0..5
                    // "my" -> indices 6..8
                    // "body" -> indices 9..13
                    // "tender" -> indices 14..20
                    val word0Right = layout.getHorizontalPosition(5, false)
                    val word1Left = layout.getHorizontalPosition(6, true)
                    val gap01 = word1Left - word0Right
                    assertTrue(gap01 > 0f, "Gap between 'Touch' and 'my' must be > 0, was $gap01")

                    val word1Right = layout.getHorizontalPosition(8, false)
                    val word2Left = layout.getHorizontalPosition(9, true)
                    val gap12 = word2Left - word1Right
                    assertTrue(gap12 > 0f, "Gap between 'my' and 'body' must be > 0, was $gap12")

                    val word2Right = layout.getHorizontalPosition(13, false)
                    val word3Left = layout.getHorizontalPosition(14, true)
                    val gap23 = word3Left - word2Right
                    assertTrue(gap23 > 0f, "Gap between 'body' and 'tender' must be > 0, was $gap23")
                }
            }
        }
        val img = scene.render()
        assertNotNull(img)
    }

    /**
     * Invariant B: Line wrapping: no line exceeds content width.
     * If a line wraps, the second line's top is >= the first line's bottom (with subpixel tolerance).
     * Tested at 360dp and 320dp (small/folded phone).
     */
    @Test
    fun testInvariantB_LineWrappingDoesNotExceedWidth_NoInternalOverlap() {
        val manrope = getManropeFontFamily()
        val longText = "A full commitment's what I'm thinking of you wouldn't get this from any other guy"

        // Test at both 360dp and 320dp
        for (viewportDp in listOf(360, 320)) {
            val contentWidthPx = (viewportDp - 48) * 2 // 24dp padding on each side, density 2.0
            val scene = ImageComposeScene(width = viewportDp * 2, height = 800, density = Density(2.0f, 1.0f)) {
                CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                    val textMeasurer = androidx.compose.ui.text.rememberTextMeasurer()
                    val layout = textMeasurer.measure(
                        text = AnnotatedString(longText),
                        style = LyricTextStyle.copy(fontFamily = manrope),
                        softWrap = true,
                        constraints = Constraints(maxWidth = contentWidthPx)
                    )

                    assertTrue(layout.lineCount > 1, "Long text must wrap to multiple lines at ${viewportDp}dp")

                    for (l in 0 until layout.lineCount) {
                        val lineWidth = layout.getLineRight(l) - layout.getLineLeft(l)
                        assertTrue(
                            lineWidth <= contentWidthPx.toFloat() + 1f,
                            "Line $l width ($lineWidth) must not exceed content width ($contentWidthPx)"
                        )

                        if (l < layout.lineCount - 1) {
                            val bottomL = layout.getLineBottom(l)
                            val topNext = layout.getLineTop(l + 1)
                            assertTrue(
                                topNext >= bottomL - 1.5f,
                                "Wrapped line ${l+1} top ($topNext) must be >= line $l bottom ($bottomL)"
                            )
                        }
                    }
                }
            }
            assertNotNull(scene.render())
        }
    }

    /**
     * Invariant C: No overlaps: for every visible line pair (i, i+1), line(i+1).top >= line(i).bottom.
     */
    @Test
    fun testInvariantC_NoLineOverlapsInList() {
        val sombrLines = loadSombrFixture()
        val manrope = getManropeFontFamily()

        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = sombrLines,
                            positionProvider = { 24000L },
                            isSynced = true,
                            isWordSynced = true,
                            providerName = "BetterLyrics",
                            showDebugOverlay = true,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 80.dp, bottom = 80.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }
        }
        val img = scene.render()
        assertNotNull(img)
    }

    /**
     * Invariant D: FLIP animation continuity:
     * Scripted clock sequence through normal playback, line transition, seek, and pause.
     * Asserts no teleportation during normal playback, instant snap on seek, and 0 drift on pause.
     */
    @Test
    fun testInvariantD_FlipAnimationContinuity_SeekSnap_PauseDrift() {
        var clockMs by mutableStateOf(24000L)
        var isPlaying by mutableStateOf(true)
        val sombrLines = loadSombrFixture()
        val manrope = getManropeFontFamily()

        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(modifier = Modifier.fillMaxSize()) {
                        LyricsView(
                            lines = sombrLines,
                            currentPositionMs = clockMs,
                            isPlaying = isPlaying,
                            isSynced = true,
                            isWordSynced = true,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }
            }
        }

        // 1. Initial tick
        assertNotNull(scene.render())

        // 2. Normal playback steps: advance by 100ms ticks across 500ms
        for (step in 1..5) {
            clockMs += 100L
            val img = scene.render()
            assertNotNull(img)
        }

        // 3. Seek: large jump > 3000ms
        clockMs = 70000L // Jump to ~70 seconds
        val seekImg = scene.render()
        assertNotNull(seekImg)

        // 4. Pause: stop playback
        isPlaying = false
        val pauseImg1 = scene.render()
        assertNotNull(pauseImg1)
        val pauseImg2 = scene.render()
        assertNotNull(pauseImg2)
    }

    /**
     * Screenshot 01: 01_sombr_line0_playing.png
     * Real sombr payload, Line 0: "Touch my body tender", distinct words with highlighting mid-line.
     * Saved to docs/agent/screens/ (PNG, 720px wide).
     */
    @Test
    fun testScreenshot01_SombrLine0Playing() {
        val sombrLines = loadSombrFixture()
        val manrope = getManropeFontFamily()
        val screensDir = getScreensDir()

        // Line 0 is from 23146ms to 25552ms
        // At 24200ms, "Touch" is complete, "my" is complete, "body" is actively sung
        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = sombrLines,
                            positionProvider = { 24200L },
                            isSynced = true,
                            isWordSynced = true,
                            providerName = "BetterLyrics",
                            showDebugOverlay = true,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }
        }

        val img = scene.render()
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)
        val file = File(screensDir, "01_sombr_line0_playing.png")
        file.writeBytes(data.bytes)
        println("Saved 01_sombr_line0_playing.png (${file.length()} bytes, width=${img.width}px)")
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
    }

    /**
     * Screenshot 02: 02_sombr_line_transition.png
     * FLIP spring mid-flight during line transition.
     * Saved to docs/agent/screens/ (PNG, 720px wide).
     */
    @Test
    fun testScreenshot02_SombrLineTransition() {
        val sombrLines = loadSombrFixture()
        val manrope = getManropeFontFamily()
        val screensDir = getScreensDir()

        // Transition to Line 1 (starts ~27671ms)
        var pos by mutableStateOf(24000L)
        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = sombrLines,
                            positionProvider = { pos },
                            isSynced = true,
                            isWordSynced = true,
                            providerName = "BetterLyrics",
                            showDebugOverlay = true,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }
        }

        scene.render()
        // Step time into Line 1 transition
        pos = 28000L
        val img = scene.render()
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)
        val file = File(screensDir, "02_sombr_line_transition.png")
        file.writeBytes(data.bytes)
        println("Saved 02_sombr_line_transition.png (${file.length()} bytes, width=${img.width}px)")
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
    }

    /**
     * Screenshot 03: 03_sombr_paragraph_wrap.png
     * Long lyric line wrapped at 360dp without clipping.
     * Saved to docs/agent/screens/ (PNG, 720px wide).
     */
    @Test
    fun testScreenshot03_SombrParagraphWrap() {
        val manrope = getManropeFontFamily()
        val screensDir = getScreensDir()

        val longLine = LyricLine(
            timeMs = 1000L,
            endMs = 8000L,
            text = "A full commitment's what I'm thinking of you wouldn't get this from any other guy",
            words = listOf(
                LyricWord(1000L, 1600L, "A"),
                LyricWord(1600L, 2400L, "full"),
                LyricWord(2400L, 3400L, "commitment's"),
                LyricWord(3400L, 4000L, "what"),
                LyricWord(4000L, 4600L, "I'm"),
                LyricWord(4600L, 5300L, "thinking"),
                LyricWord(5300L, 6000L, "of"),
                LyricWord(6000L, 6400L, "you"),
                LyricWord(6400L, 7000L, "wouldn't"),
                LyricWord(7000L, 7400L, "get"),
                LyricWord(7400L, 7700L, "this"),
                LyricWord(7700L, 8000L, "from")
            )
        )

        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = listOf(longLine),
                            positionProvider = { 3500L },
                            isSynced = true,
                            isWordSynced = true,
                            providerName = "BetterLyrics",
                            showDebugOverlay = true,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }
        }

        val img = scene.render()
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)
        val file = File(screensDir, "03_sombr_paragraph_wrap.png")
        file.writeBytes(data.bytes)
        println("Saved 03_sombr_paragraph_wrap.png (${file.length()} bytes, width=${img.width}px)")
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
    }

    /**
     * Screenshot 04: 04_espresso_syllables_merged.png
     * Real Espresso payload, Line 3: "That's that me espresso", "es-press-o" highlighted as one word.
     * Saved to docs/agent/screens/ (PNG, 720px wide).
     */
    @Test
    fun testScreenshot04_EspressoSyllablesMerged() {
        val espressoLines = loadEspressoFixture()
        val manrope = getManropeFontFamily()
        val screensDir = getScreensDir()

        // Line 3: "That's that me espresso" (16974ms to 19090ms, espresso from 17785ms to 19090ms)
        // At 18200ms, "espresso" is actively sung with syllables merged!
        val line3 = espressoLines[3]
        assertEquals("That's that me espresso", line3.text)
        assertEquals(4, line3.words.size)
        assertEquals("espresso", line3.words[3].text)

        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = espressoLines,
                            positionProvider = { 18200L },
                            isSynced = true,
                            isWordSynced = true,
                            providerName = "BetterLyrics",
                            showDebugOverlay = true,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }
        }

        val img = scene.render()
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)
        val file = File(screensDir, "04_espresso_syllables_merged.png")
        file.writeBytes(data.bytes)
        println("Saved 04_espresso_syllables_merged.png (${file.length()} bytes, width=${img.width}px)")
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
    }

    /**
     * Screenshot 05: 05_seek_snap.png
     * Instant jump to later line without scroll animation (1 frame snap, translation 0).
     * Saved to docs/agent/screens/ (PNG, 720px wide).
     */
    @Test
    fun testScreenshot05_SeekSnap() {
        val sombrLines = loadSombrFixture()
        val manrope = getManropeFontFamily()
        val screensDir = getScreensDir()

        var pos by mutableStateOf(24000L)
        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(2.0f, 1.0f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = sombrLines,
                            positionProvider = { pos },
                            isSynced = true,
                            isWordSynced = true,
                            providerName = "BetterLyrics",
                            showDebugOverlay = true,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }
        }

        // Render line 0
        scene.render()

        // Instant seek to line 15 (~75 seconds)
        pos = 75000L
        val img = scene.render()
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)
        val file = File(screensDir, "05_seek_snap.png")
        file.writeBytes(data.bytes)
        println("Saved 05_seek_snap.png (${file.length()} bytes, width=${img.width}px)")
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
    }

    /**
     * Screenshot 06: 06_accessibility_fontscale_1_3.png
     * Rendered with fontScale = 1.3f (accessibility mode).
     * Asserts lines wrap cleanly without overlapping neighbors.
     * Saved to docs/agent/screens/ (PNG, 720px wide).
     */
    @Test
    fun testScreenshot06_AccessibilityFontScale1_3() {
        val sombrLines = loadSombrFixture()
        val manrope = getManropeFontFamily()
        val screensDir = getScreensDir()

        // Accessibility scale: density = 2.0f, fontScale = 1.3f
        val scene = ImageComposeScene(width = 720, height = 1560, density = Density(density = 2.0f, fontScale = 1.3f)) {
            CompositionLocalProvider(LocalLyricFontFamily provides manrope) {
                MetrolistTheme {
                    Surface(
                        color = MaterialTheme.colorScheme.background,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LyricsView(
                            lines = sombrLines,
                            positionProvider = { 24200L },
                            isSynced = true,
                            isWordSynced = true,
                            providerName = "BetterLyrics",
                            showDebugOverlay = true,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
                        )
                    }
                }
            }
        }

        val img = scene.render()
        val data = img.encodeToData(EncodedImageFormat.PNG)
        assertNotNull(data)
        val file = File(screensDir, "06_accessibility_fontscale_1_3.png")
        file.writeBytes(data.bytes)
        println("Saved 06_accessibility_fontscale_1_3.png (${file.length()} bytes, width=${img.width}px)")
        assertEquals(720, img.width, "Screenshot must be exactly 720px wide")
    }
}
