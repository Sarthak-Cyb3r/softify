package com.softify.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.theme.ThemeMode

@Composable
fun SegmentedThemeToggle(
    themeMode: ThemeMode,
    accentColor: Color,
    onToggle: (ThemeMode) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(100.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .padding(4.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            val isMetrolist = themeMode == ThemeMode.METROLIST

            val metroBg by animateColorAsState(
                if (isMetrolist) accentColor else Color.Transparent
            )
            val metroText by animateColorAsState(
                if (isMetrolist) Color.White else Color.White.copy(alpha = 0.6f)
            )

            val appleBg by animateColorAsState(
                if (!isMetrolist) Color(0xFFFA243C) else Color.Transparent
            )
            val appleText by animateColorAsState(
                if (!isMetrolist) Color.White else Color.White.copy(alpha = 0.6f)
            )

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(100.dp))
                    .background(metroBg)
                    .clickable { onToggle(ThemeMode.METROLIST) }
                    .padding(horizontal = 14.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Metrolist",
                    fontSize = 12.sp,
                    fontWeight = if (isMetrolist) FontWeight.Bold else FontWeight.Medium,
                    color = metroText
                )
            }

            Spacer(modifier = Modifier.width(2.dp))

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(100.dp))
                    .background(appleBg)
                    .clickable { onToggle(ThemeMode.APPLE_MUSIC) }
                    .padding(horizontal = 14.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Apple Music",
                    fontSize = 12.sp,
                    fontWeight = if (!isMetrolist) FontWeight.Bold else FontWeight.Medium,
                    color = appleText
                )
            }
        }
    }
}
