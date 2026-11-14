package com.softify.app.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeDown
import androidx.compose.material.icons.automirrored.filled.VolumeMute
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Expressive Volume Slider with mute toggle.
 * Uses Compose ImageVector icons with 48dp touch targets and content descriptions.
 */
@Composable
fun ExpressiveVolumeSlider(
    volume: Float, // 0f..1f
    onVolumeChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    var previousNonZeroVolume by remember { mutableStateOf(if (volume > 0f) volume else 0.5f) }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        IconButton(
            onClick = {
                if (volume > 0f) {
                    previousNonZeroVolume = volume
                    onVolumeChange(0f)
                } else {
                    onVolumeChange(previousNonZeroVolume)
                }
            },
            enabled = enabled,
            modifier = Modifier.size(48.dp)
        ) {
            val (icon, desc) = when {
                volume <= 0f -> Icons.AutoMirrored.Filled.VolumeMute to "Volume Muted"
                volume < 0.5f -> Icons.AutoMirrored.Filled.VolumeDown to "Volume Low"
                else -> Icons.AutoMirrored.Filled.VolumeUp to "Volume High"
            }
            Icon(
                imageVector = icon,
                contentDescription = desc,
                tint = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
            )
        }

        Slider(
            value = volume,
            onValueChange = onVolumeChange,
            enabled = enabled,
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = MaterialTheme.colorScheme.primary,
                inactiveTrackColor = MaterialTheme.colorScheme.surfaceVariant
            ),
            modifier = Modifier.weight(1f)
        )
    }
}

@Preview
@Composable
fun PreviewVolumeSlider() {
    ExpressiveVolumeSlider(volume = 0.7f, onVolumeChange = {})
}
