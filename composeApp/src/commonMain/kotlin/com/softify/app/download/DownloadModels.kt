package com.softify.app.download

import uniffi.softify_core.QualityPreset
import uniffi.softify_core.Track

enum class DownloadStatus {
    QUEUED,
    DOWNLOADING,
    PAUSED,
    FAILED,
    COMPLETED;

    companion object {
        fun fromString(status: String): DownloadStatus {
            return when (status.lowercase()) {
                "queued" -> QUEUED
                "downloading" -> DOWNLOADING
                "paused" -> PAUSED
                "failed" -> FAILED
                "completed", "done" -> COMPLETED
                else -> FAILED
            }
        }
    }
}

data class DownloadTask(
    val track: Track,
    val preset: QualityPreset = QualityPreset.HIGH,
    val status: DownloadStatus = DownloadStatus.QUEUED,
    val bytesDownloaded: Long = 0L,
    val totalBytes: Long = 0L,
    val bitrateKbps: UInt = 0u,
    val codec: String = "m4a",
    val fileUri: String = "",
    val filename: String = "",
    val lastError: String? = null,
    val retryCount: Int = 0
) {
    val progress: Float
        get() = if (totalBytes > 0L) {
            (bytesDownloaded.toFloat() / totalBytes.toFloat()).coerceIn(0f, 1f)
        } else {
            0f
        }
}
