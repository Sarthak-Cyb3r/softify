package com.softify.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlin.math.min

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
