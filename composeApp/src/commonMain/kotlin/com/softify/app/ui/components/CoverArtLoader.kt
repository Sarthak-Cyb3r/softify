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
 * - YouTube: `mqdefault.jpg` (small) vs `hqdefault.jpg` (full)
 * - Saavn CDN and other hosts: preserved untouched without breaking rewrites
 */
fun formatCoverUrl(url: String?, size: CoverSize): String? {
    if (url.isNullOrBlank()) return null
    return when (size) {
        CoverSize.THUMBNAIL -> {
            if (url.contains("=w") || url.contains("=s") || url.contains("googleusercontent.com") || url.contains("ggpht.com")) {
                url.replace(Regex("=w\\d+-h\\d+[^?&]*"), "=w180-h180-l90-rj")
                    .replace(Regex("=s\\d+[^?&]*"), "=s180-c-k-c0x00ffffff-no-rj")
            } else if (url.contains("i.ytimg.com")) {
                url.replace("hqdefault.jpg", "mqdefault.jpg")
            } else {
                // Host-specific: preserve Saavn and other hosts without breaking rewrites
                url
            }
        }
        CoverSize.FULL -> {
            if (url.contains("=w") || url.contains("=s") || url.contains("googleusercontent.com") || url.contains("ggpht.com")) {
                url.replace(Regex("=w\\d+-h\\d+[^?&]*"), "=w544-h544-l90-rj")
                    .replace(Regex("=s\\d+[^?&]*"), "=s544-c-k-c0x00ffffff-no-rj")
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
 * Singleton CoverArtLoader configuring Coil with:
 * - 25% RAM memory cache
 * - 250 MB disk cache
 * - Shared OkHttpClient with HTTP/2 and 64 max concurrent / 24 per host dispatcher
 * - Negative caching for HTTP 404 URLs
 * - Background prefetching prioritizing visible UI requests
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
