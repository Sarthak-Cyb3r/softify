package com.softify.app.ui.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

@Composable
fun MetrolistTheme(
    seedColor: Color = MaterialHctGenerator.DEFAULT_SEED,
    content: @Composable () -> Unit
) {
    val targetScheme = MaterialHctGenerator.createExpressiveColorScheme(seedColor)

    // Animate color transitions smoothly when album art changes
    val animDuration = 600
    val primary = animateColorAsState(targetScheme.primary, tween(animDuration))
    val onPrimary = animateColorAsState(targetScheme.onPrimary, tween(animDuration))
    val primaryContainer = animateColorAsState(targetScheme.primaryContainer, tween(animDuration))
    val onPrimaryContainer = animateColorAsState(targetScheme.onPrimaryContainer, tween(animDuration))

    val secondary = animateColorAsState(targetScheme.secondary, tween(animDuration))
    val onSecondary = animateColorAsState(targetScheme.onSecondary, tween(animDuration))
    val secondaryContainer = animateColorAsState(targetScheme.secondaryContainer, tween(animDuration))
    val onSecondaryContainer = animateColorAsState(targetScheme.onSecondaryContainer, tween(animDuration))

    val tertiary = animateColorAsState(targetScheme.tertiary, tween(animDuration))
    val onTertiary = animateColorAsState(targetScheme.onTertiary, tween(animDuration))
    val tertiaryContainer = animateColorAsState(targetScheme.tertiaryContainer, tween(animDuration))
    val onTertiaryContainer = animateColorAsState(targetScheme.onTertiaryContainer, tween(animDuration))

    val background = animateColorAsState(targetScheme.background, tween(animDuration))
    val onBackground = animateColorAsState(targetScheme.onBackground, tween(animDuration))
    val surface = animateColorAsState(targetScheme.surface, tween(animDuration))
    val onSurface = animateColorAsState(targetScheme.onSurface, tween(animDuration))
    val surfaceVariant = animateColorAsState(targetScheme.surfaceVariant, tween(animDuration))
    val onSurfaceVariant = animateColorAsState(targetScheme.onSurfaceVariant, tween(animDuration))

    val surfaceContainer = animateColorAsState(targetScheme.surfaceContainer, tween(animDuration))
    val surfaceContainerHigh = animateColorAsState(targetScheme.surfaceContainerHigh, tween(animDuration))
    val surfaceContainerHighest = animateColorAsState(targetScheme.surfaceContainerHighest, tween(animDuration))

    val animatedScheme = ColorScheme(
        primary = primary.value,
        onPrimary = onPrimary.value,
        primaryContainer = primaryContainer.value,
        onPrimaryContainer = onPrimaryContainer.value,
        inversePrimary = targetScheme.inversePrimary,
        secondary = secondary.value,
        onSecondary = onSecondary.value,
        secondaryContainer = secondaryContainer.value,
        onSecondaryContainer = onSecondaryContainer.value,
        tertiary = tertiary.value,
        onTertiary = onTertiary.value,
        tertiaryContainer = tertiaryContainer.value,
        onTertiaryContainer = onTertiaryContainer.value,
        background = background.value,
        onBackground = onBackground.value,
        surface = surface.value,
        onSurface = onSurface.value,
        surfaceVariant = surfaceVariant.value,
        onSurfaceVariant = onSurfaceVariant.value,
        surfaceTint = primary.value,
        inverseSurface = targetScheme.inverseSurface,
        inverseOnSurface = targetScheme.inverseOnSurface,
        error = targetScheme.error,
        onError = targetScheme.onError,
        errorContainer = targetScheme.errorContainer,
        onErrorContainer = targetScheme.onErrorContainer,
        outline = targetScheme.outline,
        outlineVariant = targetScheme.outlineVariant,
        scrim = targetScheme.scrim,
        surfaceBright = targetScheme.surfaceBright,
        surfaceDim = targetScheme.surfaceDim,
        surfaceContainer = surfaceContainer.value,
        surfaceContainerHigh = surfaceContainerHigh.value,
        surfaceContainerHighest = surfaceContainerHighest.value,
        surfaceContainerLow = targetScheme.surfaceContainerLow,
        surfaceContainerLowest = targetScheme.surfaceContainerLowest
    )

    MaterialTheme(
        colorScheme = animatedScheme,
        shapes = ExpressiveShapes,
        content = content
    )
}
