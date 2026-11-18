package com.softify.app.ui.components

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
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import coil3.compose.LocalPlatformContext
import coil3.request.ImageRequest
import coil3.request.crossfade
import com.softify.app.ui.theme.SquircleShape

@Composable
fun AsyncCoverArt(
    url: String?,
    modifier: Modifier = Modifier,
    size: CoverSize = CoverSize.THUMBNAIL,
    shape: Shape = SquircleShape(12.dp),
    contentDescription: String? = "Cover Art",
    fallbackIconColor: Color = Color.Gray,
    backgroundColor: Color = Color(0xFF242424) // Solid tonal placeholder
) {
    val context = LocalPlatformContext.current
    val formattedUrl = remember(url, size) { formatCoverUrl(url, size) }
    val imageLoader = remember(context) { CoverArtLoader.getImageLoader(context) }

    Box(
        modifier = modifier
            .clip(shape)
            .background(backgroundColor),
        contentAlignment = Alignment.Center
    ) {
        if (!formattedUrl.isNullOrBlank()) {
            val request = remember(formattedUrl) {
                ImageRequest.Builder(context)
                    .data(formattedUrl)
                    .memoryCacheKey(formattedUrl)
                    .diskCacheKey(formattedUrl)
                    .crossfade(false) // Zero crossfade delay for cache hits
                    .build()
            }
            AsyncImage(
                model = request,
                imageLoader = imageLoader,
                contentDescription = contentDescription,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        } else {
            Icon(
                imageVector = Icons.Filled.MusicNote,
                contentDescription = contentDescription,
                modifier = Modifier.size(24.dp),
                tint = fallbackIconColor.copy(alpha = 0.5f)
            )
        }
    }
}
