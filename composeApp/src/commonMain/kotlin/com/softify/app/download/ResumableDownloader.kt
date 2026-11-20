package com.softify.app.download

import com.softify.app.storage.StorageProvider
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import uniffi.softify_core.QualityPreset
import uniffi.softify_core.StreamInfo
import uniffi.softify_core.Track
import uniffi.softify_core.getLyrics
import uniffi.softify_core.recordDownloadState
import uniffi.softify_core.tagAudioFile
import java.io.InputStream
import java.io.OutputStream
import kotlin.coroutines.coroutineContext

class ResumableDownloader(
    private val storageProvider: StorageProvider,
    private val httpClient: OkHttpClient = OkHttpClient.Builder().build(),
    private val streamResolver: suspend (Track, QualityPreset, Boolean) -> StreamInfo
) {

    suspend fun download(
        track: Track,
        preset: QualityPreset,
        onProgress: (bytesDownloaded: Long, totalBytes: Long) -> Unit,
        isPausedOrCancelled: () -> Boolean
    ): DownloadResult = withContext(Dispatchers.IO) {
        // 1. Resolve stream
        var forceRefresh = false
        var streamInfo = streamResolver(track, preset, forceRefresh)

        // 2. Prepare filenames
        val extension = when (streamInfo.codec.lowercase()) {
            "opus" -> "opus"
            "webm" -> "webm"
            "mp3" -> "mp3"
            else -> "m4a"
        }
        val safeTitle = track.title.replace(Regex("[^a-zA-Z0-9 ]"), "_").trim().replace(" ", "_")
        val finalFilename = "${track.id}_$safeTitle.$extension"
        val partFilename = "$finalFilename.part"

        var existingBytes = if (storageProvider.exists(partFilename)) {
            storageProvider.getFileSize(partFilename)
        } else {
            0L
        }

        var attempt = 0
        var success = false
        var totalBytes = existingBytes

        while (attempt < 3 && !success) {
            if (isPausedOrCancelled() || !coroutineContext.isActive) {
                return@withContext DownloadResult.Paused(existingBytes, totalBytes)
            }

            // Build HTTP request with Range if resuming
            val reqBuilder = Request.Builder().url(streamInfo.url)
            for (header in streamInfo.headers) {
                reqBuilder.addHeader(header.name, header.value)
            }
            if (existingBytes > 0L) {
                reqBuilder.addHeader("Range", "bytes=$existingBytes-")
            }

            var response = try {
                httpClient.newCall(reqBuilder.build()).execute()
            } catch (e: Exception) {
                attempt++
                if (attempt >= 3) throw e
                kotlinx.coroutines.delay(1000L * (1 shl attempt))
                continue
            }

            // Check for 403 Forbidden / 410 Gone / Expired URL
            if (response.code == 403 || response.code == 410) {
                response.close()
                PlaybackLogger.log("SoftifyDownload", "Stream URL expired (HTTP ${response.code}) for '${track.title}', re-resolving...")
                forceRefresh = true
                streamInfo = streamResolver(track, preset, forceRefresh)
                attempt++
                continue
            }

            if (!response.isSuccessful && response.code != 206) {
                val code = response.code
                response.close()
                throw IllegalStateException("Download HTTP failed with status code $code")
            }

            val isPartial = (response.code == 206)
            val contentLength = response.body?.contentLength() ?: -1L
            totalBytes = if (isPartial) {
                existingBytes + if (contentLength > 0L) contentLength else 0L
            } else {
                existingBytes = 0L // Restarted from beginning
                if (contentLength > 0L) contentLength else 0L
            }

            val bodyStream: InputStream = response.body?.byteStream()
                ?: throw IllegalStateException("Empty response body from stream")

            val outStream: OutputStream = storageProvider.openOutputStream(partFilename, append = isPartial)

            try {
                val buffer = ByteArray(65536) // 64 KB streaming buffer
                var bytesRead: Int
                while (bodyStream.read(buffer).also { bytesRead = it } != -1) {
                    if (isPausedOrCancelled() || !coroutineContext.isActive) {
                        outStream.flush()
                        return@withContext DownloadResult.Paused(existingBytes, totalBytes)
                    }
                    outStream.write(buffer, 0, bytesRead)
                    existingBytes += bytesRead
                    onProgress(existingBytes, totalBytes)
                }
                outStream.flush()
                success = true
            } finally {
                runCatching { bodyStream.close() }
                runCatching { outStream.close() }
                runCatching { response.close() }
            }
        }

        if (!success) {
            throw IllegalStateException("Download failed after retries for '${track.title}'")
        }

        // 3. Verify size on completion
        val actualPartSize = storageProvider.getFileSize(partFilename)
        if (totalBytes > 0L && actualPartSize < totalBytes) {
            throw IllegalStateException("Download size verification failed: expected $totalBytes bytes, got $actualPartSize bytes")
        }

        // 4. Atomically rename .part to final file
        val renamed = storageProvider.rename(partFilename, finalFilename)
        if (!renamed) {
            throw IllegalStateException("Failed to atomically rename $partFilename to $finalFilename")
        }

        val fileUri = storageProvider.getFileUri(finalFilename)

        // 5. Embed metadata tags and cover art
        try {
            val coverBytes = fetchCoverBytes(track.coverUrl)
            // If local file path accessible, tag via Rust core
            tagAudioFile(
                filePath = fileUri.removePrefix("file://"),
                title = track.title,
                artist = track.artist,
                album = track.album,
                year = null,
                coverBytes = coverBytes
            )
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "Audio tagging notice: ${e.message}")
        }

        // 6. Prefetch and save synced lyrics for offline use
        try {
            getLyrics(track)
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "Offline lyrics prefetch notice: ${e.message}")
        }

        // 7. Record completed state in SQLite
        recordDownloadState(
            trackId = track.id,
            relativePath = fileUri,
            containerFormat = extension,
            fileSizeBytes = actualPartSize.toULong(),
            bytesDownloaded = actualPartSize.toULong(),
            status = "completed",
            bitrateKbps = streamInfo.bitrateKbps,
            lastError = null
        )

        DownloadResult.Success(
            finalFilename = finalFilename,
            fileUri = fileUri,
            totalBytes = actualPartSize,
            bitrateKbps = streamInfo.bitrateKbps,
            codec = extension
        )
    }

    private fun fetchCoverBytes(coverUrl: String?): ByteArray? {
        if (coverUrl.isNullOrBlank()) return null
        return try {
            val req = Request.Builder().url(coverUrl).build()
            val resp = httpClient.newCall(req).execute()
            if (resp.isSuccessful) {
                resp.body?.bytes()
            } else {
                resp.close()
                null
            }
        } catch (e: Exception) {
            null
        }
    }
}

sealed class DownloadResult {
    data class Success(
        val finalFilename: String,
        val fileUri: String,
        val totalBytes: Long,
        val bitrateKbps: UInt,
        val codec: String
    ) : DownloadResult()

    data class Paused(
        val bytesDownloaded: Long,
        val totalBytes: Long
    ) : DownloadResult()
}
