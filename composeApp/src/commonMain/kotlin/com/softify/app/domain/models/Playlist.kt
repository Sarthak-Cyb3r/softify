package com.softify.app.domain.models

import kotlinx.serialization.Serializable

@Serializable
data class Playlist(
    val id: String,
    val title: String,
    val description: String = "",
    val coverUrl: String? = null,
    val trackCount: Int = 0,
    val author: String = "Softify"
)
