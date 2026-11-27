package com.softify.app.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.storage.StorageHealth
import com.softify.app.telemetry.TelemetryManager
import com.softify.app.ui.downloads.formatBytes
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.updater.UpdateState
import com.softify.app.viewmodel.PlaybackViewModel
import com.softify.app.viewmodel.UiStyle
import uniffi.softify_core.QualityPreset

@Composable
fun SettingsScreen(
    viewModel: PlaybackViewModel,
    onBack: () -> Unit,
    onOpenDiagnostics: () -> Unit,
    onOpenGallery: () -> Unit,
    modifier: Modifier = Modifier
) {
    val qualityPreset by viewModel.qualityPreset.collectAsState()
    val uiStyle by viewModel.uiStyle.collectAsState()
    val isIncognito by viewModel.isIncognito.collectAsState()
    val showLyricsDebugOverlay by viewModel.showLyricsDebugOverlay.collectAsState()

    val isLoudnessEnabled by viewModel.isLoudnessEnabled.collectAsState()
    val targetLufs by viewModel.targetLufs.collectAsState()
    val allowLoudnessBoost by viewModel.allowLoudnessBoost.collectAsState()
    val isGaplessEnabled by viewModel.isGaplessEnabled.collectAsState()
    val crossfadeDurationSec by viewModel.crossfadeDurationSec.collectAsState()
    val skipAlbumConsecutiveCrossfade by viewModel.skipAlbumConsecutiveCrossfade.collectAsState()

    var showClearHistoryDialog by remember { mutableStateOf(false) }

    val isLocalOnly by viewModel.isLocalOnly.collectAsState()
    val pendingSyncCount by viewModel.pendingSyncCount.collectAsState()
    val lastSyncTimestamp by viewModel.lastSyncTimestamp.collectAsState()
    val budgetTier by viewModel.budgetTier.collectAsState()
    val isTelemetryOptIn by viewModel.isTelemetryOptIn.collectAsState()
    val updateState by viewModel.updateState.collectAsState()

    var showTelemetryDisclosureDialog by remember { mutableStateOf(false) }
    var showExportDataDialog by remember { mutableStateOf(false) }
    var exportedDataText by remember { mutableStateOf("") }
    var showImportDataDialog by remember { mutableStateOf(false) }
    var importDataText by remember { mutableStateOf("") }
    var importValidationError by remember { mutableStateOf<String?>(null) }
    val customUpdateUrl by viewModel.customUpdateUrl.collectAsState()
    var updateUrlInput by remember(customUpdateUrl) { mutableStateOf(customUpdateUrl) }
    var showCustomUpdateUrl by remember { mutableStateOf(false) }
    var showDeleteAccountDialog by remember { mutableStateOf(false) }
    var showRecoverAccountDialog by remember { mutableStateOf(false) }
    var recoveryInputCode by remember { mutableStateOf("") }

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        // Top Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = onBack,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = MaterialTheme.colorScheme.onSurface
                )
            }
            Text(
                text = "Settings",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Audio Stream Quality Section
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Audio Stream Quality",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Preferred stream bitrate for online playback",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(
                            selected = qualityPreset == QualityPreset.HIGH,
                            onClick = { viewModel.setQualityPreset(QualityPreset.HIGH) },
                            label = { Text("High (320k)") },
                            shape = SquircleShape(12.dp)
                        )
                        FilterChip(
                            selected = qualityPreset == QualityPreset.MEDIUM,
                            onClick = { viewModel.setQualityPreset(QualityPreset.MEDIUM) },
                            label = { Text("Med (160k)") },
                            shape = SquircleShape(12.dp)
                        )
                        FilterChip(
                            selected = qualityPreset == QualityPreset.LOW,
                            onClick = { viewModel.setQualityPreset(QualityPreset.LOW) },
                            label = { Text("Low (96k)") },
                            shape = SquircleShape(12.dp)
                        )
                    }
                }
            }

            // UI Design System Section
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Design System",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Select active user interface theme",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(
                            selected = uiStyle == UiStyle.METROLIST,
                            onClick = { viewModel.setUiStyle(UiStyle.METROLIST) },
                            label = { Text("Metrolist M3") },
                            shape = SquircleShape(12.dp)
                        )
                        FilterChip(
                            selected = false,
                            onClick = {},
                            enabled = false,
                            label = { Text("Apple Music Liquid (M3c)") },
                            shape = SquircleShape(12.dp),
                            modifier = Modifier.alpha(0.6f)
                        )
                    }
                }
            }

            // Privacy & Taste Section
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Privacy & Listening History",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Incognito Switch Row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Incognito Mode",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Pauses listening history and taste learning",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        Switch(
                            checked = isIncognito,
                            onCheckedChange = { viewModel.toggleIncognito() }
                        )
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                    // Clear Actions
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { showClearHistoryDialog = true },
                            shape = SquircleShape(12.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Clear History", fontSize = 12.sp)
                        }

                        OutlinedButton(
                            onClick = {
                                viewModel.clearAllRecentSearches()
                                viewModel.showSnackbar("Recent searches cleared")
                            },
                            shape = SquircleShape(12.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Clear Searches", fontSize = 12.sp)
                        }
                    }
                }
            }

            // Audio Normalization & Playback Section (M4b & M4c)
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Audio & Playback",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Loudness normalization, gapless transitions, and crossfade",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // 1. Loudness Normalization Switch
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Loudness Normalization",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Match perceived loudness using ReplayGain and YouTube tags",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = isLoudnessEnabled,
                            onCheckedChange = { viewModel.toggleLoudnessEnabled() }
                        )
                    }

                    if (isLoudnessEnabled) {
                        Spacer(modifier = Modifier.height(12.dp))
                        // Target LUFS Slider
                        Column {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text("Target Level", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
                                Text("${targetLufs.toInt()} LUFS", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            }
                            Slider(
                                value = targetLufs,
                                onValueChange = { viewModel.setTargetLufs(it) },
                                valueRange = -23.0f..-9.0f,
                                steps = 13
                            )
                        }

                        Spacer(modifier = Modifier.height(8.dp))
                        // Allow Boost Switch
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Allow Volume Boost",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "Boost quiet tracks up to +6 dB when peak headroom allows",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Switch(
                                checked = allowLoudnessBoost,
                                onCheckedChange = { viewModel.toggleAllowLoudnessBoost() }
                            )
                        }
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                    // 2. Gapless Playback Switch
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Gapless Playback",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Pre-buffers upcoming tracks for zero-latency transitions",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = isGaplessEnabled,
                            onCheckedChange = { viewModel.toggleGaplessEnabled() }
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // 3. Crossfade Duration Slider
                    Column {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Crossfade Duration", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
                            Text(
                                if (crossfadeDurationSec == 0) "Off (0s)" else "${crossfadeDurationSec}s",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Slider(
                            value = crossfadeDurationSec.toFloat(),
                            onValueChange = { viewModel.setCrossfadeDurationSec(it.toInt()) },
                            valueRange = 0f..12f,
                            steps = 11
                        )
                    }

                    if (crossfadeDurationSec > 0) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Skip Consecutive Album Tracks",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "Maintains original gapless flow for conceptual albums",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Switch(
                                checked = skipAlbumConsecutiveCrossfade,
                                onCheckedChange = { viewModel.toggleSkipAlbumConsecutiveCrossfade() }
                            )
                        }
                    }
                }
            }

            // Downloads & Offline Storage Section
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Downloads & Offline Storage",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Manage storage location, network constraints, and concurrency",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    val storage = viewModel.downloadQueueManager.storageProvider
                    val usedBytes = remember { storage.getUsedSpaceBytes() }
                    val freeBytes = remember { storage.getAvailableSpaceBytes() }
                    val locationName = remember { storage.getStorageLocationName() }
                    val storageHealth = remember { storage.validateStorage() }

                    // Storage Readout
                    Text(
                        text = "Storage: ${formatBytes(usedBytes)} used • ${formatBytes(freeBytes)} free",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Location: $locationName",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedButton(
                        onClick = { viewModel.onPickDownloadFolderRequested?.invoke() },
                        shape = SquircleShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Filled.FolderOpen, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Change Download Folder")
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                    // Wi-Fi Only Switch
                    val wifiOnly by viewModel.downloadQueueManager.wifiOnly.collectAsState()
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Download over Wi-Fi only",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Pauses queue when connected to cellular data",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = wifiOnly,
                            onCheckedChange = { viewModel.downloadQueueManager.setWifiOnly(it) }
                        )
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                    // Max Concurrent Downloads (1-3)
                    val maxConcurrent by viewModel.downloadQueueManager.maxConcurrent.collectAsState()
                    Text(
                        text = "Max Concurrent Downloads ($maxConcurrent)",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for (count in 1..3) {
                            FilterChip(
                                selected = maxConcurrent == count,
                                onClick = { viewModel.downloadQueueManager.setMaxConcurrent(count) },
                                label = { Text("$count download${if (count > 1) "s" else ""}") },
                                shape = SquircleShape(12.dp)
                            )
                        }
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                    // Download Diagnostics Switch & Panel
                    var showDownloadDiagnostics by remember { mutableStateOf(false) }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Download Diagnostics",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Inspect queue state, last errors, and storage URI health",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = showDownloadDiagnostics,
                            onCheckedChange = { showDownloadDiagnostics = it }
                        )
                    }

                    if (showDownloadDiagnostics) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Surface(
                            shape = SquircleShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceContainerHighest,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            val tasksMap by viewModel.downloadQueueManager.tasks.collectAsState()
                            val tasksList = tasksMap.values.toList()
                            val errors = tasksList.filter { !it.lastError.isNullOrBlank() }
                            Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(
                                    text = "Storage Health: $storageHealth",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = if (storageHealth == StorageHealth.HEALTHY) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                                )
                                Text(
                                    text = "Queue: ${tasksList.size} total (active: ${tasksList.count { it.status != com.softify.app.download.DownloadStatus.COMPLETED }}, completed: ${tasksList.count { it.status == com.softify.app.download.DownloadStatus.COMPLETED }})",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                if (errors.isNotEmpty()) {
                                    Text(
                                        text = "Last Errors (${errors.size}):",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.error
                                    )
                                    for (e in errors.take(3)) {
                                        Text(
                                            text = "• ${e.track.title}: ${e.lastError}",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.error
                                        )
                                    }
                                } else {
                                    Text(
                                        text = "Last Errors: None",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }

                                Spacer(modifier = Modifier.height(4.dp))
                                OutlinedButton(
                                    onClick = {
                                        viewModel.downloadQueueManager.reconcile()
                                        viewModel.showSnackbar("Storage reconciled with database")
                                    },
                                    shape = SquircleShape(10.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Icon(Icons.Filled.Sync, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Reconcile Storage", fontSize = 12.sp)
                                }
                            }
                        }
                    }
                }
            }

            // Developer & Diagnostics Section
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Diagnostics & Inspection",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "In-app telemetry, playback logs, and component gallery",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = onOpenDiagnostics,
                            shape = SquircleShape(12.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Filled.BugReport, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Diagnostics", fontSize = 12.sp)
                        }

                        FilledTonalButton(
                            onClick = onOpenGallery,
                            shape = SquircleShape(12.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Filled.Widgets, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Gallery", fontSize = 12.sp)
                        }
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Lyrics Debug Overlay",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Show provider, line count, timing mode, and clock FPS",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = showLyricsDebugOverlay,
                            onCheckedChange = { viewModel.toggleLyricsDebugOverlay() }
                        )
                    }
                }
            }

            // Account & Cloud Sync Card
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "Account & Cloud Sync",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Anonymous zero-knowledge sync across your devices",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    // Anonymous ID & Recovery Code
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = "Recovery Code: ${viewModel.recoveryCode}",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = "Device ID: ${viewModel.anonymousDeviceId.take(16)}...",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // Local Only Switch
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Local only mode",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Disable all edge backend requests and keep data on-device only",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = isLocalOnly,
                            onCheckedChange = { viewModel.toggleLocalOnly() }
                        )
                    }

                    // Sync status and action
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Pending changes: $pendingSyncCount",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "Tier: $budgetTier",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Button(
                            onClick = { viewModel.syncNow() },
                            enabled = !isLocalOnly,
                            shape = SquircleShape(8.dp)
                        ) {
                            Text("Sync now")
                        }
                    }

                    // GDPR & Recovery row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = {
                                exportedDataText = viewModel.exportUserData()
                                showExportDataDialog = true
                            },
                            modifier = Modifier.weight(1f),
                            shape = SquircleShape(8.dp)
                        ) {
                            Text("Export JSON")
                        }
                        OutlinedButton(
                            onClick = {
                                importValidationError = null
                                showImportDataDialog = true
                            },
                            modifier = Modifier.weight(1f),
                            shape = SquircleShape(8.dp)
                        ) {
                            Text("Import JSON")
                        }
                        OutlinedButton(
                            onClick = { showDeleteAccountDialog = true },
                            modifier = Modifier.weight(1f),
                            shape = SquircleShape(8.dp),
                            colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                        ) {
                            Text("Delete")
                        }
                    }

                    TextButton(
                        onClick = { showRecoverAccountDialog = true },
                        modifier = Modifier.align(Alignment.CenterHorizontally)
                    ) {
                        Text("Restore with recovery code")
                    }
                }
            }

            // In-App Updates Card
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "App Updates",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Current version: ${viewModel.appVersion} (code ${viewModel.appVersionCode})",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        TextButton(onClick = { showCustomUpdateUrl = !showCustomUpdateUrl }) {
                            Text(if (showCustomUpdateUrl) "Hide URL" else "Source URL")
                        }
                    }

                    if (showCustomUpdateUrl) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = updateUrlInput,
                                onValueChange = { updateUrlInput = it },
                                label = { Text("Custom update manifest URL") },
                                singleLine = true,
                                modifier = Modifier.weight(1f)
                            )
                            OutlinedButton(
                                onClick = { viewModel.setCustomUpdateUrl(updateUrlInput) },
                                shape = SquircleShape(8.dp)
                            ) {
                                Text("Set")
                            }
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = { viewModel.checkForUpdates() },
                            enabled = !isLocalOnly && updateState !is UpdateState.Checking && updateState !is UpdateState.Downloading,
                            shape = SquircleShape(8.dp)
                        ) {
                            Text("Check for updates")
                        }
                        if (updateState is UpdateState.Available) {
                            Button(
                                onClick = { viewModel.downloadAvailableUpdate() },
                                shape = SquircleShape(8.dp)
                            ) {
                                Text("Download & Install")
                            }
                        } else if (updateState is UpdateState.ReadyToInstall) {
                            Button(
                                onClick = { viewModel.installDownloadedUpdate() },
                                shape = SquircleShape(8.dp)
                            ) {
                                Text("Install APK")
                            }
                        }
                    }

                    when (val st = updateState) {
                        is UpdateState.Checking -> {
                            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                            Text(
                                text = "Checking for update manifest...",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        is UpdateState.Available -> {
                            Text(
                                text = "Update ready: v${st.info.versionName} (${st.info.versionCode})\n${st.info.releaseNotes}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        is UpdateState.Downloading -> {
                            LinearProgressIndicator(
                                progress = { st.progress.coerceIn(0f, 1f) },
                                modifier = Modifier.fillMaxWidth()
                            )
                            Text(
                                text = "Downloading: ${formatBytes(st.bytesDownloaded)}${if (st.totalBytes > 0) " / ${formatBytes(st.totalBytes)}" else ""}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        is UpdateState.ReadyToInstall -> {
                            Text(
                                text = "Verified v${st.info.versionName} (SHA-256 matched, ${formatBytes(st.apkFile.length())})",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        is UpdateState.UpToDate -> {
                            Text(
                                text = "App is up to date (code ${viewModel.appVersionCode})",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        is UpdateState.Error -> {
                            Surface(
                                shape = SquircleShape(8.dp),
                                color = MaterialTheme.colorScheme.errorContainer
                            ) {
                                Text(
                                    text = "Update refused: ${st.message}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onErrorContainer,
                                    modifier = Modifier.padding(10.dp)
                                )
                            }
                        }
                        UpdateState.Idle -> {}
                    }
                }
            }

            // Privacy & Telemetry Card
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Anonymous Telemetry",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Opt-in anonymous error reports (strictly zero PII)",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = isTelemetryOptIn,
                            onCheckedChange = { viewModel.toggleTelemetry() }
                        )
                    }
                    TextButton(
                        onClick = { showTelemetryDisclosureDialog = true }
                    ) {
                        Text("View data disclosure")
                    }
                }
            }

            // System Information Card
            Card(
                shape = SquircleShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLowest)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "System Information",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "App: ${viewModel.appVersion}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "OS: ${viewModel.osVersion}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "ABI: ${viewModel.abi}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "Native core: ${if (viewModel.isNativeLibLoaded) "libsoftify_core.so loaded" else "FAILED"}",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (viewModel.isNativeLibLoaded) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                    )
                }
            }

            Spacer(modifier = Modifier.height(40.dp))
        }
    }

    if (showClearHistoryDialog) {
        AlertDialog(
            onDismissRequest = { showClearHistoryDialog = false },
            title = { Text("Clear listening history?") },
            text = { Text("All recorded listening history and Smart Playlist stats will be reset.") },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.clearListeningHistory()
                        showClearHistoryDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Clear")
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearHistoryDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (showTelemetryDisclosureDialog) {
        AlertDialog(
            onDismissRequest = { showTelemetryDisclosureDialog = false },
            title = { Text("Telemetry Data Disclosure") },
            text = { Text(TelemetryManager.SCHEMA_DESCRIPTION) },
            confirmButton = {
                Button(onClick = { showTelemetryDisclosureDialog = false }) {
                    Text("Understood")
                }
            }
        )
    }

    if (showExportDataDialog) {
        AlertDialog(
            onDismissRequest = { showExportDataDialog = false },
            title = { Text("Exported Library Backup (JSON)") },
            text = { Text(exportedDataText.take(600) + if (exportedDataText.length > 600) "..." else "") },
            confirmButton = {
                Button(onClick = {
                    viewModel.requestSaveBackupJson()
                    showExportDataDialog = false
                }) {
                    Text("Save .json file")
                }
            },
            dismissButton = {
                TextButton(onClick = { showExportDataDialog = false }) {
                    Text("Close")
                }
            }
        )
    }

    if (showImportDataDialog) {
        AlertDialog(
            onDismissRequest = { showImportDataDialog = false },
            title = { Text("Import Library Backup (JSON)") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Paste exported JSON backup or load from a .json file:")
                    OutlinedButton(
                        onClick = {
                            viewModel.requestPickBackupJson()
                            showImportDataDialog = false
                        },
                        shape = SquircleShape(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Choose .json File")
                    }
                    OutlinedTextField(
                        value = importDataText,
                        onValueChange = {
                            importDataText = it
                            importValidationError = null
                        },
                        label = { Text("Backup JSON payload") },
                        maxLines = 5,
                        modifier = Modifier.fillMaxWidth()
                    )
                    if (importValidationError != null) {
                        Text(
                            text = importValidationError!!,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.importUserBackup(importDataText) { ok, msg ->
                            if (ok) {
                                importDataText = ""
                                importValidationError = null
                                showImportDataDialog = false
                            } else {
                                importValidationError = msg
                            }
                        }
                    }
                ) {
                    Text("Validate & Restore")
                }
            },
            dismissButton = {
                TextButton(onClick = { showImportDataDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (showDeleteAccountDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteAccountDialog = false },
            title = { Text("Delete all sync data?") },
            text = { Text("This will permanently remove your anonymous sync account and wipe all synced data.") },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.deleteUserAccount()
                        showDeleteAccountDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAccountDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (showRecoverAccountDialog) {
        AlertDialog(
            onDismissRequest = { showRecoverAccountDialog = false },
            title = { Text("Restore Account") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Enter your 16-character recovery code (SOFT-XXXX-XXXX-XXXX):")
                    OutlinedTextField(
                        value = recoveryInputCode,
                        onValueChange = { recoveryInputCode = it.uppercase() },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (recoveryInputCode.isNotBlank()) {
                            viewModel.recoverAccount(recoveryInputCode)
                        }
                        showRecoverAccountDialog = false
                    }
                ) {
                    Text("Restore")
                }
            },
            dismissButton = {
                TextButton(onClick = { showRecoverAccountDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
