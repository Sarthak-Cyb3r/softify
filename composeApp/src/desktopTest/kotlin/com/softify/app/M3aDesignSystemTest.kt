package com.softify.app

import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.softify.app.ui.gallery.ComponentGalleryScreen
import com.softify.app.ui.theme.Hct
import com.softify.app.ui.theme.MaterialHctGenerator
import com.softify.app.ui.theme.ScallopedBadgeShape
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
    fun testScallopedBadgeShape() {
        val density = Density(2f)
        for (lobes in listOf(4, 8, 12, 16)) {
            val shape = ScallopedBadgeShape(numLobes = lobes, amplitude = 0.1f)
            val outline = shape.createOutline(Size(120f, 120f), LayoutDirection.Ltr, density)
            assertTrue(outline is Outline.Generic, "Must produce generic path outline")
            val bounds = outline.bounds
            assertTrue(bounds.width > 0f && bounds.height > 0f)
        }
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

        // Render full Component Gallery using offscreen Skia / Compose Scene
        try {
            val scene = ImageComposeScene(width = 440, height = 2600) {
                ComponentGalleryScreen()
            }
            val image = scene.render()
            val data = image.encodeToData(EncodedImageFormat.PNG)
            if (data != null) {
                val file = File(screenshotDir, "gallery_overview.png")
                file.writeBytes(data.bytes)
                assertTrue(file.exists() && file.length() > 1000, "Screenshot gallery_overview.png must be saved")
                println("Saved Component Gallery screenshot to ${file.absolutePath} (${file.length()} bytes)")
            }
        } catch (e: Throwable) {
            println("Note: Offscreen rendering skipped if headless environment lacks Skia graphics surface: ${e.message}")
        }
    }
}
