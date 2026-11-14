package com.softify.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette

@Composable
fun QueueView(
    queue: List<Track>,
    currentTrack: Track?,
    palette: DynamicColorPalette,
    isAppleMusic: Boolean = false,
    onTrackSelect: (Track) -> Unit,
    onRemoveTrack: (Int) -> Unit,
    onClose: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
            .background(if (isAppleMusic) Color(0xFF161618) else palette.surface)
            .padding(20.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Playing Next",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "${queue.size} songs in queue",
                    fontSize = 13.sp,
                    color = if (isAppleMusic) Color.White.copy(alpha = 0.6f) else palette.primary
                )
            }

            IconButton(
                onClick = onClose,
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.12f))
            ) {
                Text(text = "✕", color = Color.White, fontSize = 14.sp)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            itemsIndexed(queue) { index, track ->
                val isCurrent = track.id == currentTrack?.id
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            when {
                                isCurrent && isAppleMusic -> Color.White.copy(alpha = 0.12f)
                                isCurrent -> palette.primaryContainer.copy(alpha = 0.5f)
                                else -> Color.Transparent
                            }
                        )
                        .clickable { onTrackSelect(track) }
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    SoftifyImage(
                        url = track.coverUrl,
                        title = track.title,
                        modifier = Modifier.size(44.dp),
                        cornerRadius = 10.dp
                    )

                    Spacer(modifier = Modifier.width(14.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = track.title,
                            color = if (isCurrent) (if (isAppleMusic) Color.White else palette.primary) else Color.White,
                            fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Medium,
                            fontSize = 15.sp,
                            maxLines = 1
                        )
                        Text(
                            text = track.artist,
                            color = Color.White.copy(alpha = 0.6f),
                            fontSize = 12.sp,
                            maxLines = 1
                        )
                    }

                    if (isCurrent) {
                        Text(
                            text = "NOW PLAYING",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isAppleMusic) Color.White else palette.primary,
                            modifier = Modifier.padding(end = 8.dp)
                        )
                    }

                    IconButton(
                        onClick = { onRemoveTrack(index) },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Text(text = "✕", color = Color.White.copy(alpha = 0.4f), fontSize = 12.sp)
                    }
                }
            }
        }
    }
}
