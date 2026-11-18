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
import okhttp3.OkHttpClient
import okio.Path
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * Platform-specific cache directory for 250 MB disk cache.
 */
expect fun getCacheDirectory(context: PlatformContext): Path

/**
 * Thumbnail size targets:
 * - THUMBNAIL: ~120-200px (180px) for list rows, search results, library, and home shelves.
 * - FULL: 544px for Now Playing screen and MiniPlayer.
 */
enum class CoverSize {
    THUMBNAIL,
    FULL
}

/**
 * Converts cover URL into size-appropriate thumbnail URL.
 * - Google / YouTube Music CDN: rewrites `=w...` or `=s...`
 * - Saavn CDN: rewrites `-\d+x\d+\.jpg` to `-150x150.jpg` vs `-500x500.jpg`
 * - YouTube: `mqdefault.jpg` (small) vs `hqdefault.jpg` (full)
 */
fun formatCoverUrl(url: String?, size: CoverSize): String? {
    if (url.isNullOrBlank()) return null
    return when (size) {
        CoverSize.THUMBNAIL -> {
            if (url.contains("=w") || url.contains("=s")) {
                url.replace(Regex("=w\\d+-h\\d+[^?&]*"), "=w180-h180-l90-rj")
                    .replace(Regex("=s\\d+[^?&]*"), "=s180-c-k-c0x00ffffff-no-rj")
            } else if (url.contains("saavncdn.com")) {
                url.replace(Regex("-\\d+x\\d+\\.jpg"), "-150x150.jpg")
            } else if (url.contains("i.ytimg.com")) {
                url.replace("hqdefault.jpg", "mqdefault.jpg")
            } else {
                url
            }
        }
        CoverSize.FULL -> {
            if (url.contains("=w") || url.contains("=s")) {
                url.replace(Regex("=w\\d+-h\\d+[^?&]*"), "=w544-h544-l90-rj")
                    .replace(Regex("=s\\d+[^?&]*"), "=s544-c-k-c0x00ffffff-no-rj")
            } else if (url.contains("saavncdn.com")) {
                url.replace(Regex("-\\d+x\\d+\\.jpg"), "-500x500.jpg")
            } else if (url.contains("i.ytimg.com")) {
                url.replace("mqdefault.jpg", "hqdefault.jpg")
            } else {
                url
            }
        }
    }
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
            "Art load [$hitOrMiss]: duration=${durationMs}ms, source=$source, url=${request.data.toString().take(60)}..."
        )
    }

    override fun onError(request: ImageRequest, result: ErrorResult) {
        val durationMs = (System.currentTimeMillis() - startTime).coerceAtLeast(0L)
        PlaybackLogger.log(
            "SoftifyCoverArt",
            "Art load [FAILED]: duration=${durationMs}ms, error=${result.throwable.message}, url=${request.data.toString().take(60)}..."
        )
    }
}

/**
 * Singleton CoverArtLoader configuring Coil with:
 * - 25% RAM memory cache
 * - 250 MB disk cache
 * - Single shared OkHttpClient
 * - Consistent cache keys
 * - Immediate loading (no crossfade for cache hits)
 */
object CoverArtLoader {
    private var loaderInstance: ImageLoader? = null
    private var storedContext: PlatformContext? = null

    val sharedOkHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
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
                    .maxSizeBytes(250L * 1024 * 1024) // 250 MB disk cache
                    .build()
            }
            .components {
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
     * Can prefetch for upcoming queue items, shelf items, or search/radio results.
     */
    fun prefetch(
        context: PlatformContext,
        urls: List<String>,
        size: CoverSize = CoverSize.THUMBNAIL
    ) {
        val loader = getImageLoader(context)
        for (rawUrl in urls) {
            val formatted = formatCoverUrl(rawUrl, size) ?: continue
            val request = ImageRequest.Builder(context)
                .data(formatted)
                .memoryCacheKey(formatted)
                .diskCacheKey(formatted)
                .crossfade(false)
                .build()
            loader.enqueue(request)
        }
    }

    /**
     * Prefetch using currently cached loader instance if available.
     */
    fun prefetchIfInitialized(urls: List<String>, size: CoverSize = CoverSize.THUMBNAIL) {
        val loader = loaderInstance ?: return
        val ctx = storedContext ?: return
        for (rawUrl in urls) {
            val formatted = formatCoverUrl(rawUrl, size) ?: continue
            val request = ImageRequest.Builder(ctx)
                .data(formatted)
                .memoryCacheKey(formatted)
                .diskCacheKey(formatted)
                .crossfade(false)
                .build()
            loader.enqueue(request)
        }
    }
}
