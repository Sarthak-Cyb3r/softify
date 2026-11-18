package com.softify.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.isActive

/**
 * Word-level timing for high-precision lyric rendering.
 */
data class LyricWord(
    val startMs: Long,
    val endMs: Long,
    val text: String
)

/**
 * Lyric line data structure.
 * Supports line-level timestamps with word timings (either from enhanced LRC or estimated).
 */
data class LyricLine(
    val timeMs: Long,
    val endMs: Long = timeMs + 3000L,
    val text: String,
    val words: List<LyricWord> = emptyList()
)

/**
 * Metrolist / Apple Music typography for lyric lines:
 * Left-aligned, large bold type (~28sp, Bold, lineHeight ~1.35x = 38sp, tight letter spacing -0.5sp).
 */
val LyricTextStyle = TextStyle(
    fontSize = 28.sp,
    fontWeight = FontWeight.Bold,
    lineHeight = 38.sp,
    letterSpacing = (-0.5).sp,
    textAlign = TextAlign.Start
)

/**
 * Splits a line's duration across words by character count.
 */
fun estimateWordsForLine(text: String, lineStartMs: Long, lineEndMs: Long): List<LyricWord> {
    val tokens = text.split(Regex("\\s+")).filter { it.isNotBlank() }
    if (tokens.isEmpty()) return emptyList()

    val lineDuration = if (lineEndMs > lineStartMs) lineEndMs - lineStartMs else 3000L
    val charCounts = tokens.map { it.length.coerceAtLeast(1) }
    val totalChars = charCounts.sum().coerceAtLeast(1)

    val words = mutableListOf<LyricWord>()
    var currentStart = lineStartMs

    for (i in tokens.indices) {
        val isLast = (i == tokens.lastIndex)
        val wordDur = if (isLast) {
            (lineEndMs - currentStart).coerceAtLeast(100L)
        } else {
            val propDur = (lineDuration * charCounts[i]) / totalChars
            propDur.coerceAtLeast(100L)
        }

        val endMs = if (isLast) {
            maxOf(lineEndMs, currentStart + 100L)
        } else {
            minOf(currentStart + wordDur, lineEndMs)
        }

        words.add(LyricWord(startMs = currentStart, endMs = endMs, text = tokens[i]))
        currentStart = endMs
    }
    return words
}

/**
 * Parse plain LRC timestamp string lines "[mm:ss.xx] text" into a List<LyricLine>.
 */
fun parseLrcLines(lrcContent: String): List<LyricLine> {
    val result = mutableListOf<LyricLine>()
    val lines = lrcContent.lines()
    val regex = Regex("""\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\](.*)""")

    for (line in lines) {
        val match = regex.find(line.trim()) ?: continue
        val (minStr, secStr, fracStr, lyricText) = match.destructured
        val minutes = minStr.toLongOrNull() ?: 0L
        val seconds = secStr.toLongOrNull() ?: 0L
        val fracClean = fracStr ?: ""
        val ms = if (fracClean.length == 2) fracClean.toLongOrNull()?.times(10) ?: 0L
        else fracClean.toLongOrNull() ?: 0L
        val totalMs = minutes * 60_000L + seconds * 1000L + ms
        val text = lyricText.trim()
        if (text.isNotBlank()) {
            val words = estimateWordsForLine(text, totalMs, totalMs + 3000L)
            result.add(LyricLine(timeMs = totalMs, endMs = totalMs + 3000L, text = text, words = words))
        }
    }
    return result.sortedBy { it.timeMs }
}

/**
 * Frame-driven lyrics clock:
 * Keeps (lastPositionMs, lastUpdateNanos, isPlaying).
 * Runs a LaunchedEffect loop using withFrameNanos that writes
 * interpolatedPositionMs = lastPositionMs + (now - lastUpdateNanos) / 1_000_000L when playing,
 * and re-syncs whenever the player publishes a new position or a seek happens.
 * Pauses the loop when playback is paused or enabled is false (no wasted frames).
 * Exposes a MutableLongState read strictly by draw phase lambdas.
 */
