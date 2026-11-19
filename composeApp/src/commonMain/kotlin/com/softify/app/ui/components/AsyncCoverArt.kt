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
import com.softify.app.util.PlaybackLogger

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
    val imageLoader = remember(context) { CoverArtLoader.getImageLoader(context) }

    val initialFormatted = remember(url, size) { formatCoverUrl(url, size) }
    // Cross-size cache candidate lookup: check if a 1200px or 256px image is ALREADY cached
    val cachedCandidate = remember(url, size) { CoverArtLoader.findCachedCandidate(url, size.targetPx) }
    var activeUrl by remember(initialFormatted, cachedCandidate) { mutableStateOf(cachedCandidate ?: initialFormatted) }
    val isNegCached = remember(activeUrl) { CoverArtLoader.isNegativeCached(activeUrl) }

    Box(
        modifier = modifier
            .clip(shape)
            .background(backgroundColor),
        contentAlignment = Alignment.Center
    ) {
        if (!activeUrl.isNullOrBlank() && !isNegCached) {
            val request = remember(activeUrl) {
                ImageRequest.Builder(context)
                    .data(activeUrl)
                    .memoryCacheKey(activeUrl)
                    .diskCacheKey(activeUrl)
                    .crossfade(false) // Zero crossfade delay for cache hits
                    .build()
            }
            AsyncImage(
                model = request,
                imageLoader = imageLoader,
                contentDescription = contentDescription,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
                onError = {
                    val failedUrl = activeUrl
                    CoverArtLoader.recordNegativeCache(failedUrl)
                    // YouTube 404 fallback chain: maxresdefault -> mqdefault -> raw URL
                    val ytFallback = if (failedUrl != null) videoArtworkFallbackUrl(failedUrl) else null
                    if (ytFallback != null && ytFallback != failedUrl && !CoverArtLoader.isNegativeCached(ytFallback)) {
                        PlaybackLogger.log("SoftifyCoverArt", "YouTube 404 fallback: maxresdefault -> mqdefault: $ytFallback")
                        activeUrl = ytFallback
                    } else if (failedUrl != url && !url.isNullOrBlank() && !CoverArtLoader.isNegativeCached(url)) {
                        PlaybackLogger.log("SoftifyCoverArt", "Falling back from formatted art URL to raw URL: $url")
                        activeUrl = url
                    } else {
                        // Both failed or raw failed -> show solid tonal placeholder
                        activeUrl = null
                    }
                }
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
