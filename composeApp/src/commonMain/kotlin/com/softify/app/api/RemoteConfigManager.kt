package com.softify.app.api

import com.softify.app.util.PlaybackLogger

data class RemoteConfig(
    val lyricsApiEnabled: Boolean = true,
    val syncEnabled: Boolean = true,
    val updaterEnabled: Boolean = true,
    val telemetryEnabled: Boolean = false,
    val listenTogetherEnabled: Boolean = true,
    val maintenanceBanner: String? = null,
    val providerFallbackOrder: List<String> = listOf("betterlyrics", "lrclib", "lrcred", "kugou"),
    val etag: String? = null,
    val version: Int = 1,
    val minAppVersionCode: Int = 40000,
    val apiBaseUrl: String = "https://softify-server.workers.dev",
    val backupMirrorUrl: String = "https://sarthak-cyb3r.github.io/softify-static"
)

/**
 * Manages remote configuration with caching, ETag validation, and killswitch precedence:
 * Precedence: Server Killswitch > Remote Config > Build Default.
 */
class RemoteConfigManager(
    private var cachedConfig: RemoteConfig = RemoteConfig()
) {
    private val activeServerKillswitches = mutableMapOf<String, Boolean>()

    fun setServerKillswitch(featureKey: String, disabled: Boolean) {
        synchronized(this) {
            activeServerKillswitches[featureKey] = disabled
            PlaybackLogger.log("SoftifyConfig", "Server killswitch for $featureKey set to disabled=$disabled")
        }
    }

    fun updateConfig(newConfig: RemoteConfig) {
        synchronized(this) {
            cachedConfig = newConfig
            PlaybackLogger.log("SoftifyConfig", "Remote config updated (ETag: ${newConfig.etag})")
        }
    }

    fun isFeatureEnabled(featureKey: String, buildDefault: Boolean = true): Boolean {
        synchronized(this) {
            if (activeServerKillswitches[featureKey] == true) {
                return false
            }

            val remoteValue = when (featureKey) {
                "lyrics", "lyricsSync" -> cachedConfig.lyricsApiEnabled
                "sync", "cloudSync" -> cachedConfig.syncEnabled
                "updater" -> cachedConfig.updaterEnabled
                "telemetry" -> cachedConfig.telemetryEnabled
                "listen_together", "listenTogether" -> cachedConfig.listenTogetherEnabled
                else -> null
            }

            return remoteValue ?: buildDefault
        }
    }

    fun getMaintenanceMessage(): String? = synchronized(this) {
        cachedConfig.maintenanceBanner
    }

    fun getProviderOrder(): List<String> = synchronized(this) {
        cachedConfig.providerFallbackOrder
    }

    fun getEtag(): String? = synchronized(this) {
        cachedConfig.etag
    }

    fun getConfig(): RemoteConfig = synchronized(this) { cachedConfig }
}
