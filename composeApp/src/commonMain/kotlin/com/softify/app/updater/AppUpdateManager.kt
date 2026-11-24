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

    fun evaluateUpdate(info: UpdateInfo, currentVersionCode: Int): UpdateState {
        return if (info.versionCode > currentVersionCode) {
            UpdateState.Available(info)
        } else {
            UpdateState.UpToDate
        }
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
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }
            val apkFile = File(targetDir, "softify-${info.versionName}.apk")

            body.byteStream().use { input ->
                FileOutputStream(apkFile).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    var totalRead = 0L

                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        totalRead += bytesRead
                        val progress = if (totalBytes > 0) totalRead.toFloat() / totalBytes.toFloat() else 0f
                        _updateState.value = UpdateState.Downloading(totalRead, totalBytes, progress)
                        onProgress?.invoke(totalRead, totalBytes)
                    }
                }
            }

            // Verify SHA-256
            if (info.sha256.isNotBlank() && !verifySha256(apkFile, info.sha256)) {
                apkFile.delete()
                _updateState.value = UpdateState.Error("SHA-256 checksum mismatch")
                PlaybackLogger.log("SoftifyUpdater", "SHA-256 verification failed for downloaded APK.")
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
