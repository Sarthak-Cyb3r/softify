package com.softify.app.ui.components

import coil3.PlatformContext
import okio.Path
import okio.Path.Companion.toPath

actual fun getCacheDirectory(context: PlatformContext): Path {
    val dir = context.cacheDir.resolve("softify_art_cache")
    if (!dir.exists()) {
        dir.mkdirs()
    }
    return dir.absolutePath.toPath()
}
