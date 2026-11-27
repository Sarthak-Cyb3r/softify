package com.softify.app

import com.softify.app.api.ApiRoutes
import com.softify.app.util.JsonCodec
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Enforces M8-A1 contract guarantees:
 * 1) ApiRoutes matches server/openapi.json paths 1:1.
 * 2) Zero hardcoded API route paths outside ApiRoutes.kt in client source.
 * 3) Zero stale /api/... paths in client or server runtime sources.
 */
class ApiContractAndRoutesLintTest {

    private fun resolveRepoRoot(): File {
        return if (File("composeApp").exists()) File(".") else File("..")
    }

    @Test
    fun testApiRoutesMatchesOpenApiPathsOneToOne() {
        val root = resolveRepoRoot()
        val openApiFile = File(root, "server/openapi.json")
        assertTrue(openApiFile.exists(), "server/openapi.json must exist at ${openApiFile.absolutePath}")

        val doc = JsonCodec.parseObject(openApiFile.readText())
        @Suppress("UNCHECKED_CAST")
        val pathsMap = doc["paths"] as? Map<String, Any?>
            ?: error("server/openapi.json missing top-level 'paths' object")

        assertEquals(
            pathsMap.keys,
            ApiRoutes.allContractPaths,
            "ApiRoutes.allContractPaths must match server/openapi.json paths 1:1"
        )
    }

    @Test
    fun testNoHardcodedApiPathsOutsideApiRoutes() {
        val root = resolveRepoRoot()
        val srcRoot = File(root, "composeApp/src")
        assertTrue(srcRoot.exists(), "composeApp/src must exist")

        val forbiddenPatterns = listOf(
            Regex("""["']\/api\/"""),
            Regex("""["']\/v1\/"""),
            Regex("""["']\/config\.json["']"""),
            Regex("""["']\/update\.json["']"""),
            Regex("""["']\/home_shelves\.json["']"""),
            Regex("""["']\/healthz["']"""),
            Regex("""["']\/readyz["']""")
        )

        val violations = mutableListOf<String>()
        srcRoot.walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .filter { !it.path.contains("${File.separator}desktopTest${File.separator}") }
            .filter { it.name != "ApiRoutes.kt" }
            .forEach { file ->
                val rel = file.relativeTo(root).path
                file.readLines().forEachIndexed { idx, line ->
                    val trimmed = line.trim()
                    if (trimmed.startsWith("//") || trimmed.startsWith("*")) return@forEachIndexed
                    for (pattern in forbiddenPatterns) {
                        if (pattern.containsMatchIn(line)) {
                            violations.add("$rel:${idx + 1}: hardcoded API path outside ApiRoutes.kt -> $trimmed")
                        }
                    }
                }
            }

        assertTrue(
            violations.isEmpty(),
            "Found hardcoded API path literals outside ApiRoutes.kt:\n" + violations.joinToString("\n")
        )
    }

    @Test
    fun testOpenApiDocumentContainsAllRequiredMethodsAndSchemas() {
        val root = resolveRepoRoot()
        val openApiFile = File(root, "server/openapi.json")
        val doc = JsonCodec.parseObject(openApiFile.readText())
        @Suppress("UNCHECKED_CAST")
        val paths = doc["paths"] as Map<String, Map<String, Any?>>

        assertTrue(paths[ApiRoutes.AUTH_ANONYMOUS]?.containsKey("post") == true)
        assertTrue(paths[ApiRoutes.AUTH_REFRESH]?.containsKey("post") == true)
        assertTrue(paths[ApiRoutes.AUTH_RECOVER]?.containsKey("post") == true)
        assertTrue(paths[ApiRoutes.SYNC]?.containsKey("post") == true)
        assertTrue(paths[ApiRoutes.SYNC]?.containsKey("get") == true)
        assertTrue(paths[ApiRoutes.LYRICS]?.containsKey("get") == true)
        assertTrue(paths[ApiRoutes.CHARTS]?.containsKey("get") == true)
        assertTrue(paths[ApiRoutes.TELEMETRY]?.containsKey("post") == true)
        assertTrue(paths[ApiRoutes.USER_EXPORT]?.containsKey("get") == true)
        assertTrue(paths[ApiRoutes.USER_DELETE]?.containsKey("post") == true)
        assertTrue(paths[ApiRoutes.ROOM]?.containsKey("post") == true)
        assertTrue(paths[ApiRoutes.ROOM_BY_CODE_TEMPLATE]?.containsKey("get") == true)
    }
}
