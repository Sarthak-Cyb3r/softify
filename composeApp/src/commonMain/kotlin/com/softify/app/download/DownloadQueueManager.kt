package com.softify.app.download

import com.softify.app.storage.StorageHealth
import com.softify.app.storage.StorageProvider
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Semaphore
import uniffi.softify_core.*

class DownloadQueueManager(
    val storageProvider: StorageProvider,
    private val resumableDownloader: ResumableDownloader,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
) {

    private val _tasks = MutableStateFlow<Map<String, DownloadTask>>(emptyMap())
    val tasks: StateFlow<Map<String, DownloadTask>> = _tasks.asStateFlow()

    private val _maxConcurrent = MutableStateFlow(2)
    val maxConcurrent: StateFlow<Int> = _maxConcurrent.asStateFlow()

    private val _wifiOnly = MutableStateFlow(false)
    val wifiOnly: StateFlow<Boolean> = _wifiOnly.asStateFlow()

    private val activeJobs = mutableMapOf<String, Job>()
    private val pausedFlags = mutableSetOf<String>()

    private var concurrencySemaphore = Semaphore(2)

    init {
        loadSettings()
        reconcile()
    }

    private fun loadSettings() {
        try {
            val maxStr = getSetting("max_concurrent_downloads")
            if (maxStr != null) {
                val max = maxStr.toIntOrNull()?.coerceIn(1, 3) ?: 2
                _maxConcurrent.value = max
                concurrencySemaphore = Semaphore(max)
            }
            val wifiStr = getSetting("download_wifi_only")
            if (wifiStr != null) {
                _wifiOnly.value = (wifiStr == "true")
            }
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "Error loading download settings: ${e.message}")
        }
    }

    fun setMaxConcurrent(limit: Int) {
        val clamped = limit.coerceIn(1, 3)
        _maxConcurrent.value = clamped
        concurrencySemaphore = Semaphore(clamped)
        try {
            setSetting("max_concurrent_downloads", clamped.toString())
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "Error saving max concurrent setting: ${e.message}")
        }
        pumpQueue()
    }

    fun setWifiOnly(enabled: Boolean) {
        _wifiOnly.value = enabled
        try {
            setSetting("download_wifi_only", enabled.toString())
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "Error saving wifi only setting: ${e.message}")
        }
    }

    fun enqueue(track: Track, preset: QualityPreset = QualityPreset.HIGH) {
        val currentTasks = _tasks.value
        val existing = currentTasks[track.id]
        if (existing != null) {
            if (existing.status == DownloadStatus.COMPLETED) {
                // Already downloaded and verified
                return
            }
            if (existing.status == DownloadStatus.DOWNLOADING || existing.status == DownloadStatus.QUEUED) {
                // Deduplicate: already queued or running
                return
            }
        }

        // Verify storage health before queueing
        val health = storageProvider.validateStorage()
        if (health == StorageHealth.STORAGE_FULL) {
            PlaybackLogger.log("SoftifyDownload", "Cannot enqueue '${track.title}': Storage is full")
            return
        }

        val newTask = DownloadTask(
            track = track,
            preset = preset,
            status = DownloadStatus.QUEUED
        )

        _tasks.value = currentTasks + (track.id to newTask)
        pausedFlags.remove(track.id)

        try {
            recordDownloadState(
                trackId = track.id,
                relativePath = "",
                containerFormat = "m4a",
                fileSizeBytes = 0u,
                bytesDownloaded = 0u,
                status = "queued",
                bitrateKbps = 0u,
                lastError = null
            )
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "DB record queued notice: ${e.message}")
        }

        pumpQueue()
    }

    fun enqueueAll(tracks: List<Track>, preset: QualityPreset = QualityPreset.HIGH) {
        for (t in tracks) {
            enqueue(t, preset)
        }
    }

    fun pause(trackId: String) {
        pausedFlags.add(trackId)
        activeJobs[trackId]?.cancel()
        activeJobs.remove(trackId)

        val task = _tasks.value[trackId] ?: return
        _tasks.value = _tasks.value + (trackId to task.copy(status = DownloadStatus.PAUSED))

        try {
            updateDownloadStatus(trackId, "paused", null)
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "DB update paused error: ${e.message}")
        }
        pumpQueue()
    }

    fun resume(trackId: String) {
        pausedFlags.remove(trackId)
        val task = _tasks.value[trackId] ?: return
        _tasks.value = _tasks.value + (trackId to task.copy(status = DownloadStatus.QUEUED, lastError = null))

        try {
            updateDownloadStatus(trackId, "queued", null)
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "DB update queued error: ${e.message}")
        }
        pumpQueue()
    }

    fun retry(trackId: String) {
        pausedFlags.remove(trackId)
        val task = _tasks.value[trackId] ?: return
        _tasks.value = _tasks.value + (trackId to task.copy(
            status = DownloadStatus.QUEUED,
            lastError = null,
            retryCount = 0
        ))

        try {
            updateDownloadStatus(trackId, "queued", null)
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "DB update retry error: ${e.message}")
        }
        pumpQueue()
    }

    fun cancel(trackId: String) {
        pausedFlags.add(trackId)
        activeJobs[trackId]?.cancel()
        activeJobs.remove(trackId)

        val task = _tasks.value[trackId]
        if (task != null && task.filename.isNotBlank()) {
            storageProvider.delete("${task.filename}.part")
            storageProvider.delete(task.filename)
        }

        _tasks.value = _tasks.value - trackId

        try {
            deleteDownload(trackId)
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "DB delete download error: ${e.message}")
        }
        pumpQueue()
    }

    fun deleteCompleted(trackId: String) {
        val task = _tasks.value[trackId]
        if (task != null && task.filename.isNotBlank()) {
            storageProvider.delete(task.filename)
        }
        _tasks.value = _tasks.value - trackId
        try {
            deleteDownload(trackId)
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "DB delete download error: ${e.message}")
        }
    }

    fun deleteAll() {
        // Cancel all active jobs
        for ((_, job) in activeJobs) {
            job.cancel()
        }
        activeJobs.clear()
        pausedFlags.clear()

        // Delete all files in storage
        val tasks = _tasks.value.values
        for (t in tasks) {
            if (t.filename.isNotBlank()) {
                storageProvider.delete("${t.filename}.part")
                storageProvider.delete(t.filename)
            }
        }
        _tasks.value = emptyMap()

        try {
            deleteAllDownloads()
        } catch (e: Exception) {
            PlaybackLogger.log("SoftifyDownload", "DB deleteAllDownloads error: ${e.message}")
        }
    }

    fun reconcile() {
        scope.launch(Dispatchers.IO) {
            try {
                val dbDownloads = getDownloads()
                val updatedMap = _tasks.value.toMutableMap()

                for (d in dbDownloads) {
                    val status = DownloadStatus.fromString(d.status)
                    val filename = d.relativePath.substringAfterLast('/')
                    val fileExists = storageProvider.exists(filename)

                    if (status == DownloadStatus.COMPLETED) {
                        if (fileExists) {
                            val dummyTrack = Track(
                                id = d.trackId,
                                sourceId = "down_${d.trackId}",
                                title = filename.substringAfter('_').substringBeforeLast('.').replace('_', ' '),
                                artist = "Downloaded Track",
                                album = null,
                                durationMs = 0u,
                                coverUrl = null,
                                matchConfidence = null,
                                isLiked = false,
                                isUnavailable = false
                            )
                            updatedMap[d.trackId] = DownloadTask(
                                track = dummyTrack,
                                status = DownloadStatus.COMPLETED,
                                bytesDownloaded = d.bytesDownloaded.toLong(),
                                totalBytes = d.fileSizeBytes.toLong(),
                                bitrateKbps = d.bitrateKbps,
                                codec = d.containerFormat,
                                fileUri = d.relativePath,
                                filename = filename,
                                lastError = d.lastError
                            )
                        } else {
                            // File missing on disk! Mark failed / needs repair
                            PlaybackLogger.log("SoftifyDownload", "Reconcile: File $filename missing for ${d.trackId}")
                            markDownloadRepair(d.trackId, "File missing from storage")
                            val dummyTrack = Track(
                                id = d.trackId,
                                sourceId = "down_${d.trackId}",
                                title = filename.substringAfter('_').substringBeforeLast('.').replace('_', ' '),
                                artist = "Downloaded Track",
                                album = null,
                                durationMs = 0u,
                                coverUrl = null,
                                matchConfidence = null,
                                isLiked = false,
                                isUnavailable = false
                            )
                            updatedMap[d.trackId] = DownloadTask(
                                track = dummyTrack,
                                status = DownloadStatus.FAILED,
                                bytesDownloaded = 0L,
                                totalBytes = d.fileSizeBytes.toLong(),
                                bitrateKbps = d.bitrateKbps,
                                codec = d.containerFormat,
                                fileUri = d.relativePath,
                                filename = filename,
                                lastError = "File missing from storage, tap retry to redownload"
                            )
                        }
                    } else if (status == DownloadStatus.DOWNLOADING || status == DownloadStatus.QUEUED) {
                        // Incomplete from prior session: mark queued to resume
                        val dummyTrack = Track(
                            id = d.trackId,
                            sourceId = "down_${d.trackId}",
                            title = filename.substringAfter('_').substringBeforeLast('.').replace('_', ' '),
                            artist = "Downloaded Track",
                            album = null,
                            durationMs = 0u,
                            coverUrl = null,
                            matchConfidence = null,
                            isLiked = false,
                            isUnavailable = false
                        )
                        updatedMap[d.trackId] = DownloadTask(
                            track = dummyTrack,
                            status = DownloadStatus.QUEUED,
                            bytesDownloaded = d.bytesDownloaded.toLong(),
                            totalBytes = d.fileSizeBytes.toLong(),
                            bitrateKbps = d.bitrateKbps,
                            codec = d.containerFormat,
                            fileUri = d.relativePath,
                            filename = filename,
                            lastError = d.lastError
                        )
                    }
                }
                _tasks.value = updatedMap
                pumpQueue()
            } catch (e: Exception) {
                PlaybackLogger.log("SoftifyDownload", "Reconcile downloads error: ${e.message}")
            }
        }
    }

    private fun pumpQueue() {
        val currentTasks = _tasks.value
        val queuedTasks = currentTasks.values.filter { it.status == DownloadStatus.QUEUED }
        if (queuedTasks.isEmpty()) return

        for (task in queuedTasks) {
            if (activeJobs.containsKey(task.track.id)) continue
            if (activeJobs.size >= _maxConcurrent.value) break

            val trackId = task.track.id
            val job = scope.launch {
                concurrencySemaphore.acquire()
                try {
                    _tasks.value = _tasks.value + (trackId to task.copy(status = DownloadStatus.DOWNLOADING))
                    updateDownloadStatus(trackId, "downloading", null)

                    val result = resumableDownloader.download(
                        track = task.track,
                        preset = task.preset,
                        onProgress = { downloaded, total ->
                            val current = _tasks.value[trackId] ?: task
                            _tasks.value = _tasks.value + (trackId to current.copy(
                                bytesDownloaded = downloaded,
                                totalBytes = total,
                                status = DownloadStatus.DOWNLOADING
                            ))
                            updateDownloadProgress(trackId, downloaded.toULong(), total.toULong(), "downloading")
                        },
                        isPausedOrCancelled = {
                            pausedFlags.contains(trackId) || !isActive
                        }
                    )

                    when (result) {
                        is DownloadResult.Success -> {
                            val current = _tasks.value[trackId] ?: task
                            _tasks.value = _tasks.value + (trackId to current.copy(
                                status = DownloadStatus.COMPLETED,
                                bytesDownloaded = result.totalBytes,
                                totalBytes = result.totalBytes,
                                bitrateKbps = result.bitrateKbps,
                                codec = result.codec,
                                fileUri = result.fileUri,
                                filename = result.finalFilename,
                                lastError = null
                            ))
                        }
                        is DownloadResult.Paused -> {
                            val current = _tasks.value[trackId] ?: task
                            _tasks.value = _tasks.value + (trackId to current.copy(
                                status = DownloadStatus.PAUSED,
                                bytesDownloaded = result.bytesDownloaded,
                                totalBytes = result.totalBytes
                            ))
                        }
                    }
                } catch (e: Exception) {
                    val current = _tasks.value[trackId] ?: task
                    val errMsg = e.message ?: "Unknown download error"
                    PlaybackLogger.log("SoftifyDownload", "Download error for '${task.track.title}': $errMsg")
                    _tasks.value = _tasks.value + (trackId to current.copy(
                        status = DownloadStatus.FAILED,
                        lastError = errMsg
                    ))
                    markDownloadRepair(trackId, errMsg)
                } finally {
                    activeJobs.remove(trackId)
                    concurrencySemaphore.release()
                    pumpQueue()
                }
            }
            activeJobs[trackId] = job
        }
    }
}