@Composable
fun rememberLyricsClock(
    basePositionMs: Long,
    isPlaying: Boolean,
    enabled: Boolean = true
): MutableLongState {
    val clock = remember { mutableLongStateOf(basePositionMs) }

    // Track baseline for interpolation
    var syncPositionMs by remember { mutableLongStateOf(basePositionMs) }
    var syncTimeNanos by remember { mutableLongStateOf(0L) }

    // Re-sync whenever upstream publishes a new position (from player ticker) or seek occurs
    LaunchedEffect(basePositionMs) {
        val nowNanos = System.nanoTime()
        syncPositionMs = basePositionMs
        syncTimeNanos = nowNanos
        clock.longValue = basePositionMs
    }

    // Frame-driven animation loop: runs withFrameNanos at display refresh rate (60/120 fps)
    LaunchedEffect(isPlaying, enabled) {
        if (!isPlaying || !enabled) {
            clock.longValue = basePositionMs
            return@LaunchedEffect
        }

        if (syncTimeNanos == 0L) {
            syncTimeNanos = System.nanoTime()
            syncPositionMs = basePositionMs
        }

        var frameCount = 0
        var lastFpsLogTime = System.currentTimeMillis()

        while (isActive) {
            withFrameNanos { frameTimeNanos ->
                val elapsedNanos = (frameTimeNanos - syncTimeNanos).coerceAtLeast(0L)
                val interpolatedMs = syncPositionMs + (elapsedNanos / 1_000_000L)
                clock.longValue = interpolatedMs

                frameCount++
                val nowWall = System.currentTimeMillis()
                if (nowWall - lastFpsLogTime >= 5000L) {
                    val duration = nowWall - lastFpsLogTime
                    if (duration > 0) {
                        val fps = (frameCount * 1000f) / duration.toFloat()
                        PlaybackLogger.log("SoftifyLyrics", "Lyrics clock frame rate: ${fps.toInt()} fps (interpolatedPos=${interpolatedMs}ms)")
                    }
                    frameCount = 0
                    lastFpsLogTime = nowWall
                }
            }
        }
    }

    return clock
}

/**
 * High-performance, 60 fps synced lyrics view.
 * - Reads playback position only in draw phase (drawWithContent / graphicsLayer lambdas).
 * - Computes active line index via derivedStateOf so composition only invalidates when active line changes.
 * - Stable keys for LazyColumn items.
 * - Word-by-word highlight and fill sweep.
 * - Tap word or line to seek.
 */
