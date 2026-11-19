package com.softify.app.ui.components

import coil3.EventListener
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.decode.DataSource
import coil3.disk.DiskCache
import coil3.memory.MemoryCache
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import coil3.request.ErrorResult
import coil3.request.ImageRequest
import coil3.request.SuccessResult
import coil3.request.crossfade
import com.softify.app.util.PlaybackLogger
import okhttp3.Dispatcher
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okio.Path
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Platform-specific cache directory for 250 MB disk cache.
 */
expect fun getCacheDirectory(context: PlatformContext): Path

/**
 * Discrete sizing buckets matching Google CDN and YouTube image server targets:
 * - THUMBNAIL (256px): List rows, search results, library (<=256)
 * - SHELF (544px): Home shelves, grid cards (257-544)
 * - FULL (1200px): Now Playing screen, MiniPlayer (545-1200)
 * - MAX (2400px): Fullscreen artwork, tablet (>1200)
 */
enum class CoverSize(val targetPx: Int) {
    THUMBNAIL(256),
    SHELF(544),
    FULL(1200),
    MAX(2400);

    companion object {
        fun fromPx(px: Int): CoverSize = when {
            px <= 256 -> THUMBNAIL
            px <= 544 -> SHELF
            px <= 1200 -> FULL
            else -> MAX
        }
    }
}

private val GoogleArtworkSizeSuffix = Regex("=(?:s(\\d+)|w(\\d+)(?:-[^-?#=]+)*-h\\d+)([^?#]*)")
private val YouTubeVideoArtworkPath =
    Regex("(/vi(?:_webp)?/[^/?#]+/)(mqdefault|hqdefault|sddefault|hq720|maxresdefault)(\\.(?:jpg|webp))(?=[?#]|$)")

/**
 * Transforms artwork URL into discrete bucketed resolution:
 * - Google CDN: rewrites `=w...-h...` or `=s...` into discrete buckets (256, 544, 1200, 2400)
 * - YouTube: `mqdefault.jpg` (<=320px) vs `maxresdefault.jpg` (>320px, crisp without letterbox bars)
 * - Saavn CDN: preserved untouched to avoid 404s
 */
fun bucketedArtworkUrl(url: String, resolvedSizePx: Int): String {
    val host = url
        .substringAfter("://", missingDelimiterValue = "")
        .substringBefore('/')
        .substringBefore(':')
        .lowercase()

    val isGoogleArtworkHost = host.endsWith(".googleusercontent.com") || host.endsWith(".ggpht.com")
    val isYouTubeArtworkHost = host == "i.ytimg.com" || host.endsWith(".ytimg.com")

    if (!isGoogleArtworkHost && !isYouTubeArtworkHost) return url

    val bucketPx = when {
        resolvedSizePx <= 256 -> 256
        resolvedSizePx <= 544 -> 544
        resolvedSizePx <= 1200 -> 1200
        else -> 2400
    }

    // YouTube CDN
    val sourcePath = url.substringBefore('#').substringBefore('?')
    val videoPath = YouTubeVideoArtworkPath.find(sourcePath).takeIf { isYouTubeArtworkHost }
    if (videoPath != null) {
        val fragment = url.substringAfter('#', missingDelimiterValue = "")
        val source = sourcePath + fragment.takeIf { it.isNotEmpty() }?.let { "#$it" }.orEmpty()
        return if (bucketPx > 320) {
            source.replaceRange(videoPath.range, "${videoPath.groupValues[1]}maxresdefault${videoPath.groupValues[3]}")
        } else {
            source.replaceRange(videoPath.range, "${videoPath.groupValues[1]}mqdefault${videoPath.groupValues[3]}")
        }
    }

    // Google CDN
    if (GoogleArtworkSizeSuffix.containsMatchIn(url)) {
        return url.replace(GoogleArtworkSizeSuffix) { match ->
            val suffix = match.groupValues[3]
            val wasWidthHeight = match.groupValues[2].isNotEmpty()
            val size = if (wasWidthHeight || "s" in suffix.split('-')) "w$bucketPx-h$bucketPx" else "s$bucketPx"
            "=$size$suffix"
        }
    }

    if (!isGoogleArtworkHost) return url
    val suffixIndex = url.indexOfAny(charArrayOf('?', '#')).takeIf { it >= 0 } ?: url.length
    return url.substring(0, suffixIndex) + "=s$bucketPx" + url.substring(suffixIndex)
}

/**
 * YouTube 404 fallback chain: if maxresdefault 404s, fall back to mqdefault (320x180 bar-free).
 */
fun videoArtworkFallbackUrl(url: String): String? {
    val host = url
        .substringAfter("://", missingDelimiterValue = "")
        .substringBefore('/')
        .substringBefore(':')
        .lowercase()
    if (host != "i.ytimg.com" && !host.endsWith(".ytimg.com")) return null
    val path = YouTubeVideoArtworkPath.find(url.substringBefore('#').substringBefore('?')) ?: return null
    if (path.groupValues[2] != "maxresdefault") return null
    return url.replaceRange(path.range, "${path.groupValues[1]}mqdefault${path.groupValues[3]}")
}

