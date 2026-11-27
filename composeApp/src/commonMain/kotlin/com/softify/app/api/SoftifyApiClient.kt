package com.softify.app.api

import com.softify.app.room.RoomState
import com.softify.app.room.RoomStatus
import com.softify.app.sync.HlcTimestamp
import com.softify.app.sync.SyncChange
import com.softify.app.sync.SyncEntityType
import com.softify.app.sync.SyncResult
import com.softify.app.telemetry.TelemetryEvent
import com.softify.app.updater.UpdateInfo
import com.softify.app.util.JsonCodec
import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

data class AuthTokens(
    val accessToken: String,
    val refreshToken: String,
    val expiresInSeconds: Int,
    val accountId: String
)

sealed class ApiOutcome<out T> {
    data class Success<T>(val data: T) : ApiOutcome<T>()
    data class HttpError(val code: Int, val message: String, val retryAfterSeconds: Long? = null) : ApiOutcome<Nothing>()
    data class NetworkFailure(val message: String) : ApiOutcome<Nothing>()
    data object LocalOnlyBlocked : ApiOutcome<Nothing>()
    data object CircuitOpen : ApiOutcome<Nothing>()
}

/**
 * HTTP client interfacing with the Softify Edge Cloudflare Workers API.
 * Strictly aligned with server/openapi.json via ApiRoutes.
 * Handles 401 token refresh, 429/503 circuit breaking, timeouts, and static mirror fallback.
 */
