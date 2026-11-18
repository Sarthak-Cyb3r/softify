package com.softify.app.ui

import androidx.compose.animation.*
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.softify.app.ui.components.MiniPlayer
import com.softify.app.ui.components.QueueBottomSheet
import com.softify.app.ui.details.AlbumDetailScreen
import com.softify.app.ui.details.ArtistDetailScreen
import com.softify.app.ui.diagnostics.DiagnosticsScreen
import com.softify.app.ui.gallery.ComponentGalleryScreen
import com.softify.app.ui.home.HomeScreen
import com.softify.app.ui.library.LibraryScreen
import com.softify.app.ui.library.PlaylistDetailScreen
import com.softify.app.ui.metrolist.MetrolistNowPlaying
import com.softify.app.ui.search.SearchScreen
import com.softify.app.ui.settings.SettingsScreen
import com.softify.app.ui.theme.MetrolistTheme
import com.softify.app.ui.theme.SquircleShape
import com.softify.app.viewmodel.NavigationTab
import com.softify.app.viewmodel.PlaybackViewModel
import uniffi.softify_core.Playlist
import uniffi.softify_core.Track

@Composable
fun App(viewModel: PlaybackViewModel = remember { PlaybackViewModel() }) {
    val currentTab by viewModel.currentTab.collectAsState()
    val activeTrack by viewModel.activeTrack.collectAsState()
    val activeStream by viewModel.activeStream.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()
    val playbackProgress by viewModel.playbackProgress.collectAsState()
    val isNowPlayingExpanded by viewModel.isNowPlayingExpanded.collectAsState()
    val isQueueSheetOpen by viewModel.isQueueSheetOpen.collectAsState()

    var showSettings by remember { mutableStateOf(false) }
    var showDiagnostics by remember { mutableStateOf(false) }
    val isGalleryOpen by viewModel.isGalleryOpen.collectAsState()

    var selectedPlaylistDetail by remember { mutableStateOf<Playlist?>(null) }
    var selectedSmartPlaylistTitle by remember { mutableStateOf<String?>(null) }
    var selectedSmartPlaylistTracks by remember { mutableStateOf<List<Track>?>(null) }

    var selectedArtist by remember { mutableStateOf<String?>(null) }
    var selectedAlbum by remember { mutableStateOf<Pair<String, String>?>(null) }

    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.snackbarEvents.collect { message ->
            snackbarHostState.showSnackbar(message)
        }
    }

    MetrolistTheme {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    isGalleryOpen -> {
                        ComponentGalleryScreen(
                            onClose = { viewModel.closeComponentGallery() }
                        )
                    }

                    showDiagnostics -> {
                        DiagnosticsScreen(
                            viewModel = viewModel,
                            onClose = { showDiagnostics = false }
                        )
                    }

                    showSettings -> {
                        SettingsScreen(
                            viewModel = viewModel,
                            onBack = { showSettings = false },
                            onOpenDiagnostics = { showDiagnostics = true },
                            onOpenGallery = { viewModel.openComponentGallery() }
                        )
                    }

                    selectedArtist != null -> {
                        ArtistDetailScreen(
                            artist = selectedArtist!!,
                            viewModel = viewModel,
                            onBack = { selectedArtist = null },
                            onOpenAlbum = { album, artist ->
                                selectedAlbum = album to artist
                            }
                        )
                    }

                    selectedAlbum != null -> {
                        AlbumDetailScreen(
                            album = selectedAlbum!!.first,
                            artist = selectedAlbum!!.second,
                            viewModel = viewModel,
                            onBack = { selectedAlbum = null },
                            onOpenArtist = { artist ->
                                selectedArtist = artist
                            }
                        )
                    }

                    selectedPlaylistDetail != null || selectedSmartPlaylistTitle != null -> {
                        PlaylistDetailScreen(
                            playlist = selectedPlaylistDetail,
                            smartTitle = selectedSmartPlaylistTitle,
                            smartTracks = selectedSmartPlaylistTracks,
                            viewModel = viewModel,
                            onBack = {
                                selectedPlaylistDetail = null
                                selectedSmartPlaylistTitle = null
                                selectedSmartPlaylistTracks = null
                            },
                            onOpenArtist = { artist -> selectedArtist = artist },
                            onOpenAlbum = { album, artist -> selectedAlbum = album to artist }
                        )
                    }

                    else -> {
                        Scaffold(
                            snackbarHost = { SnackbarHost(snackbarHostState) },
                            bottomBar = {
                                Column(modifier = Modifier.navigationBarsPadding()) {
                                    // Docked Mini Player
                                    if (activeTrack != null) {
                                        MiniPlayer(
                                            track = activeTrack,
                                            streamInfo = activeStream,
                                            isPlaying = isPlaying,
                                            progress = playbackProgress,
                                            onPlayPause = { viewModel.togglePlayPause() },
                                            onNext = { viewModel.skipNext() },
                                            onClick = {
                                                viewModel.openNowPlaying()
                                            }
                                        )
                                    }

                                    // Material 3 Expressive Navigation Bar
                                    NavigationBar(
                                        containerColor = MaterialTheme.colorScheme.surfaceContainer,
                                        tonalElevation = 2.dp
                                    ) {
                                        NavigationBarItem(
                                            selected = currentTab == NavigationTab.HOME,
                                            onClick = { viewModel.setTab(NavigationTab.HOME) },
                                            icon = {
                                                Icon(
                                                    imageVector = if (currentTab == NavigationTab.HOME) Icons.Filled.Home else Icons.Outlined.Home,
                                                    contentDescription = "Home"
                                                )
                                            },
                                            label = { Text("Home") }
                                        )

                                        NavigationBarItem(
                                            selected = currentTab == NavigationTab.SEARCH,
                                            onClick = { viewModel.setTab(NavigationTab.SEARCH) },
                                            icon = {
                                                Icon(
                                                    imageVector = if (currentTab == NavigationTab.SEARCH) Icons.Filled.Search else Icons.Outlined.Search,
                                                    contentDescription = "Search"
                                                )
                                            },
                                            label = { Text("Search") }
                                        )

                                        NavigationBarItem(
                                            selected = currentTab == NavigationTab.LIBRARY,
                                            onClick = { viewModel.setTab(NavigationTab.LIBRARY) },
                                            icon = {
                                                Icon(
                                                    imageVector = if (currentTab == NavigationTab.LIBRARY) Icons.Filled.LibraryMusic else Icons.Outlined.LibraryMusic,
                                                    contentDescription = "Library"
                                                )
                                            },
                                            label = { Text("Library") }
                                        )
                                    }
                                }
                            }
                        ) { innerPadding ->
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(bottom = innerPadding.calculateBottomPadding())
                            ) {
                                when (currentTab) {
                                    NavigationTab.HOME -> {
                                        HomeScreen(
                                            viewModel = viewModel,
                                            onOpenSettings = { showSettings = true },
                                            onOpenArtist = { artist -> selectedArtist = artist },
                                            onOpenAlbum = { album, artist -> selectedAlbum = album to artist }
                                        )
                                    }

                                    NavigationTab.SEARCH -> {
                                        SearchScreen(
                                            viewModel = viewModel,
                                            onOpenArtist = { artist -> selectedArtist = artist },
                                            onOpenAlbum = { album, artist -> selectedAlbum = album to artist }
                                        )
                                    }

                                    NavigationTab.LIBRARY -> {
                                        LibraryScreen(
                                            viewModel = viewModel,
                                            onOpenPlaylistDetail = { playlist ->
                                                selectedPlaylistDetail = playlist
                                            },
                                            onOpenSmartPlaylist = { title, tracks ->
                                                selectedSmartPlaylistTitle = title
                                                selectedSmartPlaylistTracks = tracks
                                            },
                                            onOpenArtist = { artist -> selectedArtist = artist },
                                            onOpenAlbum = { album, artist -> selectedAlbum = album to artist }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Full Now Playing overlay (Container Transform / Spring slide up)
                AnimatedVisibility(
                    visible = isNowPlayingExpanded,
                    enter = slideInVertically(
                        initialOffsetY = { it },
                        animationSpec = spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow)
                    ) + fadeIn(),
                    exit = slideOutVertically(
                        targetOffsetY = { it },
                        animationSpec = spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow)
                    ) + fadeOut()
                ) {
                    MetrolistNowPlaying(
                        viewModel = viewModel,
                        onCollapse = { viewModel.closeNowPlaying() },
                        onOpenDiagnostics = { showDiagnostics = true },
                        onOpenArtist = { artist ->
                            viewModel.closeNowPlaying()
                            selectedArtist = artist
                        },
                        onOpenAlbum = { album, artist ->
                            viewModel.closeNowPlaying()
                            selectedAlbum = album to artist
                        }
                    )
                }

                // Queue Bottom Sheet
                if (isQueueSheetOpen) {
                    QueueBottomSheet(
                        viewModel = viewModel,
                        onDismissRequest = { viewModel.closeQueueSheet() }
                    )
                }
            }
        }
    }
}
