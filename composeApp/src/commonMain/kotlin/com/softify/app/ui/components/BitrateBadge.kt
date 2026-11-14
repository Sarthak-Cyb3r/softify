package com.softify.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Minimal, quiet BitrateBadge.
 * Single-line rounded pill without borders or thick colors.
 * Example: "320 kbps AAC" or "129 kbps AAC fallback" (with a small amber dot).
 * Sample rate is optional and only shown when read from the real Media3 player format.
 * Provider IDs and itag details move to the Diagnostics screen only.
 */
@Composable
fun BitrateBadge(
    bitrateKbps: UInt,
    codec: String,
    modifier: Modifier = Modifier,
    isFallback: Boolean = false,
    sampleRateHz: Int? = null,
    enabled: Boolean = true,
    provider: String? = null
) {
    if (!enabled) {
        Box(
            modifier = modifier
                .alpha(0.38f)
                .background(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(12.dp)
                )
                .padding(horizontal = 8.dp, vertical = 3.dp)
        ) {
            Text(
                text = "inactive",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 11.sp,
                fontWeight = FontWeight.Normal
            )
        }
        return
    }

    val sampleRateStr = if (sampleRateHz != null && sampleRateHz > 0) {
        val khz = sampleRateHz / 1000f
        val formatted = if (khz % 1.0f == 0f) "${khz.toInt()}" else ((khz * 10).toInt() / 10f).toString()
        " • $formatted kHz"
    } else {
        ""
    }

    val pillBg = if (isFallback) {
        Color(0xFFF59E0B).copy(alpha = 0.12f)
    } else {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    }

    val textColor = if (isFallback) {
        Color(0xFFD97706)
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    Box(
        modifier = modifier
            .background(color = pillBg, shape = RoundedCornerShape(12.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            if (isFallback) {
                Box(
                    modifier = Modifier
                        .size(5.dp)
                        .background(Color(0xFFF59E0B), CircleShape)
                )
            }

            val codecClean = codec.uppercase()
            val text = if (isFallback) {
                "${bitrateKbps} kbps $codecClean$sampleRateStr fallback"
            } else {
                "${bitrateKbps} kbps $codecClean$sampleRateStr"
            }

            Text(
                text = text,
                color = textColor,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Preview
@Composable
fun BitrateBadgeStandardPreview() {
    BitrateBadge(
        bitrateKbps = 320u,
        codec = "AAC",
        isFallback = false
    )
}

@Preview
@Composable
fun BitrateBadgeFallbackPreview() {
    BitrateBadge(
        bitrateKbps = 129u,
        codec = "AAC",
        isFallback = true
    )
}

@Preview
@Composable
fun BitrateBadgeWithSampleRatePreview() {
    BitrateBadge(
        bitrateKbps = 320u,
        codec = "AAC",
        sampleRateHz = 48000
    )
}

@Preview
@Composable
fun BitrateBadgeInactivePreview() {
    BitrateBadge(
        bitrateKbps = 0u,
        codec = "",
        enabled = false
    )
}
