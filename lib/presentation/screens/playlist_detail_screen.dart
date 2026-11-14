import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_player_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/shared/app_dialog.dart';
import '../widgets/shared/app_network_image.dart';
import '../widgets/shared/aurora_background.dart';
import '../widgets/shared/track_row.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../providers/spotify_import_providers.dart';
import '../widgets/spotify_logo_badge.dart';

// Quality of Life Features
import '../../features/qol/playlist_search_filter.dart';
import '../../features/qol/playlist_sorter.dart';
import '../../features/qol/playlist_m3u_exporter.dart';
import '../../features/qol/library/playlist_duplicate_cleaner.dart';
import '../../features/qol/library/custom_playlist_cover_picker.dart' hide SharedPreferences;
import '../../features/qol/queue/smart_bpm_shuffle.dart' hide SharedPreferences;

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _isSyncing = false;
  bool _isSearchOpen = false;
  String _searchQuery = '';
  PlaylistSearchScope _searchScope = PlaylistSearchScope.all;
  final TextEditingController _searchController = TextEditingController();
  PlaylistSortCriteria _sortCriteria = PlaylistSortCriteria.customOrder;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCoverEditor(Playlist playlist, List<Track> tracks) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaylistCoverEditorSheet(
        playlistId: playlist.id,
        playlistName: playlist.name,
        trackCoverUrls: tracks
            .map((t) => t.coverUrl)
            .whereType<String>()
            .where((url) => url.isNotEmpty)
            .toList(),
      ),
    );
  }

  void _showDuplicateCleaner(Playlist playlist) {
    showDialog<void>(
      context: context,
      builder: (_) => DuplicateCleanerDialog(
        playlistId: playlist.id,
        playlistName: playlist.name,
      ),
    );
  }

  void _exportPlaylist(Playlist playlist, List<Track> tracks, {bool isCsv = false}) {
    PlaylistM3uExporter.exportToFile(
      context,
      playlist.name,
      tracks,
      isCsv: isCsv,
    );
  }

  Future<void> _showSortSheet(Playlist playlist) async {
    final chosen = await PlaylistSortSheet.show(
      context,
      playlistId: playlist.id,
      currentCriteria: _sortCriteria,
      title: 'Sort ${playlist.name}',
    );
    if (chosen != null && mounted) {
      setState(() => _sortCriteria = chosen);
    }
  }

  void _smartBpmShufflePlay(List<Track> tracks) {
    if (tracks.isEmpty) return;
    final sorted = SmartBpmShuffleAlgorithm.reorder(tracks: tracks);
    ref.read(audioHandlerProvider).setQueue(sorted, startIndex: 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('DJ Smart BPM & Harmonic Shuffle activated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoSync(showNoUpdatesToast: false);
    });
  }

  Future<void> _checkAndAutoSync({bool showNoUpdatesToast = false}) async {
    if (_isSyncing) return;
    final playlistData = await ref
        .read(libraryRepositoryProvider)
        .getPlaylistWithTracks(widget.playlistId);
    if (playlistData == null || !playlistData.playlist.isImported) return;

    setState(() => _isSyncing = true);
    try {
      final addedCount = await ref
          .read(spotifyPlaylistSyncServiceProvider)
          .syncPlaylist(widget.playlistId);

      if (mounted) {
        if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SpotifyLogoBadge(size: 16, hasShadow: false),
                  const SizedBox(width: 8),
                  Text(
                    'Spotify playlist updated: added $addedCount new song${addedCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1DB954),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (showNoUpdatesToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SpotifyLogoBadge(size: 16, hasShadow: false),
                  SizedBox(width: 8),
                  Text('Spotify playlist is up to date'),
                ],
              ),
              backgroundColor: Color(0xFF212529),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _playAll(List<Track> tracks, {bool shuffle = false, int startIndex = 0}) {
    if (tracks.isEmpty) return;
    final audioHandler = ref.read(audioHandlerProvider);

    if (shuffle) {
      final shuffled = List<Track>.from(tracks)..shuffle();
      audioHandler.setQueue(shuffled, startIndex: 0);
    } else {
      audioHandler.setQueue(tracks, startIndex: startIndex);
    }
  }

  void _downloadAll(List<Track> tracks) async {
    final downloadRepo = ref.read(downloadRepositoryProvider);
    int queuedCount = 0;

    for (final track in tracks) {
      final isDone = await downloadRepo.isDownloaded(track.id);
      if (!isDone) {
        await downloadRepo.queueDownload(track);
        queuedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queuedCount > 0
                ? 'Queued $queuedCount tracks for offline download'
                : 'All tracks are already downloaded offline',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmDeletePlaylist(BuildContext context, Playlist playlist) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete Playlist?',
      message: 'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final playlistAsync = ref.watch(playlistWithTracksStreamProvider(widget.playlistId));
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentTrack =
        ref.watch(currentTrackProvider).value ?? audioHandler.currentTrack;
    final isPlaying = ref.watch(isPlayingProvider);

    return AuroraBackground(
      child: Scaffold(
        backgroundColor:
            tokens.isGlass ? Colors.transparent : tokens.background,
      bottomNavigationBar: MediaQuery.of(context).size.width < 800
          ? const SafeArea(top: false, bottom: true, child: MiniPlayer())
          : const DesktopPlayerBar(),
      body: playlistAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.accent),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Playlist')),
          body: Center(child: Text('Error loading playlist: $e')),
        ),
        data: (data) {
          if (data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Playlist')),
              body: const Center(child: Text('Playlist not found')),
            );
          }

          final playlist = data.playlist;
          final rawTracks = data.entries
              .map((e) =>
                  e.track ??
                  Track(
                    id: e.trackId ?? 'spotify_${e.playlistId}_${e.position}',
                    sourceId: e.trackId ?? 'spotify_${e.playlistId}_${e.position}',
                    title: e.originalTitle,
                    artist: e.originalArtist,
                    duration: Duration.zero,
                  ))
              .toList();

          // 1. Sort tracks according to selected criterion
          final sortedTracks = sortPlaylistTracks(
            rawTracks,
            _sortCriteria,
            trackExtractor: (t) => t,
          );

          // 2. Filter tracks if search query is active
          final tracks = _searchQuery.trim().isNotEmpty
              ? PlaylistSearchFilterHelper.filterTracks(
                  tracks: sortedTracks,
                  query: _searchQuery,
                  scope: _searchScope,
                )
              : sortedTracks;

          // Find first available cover URL for artwork header
          String? coverUrl;
          for (final t in rawTracks) {
            if (t.coverUrl != null && t.coverUrl!.isNotEmpty) {
              coverUrl = t.coverUrl;
              break;
            }
          }

          return CustomScrollView(
            slivers: [
              // 1. Spotify-Style Header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor:
                    tokens.isGlass ? Colors.transparent : tokens.surface,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  // Search In Playlist Button
                  IconButton(
                    icon: Icon(
                      _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                      color: _isSearchOpen ? tokens.accent : Colors.white70,
                    ),
                    tooltip: _isSearchOpen ? 'Close Search' : 'Search in Playlist',
                    onPressed: () {
                      setState(() {
                        _isSearchOpen = !_isSearchOpen;
                        if (!_isSearchOpen) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                  ),

                  // Sort Playlist Button
                  IconButton(
                    icon: Icon(
                      Icons.sort_rounded,
                      color: _sortCriteria != PlaylistSortCriteria.customOrder
                          ? tokens.accent
                          : Colors.white70,
                    ),
                    tooltip: 'Sort: ${_sortCriteria.label}',
                    onPressed: () => _showSortSheet(playlist),
                  ),

                  // More Options Popup Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                    tooltip: 'Playlist Options',
                    onSelected: (val) {
                      switch (val) {
                        case 'search':
                          setState(() => _isSearchOpen = true);
                          break;
                        case 'sort':
                          _showSortSheet(playlist);
                          break;
                        case 'cover':
                          _showCoverEditor(playlist, rawTracks);
                          break;
                        case 'clean_duplicates':
                          _showDuplicateCleaner(playlist);
                          break;
                        case 'smart_shuffle':
                          _smartBpmShufflePlay(rawTracks);
                          break;
                        case 'export_m3u':
                          _exportPlaylist(playlist, rawTracks, isCsv: false);
                          break;
                        case 'export_csv':
                          _exportPlaylist(playlist, rawTracks, isCsv: true);
                          break;
                        case 'delete':
                          _confirmDeletePlaylist(context, playlist);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'search',
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 18, color: tokens.textSecondary),
                            const SizedBox(width: 10),
                            const Text('Search in playlist'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'sort',
                        child: Row(
                          children: [
                            Icon(Icons.sort_rounded, size: 18, color: tokens.textSecondary),
                            const SizedBox(width: 10),
                            Text('Sort (${_sortCriteria.label})'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'cover',
                        child: Row(
                          children: [
                            Icon(Icons.image_outlined, size: 18, color: tokens.textSecondary),
                            const SizedBox(width: 10),
                            const Text('Change Cover Artwork'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clean_duplicates',
                        child: Row(
                          children: [
                            Icon(Icons.cleaning_services_rounded, size: 18, color: tokens.textSecondary),
                            const SizedBox(width: 10),
                            const Text('Clean Duplicate Tracks'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'smart_shuffle',
                        child: Row(
                          children: [
                            Icon(Icons.shuffle_on_rounded, size: 18, color: tokens.accent),
                            const SizedBox(width: 10),
                            const Text('DJ Smart BPM Shuffle'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'export_m3u',
                        child: Row(
                          children: [
                            Icon(Icons.file_download_outlined, size: 18, color: tokens.textSecondary),
                            const SizedBox(width: 10),
                            const Text('Export as M3U8 Playlist'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export_csv',
                        child: Row(
                          children: [
                            Icon(Icons.table_chart_outlined, size: 18, color: tokens.textSecondary),
                            const SizedBox(width: 10),
                            const Text('Export as CSV Spreadsheet'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: tokens.textPrimary,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          playlist.isImported
                              ? const Color(0xFF1DB954).withValues(alpha: 0.25)
                              : tokens.surfaceElevated.withValues(alpha: 0.6),
                          tokens.background,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 32),
                          GestureDetector(
                            onTap: () => _showCoverEditor(playlist, rawTracks),
                            child: Tooltip(
                              message: 'Tap to customize playlist artwork',
                              child: Stack(
                                children: [
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: tokens.card,
                                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: (coverUrl == null && playlist.isImported)
                                        ? Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF121212),
                                              borderRadius:
                                                  BorderRadius.circular(tokens.radiusCard),
                                            ),
                                            child: const Center(
                                              child: SpotifyLogoBadge(
                                                size: 64,
                                                hasShadow: false,
                                              ),
                                            ),
                                          )
                                        : AppNetworkImage(
                                            imageUrl: coverUrl,
                                            width: 140,
                                            height: 140,
                                            borderRadius:
                                                BorderRadius.circular(tokens.radiusCard),
                                            fit: BoxFit.cover,
                                            fallbackIcon: playlist.isImported
                                                ? Icons.music_note_rounded
                                                : Icons.queue_music,
                                            backgroundColor: tokens.card,
                                          ),
                                  ),
                                  if (playlist.isImported && coverUrl != null)
                                    const Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: SpotifyLogoBadge(size: 26),
                                    ),
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (playlist.isImported)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(tokens.radiusPill),
                                border: Border.all(
                                  color: const Color(0xFF1DB954).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SpotifyLogoBadge(size: 14, hasShadow: false),
                                  SizedBox(width: 6),
                                  Text(
                                    'Spotify Playlist',
                                    style: TextStyle(
                                      color: Color(0xFF1DB954),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: AppTheme.fontUi,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Playback Action Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      // Track count and duration subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _searchQuery.isNotEmpty
                                  ? '${tracks.length} matching (${rawTracks.length} total)'
                                  : '${tracks.length} tracks',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 13,
                                fontFamily: AppTheme.fontUi,
                              ),
                            ),
                            if (playlist.description != null && playlist.description!.isNotEmpty)
                              Text(
                                playlist.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 12,
                                  fontFamily: AppTheme.fontUi,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // In-Playlist Search Toggle Button
                      IconButton(
                        icon: Icon(
                          _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                          color: _isSearchOpen ? tokens.accent : tokens.textSecondary,
                        ),
                        tooltip: _isSearchOpen ? 'Close Search' : 'Search in Playlist',
                        onPressed: () {
                          setState(() {
                            _isSearchOpen = !_isSearchOpen;
                            if (!_isSearchOpen) {
                              _searchController.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                      ),

                      // Sort Playlist Button
                      IconButton(
                        icon: Icon(
                          Icons.sort_rounded,
                          color: _sortCriteria != PlaylistSortCriteria.customOrder
                              ? tokens.accent
                              : tokens.textSecondary,
                        ),
                        tooltip: 'Sort: ${_sortCriteria.label}',
                        onPressed: () => _showSortSheet(playlist),
                      ),

                      if (playlist.isImported)
                        IconButton(
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1DB954),
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, color: Color(0xFF1DB954)),
                          tooltip: 'Sync with Spotify',
                          onPressed: _isSyncing
                              ? null
                              : () => _checkAndAutoSync(showNoUpdatesToast: true),
                        ),

                      // Clean Duplicates Button
                      IconButton(
                        icon: Icon(Icons.cleaning_services_rounded, color: tokens.textSecondary),
                        tooltip: 'Clean Duplicate Tracks',
                        onPressed: () => _showDuplicateCleaner(playlist),
                      ),

                      // Download All Button
                      IconButton(
                        icon: Icon(Icons.download_for_offline_outlined, color: tokens.textSecondary),
                        tooltip: 'Download All Offline',
                        onPressed: rawTracks.isNotEmpty ? () => _downloadAll(rawTracks) : null,
                      ),

                      // DJ Smart BPM Shuffle Button
                      IconButton(
                        icon: Icon(Icons.shuffle_on_rounded, color: tokens.accent),
                        tooltip: 'DJ Smart BPM Shuffle',
                        onPressed: rawTracks.isNotEmpty ? () => _smartBpmShufflePlay(rawTracks) : null,
                      ),

                      // Shuffle Button
                      IconButton(
                        icon: Icon(Icons.shuffle_rounded, color: tokens.textSecondary),
                        tooltip: 'Shuffle Play',
                        onPressed: tracks.isNotEmpty ? () => _playAll(tracks, shuffle: true) : null,
                      ),

                      const SizedBox(width: 8),

                      // Big Play Button (52px circle)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow_rounded, size: 30, color: Color(0xFF000000)),
                          tooltip: 'Play',
                          onPressed: tracks.isNotEmpty ? () => _playAll(tracks, startIndex: 0) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2.5. In-Playlist Search Bar (when search is open)
              if (_isSearchOpen)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search in playlist by title, artist, or album...',
                            hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: tokens.accent),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () => setState(() {
                                      _isSearchOpen = false;
                                      _searchController.clear();
                                      _searchQuery = '';
                                    }),
                                  ),
                            filled: true,
                            fillColor: tokens.surfaceElevated,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              borderSide: BorderSide(color: tokens.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              borderSide: BorderSide(color: tokens.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              borderSide: BorderSide(color: tokens.accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Filter: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ...PlaylistSearchScope.values.map((s) {
                              final isSelected = _searchScope == s;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(s.label),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) setState(() => _searchScope = s);
                                  },
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : tokens.textSecondary,
                                  ),
                                  selectedColor: tokens.accent,
                                  backgroundColor: tokens.surfaceElevated,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                                    side: BorderSide(
                                      color: isSelected ? tokens.accent : tokens.divider,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                ),
                              );
                            }),
                          ],
                        ),
                        if (_searchQuery.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Showing ${tracks.length} of ${rawTracks.length} tracks',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // 3. Track List
              if (tracks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_off, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No tracks in this playlist yet',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = tracks[index];
                        final isCurrentTrack = currentTrack?.id == track.id;

                        return _buildTrackTile(
                          context: context,
                          tokens: tokens,
                          track: track,
                          index: index,
                          allTracks: tracks,
                          isPlayingThis: isCurrentTrack && isPlaying,
                          isSelected: isCurrentTrack,
                          playlistId: playlist.id,
                        );
                      },
                      childCount: tracks.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildTrackTile({
    required BuildContext context,
    required AppTokens tokens,
    required Track track,
    required int index,
    required List<Track> allTracks,
    required bool isPlayingThis,
    bool isSelected = false,
    required String playlistId,
  }) {
    final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
    final isDownloadedAsync = ref.watch(isTrackDownloadedProvider(track.id));
    final isLiked = isLikedAsync.value ?? track.isLiked;
    final isDownloaded = isDownloadedAsync.value ?? false;

    return TrackRow(
      track: track.copyWith(isLiked: isLiked),
      index: index + 1,
      isPlaying: isPlayingThis,
      isSelected: isSelected,
      onTap: () => _playAll(allTracks, startIndex: index),
      onPlayTap: () => _playAll(allTracks, startIndex: index),
      onLikeTap: () {
        final newLiked = !isLiked;
        ref.read(libraryRepositoryProvider).setLiked(track.id, newLiked, track: track.copyWith(isLiked: newLiked));
        ref.read(audioHandlerProvider).updateTrackLikedState(track.id, newLiked);
      },
      onOptionsTap: () {
        TrackOptionsBottomSheet.show(
          context,
          track: track,
          currentPlaylistId: playlistId,
          currentPlaylistTrackIndex: index,
        );
      },
      trailing: IconButton(
        iconSize: 18.0,
        splashRadius: 18.0,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: Icon(
          isDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_outlined,
          color: isDownloaded ? tokens.accent : tokens.textMuted,
        ),
        tooltip: isDownloaded ? 'Downloaded' : 'Download Offline',
        onPressed: isDownloaded
            ? null
            : () async {
                await ref.read(downloadRepositoryProvider).queueDownload(track);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading "${track.title}"...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
      ),
    );
  }


}
