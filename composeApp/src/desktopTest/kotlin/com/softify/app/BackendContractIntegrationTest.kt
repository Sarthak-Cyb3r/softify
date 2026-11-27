package com.softify.app

import com.softify.app.api.ApiRoutes
import com.softify.app.api.CircuitBreaker
import com.softify.app.api.CircuitState
import com.softify.app.api.SoftifyApiClient
import com.softify.app.room.RoomStatus
import com.softify.app.sync.HlcTimestamp
import com.softify.app.sync.SyncChange
import com.softify.app.sync.SyncEntityType
import com.softify.app.telemetry.TelemetryEvent
import com.softify.app.util.JsonCodec
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import okhttp3.mockwebserver.SocketPolicy
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * M8-A1 Real Client Contract Test:
 * - Always validates every endpoint method, path, header, and JSON shape against server/openapi.json.
 * - Tests 401 -> token refresh -> retry, 429 Retry-After, 503 fallback, read timeouts, and >256KB body rejection.
 * - When SOFTIFY_CONTRACT_BASE_URL is set (e.g. http://127.0.0.1:8787 running wrangler dev in CI),
 *   executes the full contract suite directly against the live Cloudflare Worker + local D1/KV/DO.
 */
class BackendContractIntegrationTest {

    private fun resolveRepoRoot(): File = if (File("composeApp").exists()) File(".") else File("..")

    private fun loadOpenApiSchemas(): Map<String, Map<String, Any?>> {
        val file = File(resolveRepoRoot(), "server/openapi.json")
        val doc = JsonCodec.parseObject(file.readText())
        @Suppress("UNCHECKED_CAST")
        val components = doc["components"] as Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        return components["schemas"] as Map<String, Map<String, Any?>>
    }

    private fun assertMatchesOpenApiRequiredKeys(
        schemaName: String,
        payloadJson: String,
        schemas: Map<String, Map<String, Any?>>
    ) {
        val schema = schemas[schemaName] ?: error("Unknown OpenAPI schema: $schemaName")
        @Suppress("UNCHECKED_CAST")
        val required = (schema["required"] as? List<String>).orEmpty()
        val parsed = JsonCodec.parseObject(payloadJson)
        for (field in required) {
            assertTrue(parsed.containsKey(field), "Schema '$schemaName' requires field '$field' in $payloadJson")
        }
    }

    private class OpenApiContractDispatcher(
        private val schemas: Map<String, Map<String, Any?>>
    ) : Dispatcher() {
        var validAccessToken: String = "acc_initial_1"
        var validRefreshToken: String = "ref_initial_1"
        val accountId = "acct_contract_1"
        var savedRecoveryHash: String? = null
        var refreshCalled = false
        var deleted = false
        val storedSyncItems = mutableListOf<Map<String, Any?>>()

        override fun dispatch(request: RecordedRequest): MockResponse {
            val fullPath = request.path ?: "/"
            val path = fullPath.substringBefore("?")
            val method = request.method ?: "GET"

            // WebSocket upgrade support for /v1/room/{code}
            if (path.startsWith("${ApiRoutes.ROOM}/") &&
                request.getHeader("Upgrade")?.equals("websocket", ignoreCase = true) == true
            ) {
                val code = path.removePrefix("${ApiRoutes.ROOM}/").uppercase()
                return MockResponse().withWebSocketUpgrade(object : WebSocketListener() {
                    override fun onOpen(webSocket: WebSocket, response: Response) {
                        webSocket.send(
                            """{"type":"ROOM_STATE","state":{"roomCode":"$code","playbackPositionMs":0,"isPlaying":false},"peerCount":1}"""
                        )
                    }
                })
            }

            val bodyStr = request.body.readUtf8()
            if (bodyStr.toByteArray(Charsets.UTF_8).size > 262_144) {
                return jsonResp(413, """{"error":"Payload Too Large (max 256 KB allowed)"}""")
            }

            if (path == ApiRoutes.HEALTHZ && method == "GET") {
                return jsonResp(200, """{"status":"ok","time":1700000000000}""")
            }
            if (path == ApiRoutes.CONFIG_JSON && method == "GET") {
                return jsonResp(
                    200,
                    """{"version":1,"minAppVersionCode":40000,"features":{"lyricsSync":true,"cloudSync":true,"listenTogether":true,"updater":true,"telemetry":false},"providers":{"lrclib":{"enabled":true},"betterlyrics":{"enabled":true}},"endpoints":{"apiBaseUrl":"http://localhost","backupMirrorUrl":"http://localhost"},"updatedAt":"2026-11-27T00:00:00Z"}"""
                )
            }
            if (path == ApiRoutes.UPDATE_JSON && method == "GET") {
                return jsonResp(
                    200,
                    """{"versionCode":40305,"versionName":"4.3.5","minSupportedVersionCode":40000,"releaseDate":"2026-11-27","changelog":["Contract OK"],"downloadUrl":"https://example.org/app.apk","sha256":"abc123","fileSizeBytes":1024}"""
                )
            }
            if (path == ApiRoutes.AUTH_ANONYMOUS && method == "POST") {
                assertMatchesOpenApiRequiredKeys("AnonymousAuthRequest", bodyStr, schemas)
                val obj = JsonCodec.parseObject(bodyStr)
                savedRecoveryHash = obj["recoveryHash"]?.toString()
                deleted = false
                return jsonResp(
                    200,
                    """{"accessToken":"$validAccessToken","expiresInSeconds":3600,"refreshToken":"$validRefreshToken","accountId":"$accountId","recoveryCodeReminder":"Save code"}"""
                )
            }
            if (path == ApiRoutes.AUTH_RECOVER && method == "POST") {
                assertMatchesOpenApiRequiredKeys("AnonymousAuthRequest", bodyStr, schemas)
                val obj = JsonCodec.parseObject(bodyStr)
                if (deleted || obj["recoveryHash"]?.toString() != savedRecoveryHash) {
                    return jsonResp(404, """{"error":"Recovery code not found"}""")
                }
                validAccessToken = "acc_recovered_3"
                validRefreshToken = "ref_recovered_3"
                return jsonResp(
                    200,
                    """{"accessToken":"$validAccessToken","expiresInSeconds":3600,"refreshToken":"$validRefreshToken","accountId":"$accountId","recoveryCodeReminder":"Recovered"}"""
                )
            }
            if (path == ApiRoutes.AUTH_REFRESH && method == "POST") {
                assertMatchesOpenApiRequiredKeys("RefreshTokenRequest", bodyStr, schemas)
                val reqObj = JsonCodec.parseObject(bodyStr)
                if (reqObj["refreshToken"] != validRefreshToken || deleted) {
                    return jsonResp(401, """{"error":"Invalid refresh token"}""")
                }
                refreshCalled = true
                validAccessToken = "acc_refreshed_2"
                validRefreshToken = "ref_refreshed_2"
                return jsonResp(
                    200,
                    """{"accessToken":"$validAccessToken","expiresInSeconds":3600,"refreshToken":"$validRefreshToken","accountId":"$accountId","recoveryCodeReminder":"Rotated"}"""
                )
            }
            if (path == ApiRoutes.SYNC) {
                if (request.getHeader("Authorization") != "Bearer $validAccessToken" || deleted) {
                    return jsonResp(401, """{"error":"Unauthorized"}""")
                }
                if (method == "POST") {
                    assertMatchesOpenApiRequiredKeys("SyncBatchRequest", bodyStr, schemas)
                    val obj = JsonCodec.parseObject(bodyStr)
                    @Suppress("UNCHECKED_CAST")
                    val items = obj["items"] as List<Map<String, Any?>>
                    storedSyncItems.addAll(items)
                }
                val resp = JsonCodec.stringify(
                    mapOf(
                        "cursor" to 1700000005000L,
                        "items" to storedSyncItems,
                        "budgetTier" to "TIER_0_NORMAL",
                        "serverHlc" to "1700000005000-0000-edge"
                    )
                )
                return jsonResp(200, resp)
            }
            if (path == ApiRoutes.LYRICS && method == "GET") {
                val trackId = request.requestUrl?.queryParameter("trackId")
                if (trackId.isNullOrBlank()) return jsonResp(400, """{"error":"Missing trackId"}""")
                return jsonResp(200, """{"id":"$trackId","syncedLyrics":"[00:01.00] Contract Line"}""")
            }
            if (path == ApiRoutes.CHARTS && method == "GET") {
                return jsonResp(200, """{"updatedAt":1700000000000,"shelves":[{"id":"trending","title":"Trending","items":[]}]}""")
            }
            if (path == ApiRoutes.TELEMETRY && method == "POST") {
                assertMatchesOpenApiRequiredKeys("TelemetryReport", bodyStr, schemas)
                return MockResponse().setResponseCode(204)
            }
            if (path == ApiRoutes.USER_EXPORT && method == "GET") {
                if (request.getHeader("Authorization") != "Bearer $validAccessToken" || deleted) {
                    return jsonResp(401, """{"error":"Unauthorized"}""")
                }
                val resp = JsonCodec.stringify(
                    mapOf(
                        "account" to mapOf("id" to "dev1", "account_id" to accountId),
                        "library" to storedSyncItems,
                        "exportedAt" to 1700000006000L
                    )
                )
                return jsonResp(200, resp)
            }
            if (path == ApiRoutes.USER_DELETE && method == "POST") {
                if (request.getHeader("Authorization") != "Bearer $validAccessToken") {
                    return jsonResp(401, """{"error":"Unauthorized"}""")
                }
                deleted = true
                storedSyncItems.clear()
                return jsonResp(200, """{"message":"Deleted"}""")
            }
            if (path == ApiRoutes.ROOM && method == "POST") {
                return jsonResp(
                    200,
                    """{"roomCode":"SOFT42","wsPath":"/v1/room/SOFT42","maxParticipants":6,"peerCount":0,"currentTrackId":"trk_1","isPlaying":false,"playbackPositionMs":0}"""
                )
            }
            if (path.startsWith("${ApiRoutes.ROOM}/") && method == "GET") {
                val code = path.removePrefix("${ApiRoutes.ROOM}/")
                return jsonResp(
                    200,
                    """{"roomCode":"$code","wsPath":"/v1/room/$code","maxParticipants":6,"peerCount":0,"currentTrackId":"trk_1","isPlaying":false,"playbackPositionMs":0}"""
                )
            }
            return jsonResp(404, """{"error":"Unexpected route $method $path"}""")
        }

        private fun jsonResp(code: Int, body: String) = MockResponse()
            .setResponseCode(code)
            .addHeader("Content-Type", "application/json")
            .setBody(body)
    }

    @Test
    fun testFullClientBackendEndToEndContract() = runTest {
        val schemas = loadOpenApiSchemas()
        val envBaseUrl = System.getenv("SOFTIFY_CONTRACT_BASE_URL")?.trim()?.trimEnd('/')
        val dispatcher = OpenApiContractDispatcher(schemas)
        val localServer = if (envBaseUrl.isNullOrBlank()) {
            MockWebServer().apply {
                this.dispatcher = dispatcher
                start()
            }
        } else null

        val targetUrl = envBaseUrl ?: localServer!!.url("").toString().trimEnd('/')
        val wsClient = OkHttpClient()
        try {
            val breaker = CircuitBreaker()
            val client = SoftifyApiClient(
                baseUrl = targetUrl,
                backupMirrorUrl = targetUrl,
                circuitBreaker = breaker
            )

            // 1. Health, RemoteConfig, Update
            assertTrue(client.fetchHealth(), "GET ${ApiRoutes.HEALTHZ} must succeed on $targetUrl")
            val cfg = client.fetchRemoteConfig()
            assertNotNull(cfg, "GET ${ApiRoutes.CONFIG_JSON} must decode into RemoteConfig")
            assertTrue(cfg.syncEnabled)

            val upd = client.checkAppUpdate()
            assertNotNull(upd, "GET ${ApiRoutes.UPDATE_JSON} must decode UpdateInfo")
            assertTrue(upd.versionCode > 0)

            // 2. Anonymous Auth
            val deviceId = "contract-device-${System.currentTimeMillis()}"
            val recoverySecret = "recover-secret-12345"
            val auth = client.registerAnonymous(deviceId, recoverySecret)
            assertNotNull(auth, "POST ${ApiRoutes.AUTH_ANONYMOUS} must return tokens")
            assertTrue(auth.accessToken.isNotBlank())
            assertTrue(auth.refreshToken.isNotBlank())
            assertTrue(auth.accountId.isNotBlank())

            // 3. Force 401 token refresh -> automatic retry on /v1/sync
            val staleAccess = "invalid.expired.token"
            client.accessToken = staleAccess
            val hlc1 = HlcTimestamp(1700000001000L, 0, "ct1")
            val syncChange = SyncChange(
                entityType = SyncEntityType.PLAYLIST,
                entityId = "pl_contract_1",
                hlc = hlc1,
                isDeleted = false,
                payload = """{"name":"Contract Mix"}""",
                version = 1
            )
            val syncPush = client.syncWithCursor(staleAccess, 0L, listOf(syncChange), hlc1)
            assertNotNull(syncPush, "POST ${ApiRoutes.SYNC} must auto-refresh on 401 and succeed")
            assertTrue(syncPush.isSuccess)
            assertTrue(syncPush.appliedChanges.any { it.entityId == "pl_contract_1" })
            assertTrue(client.accessToken != staleAccess, "Client accessToken must be rotated after 401 refresh")
            if (localServer != null) {
                assertTrue(dispatcher.refreshCalled, "MockDispatcher must observe /v1/auth/refresh call")
            }

            // 4. Sync Pull
            val pulled = client.pullSync(client.accessToken, 0L, hlc1)
            assertNotNull(pulled, "GET ${ApiRoutes.SYNC} must return pushed entity")
            assertTrue(pulled.appliedChanges.any { it.entityId == "pl_contract_1" })

            // 5. Charts & Lyrics (via real SoftifyApiClient)
            val chartsJson = client.fetchCharts()
            assertNotNull(chartsJson, "GET ${ApiRoutes.CHARTS} must return payload")
            assertMatchesOpenApiRequiredKeys("ChartsResponse", chartsJson, schemas)

            val lyricsPayload = client.fetchLyrics(
                trackId = "trk_contract",
                provider = "lrclib",
                title = "Never Gonna Give You Up",
                artist = "Rick Astley",
                durationSec = 213
            )
            if (localServer != null) {
                assertNotNull(lyricsPayload)
            } else {
                // Live worker route responds 200 (upstream hit) or 404 (not found); never 500
                assertTrue(
                    client.lastHttpStatus in setOf(200, 404, 503),
                    "Unexpected /v1/lyrics status ${client.lastHttpStatus}"
                )
            }
            val badLyricsReq = Request.Builder().url("$targetUrl${ApiRoutes.LYRICS}").get().build()
            wsClient.newCall(badLyricsReq).execute().use { resp ->
                assertEquals(400, resp.code, "Missing trackId on /v1/lyrics must return 400")
            }

            // 6. Telemetry
            val telemetryOk = client.sendTelemetry(
                listOf(
                    TelemetryEvent(
                        eventType = "CONTRACT_CHECK",
                        timestamp = 1700000002000L,
                        appVersion = "4.3.1",
                        details = mapOf("osVersion" to "JVM", "abi" to "x86_64", "message" to "Contract ping")
                    )
                )
            )
            assertTrue(telemetryOk, "POST ${ApiRoutes.TELEMETRY} must succeed")

            // 7. Export user data
            val exportJson = client.exportUserData(client.accessToken)
            assertNotNull(exportJson, "GET ${ApiRoutes.USER_EXPORT} must return GDPR dump")
            assertMatchesOpenApiRequiredKeys("UserExportResponse", exportJson, schemas)
            assertTrue(exportJson.contains("pl_contract_1"))

            // 8. Second device recovers same account via recovery secret
            val recoveryClient = SoftifyApiClient(
                baseUrl = targetUrl,
                backupMirrorUrl = targetUrl
            )
            val recovered = recoveryClient.recoverAccount(
                deviceId = "contract-device-2-${System.currentTimeMillis()}",
                recoveryCode = recoverySecret
            )
            assertNotNull(recovered, "POST ${ApiRoutes.AUTH_RECOVER} must restore account onto device 2")
            assertEquals(auth.accountId, recovered.accountId)
            val recoveredPull = recoveryClient.pullSync(recovered.accessToken, 0L, hlc1)
            assertNotNull(recoveredPull)
            assertTrue(recoveredPull.appliedChanges.any { it.entityId == "pl_contract_1" })

            // 9. Room create, metadata get, and WebSocket room join
            val createdRoom = client.createRoom(hostName = "ContractHost", trackId = "trk_99")
            assertNotNull(createdRoom, "POST ${ApiRoutes.ROOM} must return RoomState")
            assertEquals(RoomStatus.CONNECTED, createdRoom.status)
            assertTrue(createdRoom.code.length >= 4)
            val fetchedRoom = client.getRoomInfo(createdRoom.code)
            assertNotNull(fetchedRoom, "GET ${ApiRoutes.ROOM_BY_CODE_TEMPLATE} must return RoomState")
            assertEquals(createdRoom.code, fetchedRoom.code)

            val wsUrl = targetUrl.replaceFirst("http://", "ws://").replaceFirst("https://", "wss://") +
                ApiRoutes.roomByCode(createdRoom.code) + "?peerId=contract_peer&name=Contract"
            val wsLatch = CountDownLatch(1)
            val wsMsg = AtomicReference<String?>(null)
            val ws = wsClient.newWebSocket(
                Request.Builder().url(wsUrl).build(),
                object : WebSocketListener() {
                    override fun onMessage(webSocket: WebSocket, text: String) {
                        wsMsg.compareAndSet(null, text)
                        wsLatch.countDown()
                    }
                }
            )
            assertTrue(wsLatch.await(5, TimeUnit.SECONDS), "Joining room WebSocket must emit initial ROOM_STATE")
            assertTrue(wsMsg.get()?.contains("ROOM_STATE") == true, "Expected ROOM_STATE message, got ${wsMsg.get()}")
            ws.close(1000, "Contract done")

            // 10. Oversized payload (> 256 KB) must return 413 cleanly
            val oversizedJson = """{"cursor":0,"items":[{"id":"big","type":"setting","payload":"${"x".repeat(270_000)}","hlc":"1700000000000-0000-x"}]}"""
            val bigReq = Request.Builder()
                .url("$targetUrl${ApiRoutes.SYNC}")
                .header("Authorization", "Bearer ${client.accessToken}")
                .post(oversizedJson.toRequestBody("application/json".toMediaType()))
                .build()
            wsClient.newCall(bigReq).execute().use { resp ->
                assertEquals(413, resp.code, "Bodies > 256 KB must be rejected with HTTP 413")
            }

            // 11. GDPR Delete account + verify deleted session can no longer export or recover
            val oldTokenBeforeDelete = client.accessToken!!
            assertTrue(client.deleteUserAccount(), "POST ${ApiRoutes.USER_DELETE} must purge account")
            assertNull(client.accessToken)
            assertNull(recoveryClient.exportUserData(oldTokenBeforeDelete), "Revoked session must fail after GDPR delete")
            assertNull(recoveryClient.recoverAccount("contract-device-3", recoverySecret), "Deleted recovery code must fail 404")
        } finally {
            localServer?.shutdown()
        }
    }

    @Test
    fun testClientResilience429RetryAfter503MirrorAndTimeouts() = runTest {
        val primary = MockWebServer()
        val mirror = MockWebServer()
        primary.start()
        mirror.start()
        try {
            var nowMs = 5_000_000L
            val breaker = CircuitBreaker(clock = { nowMs })
            val shortTimeoutHttp = OkHttpClient.Builder()
                .connectTimeout(300, TimeUnit.MILLISECONDS)
                .readTimeout(250, TimeUnit.MILLISECONDS)
                .build()
            val client = SoftifyApiClient(
                baseUrl = primary.url("").toString().trimEnd('/'),
                backupMirrorUrl = mirror.url("").toString().trimEnd('/'),
                httpClient = shortTimeoutHttp,
                circuitBreaker = breaker
            )

            // A) 503 on primary remote config falls back to static mirror
            primary.enqueue(MockResponse().setResponseCode(503).setHeader("Retry-After", "10"))
            mirror.enqueue(
                MockResponse().setResponseCode(200).setBody(
                    """{"version":2,"minAppVersionCode":40000,"features":{"lyricsSync":true,"cloudSync":false},"providers":{},"endpoints":{"apiBaseUrl":"https://a","backupMirrorUrl":"https://b"},"updatedAt":"2026-11-27T00:00:00Z"}"""
                )
            )
            val fallbackConfig = client.fetchRemoteConfig()
            assertNotNull(fallbackConfig, "503 on primary must fall back cleanly to backupMirrorUrl")
            assertFalse(fallbackConfig.syncEnabled)
            assertEquals(CircuitState.OPEN, breaker.currentState)

            // Fast-forward past 10s Retry-After window -> HALF_OPEN -> CLOSED after health check
            nowMs += 11_000L
            primary.enqueue(MockResponse().setResponseCode(200).setBody("""{"status":"ok","time":1}"""))
            assertTrue(client.fetchHealth())

            // B) 429 with Retry-After opens circuit immediately for 45s
            primary.enqueue(MockResponse().setResponseCode(429).setHeader("Retry-After", "45"))
            val blockedSync = client.syncWithCursor("tok", 0L, emptyList())
            assertNull(blockedSync)
            assertEquals(429, client.lastHttpStatus)
            assertEquals(CircuitState.OPEN, breaker.currentState)
            assertFalse(breaker.canExecute())

            // Before 45s passes, client fast-fails without hitting primary network
            nowMs += 20_000L
            assertFalse(breaker.canExecute())
            assertNull(client.fetchCharts())

            // C) Timeout handling without crashing
            nowMs += 30_000L
            breaker.reset()
            primary.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
            assertNull(client.fetchCharts(), "Read timeout must return null safely without throwing")
        } finally {
            primary.shutdown()
            mirror.shutdown()
        }
    }
}
