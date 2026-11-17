package com.softify.app.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material3.Icon
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.softify.app.ui.theme.SquircleShape

expect suspend fun loadNetworkImageBitmap(url: String): ImageBitmap?

private val imageMemoryCache = mutableMapOf<String, ImageBitmap>()

@Composable
fun AsyncCoverArt(
    url: String?,
    modifier: Modifier = Modifier,
    shape: Shape = SquircleShape(12.dp),
    contentDescription: String? = "Cover Art",
    fallbackIconColor: Color = Color.Gray,
    backgroundColor: Color = Color(0xFF262626)
) {
    var bitmap by remember(url) { mutableStateOf(url?.let { imageMemoryCache[it] }) }

    LaunchedEffect(url) {
        if (url != null && bitmap == null) {
            val loaded = loadNetworkImageBitmap(url)
            if (loaded != null) {
                imageMemoryCache[url] = loaded
                bitmap = loaded
            }
        }
    }

    Box(
        modifier = modifier
            .clip(shape)
            .background(backgroundColor),
        contentAlignment = Alignment.Center
    ) {
        val currentBitmap = bitmap
        if (currentBitmap != null) {
            Image(
                bitmap = currentBitmap,
                contentDescription = contentDescription,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        } else {
            Icon(
                imageVector = Icons.Filled.MusicNote,
                contentDescription = contentDescription,
                modifier = Modifier.size(24.dp),
                tint = fallbackIconColor
            )
        }
    }
}
