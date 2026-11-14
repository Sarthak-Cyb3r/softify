package com.softify.app.ui.metrolist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.data.PlayerManager
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette

@Composable
fun MetrolistSearchScreen(
    palette: DynamicColorPalette,
    onTrackSelect: (Track) -> Unit
) {
    val searchQuery by PlayerManager.searchQuery.collectAsState()
    val searchResults by PlayerManager.searchResults.collectAsState()
    val currentTrack by PlayerManager.currentTrack.collectAsState()

    val moodChips = listOf("Energize", "Relax", "Workout", "Commute", "Focus", "Party", "Romance")

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(16.dp))

            // Pill Search Bar
            Surface(
                shape = RoundedCornerShape(100.dp),
                color = palette.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 18.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "🔍", fontSize = 18.sp)
                    Spacer(modifier = Modifier.width(12.dp))
                    TextField(
                        value = searchQuery,
                        onValueChange = { PlayerManager.search(it) },
                        placeholder = {
                            Text(
                                text = "Search songs, artists, albums...",
                                color = Color.White.copy(alpha = 0.5f),
                                fontSize = 14.sp
                            )
                        },
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent,
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent
                        ),
                        singleLine = true,
                        modifier = Modifier.weight(1f)
                    )
                    if (searchQuery.isNotEmpty()) {
                        IconButton(
                            onClick = { PlayerManager.search("") },
                            modifier = Modifier.size(28.dp)
                        ) {
                            Text(text = "✕", color = Color.White.copy(alpha = 0.6f))
                        }
                    }
                }
            }
        }

        // Quick Category Chips
        item {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(moodChips) { mood ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(100.dp))
                            .background(palette.primaryContainer.copy(alpha = 0.6f))
                            .clickable { PlayerManager.search(mood) }
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        Text(
                            text = mood,
                            color = palette.primary,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }

        item {
            Text(
                text = if (searchQuery.isEmpty()) "Browse All" else "Search Results",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        items(searchResults) { track ->
            MetrolistTrackRow(
                track = track,
                isSelected = track.id == currentTrack?.id,
                palette = palette,
                onClick = { onTrackSelect(track) }
            )
        }

        item {
            Spacer(modifier = Modifier.height(110.dp))
        }
    }
}