class SoftifyApiClient(
    var baseUrl: String = BuildBackendConfig.PRIMARY_BASE_URL,
    var backupMirrorUrl: String = BuildBackendConfig.STATIC_MIRROR_URL,
    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .writeTimeout(8, TimeUnit.SECONDS)
        .build(),
    val circuitBreaker: CircuitBreaker = CircuitBreaker()
) {
    var isLocalOnly: Boolean = false
    var accessToken: String? = null
    var refreshToken: String? = null
    var accountId: String? = null
    var lastHttpStatus: Int? = null
        private set

    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    object BuildBackendConfig {
        const val PRIMARY_BASE_URL = "https://softify-server.workers.dev"
        const val STATIC_MIRROR_URL = "https://sarthak-cyb3r.github.io/softify-static"
    }

    fun sha256Hex(raw: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    suspend fun fetchHealth(): Boolean = withContext(Dispatchers.IO) {
        if (isLocalOnly) return@withContext false
        try {
            val req = Request.Builder().url("$baseUrl${ApiRoutes.HEALTHZ}").get().build()
            httpClient.newCall(req).execute().use { resp ->
                lastHttpStatus = resp.code
                resp.isSuccessful
            }
        } catch (e: Exception) {
            handleException(e)
            false
        }
    }

    suspend fun fetchRemoteConfig(currentEtag: String? = null): RemoteConfig? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext null
        }

        val primary = fetchConfigFromRoot(baseUrl, currentEtag)
        if (primary != null) return@withContext primary

        if (backupMirrorUrl.isNotBlank() && backupMirrorUrl != baseUrl) {
            return@withContext fetchConfigFromRoot(backupMirrorUrl, currentEtag, affectCircuit = false)
        }
        null
    }

    private fun fetchConfigFromRoot(root: String, currentEtag: String?, affectCircuit: Boolean = true): RemoteConfig? {
        return try {
            val reqBuilder = Request.Builder().url("$root${ApiRoutes.CONFIG_JSON}")
            if (currentEtag != null) {
                reqBuilder.header("If-None-Match", currentEtag)
            }
            httpClient.newCall(reqBuilder.build()).execute().use { response ->
                lastHttpStatus = response.code
                if (response.code == 304) {
                    if (affectCircuit) circuitBreaker.recordSuccess()
                    return null
                }
                if (!response.isSuccessful) {
                    if (affectCircuit) handleHttpError(response.code, response.header("Retry-After"))
                    return null
                }
                if (affectCircuit) circuitBreaker.recordSuccess()
                val bodyStr = response.body?.string() ?: return null
                parseRemoteConfig(bodyStr, response.header("ETag"))
            }
        } catch (e: Exception) {
            if (affectCircuit) handleException(e)
            null
        }
    }

    private fun parseRemoteConfig(bodyStr: String, etag: String?): RemoteConfig {
        val obj = JsonCodec.parseObject(bodyStr)
        @Suppress("UNCHECKED_CAST")
        val features = obj["features"] as? Map<String, Any?> ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val providers = obj["providers"] as? Map<String, Any?> ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val endpoints = obj["endpoints"] as? Map<String, Any?> ?: emptyMap()

        val enabledProviders = providers.entries
            .filter {
                @Suppress("UNCHECKED_CAST")
                val pMap = it.value as? Map<String, Any?>
                pMap?.get("enabled") as? Boolean ?: false
            }
            .map { it.key }
            .ifEmpty { listOf("betterlyrics", "lrclib", "lrcred", "kugou") }

        return RemoteConfig(
            lyricsApiEnabled = (features["lyricsSync"] as? Boolean) ?: true,
            syncEnabled = (features["cloudSync"] as? Boolean) ?: true,
            updaterEnabled = (features["updater"] as? Boolean) ?: true,
            telemetryEnabled = (features["telemetry"] as? Boolean) ?: false,
            listenTogetherEnabled = (features["listenTogether"] as? Boolean) ?: true,
            maintenanceBanner = obj["maintenanceBanner"] as? String,
            providerFallbackOrder = enabledProviders,
            etag = etag,
            version = (obj["version"] as? Number)?.toInt() ?: 1,
            minAppVersionCode = (obj["minAppVersionCode"] as? Number)?.toInt() ?: 40000,
            apiBaseUrl = (endpoints["apiBaseUrl"] as? String) ?: baseUrl,
            backupMirrorUrl = (endpoints["backupMirrorUrl"] as? String) ?: backupMirrorUrl
        )
    }

    suspend fun checkAppUpdate(): UpdateInfo? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) {
            return@withContext null
        }
        val primary = fetchUpdateFromRoot(baseUrl)
        if (primary != null) return@withContext primary
        if (backupMirrorUrl.isNotBlank() && backupMirrorUrl != baseUrl) {
            return@withContext fetchUpdateFromRoot(backupMirrorUrl, affectCircuit = false)
        }
        null
    }

    private fun fetchUpdateFromRoot(root: String, affectCircuit: Boolean = true): UpdateInfo? {
        return try {
            val request = Request.Builder().url("$root${ApiRoutes.UPDATE_JSON}").build()
            httpClient.newCall(request).execute().use { response ->
                lastHttpStatus = response.code
                if (!response.isSuccessful) {
                    if (affectCircuit) handleHttpError(response.code, response.header("Retry-After"))
                    return null
                }
                if (affectCircuit) circuitBreaker.recordSuccess()
                val body = response.body?.string() ?: return null
                val obj = JsonCodec.parseObject(body)
                @Suppress("UNCHECKED_CAST")
                val changelog = (obj["changelog"] as? List<Any?>)?.mapNotNull { it?.toString() } ?: emptyList()

                UpdateInfo(
                    versionCode = (obj["versionCode"] as? Number)?.toInt() ?: 0,
                    versionName = obj["versionName"]?.toString() ?: "",
                    releaseNotes = changelog.joinToString("\n- ", prefix = if (changelog.isNotEmpty()) "- " else ""),
                    apkUrl = obj["downloadUrl"]?.toString() ?: "",
                    sha256 = obj["sha256"]?.toString() ?: "",
                    expectedSizeBytes = (obj["fileSizeBytes"] as? Number)?.toLong() ?: -1L
                )
            }
        } catch (e: Exception) {
            if (affectCircuit) handleException(e)
            null
        }
    }

    suspend fun registerAnonymous(deviceId: String, recoveryCode: String = deviceId): AuthTokens? =
        authPost(ApiRoutes.AUTH_ANONYMOUS, deviceId, sha256Hex(recoveryCode))

    suspend fun recoverAccount(deviceId: String, recoveryCode: String): AuthTokens? =
        authPost(ApiRoutes.AUTH_RECOVER, deviceId, sha256Hex(recoveryCode))

    private suspend fun authPost(route: String, deviceId: String, recoveryHash: String): AuthTokens? =
        withContext(Dispatchers.IO) {
            if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null
            try {
                val jsonBody = JsonCodec.stringify(
                    mapOf("deviceId" to deviceId, "recoveryHash" to recoveryHash)
                )
                val request = Request.Builder()
                    .url("$baseUrl$route")
                    .post(jsonBody.toRequestBody(jsonMediaType))
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (!response.isSuccessful) {
                        if (response.code != 404) {
                            handleHttpError(response.code, response.header("Retry-After"))
                        }
                        return@withContext null
                    }
                    circuitBreaker.recordSuccess()
                    val body = response.body?.string() ?: return@withContext null
                    parseAuthTokens(body)
                }
            } catch (e: Exception) {
                handleException(e)
                null
            }
        }

    suspend fun refreshAccessToken(tokenToUse: String? = refreshToken): AuthTokens? =
        withContext(Dispatchers.IO) {
            if (isLocalOnly || tokenToUse.isNullOrBlank() || !circuitBreaker.canExecute()) {
                return@withContext null
            }
            try {
                val jsonBody = JsonCodec.stringify(mapOf("refreshToken" to tokenToUse))
                val request = Request.Builder()
                    .url("$baseUrl${ApiRoutes.AUTH_REFRESH}")
                    .post(jsonBody.toRequestBody(jsonMediaType))
                    .build()
                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (!response.isSuccessful) {
                        if (response.code != 401) {
                            handleHttpError(response.code, response.header("Retry-After"))
                        }
                        return@withContext null
                    }
                    circuitBreaker.recordSuccess()
                    val body = response.body?.string() ?: return@withContext null
                    parseAuthTokens(body)
                }
            } catch (e: Exception) {
                handleException(e)
                null
            }
        }

    private fun parseAuthTokens(body: String): AuthTokens? {
        val obj = JsonCodec.parseObject(body)
        val at = obj["accessToken"]?.toString() ?: return null
        val rt = obj["refreshToken"]?.toString() ?: ""
        val exp = (obj["expiresInSeconds"] as? Number)?.toInt() ?: 3600
        val acct = obj["accountId"]?.toString() ?: ""
        accessToken = at
        if (rt.isNotBlank()) refreshToken = rt
        if (acct.isNotBlank()) accountId = acct
        return AuthTokens(at, rt, exp, acct)
    }

    private suspend fun <T> executeWithAuthRetry(
        providedToken: String?,
        block: (activeToken: String) -> Pair<Int, T?>
    ): T? {
        var active = providedToken ?: accessToken ?: return null
        val (status1, res1) = block(active)
        if (status1 == 401 && refreshToken != null) {
            val refreshed = refreshAccessToken(refreshToken) ?: return null
            active = refreshed.accessToken
            val (_, res2) = block(active)
            return res2
        }
        return res1
    }

    suspend fun sync(
        token: String,
        clientHlc: HlcTimestamp,
        outbox: List<SyncChange>
    ): SyncResult? = syncWithCursor(token, 0L, outbox, clientHlc)

    suspend fun syncWithCursor(
        token: String?,
        cursor: Long,
        outbox: List<SyncChange>,
        fallbackHlc: HlcTimestamp = HlcTimestamp(System.currentTimeMillis(), 0, "local")
    ): SyncResult? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null

        val itemsPayload = outbox.map { change ->
            mapOf(
                "id" to change.entityId,
                "type" to change.entityType.toWireType(),
                "payload" to change.payload,
                "hlc" to change.hlc.toString(),
                "deleted" to change.isDeleted,
                "version" to change.version
            )
        }
        val requestJson = JsonCodec.stringify(mapOf("cursor" to cursor, "items" to itemsPayload))

        executeWithAuthRetry(token) { activeToken ->
            try {
                val request = Request.Builder()
                    .url("$baseUrl${ApiRoutes.SYNC}")
                    .header("Authorization", "Bearer $activeToken")
                    .post(requestJson.toRequestBody(jsonMediaType))
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (response.code == 401) {
                        return@executeWithAuthRetry 401 to null
                    }
                    if (!response.isSuccessful) {
                        handleHttpError(response.code, response.header("Retry-After"))
                        return@executeWithAuthRetry response.code to null
                    }
                    circuitBreaker.recordSuccess()
                    val body = response.body?.string() ?: return@executeWithAuthRetry response.code to null
                    response.code to parseSyncResponse(body, fallbackHlc)
                }
            } catch (e: Exception) {
                handleException(e)
                0 to null
            }
        }
    }

    suspend fun pullSync(
        token: String?,
        cursor: Long = 0L,
        fallbackHlc: HlcTimestamp = HlcTimestamp(System.currentTimeMillis(), 0, "local")
    ): SyncResult? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null

        executeWithAuthRetry(token) { activeToken ->
            try {
                val request = Request.Builder()
                    .url("$baseUrl${ApiRoutes.SYNC}?cursor=$cursor")
                    .header("Authorization", "Bearer $activeToken")
                    .get()
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (response.code == 401) return@executeWithAuthRetry 401 to null
                    if (!response.isSuccessful) {
                        handleHttpError(response.code, response.header("Retry-After"))
                        return@executeWithAuthRetry response.code to null
                    }
                    circuitBreaker.recordSuccess()
                    val body = response.body?.string() ?: return@executeWithAuthRetry response.code to null
                    response.code to parseSyncResponse(body, fallbackHlc)
                }
            } catch (e: Exception) {
                handleException(e)
                0 to null
            }
        }
    }

    private fun parseSyncResponse(body: String, fallbackHlc: HlcTimestamp): SyncResult {
        val obj = JsonCodec.parseObject(body)
        val nextCursor = (obj["cursor"] as? Number)?.toLong() ?: 0L
        val tier = obj["budgetTier"]?.toString() ?: "TIER_0_NORMAL"
        val serverHlcStr = obj["serverHlc"]?.toString()
        val serverHlc = runCatching {
            if (!serverHlcStr.isNullOrBlank()) HlcTimestamp.parse(serverHlcStr) else fallbackHlc
        }.getOrDefault(fallbackHlc)

        val rawItems = obj["items"] as? List<*> ?: emptyList<Any?>()
        val remoteChanges = rawItems.mapNotNull { entry ->
            @Suppress("UNCHECKED_CAST")
            val m = entry as? Map<String, Any?> ?: return@mapNotNull null
            val id = m["id"]?.toString() ?: return@mapNotNull null
            val typeStr = m["type"]?.toString() ?: "setting"
            val payload = m["payload"]?.toString() ?: ""
            val hlcStr = m["hlc"]?.toString() ?: return@mapNotNull null
            val deleted = (m["deleted"] as? Boolean) ?: false
            val version = (m["version"] as? Number)?.toInt() ?: 1
            runCatching {
                SyncChange(
                    entityType = SyncEntityType.fromWireType(typeStr),
                    entityId = id,
                    hlc = HlcTimestamp.parse(hlcStr),
                    isDeleted = deleted,
                    payload = payload,
                    version = version
                )
            }.getOrNull()
        }

        return SyncResult(
            serverHlc = serverHlc,
            appliedChanges = remoteChanges,
            budgetTier = tier,
            isSuccess = true,
            cursor = nextCursor
        )
    }

    suspend fun fetchLyrics(
        trackId: String,
        provider: String = "lrclib",
        title: String? = null,
        artist: String? = null,
        durationSec: Long? = null
    ): String? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null
        try {
            val urlBuilder = "$baseUrl${ApiRoutes.LYRICS}".toHttpUrlOrNull()?.newBuilder()
                ?: return@withContext null
            urlBuilder.addQueryParameter("trackId", trackId)
            urlBuilder.addQueryParameter("provider", provider)
            if (!title.isNullOrBlank()) urlBuilder.addQueryParameter("title", title)
            if (!artist.isNullOrBlank()) urlBuilder.addQueryParameter("artist", artist)
            if (durationSec != null && durationSec > 0) urlBuilder.addQueryParameter("duration", durationSec.toString())

            val request = Request.Builder().url(urlBuilder.build()).get().build()
            httpClient.newCall(request).execute().use { response ->
                lastHttpStatus = response.code
                if (response.code == 404) {
                    circuitBreaker.recordSuccess()
                    return@withContext null
                }
                if (!response.isSuccessful) {
                    handleHttpError(response.code, response.header("Retry-After"))
                    return@withContext null
                }
                circuitBreaker.recordSuccess()
                response.body?.string()
            }
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    suspend fun fetchCharts(): String? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null
        try {
            val request = Request.Builder().url("$baseUrl${ApiRoutes.CHARTS}").get().build()
            httpClient.newCall(request).execute().use { response ->
                lastHttpStatus = response.code
                if (!response.isSuccessful) {
                    handleHttpError(response.code, response.header("Retry-After"))
                    return@withContext null
                }
                circuitBreaker.recordSuccess()
                response.body?.string()
            }
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    suspend fun sendTelemetry(events: List<TelemetryEvent>): Boolean = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute() || events.isEmpty()) {
            return@withContext false
        }
        var allOk = true
        for (ev in events) {
            val payload = JsonCodec.stringify(
                mapOf(
                    "appVersion" to ev.appVersion,
                    "osVersion" to (ev.details["osVersion"] ?: "unknown"),
                    "abi" to (ev.details["abi"] ?: "unknown"),
                    "errorType" to ev.eventType,
                    "redactedMessage" to (ev.details["message"] ?: ev.eventType).take(512),
                    "occurredAtMs" to ev.timestamp
                )
            )
            try {
                val request = Request.Builder()
                    .url("$baseUrl${ApiRoutes.TELEMETRY}")
                    .post(payload.toRequestBody(jsonMediaType))
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (response.code == 204 || response.isSuccessful) {
                        circuitBreaker.recordSuccess()
                    } else {
                        handleHttpError(response.code, response.header("Retry-After"))
                        allOk = false
                    }
                }
            } catch (e: Exception) {
                handleException(e)
                allOk = false
            }
        }
        allOk
    }

    suspend fun exportUserData(token: String? = accessToken): String? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null

        executeWithAuthRetry(token) { activeToken ->
            try {
                val request = Request.Builder()
                    .url("$baseUrl${ApiRoutes.USER_EXPORT}")
                    .header("Authorization", "Bearer $activeToken")
                    .get()
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (response.code == 401) return@executeWithAuthRetry 401 to null
                    if (!response.isSuccessful) {
                        handleHttpError(response.code, response.header("Retry-After"))
                        return@executeWithAuthRetry response.code to null
                    }
                    circuitBreaker.recordSuccess()
                    response.code to response.body?.string()
                }
            } catch (e: Exception) {
                handleException(e)
                0 to null
            }
        }
    }

    suspend fun deleteUserAccount(token: String? = accessToken): Boolean = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext false

        val ok = executeWithAuthRetry(token) { activeToken ->
            try {
                val request = Request.Builder()
                    .url("$baseUrl${ApiRoutes.USER_DELETE}")
                    .header("Authorization", "Bearer $activeToken")
                    .post("{}".toRequestBody(jsonMediaType))
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (response.code == 401) return@executeWithAuthRetry 401 to false
                    if (!response.isSuccessful) {
                        handleHttpError(response.code, response.header("Retry-After"))
                        return@executeWithAuthRetry response.code to false
                    }
                    circuitBreaker.recordSuccess()
                    response.code to true
                }
            } catch (e: Exception) {
                handleException(e)
                0 to false
            }
        } ?: false

        if (ok) {
            accessToken = null
            refreshToken = null
            accountId = null
        }
        ok
    }

    suspend fun createRoom(hostName: String? = null, trackId: String? = null): RoomState? =
        withContext(Dispatchers.IO) {
            if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null
            try {
                val bodyMap = mutableMapOf<String, Any?>()
                if (!hostName.isNullOrBlank()) bodyMap["hostName"] = hostName
                if (!trackId.isNullOrBlank()) bodyMap["trackId"] = trackId
                val request = Request.Builder()
                    .url("$baseUrl${ApiRoutes.ROOM}")
                    .post(JsonCodec.stringify(bodyMap).toRequestBody(jsonMediaType))
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    lastHttpStatus = response.code
                    if (!response.isSuccessful) {
                        handleHttpError(response.code, response.header("Retry-After"))
                        return@withContext null
                    }
                    circuitBreaker.recordSuccess()
                    val body = response.body?.string() ?: return@withContext null
                    parseRoomState(body, isHost = true)
                }
            } catch (e: Exception) {
                handleException(e)
                null
            }
        }

    suspend fun getRoomInfo(code: String): RoomState? = withContext(Dispatchers.IO) {
        if (isLocalOnly || !circuitBreaker.canExecute()) return@withContext null
        try {
            val request = Request.Builder()
                .url("$baseUrl${ApiRoutes.roomByCode(code)}")
                .get()
                .build()

            httpClient.newCall(request).execute().use { response ->
                lastHttpStatus = response.code
                if (!response.isSuccessful) {
                    handleHttpError(response.code, response.header("Retry-After"))
                    return@withContext null
                }
                circuitBreaker.recordSuccess()
                val body = response.body?.string() ?: return@withContext null
                parseRoomState(body, isHost = false)
            }
        } catch (e: Exception) {
            handleException(e)
            null
        }
    }

    private fun parseRoomState(body: String, isHost: Boolean): RoomState {
        val obj = JsonCodec.parseObject(body)
        return RoomState(
            code = obj["roomCode"]?.toString() ?: "",
            hostId = if (isHost) "local" else "",
            isHost = isHost,
            currentTrackId = obj["currentTrackId"] as? String,
            hostPositionMs = (obj["playbackPositionMs"] as? Number)?.toLong() ?: 0L,
            isPlaying = (obj["isPlaying"] as? Boolean) ?: false,
            status = RoomStatus.CONNECTED
        )
    }

    private fun handleHttpError(code: Int, retryAfterHeader: String?) {
        val retryAfterSec = retryAfterHeader?.toLongOrNull()
        // Client payload/validation errors (400, 413) do not trip the backend outage circuit breaker
        if (code == 429 || code >= 500) {
            circuitBreaker.recordFailure(code, retryAfterSec)
        }
        PlaybackLogger.log("SoftifyEdge", "HTTP error $code (Retry-After: $retryAfterSec)")
    }

    private fun handleException(e: Exception) {
        if (e is IOException) {
            circuitBreaker.recordFailure()
        }
        PlaybackLogger.log("SoftifyEdge", "Network exception: ${e.message}")
    }
}