/**
 * Returns candidate URLs for cross-size cache lookup ordered by preference.
 */
fun artworkCacheCandidates(url: String, resolvedSizePx: Int): List<String> {
    val requested = bucketedArtworkUrl(url, resolvedSizePx)
    val buckets = listOf(256, 544, 1200, 2400)
    val remaining = buckets.filter { it != resolvedSizePx }
        .sortedBy { if (it > resolvedSizePx) it - resolvedSizePx else (resolvedSizePx - it) * 2 }
        .map { bucketedArtworkUrl(url, it) }
    return (listOf(requested) + remaining).distinct()
}

/**
 * Converts cover URL into size-appropriate thumbnail URL using discrete resolution buckets.
 */
fun formatCoverUrl(url: String?, size: CoverSize): String? {
    if (url.isNullOrBlank()) return null
    return bucketedArtworkUrl(url, size.targetPx)
}

/**
 * Coil event listener logging art load times and cache hit/miss status in debug builds.
 */
class CoverArtEventListener : EventListener() {
    private var startTime = 0L

    companion object {
        val totalRequests = AtomicInteger(0)
        val memoryHits = AtomicInteger(0)
        val diskHits = AtomicInteger(0)
        val networkMisses = AtomicInteger(0)

        val memoryDurationSum = AtomicLong(0)
        val diskDurationSum = AtomicLong(0)
        val networkDurationSum = AtomicLong(0)

        fun getStatsSummary(): String {
            val total = totalRequests.get().coerceAtLeast(1)
            val memCount = memoryHits.get()
            val diskCount = diskHits.get()
            val netCount = networkMisses.get()

            val avgMem = if (memCount > 0) memoryDurationSum.get() / memCount else 0L
            val avgDisk = if (diskCount > 0) diskDurationSum.get() / diskCount else 0L
            val avgNet = if (netCount > 0) networkDurationSum.get() / netCount else 0L

            return "Total: $total | Memory Hits: $memCount (avg ${avgMem}ms) | Disk Hits: $diskCount (avg ${avgDisk}ms) | Network Misses: $netCount (avg ${avgNet}ms)"
        }
    }

    override fun onStart(request: ImageRequest) {
        startTime = System.currentTimeMillis()
        totalRequests.incrementAndGet()
    }

    override fun onSuccess(request: ImageRequest, result: SuccessResult) {
        val durationMs = (System.currentTimeMillis() - startTime).coerceAtLeast(0L)
        val source = result.dataSource
        val hitOrMiss = when (source) {
            DataSource.MEMORY -> {
                memoryHits.incrementAndGet()
                memoryDurationSum.addAndGet(durationMs)
                "MEMORY_HIT"
            }
            DataSource.DISK -> {
                diskHits.incrementAndGet()
                diskDurationSum.addAndGet(durationMs)
                "DISK_HIT"
            }
            DataSource.NETWORK -> {
                networkMisses.incrementAndGet()
                networkDurationSum.addAndGet(durationMs)
                "NETWORK_MISS"
            }
            else -> "OTHER"
        }

        PlaybackLogger.log(
            "SoftifyCoverArt",
            "Art load [$hitOrMiss]: duration=${durationMs}ms, source=$source, url=${request.data}"
        )
    }

    override fun onError(request: ImageRequest, result: ErrorResult) {
        val durationMs = (System.currentTimeMillis() - startTime).coerceAtLeast(0L)
        PlaybackLogger.log(
            "SoftifyCoverArt",
            "Art load [FAILED]: duration=${durationMs}ms, error=${result.throwable.message}, url=${request.data}"
        )
    }
}

/**
 * Transparent Coil interceptor implementing the YouTube 404 fallback chain:
 * If maxresdefault.jpg fails (HTTP 404), seamlessly falls back to mqdefault.jpg.
 */
class VideoArtworkFallbackInterceptor : coil3.intercept.Interceptor {
    override suspend fun intercept(chain: coil3.intercept.Interceptor.Chain): coil3.request.ImageResult {
        val result = chain.proceed()
        if (result is coil3.request.ErrorResult) {
            val url = chain.request.data as? String
            if (url != null) {
                val fallback = videoArtworkFallbackUrl(url)
                if (fallback != null && fallback != url && !CoverArtLoader.isNegativeCached(fallback)) {
                    val fallbackRequest = chain.request.newBuilder()
                        .data(fallback)
                        .memoryCacheKey(fallback)
                        .diskCacheKey(fallback)
                        .build()
                    val fallbackResult = chain.withRequest(fallbackRequest).proceed()
                    if (fallbackResult is coil3.request.SuccessResult) {
                        return fallbackResult
                    }
                }
            }
        }
        return result
    }
}

/**
 * Singleton CoverArtLoader configuring Coil with:
 * - 25% RAM memory cache
 * - 250 MB disk cache
 * - Shared OkHttpClient with HTTP/2 and 64 max concurrent / 24 per host dispatcher
 * - Negative caching for HTTP 404 URLs
 * - Background prefetching prioritizing visible UI requests
 * - Cross-size cache candidate lookup across discrete resolution buckets (256, 544, 1200, 2400)
 */
