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
    val etag: String? = null
)

/**
 * Manages remote configuration with caching, ETag validation, and killswitch precedence:
 * Precedence: Server Killswitch > Remote Config > Build Default.
 */
class RemoteConfigManager(
    private var cachedConfig: RemoteConfig = RemoteConfig()
) {
    // Explicit server killswitch overrides (can disable features regardless of remote config)
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
            // 1. Highest precedence: Server killswitch
            if (activeServerKillswitches[featureKey] == true) {
                return false
            }

            // 2. Medium precedence: Remote config
            val remoteValue = when (featureKey) {
                "lyrics" -> cachedConfig.lyricsApiEnabled
                "sync" -> cachedConfig.syncEnabled
                "updater" -> cachedConfig.updaterEnabled
                "telemetry" -> cachedConfig.telemetryEnabled
                "listen_together" -> cachedConfig.listenTogetherEnabled
                else -> null
            }

            // 3. Lowest precedence: Build default
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
}
