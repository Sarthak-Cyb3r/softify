package com.softify.app.ui.downloads

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.download.DownloadStatus
import com.softify.app.download.DownloadTask
import com.softify.app.storage.StorageHealth
import com.softify.app.ui.components.AsyncCoverArt
import com.softify.app.ui.components.BitrateBadge
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.Track

@Composable
fun DownloadsScreen(
    viewModel: PlaybackViewModel,
    modifier: Modifier = Modifier
) {
    val tasksMap by viewModel.downloadQueueManager.tasks.collectAsState()
    val allTasks = remember(tasksMap) { tasksMap.values.toList() }

    val activeTasks = remember(allTasks) {
        allTasks.filter { it.status != DownloadStatus.COMPLETED }
    }
    val completedTasks = remember(allTasks) {
        allTasks.filter { it.status == DownloadStatus.COMPLETED }
    }

    var showDeleteAllDialog by remember { mutableStateOf(false) }

    val storageProvider = viewModel.downloadQueueManager.storageProvider
    val usedBytes = remember(allTasks) { storageProvider.getUsedSpaceBytes() }
    val freeBytes = remember(allTasks) { storageProvider.getAvailableSpaceBytes() }
    val health = remember(allTasks) { storageProvider.validateStorage() }
    val locationName = remember { storageProvider.getStorageLocationName() }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        // Storage Header Card
        Card(
            shape = SquircleShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Storage Usage",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = "${formatBytes(usedBytes)} used • ${formatBytes(freeBytes)} free",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "Location: $locationName",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }

                    if (completedTasks.isNotEmpty() || activeTasks.isNotEmpty()) {
                        IconButton(onClick = { showDeleteAllDialog = true }) {
                            Icon(
                                imageVector = Icons.Filled.DeleteSweep,
                                contentDescription = "Delete all downloads",
                                tint = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                }

                // Storage Health Alerts
                if (health != StorageHealth.HEALTHY) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Surface(
                        shape = SquircleShape(10.dp),
                        color = if (health == StorageHealth.STORAGE_FULL) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.tertiaryContainer,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Warning,
                                contentDescription = null,
                                tint = if (health == StorageHealth.STORAGE_FULL) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onTertiaryContainer,
                                modifier = Modifier.size(16.dp)
                            )
                            Text(
                                text = when (health) {
                                    StorageHealth.PERMISSION_REVOKED -> "Storage permission revoked. Please re-select folder in Settings."
                                    StorageHealth.FOLDER_DELETED -> "Download folder missing. Please re-select in Settings."
                                    StorageHealth.STORAGE_FULL -> "Storage full (<50 MB free). Free up space to resume downloads."
                                    else -> ""
                                },
                                style = MaterialTheme.typography.labelSmall,
                                color = if (health == StorageHealth.STORAGE_FULL) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onTertiaryContainer
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Main List
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(bottom = 80.dp)
        ) {
            // Active Downloads Section
            if (activeTasks.isNotEmpty()) {
                item {
                    Text(
                        text = "Active Queue (${activeTasks.size})",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(vertical = 4.dp)
                    )
                }

                items(activeTasks, key = { "active_${it.track.id}" }) { task ->
                    ActiveDownloadRow(
                        task = task,
                        onPause = { viewModel.downloadQueueManager.pause(task.track.id) },
                        onResume = { viewModel.downloadQueueManager.resume(task.track.id) },
                        onRetry = { viewModel.downloadQueueManager.retry(task.track.id) },
                        onCancel = { viewModel.downloadQueueManager.cancel(task.track.id) }
                    )
                }

                item {
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }

            // Completed Downloads Section
            item {
                Text(
                    text = "Downloaded Tracks (${completedTasks.size})",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }

            if (completedTasks.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Filled.DownloadDone,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                                modifier = Modifier.size(48.dp)
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "No downloaded tracks yet",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "Tap download on songs, albums, or playlists for offline play",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                            )
                        }
                    }
                }
            } else {
                items(completedTasks, key = { "done_${it.track.id}" }) { task ->
                    CompletedDownloadRow(
                        task = task,
                        onClick = { viewModel.playTrack(task.track) },
                        onDelete = { viewModel.downloadQueueManager.deleteCompleted(task.track.id) }
                    )
                }
            }
        }
    }

    if (showDeleteAllDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteAllDialog = false },
            title = { Text("Delete All Downloads") },
            text = { Text("Are you sure you want to delete all downloaded tracks from storage?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.downloadQueueManager.deleteAll()
                        showDeleteAllDialog = false
                    }
                ) {
                    Text("Delete All", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAllDialog = false }) {
                    Text("Cancel")
                }
            },
            shape = SquircleShape(16.dp)
        )
    }
}

