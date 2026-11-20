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
import com.softify.app.ui.downloads.formatBytes
import com.softify.app.ui.theme.SquircleShape
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

    var showClearHistoryDialog by remember { mutableStateOf(false) }

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
}
