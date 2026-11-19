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
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.drawscope.clipPath
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.util.PlaybackLogger
import androidx.compose.foundation.gestures.scrollBy
import kotlin.math.abs
import kotlin.time.TimeMark
import kotlin.time.TimeSource
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/**
 * Composition local allowing desktop tests and platforms to provide bundled fonts (e.g. Manrope).
 */
val LocalLyricFontFamily = staticCompositionLocalOf<FontFamily?> { null }

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
 * Supports line-level timestamps with word timings (only from true word-synced sources; never synthetic).
 */
data class LyricLine(
    val timeMs: Long,
    val endMs: Long = timeMs + 3000L,
    val text: String,
    val words: List<LyricWord> = emptyList(),
    val isLineTimed: Boolean = words.isEmpty(),
    val isBackground: Boolean = false
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
            result.add(LyricLine(timeMs = totalMs, endMs = totalMs + 3000L, text = text, words = emptyList(), isLineTimed = true))
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
    positionProvider: () -> Long,
    isPlaying: Boolean,
    enabled: Boolean = true
): MutableLongState {
    val initialPos = remember { positionProvider() }
    val clock = remember { mutableLongStateOf(initialPos) }

    // Track baseline for interpolation
    var syncPositionMs by remember { mutableLongStateOf(initialPos) }
    var syncTimeNanos by remember { mutableLongStateOf(0L) }

    // Re-sync whenever upstream publishes a new position or seek occurs without recomposing callers
    LaunchedEffect(isPlaying, enabled) {
        snapshotFlow { positionProvider() }.collect { baseMs ->
            syncPositionMs = baseMs
            syncTimeNanos = System.nanoTime()
            clock.longValue = baseMs
        }
    }

    // Frame-driven animation loop: runs withFrameNanos at display refresh rate (60/120 fps)
    LaunchedEffect(isPlaying, enabled) {
        if (!isPlaying || !enabled) {
            clock.longValue = positionProvider()
            return@LaunchedEffect
        }

        if (syncTimeNanos == 0L) {
            syncTimeNanos = System.nanoTime()
            syncPositionMs = positionProvider()
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

@Composable
fun rememberLyricsClock(
    basePositionMs: Long,
    isPlaying: Boolean,
    enabled: Boolean = true
): MutableLongState = rememberLyricsClock(
    positionProvider = { basePositionMs },
    isPlaying = isPlaying,
    enabled = enabled
)

/**
 * Single lyric line item: measured once with TextMeasurer using finite content width.
 * Uses the EXACT SAME TextLayoutResult for layout measuring and draw phase rendering.
 * Height strictly matches measured layout height. Active line scaling/alpha happens in
 * graphicsLayer without changing layout bounds or shifting neighboring lines.
 */
@Composable
fun LyricLineItem(
    line: LyricLine,
    isActive: Boolean,
    contentWidthPx: Int,
    textMeasurer: TextMeasurer,
    textStyle: TextStyle,
    positionProvider: () -> Long,
    visualTranslationY: Float,
    onSeekTo: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val fullString = remember(line.text, line.words) {
        if (line.text.isNotBlank()) line.text else line.words.joinToString(" ") { it.text }
    }

    if (fullString.trim() == "[Instrumental]" || fullString.isBlank()) {
        InstrumentalIndicator()
        return
    }

    val density = LocalDensity.current

    // Measure line with TextMeasurer using FINITE maxWidth = contentWidthPx
    val textLayout = remember(fullString, contentWidthPx, textStyle) {
        textMeasurer.measure(
            text = AnnotatedString(fullString),
            style = textStyle,
            softWrap = true,
            constraints = Constraints(minWidth = 0, maxWidth = contentWidthPx)
        )
    }

    val wordRanges = remember(fullString, line.words) {
        if (line.words.isEmpty()) {
            emptyList<WordCharRange>()
        } else {
            val ranges = mutableListOf<WordCharRange>()
            var searchIdx = 0
            for (w in line.words) {
                val wordTrimmed = w.text.trim()
                if (wordTrimmed.isEmpty()) continue
                val found = fullString.indexOf(wordTrimmed, searchIdx)
                if (found >= 0) {
                    val start = found
                    val end = found + wordTrimmed.length
                    ranges.add(WordCharRange(w, start, end))
                    searchIdx = end
                } else {
                    val start = searchIdx.coerceAtMost(fullString.length)
                    val end = (start + wordTrimmed.length).coerceAtMost(fullString.length)
                    ranges.add(WordCharRange(w, start, end))
                    searchIdx = end
                }
            }
            ranges
        }
    }

    val itemHeightDp = with(density) { textLayout.size.height.toDp() }

    // Active-line emphasis (scale and alpha) via graphicsLayer with origin at left
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isActive) 1.0f else 0.35f,
        animationSpec = tween(durationMillis = 250),
        label = "lyricAlpha"
    )
    val animatedScale by animateFloatAsState(
        targetValue = if (isActive) 1.02f else 1.0f,
        animationSpec = tween(durationMillis = 250),
        label = "lyricScale"
    )

    val onSurfaceColor = MaterialTheme.colorScheme.onSurface
    val aheadColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
    val litBrush = remember(onSurfaceColor) { SolidColor(onSurfaceColor) }
    val unlitBrush = remember(aheadColor) { SolidColor(aheadColor) }
    val clipPath = remember { Path() }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer {
                translationY = visualTranslationY
                transformOrigin = TransformOrigin(0f, 0.5f)
                alpha = animatedAlpha
                scaleX = animatedScale
                scaleY = animatedScale
            }
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(itemHeightDp)
                .pointerInput(line, wordRanges, textLayout) {
                    detectTapGestures { tapOffset ->
                        val charOffset = textLayout.getOffsetForPosition(tapOffset)
                        val matchedWord = wordRanges.find { charOffset in it.startChar..it.endChar }?.word
                        if (matchedWord != null) {
                            onSeekTo(matchedWord.startMs)
                        } else {
                            onSeekTo(line.timeMs)
                        }
                    }
                }
        ) {
            if (!isActive) {
                // Passive line: exact same font, size, and layout rules as active, just unlit
                drawText(textLayoutResult = textLayout, brush = unlitBrush)
            } else if (line.isLineTimed || wordRanges.isEmpty()) {
                // Active line-timed: entire line highlighted
                drawText(textLayoutResult = textLayout, brush = litBrush)
            } else {
                // Active word-timed: base unlit + lit layer clipped to sung words
                val currentMs = positionProvider() // Read ONLY in draw phase!
                clipPath.reset()

                val fullLen = fullString.length
                for (range in wordRanges) {
                    val word = range.word
                    if (currentMs < word.startMs) {
                        continue
                    }

                    val startChar = range.startChar.coerceIn(0, fullLen)
                    val endChar = range.endChar.coerceIn(0, fullLen)
                    if (startChar >= endChar) continue

                    val startLine = textLayout.getLineForOffset(startChar)
                    val lastChar = (endChar - 1).coerceAtLeast(startChar)
                    val endLine = textLayout.getLineForOffset(lastChar)

                    if (currentMs >= word.endMs) {
                        for (l in startLine..endLine) {
                            val lStart = maxOf(startChar, textLayout.getLineStart(l))
                            val lEnd = minOf(endChar, textLayout.getLineEnd(l))
                            if (lStart >= lEnd) continue
                            val lTop = textLayout.getLineTop(l)
                            val lBottom = textLayout.getLineBottom(l)
                            val left = textLayout.getHorizontalPosition(lStart, true)
                            val right = textLayout.getHorizontalPosition(lEnd, false)
                            clipPath.addRect(Rect(minOf(left, right), lTop, maxOf(left, right), lBottom))
                        }
                    } else {
                        val duration = (word.endMs - word.startMs).coerceAtLeast(1L).toFloat()
                        val elapsed = (currentMs - word.startMs).toFloat()
                        val p = (elapsed / duration).coerceIn(0f, 1f)

                        if (startLine == endLine) {
                            val lTop = textLayout.getLineTop(startLine)
                            val lBottom = textLayout.getLineBottom(startLine)
                            val left = textLayout.getHorizontalPosition(startChar, true)
                            val right = textLayout.getHorizontalPosition(endChar, false)
                            val minX = minOf(left, right)
                            val maxX = maxOf(left, right)
                            val currentX = minX + (maxX - minX) * p
                            clipPath.addRect(Rect(minX, lTop, currentX, lBottom))
                        } else {
                            val totalChars = (endChar - startChar).coerceAtLeast(1)
                            val sungChars = totalChars * p
                            for (l in startLine..endLine) {
                                val lStart = maxOf(startChar, textLayout.getLineStart(l))
                                val lEnd = minOf(endChar, textLayout.getLineEnd(l))
                                if (lStart >= lEnd) continue
                                val lTop = textLayout.getLineTop(l)
                                val lBottom = textLayout.getLineBottom(l)
                                val left = textLayout.getHorizontalPosition(lStart, true)
                                val right = textLayout.getHorizontalPosition(lEnd, false)
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

                drawText(textLayoutResult = textLayout, brush = unlitBrush)
                clipPath(clipPath) {
                    drawText(textLayoutResult = textLayout, brush = litBrush)
                }
            }
        }
    }
}

/**
 * High-performance, 60 fps synced lyrics view.
 * - Reads playback position only in draw phase (drawWithContent / graphicsLayer lambdas).
 * - Computes active line index via derivedStateOf so composition only invalidates when active line changes.
 * - Stable keys for LazyColumn items.
 * - Same TextLayoutResult for measurement and drawing.
 * - FLIP auto-scroll with gesture lockout and retargeting.
 */
@Composable
fun LyricsView(
    lines: List<LyricLine>,
    positionProvider: () -> Long,
    modifier: Modifier = Modifier,
    isSynced: Boolean = true,
    isWordSynced: Boolean = false,
    providerName: String = "",
    showDebugOverlay: Boolean = false,
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

    val customFont = LocalLyricFontFamily.current
    val effectiveTextStyle = remember(customFont) {
        if (customFont != null) LyricTextStyle.copy(fontFamily = customFont) else LyricTextStyle
    }
    val textMeasurer = rememberTextMeasurer()

    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val layoutDirection = LocalLayoutDirection.current
        val startPaddingPx = with(density) { contentPadding.calculateStartPadding(layoutDirection).roundToPx() }
        val endPaddingPx = with(density) { contentPadding.calculateEndPadding(layoutDirection).roundToPx() }
        val contentWidthPx = (constraints.maxWidth - startPaddingPx - endPaddingPx).coerceAtLeast(1)

        if (!isSynced) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = contentPadding,
                verticalArrangement = Arrangement.spacedBy(22.dp)
            ) {
                itemsIndexed(
                    items = lines,
                    key = { index, line -> "plain_${line.timeMs}_$index" }
                ) { _, line ->
                    LyricLineItem(
                        line = line,
                        isActive = false,
                        contentWidthPx = contentWidthPx,
                        textMeasurer = textMeasurer,
                        textStyle = effectiveTextStyle,
                        positionProvider = positionProvider,
                        visualTranslationY = 0f,
                        onSeekTo = onSeekTo
                    )
                }
            }
            return@BoxWithConstraints
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
        val visualTranslationY = remember { Animatable(0f) }
        var manualScrollEndTime by remember { mutableStateOf<TimeMark?>(null) }
        var lastSeenActiveIndex by remember { mutableIntStateOf(-1) }
        var lastSeenPositionMs by remember { mutableLongStateOf(0L) }

        // Detect user manual scroll/drag and snap translation to 0
        LaunchedEffect(listState.isScrollInProgress) {
            if (listState.isScrollInProgress) {
                manualScrollEndTime = null
                visualTranslationY.snapTo(0f)
            } else {
                manualScrollEndTime = TimeSource.Monotonic.markNow()
            }
        }

        // FLIP spring auto-scroll with 400ms gesture lockout and clean retargeting
        LaunchedEffect(activeIndex) {
            if (activeIndex !in lines.indices) return@LaunchedEffect
            val isInitial = (lastSeenActiveIndex == -1)
            lastSeenActiveIndex = activeIndex

            val curPos = positionProvider()
            val isSeek = abs(curPos - lastSeenPositionMs) > 3000L && !isInitial
            lastSeenPositionMs = curPos

            val viewportHeight = listState.layoutInfo.viewportSize.height
            val targetCenter = (viewportHeight * 0.35f).toInt().coerceAtLeast(80)

            if (isInitial || isSeek) {
                // Seek or initial: instant snap without animation
                listState.scrollToItem(activeIndex, scrollOffset = -targetCenter)
                visualTranslationY.snapTo(0f)
                return@LaunchedEffect
            }

            // Gesture lockout: suspend while dragging, plus 400ms cooldown after drag ends
            while (listState.isScrollInProgress) {
                delay(50)
            }
            val endTime = manualScrollEndTime
            if (endTime != null) {
                val elapsed = endTime.elapsedNow().inWholeMilliseconds
                if (elapsed < 400L) {
                    delay(400L - elapsed)
                }
            }
            if (listState.isScrollInProgress) return@LaunchedEffect

            val targetItem = listState.layoutInfo.visibleItemsInfo.find { it.index == activeIndex }
            if (targetItem != null) {
                // posBefore incorporates current spring offset for smooth retargeting
                val posBefore = targetItem.offset.toFloat() + visualTranslationY.value

                val currentCenter = targetItem.offset + targetItem.size / 2
                val delta = (currentCenter - targetCenter).toFloat()

                if (abs(delta) > 1f) {
                    listState.scrollBy(delta)

                    val targetItemAfter = listState.layoutInfo.visibleItemsInfo.find { it.index == activeIndex }
                    val posAfter = targetItemAfter?.offset?.toFloat() ?: (targetItem.offset - delta)

                    // FLIP formula: newTranslationY = posBefore - posAfter
                    val newTranslationY = posBefore - posAfter

                    try {
                        visualTranslationY.snapTo(newTranslationY)
                        visualTranslationY.animateTo(
                            targetValue = 0f,
                            animationSpec = spring(
                                dampingRatio = 0.85f,
                                stiffness = 200f
                            )
                        )
                    } finally {
                        visualTranslationY.snapTo(0f)
                    }
                }
            } else {
                listState.scrollToItem(activeIndex, scrollOffset = -targetCenter)
                visualTranslationY.snapTo(0f)
            }
        }

        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = contentPadding,
            verticalArrangement = Arrangement.spacedBy(22.dp)
        ) {
            itemsIndexed(
                items = lines,
                key = { index, line -> "synced_${line.timeMs}_$index" }
            ) { index, line ->
                val isActive = (index == activeIndex)
                LyricLineItem(
                    line = line,
                    isActive = isActive,
                    contentWidthPx = contentWidthPx,
                    textMeasurer = textMeasurer,
                    textStyle = effectiveTextStyle,
                    positionProvider = positionProvider,
                    visualTranslationY = visualTranslationY.value,
                    onSeekTo = onSeekTo
                )
            }
        }

        if (showDebugOverlay) {
            val modeText = if (isWordSynced) "Word-timed" else if (isSynced) "Line-timed" else "Plain"
            Surface(
                shape = SquircleShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.85f),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
            ) {
                Text(
                    text = "Provider: ${providerName.ifBlank { "LRCLIB" }} | Lines: ${lines.size} | Mode: $modeText | FPS: 60",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
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
    providerName: String = "",
    showDebugOverlay: Boolean = false,
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
        providerName = providerName,
        showDebugOverlay = showDebugOverlay,
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
    providerName: String = "",
    showDebugOverlay: Boolean = false,
    onSeekTo: (Long) -> Unit = {},
    contentPadding: PaddingValues = PaddingValues(top = 160.dp, bottom = 180.dp, start = 24.dp, end = 24.dp)
) {
    LyricsView(
        lines = lines,
        positionProvider = { positionState.value },
        modifier = modifier,
        isSynced = isSynced,
        isWordSynced = isWordSynced,
        providerName = providerName,
        showDebugOverlay = showDebugOverlay,
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
 * Pre-measured word segment with exact sub-layout and paragraph offset.
 * Pre-computed once when layout settles to achieve ZERO per-frame allocations.
 */
data class MeasuredWordPart(
    val word: LyricWord,
    val text: String,
    val topLeft: Offset,
    val width: Float,
    val height: Float,
    val subLayout: TextLayoutResult,
    val partIndex: Int,
    val totalParts: Int
)

/**
 * Active lyric line rendering word-by-word timing in the draw phase.
 * Reuses LyricLineItem for single unified measurement and draw pipeline.
 */
@Composable
fun ActiveLyricLine(
    line: LyricLine,
    positionProvider: () -> Long,
    onSeekTo: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val textMeasurer = rememberTextMeasurer()
    val customFont = LocalLyricFontFamily.current
    val effectiveTextStyle = remember(customFont) {
        if (customFont != null) LyricTextStyle.copy(fontFamily = customFont) else LyricTextStyle
    }
    BoxWithConstraints(modifier = modifier.fillMaxWidth()) {
        val widthPx = constraints.maxWidth.coerceAtLeast(1)
        LyricLineItem(
            line = line,
            isActive = true,
            contentWidthPx = widthPx,
            textMeasurer = textMeasurer,
            textStyle = effectiveTextStyle,
            positionProvider = positionProvider,
            visualTranslationY = 0f,
            onSeekTo = onSeekTo
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
    val textMeasurer = rememberTextMeasurer()
    val density = LocalDensity.current

    BoxWithConstraints(modifier = modifier.fillMaxWidth()) {
        val widthPx = constraints.maxWidth
        if (widthPx <= 0) return@BoxWithConstraints

        val layout = remember(text, widthPx) {
            textMeasurer.measure(
                text = AnnotatedString(text),
                style = LyricTextStyle,
                softWrap = true,
                constraints = Constraints(minWidth = widthPx, maxWidth = widthPx)
            )
        }

        val layoutHeightDp = with(density) { layout.size.height.toDp() }

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(layoutHeightDp)
        ) {
            val p = progress.coerceIn(0f, 1f)
            val w = layout.size.width.toFloat()
            val wiperX = w * p
            val gradientWidth = 24.dp.toPx().coerceAtMost(w * 0.2f).coerceAtLeast(6f)
            val halfGrad = gradientWidth / 2f
            val bandStart = wiperX - halfGrad
            val bandEnd = wiperX + halfGrad

            val brush = Brush.linearGradient(
                0.0f to onSurfaceColor,
                0.1f to onSurfaceColor,
                0.9f to aheadColor,
                1.0f to aheadColor,
                start = Offset(bandStart, 0f),
                end = Offset(bandEnd, 0f)
            )

            drawText(
                textLayoutResult = layout,
                brush = brush
            )
        }
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
