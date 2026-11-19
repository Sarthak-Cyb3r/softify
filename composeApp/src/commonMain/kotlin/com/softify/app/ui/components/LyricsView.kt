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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.util.PlaybackLogger
import androidx.compose.foundation.gestures.scrollBy
import kotlin.math.abs
import kotlin.time.TimeMark
import kotlin.time.TimeSource
import kotlinx.coroutines.delay
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
    val visualTranslationY = remember { Animatable(0f) }
    var manualScrollEndTime by remember { mutableStateOf<TimeMark?>(null) }

    LaunchedEffect(listState.isScrollInProgress) {
        if (listState.isScrollInProgress) {
            manualScrollEndTime = null
            visualTranslationY.snapTo(0f)
        } else {
            manualScrollEndTime = TimeSource.Monotonic.markNow()
        }
    }

    // FLIP spring auto-scroll with 400ms gesture lockout (instant scrollBy shift + damped spring graphicsLayer decay)
    LaunchedEffect(activeIndex, listState.isScrollInProgress) {
        if (activeIndex !in lines.indices) return@LaunchedEffect

        // 400ms gesture lockout: suppress while user touches or flings
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

        val visibleItems = listState.layoutInfo.visibleItemsInfo
        val targetItem = visibleItems.find { it.index == activeIndex }
        val viewportHeight = listState.layoutInfo.viewportSize.height
        val targetCenter = (viewportHeight * 0.35f).toInt().coerceAtLeast(80)

        if (targetItem != null) {
            val currentCenter = targetItem.offset + targetItem.size / 2
            val delta = (currentCenter - targetCenter).toFloat()
            if (abs(delta) > 2f) {
                // FLIP shift: instant list viewport update
                listState.scrollBy(delta)
                // Inverse visual offset on graphicsLayer to prevent any visual jump
                visualTranslationY.snapTo(delta)
                // Decays smoothly to 0 with a damped spring
                visualTranslationY.animateTo(
                    targetValue = 0f,
                    animationSpec = spring(
                        dampingRatio = 0.85f,
                        stiffness = 200f
                    )
                )
            }
        } else {
            // Far jump / initial positioning
            listState.scrollToItem(activeIndex, scrollOffset = -targetCenter)
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
                    .graphicsLayer { translationY = visualTranslationY.value }
                    .alpha(animatedAlpha)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        onSeekTo(line.timeMs)
                    }
                    .padding(vertical = 4.dp)
            ) {
                val lineDisplayText = if (line.text.isNotBlank()) line.text else line.words.joinToString(" ") { it.text }
                if (lineDisplayText.trim() == "[Instrumental]" || lineDisplayText.isBlank()) {
                    InstrumentalIndicator()
                } else if (isActive) {
                    ActiveLyricLine(
                        line = line,
                        positionProvider = positionProvider,
                        onSeekTo = onSeekTo
                    )
                } else {
                    Text(
                        text = lineDisplayText,
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
 * Renders each line as ONE single paragraph layout using TextMeasurer so the text engine
 * wraps it as a paragraph. Lit words and fill sweep are drawn via a 4-stop Brush.linearGradient
 * (0f to lit, 0.1f to lit, 0.9f to unlit, 1.0f to unlit) driven by the frame clock strictly in
 * the draw phase, with zero per-frame Path/clipPath allocations.
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
    val density = LocalDensity.current
    val textMeasurer = rememberTextMeasurer()

    // 1. Build canonical paragraph string and character ranges for each word
    val fullString = remember(line.words, line.text) {
        if (line.text.isNotBlank()) line.text else line.words.joinToString(" ") { it.text }
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

    BoxWithConstraints(modifier = modifier.fillMaxWidth()) {
        val widthPx = constraints.maxWidth
        if (widthPx <= 0) return@BoxWithConstraints

        // 2. Pre-measure full paragraph layout (determines line breaks and wrapping)
        val fullLayout = remember(fullString, widthPx) {
            textMeasurer.measure(
                text = AnnotatedString(fullString),
                style = LyricTextStyle,
                softWrap = true,
                constraints = Constraints(minWidth = widthPx, maxWidth = widthPx)
            )
        }

        // 3. Pre-measure per-line word bounding boxes and sub-layouts once when layout settles (zero per-frame allocations)
        val measuredWordParts = remember(fullLayout, wordRanges) {
            val parts = mutableListOf<MeasuredWordPart>()
            val fullLen = fullString.length
            for (range in wordRanges) {
                val w = range.word
                val startChar = range.startChar.coerceIn(0, fullLen)
                val endChar = range.endChar.coerceIn(0, fullLen)
                if (startChar >= endChar) continue

                val startLine = fullLayout.getLineForOffset(startChar)
                val lastChar = (endChar - 1).coerceAtLeast(startChar)
                val endLine = fullLayout.getLineForOffset(lastChar)
                val totalParts = endLine - startLine + 1

                for (l in startLine..endLine) {
                    val lStart = maxOf(startChar, fullLayout.getLineStart(l))
                    val lEnd = minOf(endChar, fullLayout.getLineEnd(l))
                    if (lStart >= lEnd) continue

                    val partText = fullString.substring(lStart, lEnd)
                    val subLayout = textMeasurer.measure(
                        text = AnnotatedString(partText),
                        style = LyricTextStyle
                    )

                    val left = fullLayout.getHorizontalPosition(lStart, true)
                    val right = fullLayout.getHorizontalPosition(lEnd, false)
                    val minX = minOf(left, right)
                    val maxX = maxOf(left, right)
                    val top = fullLayout.getLineTop(l)
                    val bottom = fullLayout.getLineBottom(l)

                    parts.add(
                        MeasuredWordPart(
                            word = w,
                            text = partText,
                            topLeft = Offset(minX, top),
                            width = (maxX - minX).coerceAtLeast(1f),
                            height = (bottom - top).coerceAtLeast(1f),
                            subLayout = subLayout,
                            partIndex = l - startLine,
                            totalParts = totalParts
                        )
                    )
                }
            }
            parts
        }

        val layoutHeightDp = with(density) { fullLayout.size.height.toDp() }

        // Cached solid brushes
        val litBrush = remember(onSurfaceColor) { SolidColor(onSurfaceColor) }
        val unlitBrush = remember(aheadColor) { SolidColor(aheadColor) }

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(layoutHeightDp)
                .pointerInput(line, wordRanges, fullLayout) {
                    detectTapGestures { tapOffset ->
                        val charOffset = fullLayout.getOffsetForPosition(tapOffset)
                        val matchedWord = wordRanges.find { charOffset in it.startChar..it.endChar }?.word
                        if (matchedWord != null) {
                            onSeekTo(matchedWord.startMs)
                        } else {
                            onSeekTo(line.timeMs)
                        }
                    }
                }
        ) {
            val currentMs = positionProvider() // Read ONLY in draw phase!

            if (line.isLineTimed || measuredWordParts.isEmpty()) {
                // Line-timed lyrics: highlight whole line with lit color immediately when active
                drawText(textLayoutResult = fullLayout, brush = litBrush)
            } else {
                // Word-timed lyrics: hardware-accelerated 4-stop horizontal gradient sweep per word
                for (part in measuredWordParts) {
                    val word = part.word
                    if (currentMs < word.startMs) {
                        // Future word: unlit / dimmed
                        drawText(
                            textLayoutResult = part.subLayout,
                            topLeft = part.topLeft,
                            brush = unlitBrush
                        )
                    } else if (currentMs >= word.endMs) {
                        // Fully sung word: lit
                        drawText(
                            textLayoutResult = part.subLayout,
                            topLeft = part.topLeft,
                            brush = litBrush
                        )
                    } else {
                        // Actively sung word: 4-stop gradient wipe across word bounds
                        val duration = (word.endMs - word.startMs).coerceAtLeast(1L).toFloat()
                        val elapsed = (currentMs - word.startMs).toFloat()
                        val totalProgress = (elapsed / duration).coerceIn(0f, 1f)
                        val partProgress = if (part.totalParts > 1) {
                            ((totalProgress * part.totalParts) - part.partIndex).coerceIn(0f, 1f)
                        } else {
                            totalProgress
                        }

                        val wiperX = part.width * partProgress
                        val gradientWidth = 24.dp.toPx().coerceAtMost(part.width * 0.4f).coerceAtLeast(4f)
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
                            textLayoutResult = part.subLayout,
                            topLeft = part.topLeft,
                            brush = brush
                        )
                    }
                }
            }
        }
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
