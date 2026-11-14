package com.softify.app.ui.applemusic

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.data.PlayerManager
import com.softify.app.domain.models.Track
import com.softify.app.theme.DynamicColorPalette
import com.softify.app.theme.GlassmorphicContainer
import com.softify.app.ui.components.SoftifyIcons

@Composable
fun AppleMusicSearchScreen(
    palette: DynamicColorPalette,
    onTrackSelect: (Track) -> Unit
) {
    val searchQuery by PlayerManager.searchQuery.collectAsState()
    val searchResults by PlayerManager.searchResults.collectAsState()
    val currentTrack by PlayerManager.currentTrack.collectAsState()

    val categories = listOf(
        Pair("Spatial Audio", listOf(Color(0xFF7C3AED), Color(0xFF2563EB))),
        Pair("Pop", listOf(Color(0xFFEC4899), Color(0xFFF43F5E))),
        Pair("Hip-Hop", listOf(Color(0xFFD97706), Color(0xFFDC2626))),
        Pair("Bollywood", listOf(Color(0xFFEA580C), Color(0xFFF59E0B))),
        Pair("Dance / Electronic", listOf(Color(0xFF059669), Color(0xFF06B6D4))),
        Pair("Rock", listOf(Color(0xFFB91C1C), Color(0xFF4B5563))),
        Pair("Indie & Alternative", listOf(Color(0xFF4F46E5), Color(0xFF9333EA))),
        Pair("Chill & Lo-Fi", listOf(Color(0xFF0284C7), Color(0xFF38BDF8)))
    )

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                text = "Search",
                fontSize = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(14.dp))

            // Apple Music Translucent Search Bar
            GlassmorphicContainer(
                modifier = Modifier.fillMaxWidth(),
                cornerRadius = 14
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = SoftifyIcons.Search,
                        contentDescription = "Search",
                        tint = Color.White.copy(alpha = 0.5f),
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    TextField(
                        value = searchQuery,
                        onValueChange = { PlayerManager.search(it) },
                        placeholder = {
                            Text(
                                text = "Artists, Songs, Lyrics, and More",
                                color = Color.White.copy(alpha = 0.5f),
                                fontSize = 15.sp
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
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = SoftifyIcons.Close,
                                contentDescription = "Clear",
                                tint = Color.White.copy(alpha = 0.6f),
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }
        }

        if (searchQuery.isEmpty()) {
            item {
                Text(
                    text = "Browse Categories",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            items(categories.chunked(2)) { pair ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    pair.forEach { (name, colors) ->
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(110.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(Brush.linearGradient(colors))
                                .clickable { PlayerManager.search(name) }
                                .padding(16.dp),
                            contentAlignment = Alignment.BottomStart
                        ) {
                            Text(
                                text = name,
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                        }
                    }
                }
            }
        } else {
            item {
                Text(
                    text = "Top Results",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            items(searchResults) { track ->
                AppleMusicTrackRow(
                    track = track,
                    isSelected = track.id == currentTrack?.id,
                    onClick = { onTrackSelect(track) }
                )
            }
        }

        item {
            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}