@Composable
fun ActiveDownloadRow(
    task: DownloadTask,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onRetry: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        shape = SquircleShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        modifier = modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AsyncCoverArt(
                url = task.track.coverUrl,
                modifier = Modifier.size(44.dp),
                shape = SquircleShape(8.dp)
            )

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = task.track.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = task.track.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(4.dp))

                LinearProgressIndicator(
                    progress = { task.progress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp),
                    color = if (task.status == DownloadStatus.FAILED) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                )

                Spacer(modifier = Modifier.height(2.dp))

                val statusText = when (task.status) {
                    DownloadStatus.DOWNLOADING -> "${(task.progress * 100).toInt()}% • ${formatBytes(task.bytesDownloaded)} / ${formatBytes(task.totalBytes)}"
                    DownloadStatus.QUEUED -> "Queued in download engine"
                    DownloadStatus.PAUSED -> "Paused • ${formatBytes(task.bytesDownloaded)}"
                    DownloadStatus.FAILED -> "Failed: ${task.lastError ?: "Error"}"
                    else -> ""
                }
                Text(
                    text = statusText,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (task.status == DownloadStatus.FAILED) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Action Buttons
            when (task.status) {
                DownloadStatus.DOWNLOADING -> {
                    IconButton(onClick = onPause, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Filled.Pause, contentDescription = "Pause", modifier = Modifier.size(20.dp))
                    }
                    IconButton(onClick = onCancel, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Filled.Close, contentDescription = "Cancel", modifier = Modifier.size(20.dp))
                    }
                }
                DownloadStatus.PAUSED -> {
                    IconButton(onClick = onResume, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Filled.PlayArrow, contentDescription = "Resume", modifier = Modifier.size(20.dp))
                    }
                    IconButton(onClick = onCancel, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Filled.Close, contentDescription = "Cancel", modifier = Modifier.size(20.dp))
                    }
                }
                DownloadStatus.FAILED -> {
                    IconButton(onClick = onRetry, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Filled.Refresh, contentDescription = "Retry", modifier = Modifier.size(20.dp))
                    }
                    IconButton(onClick = onCancel, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Filled.Close, contentDescription = "Cancel", modifier = Modifier.size(20.dp))
                    }
                }
                else -> {
                    IconButton(onClick = onCancel, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Filled.Close, contentDescription = "Cancel", modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
    }
}

@Composable
fun CompletedDownloadRow(
    task: DownloadTask,
    onClick: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncCoverArt(
            url = task.track.coverUrl,
            modifier = Modifier.size(48.dp),
            shape = SquircleShape(10.dp)
        )

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = task.track.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.DownloadDone,
                    contentDescription = "Downloaded",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = "${task.track.artist} • ${formatBytes(task.totalBytes)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        BitrateBadge(
            bitrateKbps = task.bitrateKbps,
            codec = task.codec,
            isFallback = false
        )

        IconButton(onClick = onDelete, modifier = Modifier.size(40.dp)) {
            Icon(
                imageVector = Icons.Filled.DeleteOutline,
                contentDescription = "Delete download",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

fun formatBytes(bytes: Long): String {
    if (bytes <= 0) return "0 B"
    val kb = bytes / 1024.0
    val mb = kb / 1024.0
    val gb = mb / 1024.0
    return when {
        gb >= 1.0 -> "${(gb * 10).toInt() / 10.0} GB"
        mb >= 1.0 -> "${(mb * 10).toInt() / 10.0} MB"
        kb >= 1.0 -> "${kb.toInt()} KB"
        else -> "$bytes B"
    }
}
