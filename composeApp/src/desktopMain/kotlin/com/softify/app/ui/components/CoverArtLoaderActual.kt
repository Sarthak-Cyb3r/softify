package com.softify.app.ui.components

import coil3.PlatformContext
import okio.Path
import okio.Path.Companion.toPath
import java.io.File

actual fun getCacheDirectory(context: PlatformContext): Path {
    val dir = File(System.getProperty("java.io.tmpdir"), "softify_art_cache")
    if (!dir.exists()) {
        dir.mkdirs()
    }
    return dir.absolutePath.toPath()
}
