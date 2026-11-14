package com.softify.app.domain.models

import kotlinx.serialization.Serializable

@Serializable
data class Track(
    val id: String,
    val sourceId: String,
    val title: String,
    val artist: String,
    val album: String? = null,
    val durationMs: Long = 0,
    val coverUrl: String? = null,
    val isLiked: Boolean = false,
    val streamUrl: String? = null
) {
    val durationFormatted: String
        get() {
            val totalSeconds = durationMs / 1000
            val minutes = totalSeconds / 60
            val seconds = totalSeconds % 60
            return "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
        }
}

@Serializable
data class LyricLine(
    val startTimeMs: Long,
    val text: String,
    val romanizedText: String? = null
)

@Serializable
data class Lyrics(
    val trackId: String,
    val lines: List<LyricLine> = emptyList()
)