@Composable
fun LyricsView(
    lines: List<LyricLine>,
    positionProvider: () -> Long,
    modifier: Modifier = Modifier,
    isSynced: Boolean = true,
    isWordSynced: Boolean = false,
    onSeekTo: (Long) -> Unit = {},
    contentPadding: PaddingValues = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
) {
    if (lines.isEmpty()) {
        Box(
            modifier = modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            InstrumentalIndicator()
        }
        return
    }

    if (!isSynced) {
        // Plain (unsynced) lyrics: readable scrollable list without shine or dimming
        LazyColumn(
            modifier = modifier.fillMaxSize(),
            contentPadding = contentPadding,
            verticalArrangement = Arrangement.spacedBy(22.dp)
        ) {
            itemsIndexed(
                items = lines,
                key = { index, line -> "plain_${line.timeMs}_$index" }
            ) { _, line ->
                if (line.text.trim() == "[Instrumental]" || line.text.isBlank()) {
                    InstrumentalIndicator()
                } else {
                    Text(
                        text = line.text,
                        style = LyricTextStyle.copy(
                            color = MaterialTheme.colorScheme.onSurface,
                            textAlign = TextAlign.Start
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
        return
    }

    // Active line index computed via derivedStateOf: invalidates composition ONLY when index changes!
    val activeIndex by remember(lines) {
        derivedStateOf {
            val currentMs = positionProvider()
            var idx = -1
            for (i in lines.indices) {
                if (lines[i].timeMs <= currentMs) {
                    idx = i
                } else {
                    break
                }
            }
            idx
        }
    }

    val listState = rememberLazyListState()

    // Smooth auto-scroll to keep active line centered (triggers ONLY when active line changes)
    LaunchedEffect(activeIndex) {
        if (activeIndex in lines.indices) {
            listState.animateScrollToItem(
                index = activeIndex,
                scrollOffset = -150
            )
        }
    }

    LazyColumn(
        state = listState,
        modifier = modifier.fillMaxSize(),
        contentPadding = contentPadding,
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        itemsIndexed(
            items = lines,
            key = { index, line -> "synced_${line.timeMs}_$index" }
        ) { index, line ->
            val isActive = (index == activeIndex)

            val animatedAlpha by animateFloatAsState(
                targetValue = if (isActive) 1.0f else 0.35f,
                animationSpec = tween(durationMillis = 250),
                label = "lyricAlpha"
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .alpha(animatedAlpha)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        onSeekTo(line.timeMs)
                    }
                    .padding(vertical = 4.dp)
            ) {
                if (line.text.trim() == "[Instrumental]" || line.text.isBlank()) {
                    InstrumentalIndicator()
                } else if (isActive) {
                    ActiveLyricLine(
                        line = line,
                        positionProvider = positionProvider,
                        onSeekTo = onSeekTo
                    )
                } else {
                    Text(
                        text = line.text,
                        style = LyricTextStyle.copy(
                            color = MaterialTheme.colorScheme.onSurface
                        ),
                        textAlign = TextAlign.Start,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

/**
 * Overload accepting raw Long position and isPlaying state, driving the internal 60 fps lyrics clock.
 */
@Composable
fun LyricsView(
    lines: List<LyricLine>,
    currentPositionMs: Long,
    isPlaying: Boolean = true,
    modifier: Modifier = Modifier,
    isSynced: Boolean = true,
    isWordSynced: Boolean = false,
    onSeekTo: (Long) -> Unit = {},
    contentPadding: PaddingValues = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
) {
    val clock = rememberLyricsClock(
        basePositionMs = currentPositionMs,
        isPlaying = isPlaying
    )
    LyricsView(
        lines = lines,
        positionProvider = { clock.longValue },
        modifier = modifier,
        isSynced = isSynced,
        isWordSynced = isWordSynced,
        onSeekTo = onSeekTo,
        contentPadding = contentPadding
    )
}

/**
 * Overload accepting State<Long> clock directly.
 */
@Composable
fun LyricsView(
    lines: List<LyricLine>,
    positionState: State<Long>,
    modifier: Modifier = Modifier,
    isSynced: Boolean = true,
    isWordSynced: Boolean = false,
    onSeekTo: (Long) -> Unit = {},
    contentPadding: PaddingValues = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
) {
    LyricsView(
        lines = lines,
        positionProvider = { positionState.value },
        modifier = modifier,
        isSynced = isSynced,
        isWordSynced = isWordSynced,
        onSeekTo = onSeekTo,
        contentPadding = contentPadding
    )
}

/**
 * Active lyric line rendering word-by-word timing in the draw phase.
 * If word timings exist, renders words with smooth fill sweep, lit past words, and dimmed upcoming words.
 * If word timings are absent, renders line-level sweep gradient.
 */
/**
 * Character span mapping a LyricWord to its exact character range in the single AnnotatedString.
 */
data class WordCharRange(
    val word: LyricWord,
    val startChar: Int,
    val endChar: Int
)

/**
 * Builds the clip Path for the lit lyric text layer based on TextLayoutResult.
 * - Fully sung words: uses layout.getPathForRange(startChar, endChar).
 * - Actively sung word: uses the bounding rect on the word's line(s) scaled by progress.
 * - Upcoming words: not added (remain dim).
 */
fun buildActiveLyricClipPath(
    layout: TextLayoutResult,
    wordRanges: List<WordCharRange>,
    currentMs: Long,
    line: LyricLine
): Path {
    val clipPath = Path()

    if (wordRanges.isEmpty()) {
        val durationMs = (line.endMs - line.timeMs).coerceAtLeast(500L)
        val elapsed = (currentMs - line.timeMs).coerceAtLeast(0L)
        val p = (elapsed.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
        val w = layout.size.width.toFloat()
        val h = layout.size.height.toFloat()
        clipPath.addRect(Rect(0f, 0f, w * p, h))
        return clipPath
    }

    val textLength = layout.layoutInput.text.length

    for (range in wordRanges) {
        val word = range.word
        if (currentMs < word.startMs) {
            // Upcoming word: not sung yet (remains dim)
            continue
        }

        val startChar = range.startChar.coerceIn(0, textLength)
        val endChar = range.endChar.coerceIn(0, textLength)
        if (startChar >= endChar) continue

        if (currentMs >= word.endMs) {
            // Fully sung word: union its exact bounding range path
            clipPath.addPath(layout.getPathForRange(startChar, endChar))
        } else {
            // Actively sung word: partial bounding rect
            val duration = (word.endMs - word.startMs).coerceAtLeast(50L).toFloat()
            val elapsed = (currentMs - word.startMs).coerceAtLeast(0L).toFloat()
            val p = (elapsed / duration).coerceIn(0f, 1f)

            val startLine = layout.getLineForOffset(startChar)
            val lastChar = (endChar - 1).coerceAtLeast(startChar)
            val endLine = layout.getLineForOffset(lastChar)

            if (startLine == endLine) {
                val lineTop = layout.getLineTop(startLine)
                val lineBottom = layout.getLineBottom(startLine)
                val left = layout.getHorizontalPosition(startChar, true)
                val right = layout.getHorizontalPosition(endChar, false)
                val minX = minOf(left, right)
                val maxX = maxOf(left, right)
                val partialX = minX + (maxX - minX) * p
                clipPath.addRect(Rect(minX, lineTop, partialX, lineBottom))
            } else {
                // Word wraps across lines
                val totalChars = (endChar - startChar).coerceAtLeast(1)
                val sungChars = totalChars * p
                for (l in startLine..endLine) {
                    val lStart = maxOf(startChar, layout.getLineStart(l))
                    val lEnd = minOf(endChar, layout.getLineEnd(l))
                    if (lStart >= lEnd) continue
                    val lTop = layout.getLineTop(l)
                    val lBottom = layout.getLineBottom(l)
                    val left = layout.getHorizontalPosition(lStart, true)
                    val right = layout.getHorizontalPosition(lEnd, false)
                    val minX = minOf(left, right)
                    val maxX = maxOf(left, right)

                    val lineCharStartInWord = lStart - startChar
                    val lineCharEndInWord = lEnd - startChar
                    if (sungChars >= lineCharEndInWord) {
                        clipPath.addRect(Rect(minX, lTop, maxX, lBottom))
                    } else if (sungChars > lineCharStartInWord) {
                        val lineProg = (sungChars - lineCharStartInWord) / (lineCharEndInWord - lineCharStartInWord).toFloat()
                        val partialX = minX + (maxX - minX) * lineProg.coerceIn(0f, 1f)
                        clipPath.addRect(Rect(minX, lTop, partialX, lBottom))
                    }
                }
            }
        }
    }

    return clipPath
}

/**
 * Active lyric line rendering word-by-word timing in the draw phase.
 * Renders each line as ONE single Text using an AnnotatedString so the text engine
 * wraps it as a paragraph. Lit words and fill sweep are drawn via TextLayoutResult
 * bounding boxes, driven by the frame clock strictly in the draw phase.
 * Tap-to-seek maps tap offset to word timestamp via getOffsetForPosition.
 */
@Composable
fun ActiveLyricLine(
    line: LyricLine,
    positionProvider: () -> Long,
    onSeekTo: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val onSurfaceColor = MaterialTheme.colorScheme.onSurface
    val aheadColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)

    // Build single paragraph string and character ranges for each word
    val (annotatedText, wordRanges) = remember(line.words, line.text) {
        if (line.words.isNotEmpty()) {
            val fullString = line.words.joinToString(" ") { it.text }
            val ranges = mutableListOf<WordCharRange>()
            var curr = 0
            for (w in line.words) {
                val start = curr
                val end = start + w.text.length
                ranges.add(WordCharRange(w, start, end))
                curr = end + 1 // space separator
            }
            AnnotatedString(fullString) to ranges
        } else {
            AnnotatedString(line.text) to emptyList<WordCharRange>()
        }
    }

    var textLayoutResult by remember { mutableStateOf<TextLayoutResult?>(null) }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .pointerInput(line, wordRanges) {
                detectTapGestures { tapOffset ->
                    val layout = textLayoutResult ?: return@detectTapGestures
                    val charOffset = layout.getOffsetForPosition(tapOffset)
                    val matchedWord = wordRanges.find { charOffset in it.startChar..it.endChar }?.word
                    if (matchedWord != null) {
                        onSeekTo(matchedWord.startMs)
                    } else {
                        onSeekTo(line.timeMs)
                    }
                }
            }
    ) {
        // Layer 1: Base Dim Text (captures platform text layout result)
        Text(
            text = annotatedText,
            style = LyricTextStyle.copy(color = aheadColor),
            textAlign = TextAlign.Start,
            modifier = Modifier.fillMaxWidth(),
            onTextLayout = { textLayoutResult = it }
        )

        // Layer 2: Lit Text, clipped strictly in draw phase via TextLayoutResult bounding boxes
        Text(
            text = annotatedText,
            style = LyricTextStyle.copy(color = onSurfaceColor),
            textAlign = TextAlign.Start,
            modifier = Modifier
                .fillMaxWidth()
                .drawWithContent {
                    val layout = textLayoutResult ?: return@drawWithContent
                    val currentMs = positionProvider() // Read ONLY in draw phase!

                    val clipPath = buildActiveLyricClipPath(
                        layout = layout,
                        wordRanges = wordRanges,
                        currentMs = currentMs,
                        line = line
                    )

                    clipPath(clipPath) {
                        this@drawWithContent.drawContent()
                    }
                }
        )
    }
}

/**
 * Preview / single-line overload for ActiveLyricLine.
 */
@Composable
fun ActiveLyricLine(
    text: String,
    progress: Float,
    modifier: Modifier = Modifier
) {
    val onSurfaceColor = MaterialTheme.colorScheme.onSurface
    val aheadColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)

    var textLayoutResult by remember { mutableStateOf<TextLayoutResult?>(null) }

    Box(modifier = modifier.fillMaxWidth()) {
        Text(
            text = text,
            style = LyricTextStyle.copy(color = aheadColor),
            textAlign = TextAlign.Start,
            modifier = Modifier.fillMaxWidth(),
            onTextLayout = { textLayoutResult = it }
        )

        Text(
            text = text,
            style = LyricTextStyle.copy(color = onSurfaceColor),
            textAlign = TextAlign.Start,
            modifier = Modifier
                .fillMaxWidth()
                .drawWithContent {
                    val p = progress.coerceIn(0f, 1f)
                    val w = size.width.coerceAtLeast(1f)
                    val h = size.height.coerceAtLeast(1f)
                    val path = Path().apply {
                        addRect(Rect(0f, 0f, w * p, h))
                    }
                    clipPath(path) {
                        this@drawWithContent.drawContent()
                    }
                }
        )
    }
}

/**
 * Minimal instrumental indicator with pulsing Canvas dots (no emoji/glyph characters).
 */
@Composable
fun InstrumentalIndicator(
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "instrumentalDots")
    val dotAlpha1 by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dot1"
    )
    val dotAlpha2 by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, delayMillis = 200, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dot2"
    )
    val dotAlpha3 by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, delayMillis = 400, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dot3"
    )

    val dotColor = MaterialTheme.colorScheme.primary

    Row(
        modifier = modifier.padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = "Instrumental",
            style = MaterialTheme.typography.bodyMedium.copy(
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
            )
        )
        Canvas(modifier = Modifier.size(width = 32.dp, height = 12.dp)) {
            val radius = 2.5.dp.toPx()
            drawCircle(
                color = dotColor.copy(alpha = dotAlpha1),
                radius = radius,
                center = Offset(4.dp.toPx(), size.height / 2f)
            )
            drawCircle(
                color = dotColor.copy(alpha = dotAlpha2),
                radius = radius,
                center = Offset(16.dp.toPx(), size.height / 2f)
            )
            drawCircle(
                color = dotColor.copy(alpha = dotAlpha3),
                radius = radius,
                center = Offset(28.dp.toPx(), size.height / 2f)
            )
        }
    }
}