object CoverArtLoader {
    private var loaderInstance: ImageLoader? = null
    private var storedContext: PlatformContext? = null

    // Session negative cache: maps 404 URLs to timestamp to prevent retrying dead URLs
    val negativeCache = ConcurrentHashMap<String, Long>()

    fun isNegativeCached(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        return negativeCache.containsKey(url)
    }

    fun recordNegativeCache(url: String?) {
        if (url.isNullOrBlank()) return
        negativeCache[url] = System.currentTimeMillis()
        PlaybackLogger.log("SoftifyCoverArt", "Recorded negative cache (HTTP 404): $url")
    }

    /**
     * Cross-size cache candidate lookup:
     * Checks if a different resolution bucket (e.g. 1200px or 256px) for the same track
     * is already present in Coil's memory or disk cache.
     */
    fun findCachedCandidate(url: String?, resolvedSizePx: Int): String? {
        if (url.isNullOrBlank()) return null
        val loader = loaderInstance ?: return null
        val candidates = artworkCacheCandidates(url, resolvedSizePx)

        // 1. Memory cache check
        val memCache = loader.memoryCache
        if (memCache != null) {
            for (candidate in candidates) {
                if (memCache[MemoryCache.Key(candidate)] != null) {
                    return candidate
                }
            }
        }

        // 2. Disk cache check
        val diskCache = loader.diskCache
        if (diskCache != null) {
            for (candidate in candidates) {
                try {
                    val snapshot = diskCache.openSnapshot(candidate)
                    if (snapshot != null) {
                        snapshot.close()
                        return candidate
                    }
                } catch (_: Throwable) {}
            }
        }

        return null
    }

    // High throughput OkHttp dispatcher: 64 concurrent requests, 24 per host
    val dispatcher = Dispatcher().apply {
        maxRequests = 64
        maxRequestsPerHost = 24
    }

    val sharedOkHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .dispatcher(dispatcher)
            .protocols(listOf(Protocol.HTTP_2, Protocol.HTTP_1_1))
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .addInterceptor { chain ->
                val request = chain.request()
                val urlStr = request.url.toString()
                if (negativeCache.containsKey(urlStr)) {
                    throw IOException("HTTP 404 (negative cache hit): $urlStr")
                }
                val response = chain.proceed(request)
                if (response.code == 404) {
                    recordNegativeCache(urlStr)
                }
                response
            }
            .build()
    }

    fun getImageLoader(context: PlatformContext): ImageLoader {
        storedContext = context
        return loaderInstance ?: synchronized(this) {
            loaderInstance ?: buildImageLoader(context).also {
                loaderInstance = it
                SingletonImageLoader.setSafe { _ -> it }
            }
        }
    }

    private fun buildImageLoader(context: PlatformContext): ImageLoader {
        val diskCacheDir = getCacheDirectory(context)

        return ImageLoader.Builder(context)
            .memoryCache {
                MemoryCache.Builder()
                    .maxSizePercent(context, 0.25)
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(diskCacheDir)
                    .maxSizeBytes(150L * 1024 * 1024) // 150 MB disk cache (optimized footprint, ~3000 covers)
                    .build()
            }
            .components {
                add(VideoArtworkFallbackInterceptor())
                add(
                    OkHttpNetworkFetcherFactory(
                        callFactory = { sharedOkHttpClient }
                    )
                )
            }
            .eventListener(CoverArtEventListener())
            .build()
    }

    /**
     * Prefetches cover art into disk and memory cache.
     * Deduplicates URLs, skips negative cache and memory-cached items, and yields to visible items.
     */
    fun prefetch(
        context: PlatformContext,
        urls: List<String>,
        size: CoverSize = CoverSize.THUMBNAIL
    ) {
        val loader = getImageLoader(context)
        val distinctUrls = urls.distinct().filter { !isNegativeCached(it) }

        // Yield to visible item network requests before background prefetch
        CoroutineScope(Dispatchers.Default).launch {
            delay(100L)
            for (rawUrl in distinctUrls) {
                val formatted = formatCoverUrl(rawUrl, size) ?: continue
                if (isNegativeCached(formatted)) continue

                // Check memory cache first to skip already loaded items
                val memoryKey = MemoryCache.Key(formatted)
                if (loader.memoryCache?.get(memoryKey) != null) continue

                val request = ImageRequest.Builder(context)
                    .data(formatted)
                    .memoryCacheKey(formatted)
                    .diskCacheKey(formatted)
                    .crossfade(false)
                    .build()
                loader.enqueue(request)
            }
        }
    }

    /**
     * Prefetch using currently cached loader instance if available.
     */
    fun prefetchIfInitialized(urls: List<String>, size: CoverSize = CoverSize.THUMBNAIL) {
        val ctx = storedContext ?: return
        prefetch(ctx, urls, size)
    }
}
