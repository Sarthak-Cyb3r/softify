package com.softify.app.ui.components

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toComposeImageBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL
import javax.imageio.ImageIO

actual suspend fun loadNetworkImageBitmap(url: String): ImageBitmap? = withContext(Dispatchers.IO) {
    runCatching {
        val connection = URL(url).openConnection()
        connection.connectTimeout = 8000
        connection.readTimeout = 8000
        connection.getInputStream().use { stream ->
            val buffered = ImageIO.read(stream)
            buffered?.toComposeImageBitmap()
        }
    }.getOrNull()
}
