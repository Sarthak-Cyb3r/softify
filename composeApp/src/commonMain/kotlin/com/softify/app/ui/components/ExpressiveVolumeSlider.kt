package com.softify.app.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Expressive Volume Slider with mute toggle.
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
            modifier = Modifier.size(32.dp)
        ) {
            val icon = when {
                volume <= 0f -> "🔈"
                volume < 0.5f -> "🔉"
                else -> "🔊"
            }
            Text(icon, fontSize = 14.sp)
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
