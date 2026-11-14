package com.softify.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Material 3 Expressive Bitrate & Audio Fidelity Badge.
 * ONLY displays real measured telemetry (provider, kbps, codec, fallback indicator).
 * Sample rate is strictly rendered only when available from player format (never hardcoded).
 */
@Composable
fun BitrateBadge(
    provider: String,
    bitrateKbps: UInt,
    codec: String,
    modifier: Modifier = Modifier,
    isFallback: Boolean = false,
    sampleRateHz: Int? = null,
    enabled: Boolean = true
) {
    val isStudioMaster = bitrateKbps >= 320u && !isFallback

    val (bgColor, borderColor, accentColor, labelText) = when {
        !enabled -> Quad(Color(0xFF1E1E28), Color(0xFF333344), Color.Gray, "INACTIVE")
        isFallback -> Quad(Color(0xFF2E1A05), Color(0xFFF59E0B), Color(0xFFFBBF24), "FALLBACK")
        isStudioMaster -> Quad(Color(0xFF032212), Color(0xFF10B981), Color(0xFF34D399), "STUDIO MASTER")
        else -> Quad(Color(0xFF131B2E), Color(0xFF3B82F6), Color(0xFF60A5FA), "HIGH FIDELITY")
    }

    val sampleRateStr = if (sampleRateHz != null && sampleRateHz > 0) {
        val khz = sampleRateHz / 1000f
        " • ${if (khz % 1.0f == 0f) "${khz.toInt()}" else "%.1f".format(khz)} kHz"
    } else {
        ""
    }

    Box(
        modifier = modifier
            .background(bgColor, RoundedCornerShape(10.dp))
            .border(1.dp, borderColor.copy(alpha = if (enabled) 0.8f else 0.3f), RoundedCornerShape(10.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // Pulse dot
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(accentColor, RoundedCornerShape(3.dp))
            )

            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "${bitrateKbps} kbps",
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                    Text(
                        text = "• ${codec.uppercase()}$sampleRateStr",
                        color = Color.LightGray,
                        fontSize = 10.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = labelText,
                        color = accentColor,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.ExtraBold,
                        letterSpacing = 0.5.sp
                    )
                    Text(
                        text = "(${provider.replace("youtube_innertube_", "yt-")})",
                        color = Color.Gray,
                        fontSize = 8.sp,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

private data class Quad<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)

@Preview
@Composable
fun PreviewBitrateBadgeStudioMaster() {
    BitrateBadge(
        provider = "jiosaavn_direct_master",
        bitrateKbps = 320u,
        codec = "aac",
        isFallback = false,
        sampleRateHz = 48000
    )
}

@Preview
@Composable
fun PreviewBitrateBadgeStudioNoSampleRate() {
    BitrateBadge(
        provider = "jiosaavn_direct_master",
        bitrateKbps = 320u,
        codec = "aac",
        isFallback = false,
        sampleRateHz = null
    )
}

@Preview
@Composable
fun PreviewBitrateBadgeFallback() {
    BitrateBadge(
        provider = "youtube_innertube_visionos",
        bitrateKbps = 129u,
        codec = "aac",
        isFallback = true,
        sampleRateHz = 44100
    )
}

@Preview
@Composable
fun PreviewBitrateBadgeDisabled() {
    BitrateBadge(
        provider = "unknown",
        bitrateKbps = 0u,
        codec = "none",
        enabled = false
    )
}
