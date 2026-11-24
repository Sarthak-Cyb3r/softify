package com.softify.app.api

import com.softify.app.sync.HlcTimestamp
import com.softify.app.sync.SyncChange
import com.softify.app.sync.SyncEntityType
import com.softify.app.sync.SyncResult
import com.softify.app.telemetry.TelemetryEvent
import com.softify.app.updater.UpdateInfo
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Robust HTTP client interfacing with the Softify Edge Cloudflare Workers API.
 * Integrates circuit breaker, exponential backoff, Local-Only bypass, and zero-crash fallbacks.
 */
class SoftifyApiClient(
    var baseUrl: String = "https://softify-edge.workers.dev",
    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .writeTimeout(8, TimeUnit.SECONDS)
        .build(),
    val circuitBreaker: CircuitBreaker = CircuitBreaker()
) {
    var isLocalOnly: Boolean = false

    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun fetchRemoteConfig(currentEtag: String? = null): RemoteConfig? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext null
        }

        try {
            val reqBuilder = Request.Builder().url("$baseUrl/config.json")
            if (currentEtag != null) {
                reqBuilder.header("If-None-Match", currentEtag)
            }
            val response = httpClient.newCall(reqBuilder.build()).execute()

            if (response.code == 304) {
                circuitBreaker.recordSuccess()
                return@withContext null // Not modified
            }

            if (!response.isSuccessful) {
                handleHttpError(response.code, response.header("Retry-After"))
                return@withContext null
            }

            circuitBreaker.recordSuccess()
            val newEtag = response.header("ETag")
            val bodyStr = response.body?.string() ?: return@withContext null

            // Minimalist parse
            val lyricsEnabled = !bodyStr.contains("\"lyrics\":false")
            val syncEnabled = !bodyStr.contains("\"sync\":false")
            val updaterEnabled = !bodyStr.contains("\"updater\":false")
            val telemetryEnabled = bodyStr.contains("\"telemetry\":true")
            val listenTogetherEnabled = !bodyStr.contains("\"listen_together\":false")

            RemoteConfig(
                lyricsApiEnabled = lyricsEnabled,
                syncEnabled = syncEnabled,
                updaterEnabled = updaterEnabled,
                telemetryEnabled = telemetryEnabled,
                listenTogetherEnabled = listenTogetherEnabled,
                etag = newEtag
            )
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    suspend fun checkAppUpdate(): UpdateInfo? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext null
        }

        try {
            val request = Request.Builder().url("$baseUrl/update.json").build()
            val response = httpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                handleHttpError(response.code, response.header("Retry-After"))
                return@withContext null
            }

            circuitBreaker.recordSuccess()
            val body = response.body?.string() ?: return@withContext null

            // Parse version_code, version_name, apk_url, sha256
            val versionCode = Regex("\"version_code\":\\s*(\\d+)").find(body)?.groupValues?.get(1)?.toIntOrNull() ?: 0
            val versionName = Regex("\"version_name\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: ""
            val releaseNotes = Regex("\"release_notes\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: ""
            val apkUrl = Regex("\"apk_url\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: ""
            val sha256 = Regex("\"sha256\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: ""

            UpdateInfo(
                versionCode = versionCode,
                versionName = versionName,
                releaseNotes = releaseNotes,
                apkUrl = apkUrl,
                sha256 = sha256
            )
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    suspend fun registerAnonymous(deviceId: String): Pair<String, String>? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext null
        }

        try {
            val jsonBody = "{\"device_id\":\"$deviceId\"}"
            val request = Request.Builder()
                .url("$baseUrl/api/auth/register")
                .post(jsonBody.toRequestBody(jsonMediaType))
                .build()

            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                handleHttpError(response.code, response.header("Retry-After"))
                return@withContext null
            }

            circuitBreaker.recordSuccess()
            val body = response.body?.string() ?: return@withContext null
            val token = Regex("\"token\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: return@withContext null
            val recoveryCode = Regex("\"recovery_code\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: ""

            Pair(token, recoveryCode)
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    suspend fun sync(
        token: String,
        clientHlc: HlcTimestamp,
        outbox: List<SyncChange>
    ): SyncResult? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext null
        }

        try {
            val changesJson = outbox.joinToString(",") { change ->
                val escapedPayload = change.payload.replace("\"", "\\\"")
                "{\"entity_type\":\"${change.entityType.name}\",\"entity_id\":\"${change.entityId}\",\"hlc\":\"${change.hlc}\",\"is_deleted\":${change.isDeleted},\"payload\":\"$escapedPayload\"}"
            }
            val requestJson = "{\"client_hlc\":\"$clientHlc\",\"changes\":[$changesJson]}"

            val request = Request.Builder()
                .url("$baseUrl/api/sync")
                .header("Authorization", "Bearer $token")
                .post(requestJson.toRequestBody(jsonMediaType))
                .build()

            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                handleHttpError(response.code, response.header("Retry-After"))
                return@withContext null
            }

            circuitBreaker.recordSuccess()
            val body = response.body?.string() ?: return@withContext null

            val serverHlcStr = Regex("\"server_hlc\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: clientHlc.toString()
            val tier = Regex("\"tier\":\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: "TIER_1_NORMAL"

            SyncResult(
                serverHlc = HlcTimestamp.parse(serverHlcStr),
                appliedChanges = emptyList(),
                budgetTier = tier,
                isSuccess = true
            )
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    suspend fun sendTelemetry(events: List<TelemetryEvent>): Boolean = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute() || events.isEmpty()) {
            return@withContext false
        }

        try {
            val eventsJson = events.joinToString(",") { ev ->
                "{\"event_type\":\"${ev.eventType}\",\"timestamp\":${ev.timestamp},\"app_version\":\"${ev.appVersion}\"}"
            }
            val payload = "{\"events\":[$eventsJson]}"

            val request = Request.Builder()
                .url("$baseUrl/api/telemetry")
                .post(payload.toRequestBody(jsonMediaType))
                .build()

            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                handleHttpError(response.code, response.header("Retry-After"))
                return@withContext false
            }

            circuitBreaker.recordSuccess()
            true
        } catch (e: Exception) {
            handleException(e)
            false
        }
    }

    suspend fun exportUserData(token: String): String? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext null
        }

        try {
            val request = Request.Builder()
                .url("$baseUrl/api/user/export")
                .header("Authorization", "Bearer $token")
                .get()
                .build()

            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                handleHttpError(response.code, response.header("Retry-After"))
                return@withContext null
            }

            circuitBreaker.recordSuccess()
            response.body?.string()
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    suspend fun deleteUserAccount(token: String): Boolean = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext false
        }

        try {
            val request = Request.Builder()
                .url("$baseUrl/api/user")
                .header("Authorization", "Bearer $token")
                .delete()
                .build()

            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                handleHttpError(response.code, response.header("Retry-After"))
                return@withContext false
            }

            circuitBreaker.recordSuccess()
            true
        } catch (e: Exception) {
            handleException(e)
            false
        }
    }

    private fun handleHttpError(code: Int, retryAfterHeader: String?) {
        val retryAfterSec = retryAfterHeader?.toLongOrNull()
        circuitBreaker.recordFailure(code, retryAfterSec)
        PlaybackLogger.log("SoftifyEdge", "HTTP error $code (Retry-After: $retryAfterSec)")
    }

    private fun handleException(e: Exception) {
        if (e is IOException) {
            circuitBreaker.recordFailure()
        }
        PlaybackLogger.log("SoftifyEdge", "Network exception: ${e.message}")
    }
}
