package com.softify.app.ui.applemusic

import androidx.compose.ui.graphics.vector.ImageVector
import com.softify.app.ui.components.SoftifyIcons

enum class AppleMusicTab(val label: String, val icon: ImageVector) {
    LISTEN_NOW("Listen Now", SoftifyIcons.Play),
    BROWSE("Browse", SoftifyIcons.Explore),
    RADIO("Radio", SoftifyIcons.Radio),
    LIBRARY("Library", SoftifyIcons.Library),
    SEARCH("Search", SoftifyIcons.Search)
}
