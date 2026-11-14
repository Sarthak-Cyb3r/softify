package com.softify.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.domain.models.Lyrics

@Composable
fun SyncedLyricsView(
    lyrics: Lyrics?,
    activeLineIndex: Int = 2,
    isAppleMusic: Boolean = false,
    onLineClick: (Int) -> Unit = {}
) {
    if (lyrics == null || lyrics.lines.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize().padding(32.dp),
            contentAlignment = androidx.compose.ui.Alignment.Center
        ) {
            Text(
                text = "Looking for synchronized lyrics...",
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 16.sp
            )
        }
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(vertical = 48.dp, horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(28.dp)
    ) {
        itemsIndexed(lyrics.lines) { index, line ->
            val isActive = index == activeLineIndex

            val scale by animateFloatAsState(
                targetValue = if (isActive) (if (isAppleMusic) 1.08f else 1.04f) else 0.96f,
                animationSpec = spring()
            )

            val textColor by animateColorAsState(
                targetValue = when {
                    isActive -> Color.White
                    index < activeLineIndex -> Color.White.copy(alpha = 0.35f)
                    else -> Color.White.copy(alpha = 0.55f)
                }
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .scale(scale)
                    .clickable { onLineClick(index) }
            ) {
                Text(
                    text = line.text,
                    color = textColor,
                    fontSize = if (isAppleMusic) 26.sp else 22.sp,
                    fontWeight = if (isActive) FontWeight.Bold else FontWeight.Medium,
                    lineHeight = if (isAppleMusic) 34.sp else 30.sp
                )

                line.romanizedText?.let { romanized ->
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = romanized,
                        color = textColor.copy(alpha = if (isActive) 0.85f else 0.40f),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Normal
                    )
                }
            }
        }
    }
}
