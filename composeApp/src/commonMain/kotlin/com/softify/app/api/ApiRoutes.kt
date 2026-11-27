package com.softify.app.api

/**
 * Single client-side source of truth for all Softify Edge backend paths.
 * Must stay 1:1 with server/openapi.json (verified by ApiContractAndRoutesLintTest).
 */
object ApiRoutes {
    const val HEALTHZ = "/healthz"
    const val READYZ = "/readyz"
    const val CONFIG_JSON = "/config.json"
    const val UPDATE_JSON = "/update.json"
    const val HOME_SHELVES_JSON = "/home_shelves.json"

    const val AUTH_ANONYMOUS = "/v1/auth/anonymous"
    const val AUTH_REFRESH = "/v1/auth/refresh"
    const val AUTH_RECOVER = "/v1/auth/recover"

    const val SYNC = "/v1/sync"
    const val LYRICS = "/v1/lyrics"
    const val CHARTS = "/v1/charts"
    const val TELEMETRY = "/v1/telemetry"

    const val USER_EXPORT = "/v1/user/export"
    const val USER_DELETE = "/v1/user/delete"

    const val ROOM = "/v1/room"
    const val ROOM_BY_CODE_TEMPLATE = "/v1/room/{code}"

    fun roomByCode(code: String): String = "$ROOM/${code.uppercase()}"

    val allContractPaths: Set<String> = setOf(
        HEALTHZ,
        READYZ,
        CONFIG_JSON,
        UPDATE_JSON,
        HOME_SHELVES_JSON,
        AUTH_ANONYMOUS,
        AUTH_REFRESH,
        AUTH_RECOVER,
        SYNC,
        LYRICS,
        CHARTS,
        TELEMETRY,
        USER_EXPORT,
        USER_DELETE,
        ROOM,
        ROOM_BY_CODE_TEMPLATE
    )
}
