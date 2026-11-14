package com.softify.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.*

/**
 * Custom Material 3 Expressive Squiggly Waveform Slider.
 * - Played: Sine wave with smoothstep dampening at playhead, traveling phase animated by frame clock.
 * - Paused / Unplayed: Smoothly collapses to flat line.
 * - Scrubbing: Pill thumb stretches with spring physics.
 */
@Composable
fun SquigglySlider(
    value: Float, // 0f..1f
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    onValueChangeFinished: (() -> Unit)? = null,
    isPlaying: Boolean = false,
    isBuffering: Boolean = false,
    enabled: Boolean = true,
    activeColor: Color = MaterialTheme.colorScheme.primary,
    inactiveColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    thumbColor: Color = MaterialTheme.colorScheme.primary,
    trackHeight: Dp = 4.dp,
    waveAmplitude: Dp = 4.dp,
    waveLength: Dp = 32.dp
) {
    var isDragging by remember { mutableStateOf(false) }
    var dragFraction by remember { mutableStateOf(value) }

    LaunchedEffect(value) {
        if (!isDragging) {
            dragFraction = value.coerceIn(0f, 1f)
        }
    }

    // Phase animation driven by frame clock when playing
    val infiniteTransition = rememberInfiniteTransition(label = "SquigglyPhase")
    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "phaseAnim"
    )

    // Smooth amplitude transition between playing and paused
    val targetAmplitude = if (isPlaying && enabled) 1f else 0f
    val amplitudeScale by animateFloatAsState(
        targetValue = targetAmplitude,
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "amplitudeAnim"
    )

    // Buffering pulse
    val bufferingScale by infiniteTransition.animateFloat(
        initialValue = 0.5f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "bufferingPulse"
    )

    // Spring stretched pill thumb
    val thumbWidth by animateDpAsState(
        targetValue = if (isDragging) 14.dp else 6.dp,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "thumbWidthAnim"
    )
    val thumbHeight by animateDpAsState(
        targetValue = if (isDragging) 24.dp else 16.dp,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "thumbHeightAnim"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectTapGestures { offset ->
                    val pad = 16.dp.toPx()
                    val totalWidth = size.width - 2 * pad
                    if (totalWidth > 0) {
                        val fraction = ((offset.x - pad) / totalWidth).coerceIn(0f, 1f)
                        dragFraction = fraction
                        onValueChange(fraction)
                        onValueChangeFinished?.invoke()
                    }
                }
            }
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectDragGestures(
                    onDragStart = { offset ->
                        isDragging = true
                        val pad = 16.dp.toPx()
                        val totalWidth = size.width - 2 * pad
                        if (totalWidth > 0) {
                            val fraction = ((offset.x - pad) / totalWidth).coerceIn(0f, 1f)
                            dragFraction = fraction
                            onValueChange(fraction)
                        }
                    },
                    onDragEnd = {
                        isDragging = false
                        onValueChange(dragFraction)
                        onValueChangeFinished?.invoke()
                    },
                    onDragCancel = {
                        isDragging = false
                        dragFraction = value
                    },
                    onDrag = { change, _ ->
                        change.consume()
                        val pad = 16.dp.toPx()
                        val totalWidth = size.width - 2 * pad
                        if (totalWidth > 0) {
                            val fraction = ((change.position.x - pad) / totalWidth).coerceIn(0f, 1f)
                            dragFraction = fraction
                            onValueChange(fraction)
                        }
                    }
                )
            }
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val pad = 16.dp.toPx()
            val totalWidth = size.width - 2 * pad
            if (totalWidth <= 0) return@Canvas

            val cy = size.height / 2f
            val fraction = if (isDragging) dragFraction else value.coerceIn(0f, 1f)
            val headX = pad + fraction * totalWidth
            val strokeWidthPx = trackHeight.toPx()
            val maxAmpPx = waveAmplitude.toPx() * amplitudeScale * (if (isBuffering) bufferingScale else 1f)
            val waveLenPx = waveLength.toPx()

            // 1. Draw Played Section (Squiggly Sine Wave with Smoothstep Dampening)
            val playedPath = Path()
            if (headX > pad) {
                playedPath.moveTo(pad, cy)
                val step = 2f
                var x = pad
                while (x <= headX) {
                    val distFromHead = headX - x
                    val distFromStart = x - pad
                    // Smoothstep dampening at both ends
                    val taperHead = (distFromHead / 24.dp.toPx()).coerceIn(0f, 1f)
                    val taperStart = (distFromStart / 16.dp.toPx()).coerceIn(0f, 1f)
                    val smoothTaper = (3 * taperHead.pow(2) - 2 * taperHead.pow(3)) *
                            (3 * taperStart.pow(2) - 2 * taperStart.pow(3))

                    val y = cy + maxAmpPx * smoothTaper * sin((2f * PI.toFloat() * (x - pad) / waveLenPx) - phase)
                    playedPath.lineTo(x, y)
                    x += step
                }
                playedPath.lineTo(headX, cy)

                drawPath(
                    path = playedPath,
                    color = if (enabled) activeColor else activeColor.copy(alpha = 0.38f),
                    style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round)
                )
            }

            // 2. Draw Unplayed Section (Flat Straight Line)
            if (headX < pad + totalWidth) {
                drawLine(
                    color = if (enabled) inactiveColor else inactiveColor.copy(alpha = 0.38f),
                    start = Offset(headX, cy),
                    end = Offset(pad + totalWidth, cy),
                    strokeWidth = strokeWidthPx,
                    cap = StrokeCap.Round
                )
            }

            // 3. Draw Pill Thumb
            val tw = thumbWidth.toPx()
            val th = thumbHeight.toPx()
            val cornerRadius = CornerRadius(tw / 2f, tw / 2f)

            drawRoundRect(
                color = if (enabled) thumbColor else thumbColor.copy(alpha = 0.38f),
                topLeft = Offset(headX - tw / 2f, cy - th / 2f),
                size = Size(tw, th),
                cornerRadius = cornerRadius
            )
        }
    }
}

@Preview
@Composable
fun PreviewSquigglySliderPlaying() {
    SquigglySlider(
        value = 0.45f,
        onValueChange = {},
        isPlaying = true
    )
}

@Preview
@Composable
fun PreviewSquigglySliderPaused() {
    SquigglySlider(
        value = 0.45f,
        onValueChange = {},
        isPlaying = false
    )
}

@Preview
@Composable
fun PreviewSquigglySliderBuffering() {
    SquigglySlider(
        value = 0.65f,
        onValueChange = {},
        isPlaying = true,
        isBuffering = true
    )
}
