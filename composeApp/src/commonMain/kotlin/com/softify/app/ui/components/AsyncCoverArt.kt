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
    backgroundColor: Color = Color(0xFF242424), // Solid tonal placeholder
    screen: ScreenType = ScreenType.HOME,
    trackId: String? = null
) {
    val context = LocalPlatformContext.current
    val imageLoader = remember(context) { CoverArtLoader.getImageLoader(context) }

    // Resolve initial URL: if null/empty, check if track has a deterministic YouTube video ID
    val resolvedUrl = remember(url, trackId) {
        if (!url.isNullOrBlank()) {
            url
        } else if (trackId != null) {
            val vid = when {
                trackId.startsWith("yt_") -> trackId.removePrefix("yt_")
                trackId.startsWith("ytm_") -> trackId.removePrefix("ytm_")
                trackId.length == 11 -> trackId
                else -> null
            }
            if (vid != null) "https://i.ytimg.com/vi/$vid/mqdefault.jpg" else null
        } else {
            null
        }
    }

    LaunchedEffect(resolvedUrl, screen, trackId) {
        if (resolvedUrl.isNullOrBlank()) {
            PlaybackLogger.log("SoftifyCoverArt", "EMPTY_URL: screen=${screen.displayName}, trackId=$trackId")
            CoverTelemetry.recordNoUrl(screen)
        }
    }

    val initialFormatted = remember(resolvedUrl, size) { formatCoverUrl(resolvedUrl, size) }
    // Cross-size cache candidate lookup: check if a 1200px or 256px image is ALREADY cached
    val cachedCandidate = remember(resolvedUrl, size) { CoverArtLoader.findCachedCandidate(resolvedUrl, size.targetPx) }
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
                onSuccess = {
                    CoverTelemetry.recordOk(screen)
                },
                onError = { errorResult ->
                    val failedUrl = activeUrl
                    val host = failedUrl?.let { u ->
                        u.substringAfter("://", missingDelimiterValue = "").substringBefore('/').substringBefore(':')
                    } ?: "unknown"

                    var httpStatus: Int? = null
                    var cause: Throwable? = errorResult.result.throwable
                    while (cause != null) {
                        val msg = cause.message ?: ""
                        if (msg.contains("404")) {
                            httpStatus = 404
                            break
                        }
                        cause = cause.cause
                    }

                    val reason = errorResult.result.throwable.message ?: "Unknown image load error"
                    PlaybackLogger.log(
                        "SoftifyCoverArt",
                        "FAILED: url=$failedUrl, host=$host, status=$httpStatus, reason=$reason"
                    )
                    CoverTelemetry.recordFailed(screen, failedUrl ?: "null", host, httpStatus, reason)

                    CoverArtLoader.recordNegativeCache(failedUrl)
                    // YouTube 404 fallback chain: maxresdefault -> mqdefault -> raw URL -> solid tonal placeholder
                    val ytFallback = if (failedUrl != null) videoArtworkFallbackUrl(failedUrl) else null
                    if (ytFallback != null && ytFallback != failedUrl && !CoverArtLoader.isNegativeCached(ytFallback)) {
                        PlaybackLogger.log("SoftifyCoverArt", "YouTube 404 fallback: maxresdefault -> mqdefault: $ytFallback")
                        activeUrl = ytFallback
                    } else if (failedUrl != resolvedUrl && !resolvedUrl.isNullOrBlank() && !CoverArtLoader.isNegativeCached(resolvedUrl)) {
                        PlaybackLogger.log("SoftifyCoverArt", "Falling back from formatted art URL to raw URL: $resolvedUrl")
                        activeUrl = resolvedUrl
                    } else {
                        // Both failed or raw failed -> show deterministic solid tonal placeholder
                        activeUrl = null
                    }
                }
            )
        } else {
            // Deterministic solid tonal placeholder: subtle note icon on dark surface (never white card, never broken image icon)
            Icon(
                imageVector = Icons.Filled.MusicNote,
                contentDescription = contentDescription,
                modifier = Modifier.size(24.dp),
                tint = fallbackIconColor.copy(alpha = 0.5f)
            )
        }
    }
}
