package com.softify.app

import com.softify.app.api.RemoteConfig
import com.softify.app.api.RemoteConfigManager
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RemoteConfigTest {

    @Test
    fun testKillswitchPrecedence() {
        val manager = RemoteConfigManager()

        // 1. Initial build default: lyrics is enabled
        assertTrue(manager.isFeatureEnabled("lyrics", buildDefault = true))

        // 2. Remote config enables lyrics
        manager.updateConfig(RemoteConfig(lyricsApiEnabled = true))
        assertTrue(manager.isFeatureEnabled("lyrics"))

        // 3. Server killswitch explicitly disables lyrics -> overrides remote config
        manager.setServerKillswitch("lyrics", disabled = true)
        assertFalse(manager.isFeatureEnabled("lyrics"), "Server killswitch must override remote config")

        // 4. Remote config change cannot re-enable while server killswitch is active
        manager.updateConfig(RemoteConfig(lyricsApiEnabled = true))
        assertFalse(manager.isFeatureEnabled("lyrics"))

        // 5. Releasing killswitch restores remote config state
        manager.setServerKillswitch("lyrics", disabled = false)
        assertTrue(manager.isFeatureEnabled("lyrics"))
    }

    @Test
    fun testProviderFallbackOrder() {
        val manager = RemoteConfigManager()
        val customProviders = listOf("kugou", "lrclib", "betterlyrics")
        manager.updateConfig(RemoteConfig(providerFallbackOrder = customProviders, etag = "w/123"))

        assertEquals(customProviders, manager.getProviderOrder())
        assertEquals("w/123", manager.getEtag())
    }
}
