package com.softify.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.ui.theme.SquircleShape
import uniffi.softify_core.Track

/**
 * Standard Material 3 Expressive Track Item Row.
 * Includes cover art, title, artist, active playback indicator, and overflow dropdown menu.
 */
@Composable
fun TrackItemRow(
    track: Track,
    isActive: Boolean = false,
    isPlaying: Boolean = false,
    trackNumber: Int? = null,
    onClick: () -> Unit,
    onPlayNext: () -> Unit,
    onAddToQueue: () -> Unit,
    onStartRadio: (() -> Unit)? = null,
    onAddToPlaylist: () -> Unit = {},
    onToggleLike: () -> Unit = {},
    onRemoveFromPlaylist: (() -> Unit)? = null,
    onOpenArtist: ((String) -> Unit)? = null,
    onOpenAlbum: ((String) -> Unit)? = null,
    downloadProgress: Float? = null,
    isDownloaded: Boolean = false,
    onDownload: (() -> Unit)? = null,
    onDeleteDownload: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    var menuExpanded by remember { mutableStateOf(false) }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Optional Track Number or Active Wave Icon
        if (trackNumber != null) {
            Box(
                modifier = Modifier.width(28.dp),
                contentAlignment = Alignment.CenterStart
            ) {
                if (isActive && isPlaying) {
                    Icon(
                        imageVector = Icons.Filled.GraphicEq,
                        contentDescription = "Playing",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(18.dp)
                    )
                } else {
                    Text(
                        text = "$trackNumber",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // Cover Art Thumbnail
        AsyncCoverArt(
            url = track.coverUrl,
            modifier = Modifier.size(48.dp),
            shape = SquircleShape(10.dp)
        )

        Spacer(modifier = Modifier.width(12.dp))

        // Title and Artist
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = track.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = if (isActive) FontWeight.Bold else FontWeight.Medium,
                color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "${track.artist}${if (!track.album.isNullOrEmpty()) " • ${track.album}" else ""}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Ellipsis
            )
        }

        Spacer(modifier = Modifier.width(8.dp))

        // Download status indicator (vector icons only)
        if (downloadProgress != null) {
            CircularProgressIndicator(
                progress = { downloadProgress },
                modifier = Modifier.size(16.dp),
                strokeWidth = 2.dp,
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceContainerHighest
            )
            Spacer(modifier = Modifier.width(6.dp))
        } else if (isDownloaded) {
            Icon(
                imageVector = Icons.Filled.DownloadDone,
                contentDescription = "Downloaded",
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
        }

        // Duration text (if durationMs > 0)
        if (track.durationMs > 0u) {
            val totalSec = track.durationMs / 1000u
            val min = totalSec / 60u
            val sec = totalSec % 60u
            Text(
                text = "$min:${sec.toString().padStart(2, '0')}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(end = 4.dp)
            )
        }

        // Overflow 3-dots Menu Button
        Box {
            IconButton(
                onClick = { menuExpanded = true },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.MoreVert,
                    contentDescription = "Track options",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
            }

            DropdownMenu(
                expanded = menuExpanded,
                onDismissRequest = { menuExpanded = false },
                shape = SquircleShape(12.dp),
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            ) {
                if (onStartRadio != null) {
                    DropdownMenuItem(
                        text = { Text("Start radio") },
                        leadingIcon = {
                            Icon(Icons.Filled.Radio, contentDescription = null, modifier = Modifier.size(20.dp))
                        },
                        onClick = {
                            menuExpanded = false
                            onStartRadio()
                        }
                    )
                }

                DropdownMenuItem(
                    text = { Text("Play next") },
                    leadingIcon = {
                        Icon(Icons.Filled.PlaylistPlay, contentDescription = null, modifier = Modifier.size(20.dp))
                    },
                    onClick = {
                        menuExpanded = false
                        onPlayNext()
                    }
                )

                DropdownMenuItem(
                    text = { Text("Add to queue") },
                    leadingIcon = {
                        Icon(Icons.Filled.QueueMusic, contentDescription = null, modifier = Modifier.size(20.dp))
                    },
                    onClick = {
                        menuExpanded = false
                        onAddToQueue()
                    }
                )

                DropdownMenuItem(
                    text = { Text("Add to playlist") },
                    leadingIcon = {
                        Icon(Icons.Filled.PlaylistAdd, contentDescription = null, modifier = Modifier.size(20.dp))
                    },
                    onClick = {
                        menuExpanded = false
                        onAddToPlaylist()
                    }
                )

                if (isDownloaded) {
                    DropdownMenuItem(
                        text = { Text("Delete download") },
                        leadingIcon = {
                            Icon(Icons.Filled.DeleteOutline, contentDescription = null, modifier = Modifier.size(20.dp))
                        },
                        onClick = {
                            menuExpanded = false
                            onDeleteDownload?.invoke()
                        }
                    )
                } else if (onDownload != null) {
                    DropdownMenuItem(
                        text = { Text("Download") },
                        leadingIcon = {
                            Icon(Icons.Filled.Download, contentDescription = null, modifier = Modifier.size(20.dp))
                        },
                        onClick = {
                            menuExpanded = false
                            onDownload()
                        }
                    )
                }

                DropdownMenuItem(
                    text = { Text(if (track.isLiked) "Unlike" else "Like") },
                    leadingIcon = {
                        Icon(
                            imageVector = if (track.isLiked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = null,
                            tint = if (track.isLiked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    },
                    onClick = {
                        menuExpanded = false
                        onToggleLike()
                    }
                )

                if (onOpenArtist != null) {
                    DropdownMenuItem(
                        text = { Text("Go to artist") },
                        leadingIcon = {
                            Icon(Icons.Filled.Person, contentDescription = null, modifier = Modifier.size(20.dp))
                        },
                        onClick = {
                            menuExpanded = false
                            onOpenArtist(track.artist)
                        }
                    )
                }

                if (onOpenAlbum != null && !track.album.isNullOrEmpty()) {
                    DropdownMenuItem(
                        text = { Text("Go to album") },
                        leadingIcon = {
                            Icon(Icons.Filled.Album, contentDescription = null, modifier = Modifier.size(20.dp))
                        },
                        onClick = {
                            menuExpanded = false
                            onOpenAlbum(track.album!!)
                        }
                    )
                }

                if (onRemoveFromPlaylist != null) {
                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                    DropdownMenuItem(
                        text = { Text("Remove from playlist", color = MaterialTheme.colorScheme.error) },
                        leadingIcon = {
                            Icon(
                                Icons.Filled.Delete,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(20.dp)
                            )
                        },
                        onClick = {
                            menuExpanded = false
                            onRemoveFromPlaylist()
                        }
                    )
                }
            }
        }
    }
}
