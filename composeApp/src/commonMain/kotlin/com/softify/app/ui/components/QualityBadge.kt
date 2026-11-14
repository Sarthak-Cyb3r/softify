package com.softify.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uniffi.softify_core.StreamInfo

@Composable
fun QualityBadge(
    streamInfo: StreamInfo?,
    modifier: Modifier = Modifier
) {
    if (streamInfo == null) return

    val isMaster = streamInfo.bitrateKbps >= 320u && streamInfo.isRequestedQuality
    val badgeBg = if (isMaster) Color(0xFF1B382B) else Color(0xFF382E1B)
    val badgeBorder = if (isMaster) Color(0xFF34D399) else Color(0xFFFBBF24)
    val textColor = if (isMaster) Color(0xFF6EE7B7) else Color(0xFFFDE68A)

    val label = if (isMaster) {
        "${streamInfo.bitrateKbps} kbps ${streamInfo.codec.uppercase()} • STUDIO MASTER"
    } else {
        "${streamInfo.bitrateKbps} kbps ${streamInfo.codec.uppercase()} • DOWNGRADED"
    }

    Box(
        modifier = modifier
            .background(badgeBg, RoundedCornerShape(6.dp))
            .border(1.dp, badgeBorder.copy(alpha = 0.6f), RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(badgeBorder, RoundedCornerShape(3.dp))
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = label,
                color = textColor,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp
            )
        }
    }
}
