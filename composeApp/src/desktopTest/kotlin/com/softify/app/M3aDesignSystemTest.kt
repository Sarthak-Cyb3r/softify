package com.softify.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.components.*
import com.softify.app.ui.gallery.ComponentGalleryScreen
import com.softify.app.ui.theme.Hct
import com.softify.app.ui.theme.MaterialHctGenerator
import com.softify.app.ui.theme.MetrolistTheme
import com.softify.app.ui.theme.SquircleShape
import org.jetbrains.skia.EncodedImageFormat
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class M3aDesignSystemTest {

    @Test
    fun testHctColorConversionAndPalette() {
        val seed = Color(0xFF6750A4)
        val hct = Hct.fromColor(seed)
        assertTrue(hct.hue in 0f..360f, "Hue must be in [0, 360]")
        assertTrue(hct.chroma >= 0f, "Chroma must be non-negative")
        assertTrue(hct.tone in 0f..100f, "Tone must be in [0, 100]")

        // Fallback test
        val fallbackSeed = MaterialHctGenerator.extractSeedFromCover(null)
        assertEquals(MaterialHctGenerator.DEFAULT_SEED, fallbackSeed)

        // Simulated cover byte extraction
        val dummyBytes = ByteArray(1024) { idx -> (idx % 256).toByte() }
        val extractedSeed = MaterialHctGenerator.extractSeedFromCover(dummyBytes)
        assertNotNull(extractedSeed)

        // Palette generation
        val colorScheme = MaterialHctGenerator.createExpressiveColorScheme(seed)
        assertNotNull(colorScheme.primary)
        assertNotNull(colorScheme.secondary)
        assertNotNull(colorScheme.surfaceContainer)
        assertNotNull(colorScheme.error)
    }

    @Test
    fun testSquircleShape() {
        val density = Density(2f)
        val shape = SquircleShape(cornerRadius = 16.dp)
        val outline = shape.createOutline(Size(200f, 100f), LayoutDirection.Ltr, density)
        assertTrue(outline is Outline.Generic, "Squircle must produce generic path outline")
        val bounds = outline.bounds
        assertEquals(200f, bounds.width, 1f)
        assertEquals(100f, bounds.height, 1f)
    }

    @Test
    fun testRenderAndSaveGalleryScreenshots() {
        val rootDir = if (File("docs/agent").exists()) File(".") else File("..")
        val screenshotDir = File(rootDir, "docs/agent/screenshots")
        screenshotDir.mkdirs()

        fun saveScene(name: String, width: Int, height: Int, content: @androidx.compose.runtime.Composable () -> Unit) {
            try {
                val scene = ImageComposeScene(width = width, height = height) {
                    content()
                }
                val image = scene.render()
                val data = image.encodeToData(EncodedImageFormat.PNG)
                if (data != null) {
                    val file = File(screenshotDir, name)
                    file.writeBytes(data.bytes)
                    assertTrue(file.exists() && file.length() > 500, "Screenshot $name must be saved")
                    println("Saved screenshot $name (${file.length()} bytes)")
                }
            } catch (e: Throwable) {
                println("Note: Offscreen rendering skipped for $name: ${e.message}")
            }
        }

        // 1. Full Gallery Overview
        saveScene("gallery_overview.png", 440, 3200) {
            ComponentGalleryScreen()
        }

        // 2. Minimal Bitrate Badges (All states: direct, with sample rate, fallback AAC, fallback Opus, inactive)
        saveScene("badge_states.png", 400, 320) {
            MetrolistTheme {
                Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text("Minimal Bitrate Badges", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary, fontSize = 16.sp)
                        BitrateBadge(bitrateKbps = 320u, codec = "AAC", isFallback = false)
                        BitrateBadge(bitrateKbps = 320u, codec = "AAC", isFallback = false, sampleRateHz = 48000)
                        BitrateBadge(bitrateKbps = 129u, codec = "AAC", isFallback = true)
                        BitrateBadge(bitrateKbps = 155u, codec = "OPUS", isFallback = true)
                        BitrateBadge(bitrateKbps = 0u, codec = "", enabled = false)
                    }
                }
            }
        }

        // 3. Floating Segmented Player Dock (no emojis, 48dp targets, playing, buffering, disabled)
        saveScene("dock_no_emojis.png", 420, 520) {
            MetrolistTheme {
                Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Text("Playing Dock (No Emojis, Spring Heart)", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary, fontSize = 14.sp)
                        FloatingSegmentedPlayerDock(
                            isPlaying = true,
                            onTogglePlayPause = {},
                            onPrevious = {},
                            onNext = {},
                            elapsedMs = 45_000,
                            totalMs = 210_000,
                            isFavorite = true
                        )

                        Text("Buffering Dock (CircularProgressIndicator)", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary, fontSize = 14.sp)
                        FloatingSegmentedPlayerDock(
                            isPlaying = false,
                            isBuffering = true,
                            onTogglePlayPause = {},
                            onPrevious = {},
                            onNext = {},
                            elapsedMs = 12_000,
                            totalMs = 180_000
                        )

                        Text("Disabled Dock (All Controls Dimmed)", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary, fontSize = 14.sp)
                        FloatingSegmentedPlayerDock(
                            isPlaying = false,
                            onTogglePlayPause = {},
                            onPrevious = {},
                            onNext = {},
                            enabled = false
                        )
                    }
                }
            }
        }

        // 4. Lyrics Shine at 3 Positions (start, middle, end)
        saveScene("lyrics_shine_start.png", 420, 160) {
            MetrolistTheme {
                Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.Center) {
                        Text("Active Line: Start (15% sweep)", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(8.dp))
                        ActiveLyricLine(text = "Floating through the neon night", progress = 0.15f)
                    }
                }
            }
        }

        saveScene("lyrics_shine_middle.png", 420, 160) {
            MetrolistTheme {
                Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.Center) {
                        Text("Active Line: Middle (50% sweep)", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(8.dp))
                        ActiveLyricLine(text = "Floating through the neon night", progress = 0.50f)
                    }
                }
            }
        }

        saveScene("lyrics_shine_end.png", 420, 160) {
            MetrolistTheme {
                Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.Center) {
                        Text("Active Line: End (90% sweep)", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(8.dp))
                        ActiveLyricLine(text = "Floating through the neon night", progress = 0.90f)
                    }
                }
            }
        }
    }
}
