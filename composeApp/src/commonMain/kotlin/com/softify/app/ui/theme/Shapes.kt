package com.softify.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlin.math.*

/**
 * Parametric Scalloped Multi-Lobe Badge Shape.
 * Implements a smooth trochoid/rosette bezier curve for badges, avatars, and icons.
 * Formula: r(θ) = R * (1 - amplitude * cos(numLobes * θ))
 */
class ScallopedBadgeShape(
    private val numLobes: Int = 12,
    private val amplitude: Float = 0.08f
) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density
    ): Outline {
        val path = Path()
        val centerX = size.width / 2f
        val centerY = size.height / 2f
        val baseRadius = min(centerX, centerY)

        val steps = numLobes * 16
        for (i in 0..steps) {
            val theta = (i.toFloat() / steps.toFloat()) * (2f * PI.toFloat())
            val r = baseRadius * (1f - amplitude * cos(numLobes * theta))
            val x = centerX + r * cos(theta)
            val y = centerY + r * sin(theta)

            if (i == 0) {
                path.moveTo(x, y)
            } else {
                path.lineTo(x, y)
            }
        }
        path.close()
        return Outline.Generic(path)
    }
}

/**
 * Continuous curvature Squircle Shape (superellipse-style smooth corners).
 */
class SquircleShape(private val cornerRadius: Dp = 16.dp) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density
    ): Outline {
        val radiusPx = with(density) { cornerRadius.toPx() }.coerceAtMost(min(size.width, size.height) / 2f)
        val path = Path()
        val w = size.width
        val h = size.height

        // Continuous curvature bezier approximation
        val c = radiusPx * 0.55f // cubic handle offset

        path.moveTo(radiusPx, 0f)
        path.lineTo(w - radiusPx, 0f)
        path.cubicTo(w - radiusPx + c, 0f, w, radiusPx - c, w, radiusPx)
        path.lineTo(w, h - radiusPx)
        path.cubicTo(w, h - radiusPx + c, w - radiusPx + c, h, w - radiusPx, h)
        path.lineTo(radiusPx, h)
        path.cubicTo(radiusPx - c, h, 0f, h - radiusPx + c, 0f, h - radiusPx)
        path.lineTo(0f, radiusPx)
        path.cubicTo(0f, radiusPx - c, radiusPx - c, 0f, radiusPx, 0f)
        path.close()

        return Outline.Generic(path)
    }
}

val ExpressiveShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(32.dp)
)
