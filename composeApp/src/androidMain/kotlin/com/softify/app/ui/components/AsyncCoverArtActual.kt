package com.softify.app.ui.components

import android.graphics.BitmapFactory
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL

actual suspend fun loadNetworkImageBitmap(url: String): ImageBitmap? = withContext(Dispatchers.IO) {
    runCatching {
        val connection = URL(url).openConnection()
        connection.connectTimeout = 8000
        connection.readTimeout = 8000
        connection.getInputStream().use { stream ->
            val bitmap = BitmapFactory.decodeStream(stream)
            bitmap?.asImageBitmap()
        }
    }.getOrNull()
}
