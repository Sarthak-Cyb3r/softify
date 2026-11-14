package com.softify.app.ui.metrolist

import androidx.compose.ui.graphics.vector.ImageVector
import com.softify.app.ui.components.SoftifyIcons

enum class MetrolistTab(val label: String, val icon: ImageVector) {
    HOME("Home", SoftifyIcons.Home),
    SEARCH("Explore", SoftifyIcons.Search),
    LIBRARY("Library", SoftifyIcons.Library),
    SETTINGS("Settings", SoftifyIcons.Settings)
}
