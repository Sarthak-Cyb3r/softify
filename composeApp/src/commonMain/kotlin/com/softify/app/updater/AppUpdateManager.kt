package com.softify.app.updater

import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest

data class UpdateInfo(
    val versionCode: Int,
    val versionName: String,
    val releaseNotes: String,
    val apkUrl: String,
    val sha256: String,
    val expectedSizeBytes: Long = -1L,
    val isMandatory: Boolean = false
)

sealed class UpdateState {
    data object Idle : UpdateState()
    data object Checking : UpdateState()
    data class Available(val info: UpdateInfo) : UpdateState()
    data class Downloading(val bytesDownloaded: Long, val totalBytes: Long, val progress: Float) : UpdateState()
    data class ReadyToInstall(val apkFile: File, val info: UpdateInfo) : UpdateState()
    data object UpToDate : UpdateState()
    data class Error(val message: String) : UpdateState()
}

/**
 * Manages zero-cost in-app update checks, download with progress, and SHA-256 integrity verification.
 */
class AppUpdateManager(
    private val httpClient: OkHttpClient = OkHttpClient.Builder().build()
) {
    private val _updateState = MutableStateFlow<UpdateState>(UpdateState.Idle)
    val updateState: StateFlow<UpdateState> = _updateState.asStateFlow()

    fun setChecking() {
        _updateState.value = UpdateState.Checking
    }

    fun setError(message: String) {
        _updateState.value = UpdateState.Error(message)
    }

    fun evaluateUpdate(info: UpdateInfo, currentVersionCode: Int): UpdateState {
        return if (info.versionCode > currentVersionCode) {
            UpdateState.Available(info)
        } else {
            UpdateState.UpToDate
        }
    }

    fun evaluateAndPublishUpdate(info: UpdateInfo, currentVersionCode: Int): UpdateState {
        val state = evaluateUpdate(info, currentVersionCode)
        _updateState.value = state
        return state
    }

    suspend fun downloadApk(
        info: UpdateInfo,
        targetDir: File,
        onProgress: ((Long, Long) -> Unit)? = null
    ): File? = withContext(Dispatchers.IO) {
        try {
            _updateState.value = UpdateState.Downloading(0L, 0L, 0f)
            val request = Request.Builder().url(info.apkUrl).build()
            val response = httpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                _updateState.value = UpdateState.Error("HTTP error: ${response.code}")
                return@withContext null
            }

            val body = response.body ?: run {
                _updateState.value = UpdateState.Error("Empty response body")
                return@withContext null
            }

            val totalBytes = body.contentLength()
            val expectedSize = when {
                info.expectedSizeBytes > 0L -> info.expectedSizeBytes
                totalBytes > 0L -> totalBytes
                else -> -1L
            }
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }
            val apkFile = File(targetDir, "softify-${info.versionName}.apk")
            var totalRead = 0L

            body.byteStream().use { input ->
                FileOutputStream(apkFile).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int

                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        totalRead += bytesRead
                        val denom = if (expectedSize > 0L) expectedSize else totalBytes
                        val progress = if (denom > 0L) (totalRead.toFloat() / denom.toFloat()).coerceIn(0f, 1f) else 0f
                        _updateState.value = UpdateState.Downloading(totalRead, denom, progress)
                        onProgress?.invoke(totalRead, denom)
                    }
                }
            }

            if (totalRead <= 0L || (expectedSize > 0L && totalRead != expectedSize) || (totalBytes > 0L && totalRead != totalBytes)) {
                apkFile.delete()
                val targetLen = if (expectedSize > 0L) expectedSize else totalBytes
                _updateState.value = UpdateState.Error("Truncated download: expected $targetLen bytes, got $totalRead bytes")
                PlaybackLogger.log("SoftifyUpdater", "Truncated download refused: expected=$targetLen actual=$totalRead")
                return@withContext null
            }

            if (info.sha256.isBlank() || !verifySha256(apkFile, info.sha256)) {
                apkFile.delete()
                val reason = if (info.sha256.isBlank()) "Missing SHA-256 checksum" else "SHA-256 checksum mismatch"
                _updateState.value = UpdateState.Error(reason)
                PlaybackLogger.log("SoftifyUpdater", "$reason for downloaded APK.")
                return@withContext null
            }

            _updateState.value = UpdateState.ReadyToInstall(apkFile, info)
            PlaybackLogger.log("SoftifyUpdater", "APK verified successfully: ${apkFile.absolutePath}")
            apkFile
        } catch (e: Exception) {
            _updateState.value = UpdateState.Error("Download failed: ${e.message}")
            PlaybackLogger.log("SoftifyUpdater", "APK download error: ${e.message}")
            null
        }
    }

    fun verifySha256(file: File, expectedHash: String): Boolean {
        if (!file.exists()) return false
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                md.update(buffer, 0, bytesRead)
            }
        }
        val digest = md.digest()
        val hex = digest.joinToString("") { "%02x".format(it) }
        return hex.equals(expectedHash.trim(), ignoreCase = true)
    }

    fun resetState() {
        _updateState.value = UpdateState.Idle
    }
}
