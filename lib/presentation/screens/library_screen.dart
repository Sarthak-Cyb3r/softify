import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/folder_launcher_service.dart';
import '../../data/services/local_audio_scanner.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/shelf_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/shared/shared_components.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../widgets/wrapped_insights_dialog.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';
import 'spotify_import_screen.dart';
import 'tracks_list_screen.dart';

enum LibrarySortOrder {
  recentlyAdded('Recent'),
  titleAZ('Title A-Z'),
  artistAZ('Artist A-Z');

  final String label;
  const LibrarySortOrder(this.label);
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanningLocalAudio = false;
  LibrarySortOrder _likedSort = LibrarySortOrder.recentlyAdded;
  LibrarySortOrder _downloadsSort = LibrarySortOrder.recentlyAdded;
  LibrarySortOrder _deviceMusicSort = LibrarySortOrder.recentlyAdded;

  List<Track> _sortTracks(List<Track> list, LibrarySortOrder sort) {
    if (sort == LibrarySortOrder.recentlyAdded) return list;
    final copy = List<Track>.from(list);
    switch (sort) {
      case LibrarySortOrder.recentlyAdded:
        return copy;
      case LibrarySortOrder.titleAZ:
        final titles = {for (final t in copy) t: t.title.toLowerCase()};
        copy.sort((a, b) => titles[a]!.compareTo(titles[b]!));
        return copy;
      case LibrarySortOrder.artistAZ:
        final artists = {for (final t in copy) t: t.artist.toLowerCase()};
        copy.sort((a, b) => artists[a]!.compareTo(artists[b]!));
        return copy;
    }
  }

  List<DownloadItem> _sortDownloads(List<DownloadItem> list, LibrarySortOrder sort) {
    if (sort == LibrarySortOrder.recentlyAdded) return list;
    final copy = List<DownloadItem>.from(list);
    switch (sort) {
      case LibrarySortOrder.recentlyAdded:
        return copy;
      case LibrarySortOrder.titleAZ:
        final titles = {for (final d in copy) d: (d.track?.title ?? d.trackId).toLowerCase()};
        copy.sort((a, b) => titles[a]!.compareTo(titles[b]!));
        return copy;
      case LibrarySortOrder.artistAZ:
        final artists = {for (final d in copy) d: (d.track?.artist ?? '').toLowerCase()};
        copy.sort((a, b) => artists[a]!.compareTo(artists[b]!));
        return copy;
    }
  }

  Widget _buildLibraryActionHeader({
    required AppTokens tokens,
    required int trackCount,
    required LibrarySortOrder currentSort,
    required ValueChanged<LibrarySortOrder> onSortChanged,
    required VoidCallback onPlayAll,
    required VoidCallback onShuffle,
    Widget? trailingAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            AppFilterChip(
              label: currentSort.label,
              isSelected: false,
              height: 32,
              icon: const Icon(Icons.swap_vert_rounded, size: 14),
              onTap: () {
                final nextIndex = (currentSort.index + 1) % LibrarySortOrder.values.length;
                onSortChanged(LibrarySortOrder.values[nextIndex]);
              },
            ),
            const SizedBox(width: 10),
            Text(
              '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            if (trailingAction != null) ...[
              trailingAction,
              const SizedBox(width: 8),
            ],
            AppPillButton(
              label: 'Shuffle',
              icon: const Icon(Icons.shuffle_rounded, size: 16),
              variant: AppPillButtonVariant.secondary,
              height: 32,
              onPressed: onShuffle,
            ),
            const SizedBox(width: 8),
            AppPillButton(
              label: 'Play',
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              variant: AppPillButtonVariant.primary,
              height: 32,
              onPressed: onPlayAll,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanDeviceAudio() async {
    setState(() => _isScanningLocalAudio = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(databaseProvider);
      final count = await LocalAudioScanner.scanAndIndex(db);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Discovered and indexed $count local audio tracks'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error scanning audio: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanningLocalAudio = false);
      }
    }
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final tokens = context.tokens;
    final controller = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: 'New Playlist',
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              color: tokens.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: TextStyle(
                fontFamily: AppTheme.fontUi,
                color: tokens.textMuted,
                fontSize: 14,
              ),
              filled: true,
              fillColor: tokens.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          customActions: [
            AppPillButton(
              label: 'Cancel',
              variant: AppPillButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppPillButton(
              label: 'Create',
              variant: AppPillButtonVariant.primary,
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await ref.read(libraryRepositoryProvider).createPlaylist(name);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (_) {}
                }
              },
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final likedAsync = ref.watch(likedTracksStreamProvider);
    final downloadsAsync = ref.watch(downloadsStreamProvider);
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final localTracksAsync = ref.watch(localTracksStreamProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentTrack = ref.watch(currentTrackProvider).value;
    final isPlaying = ref.watch(isPlayingProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: tokens.isGlass ? Colors.transparent : tokens.background,
      appBar: AppBar(
        backgroundColor:
            tokens.isGlass ? Colors.transparent : tokens.background,
        elevation: 0,
        title: Text(
          'Your Library',
          style: TextStyle(
            fontFamily: AppTheme.fontPageTitle,
            fontSize: isDesktop ? 28 : 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
          if (isDesktop) ...[
            AppPillButton(
              label: 'Create playlist',
              icon: const Icon(Icons.add_rounded, size: 16),
              variant: AppPillButtonVariant.primary,
              height: 32,
              onPressed: () => _showCreatePlaylistDialog(context),
            ),
            const SizedBox(width: 8),
          ] else ...[
            BouncingScaleButton(
              scaleFactor: 0.9,
              onTap: () => _showCreatePlaylistDialog(context),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.add_rounded, size: 24),
              ),
            ),
          ],
          BouncingScaleButton(
            scaleFactor: 0.9,
            onTap: _isScanningLocalAudio ? null : _scanDeviceAudio,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _isScanningLocalAudio
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
                    )
                  : const Icon(Icons.sync_rounded, size: 22),
            ),
          ),
          BouncingScaleButton(
            scaleFactor: 0.9,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Icon(Icons.settings_outlined, size: 22),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                AppFilterChip(
                  label: 'Playlists',
                  isSelected: _tabController.index == 0,
                  onTap: () => setState(() => _tabController.animateTo(0)),
                ),
                const SizedBox(width: 8),
                AppFilterChip(
                  label: 'Songs',
                  isSelected: _tabController.index == 1,
                  onTap: () => setState(() => _tabController.animateTo(1)),
                ),
                const SizedBox(width: 8),
                AppFilterChip(
                  label: 'Downloads',
                  isSelected: _tabController.index == 2,
                  onTap: () => setState(() => _tabController.animateTo(2)),
                ),
                const SizedBox(width: 8),
                AppFilterChip(
                  label: 'Device Music',
                  isSelected: _tabController.index == 3,
                  onTap: () => setState(() => _tabController.animateTo(3)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Playlists Tab
          _buildPlaylistsTab(
            tokens,
            playlistsAsync,
            isDesktop,
            likedAsync,
            downloadsAsync,
            audioHandler,
          ),

          // 2. Liked Songs Tab
          _buildLikedSongsTab(tokens, likedAsync, audioHandler, currentTrack, isPlaying),

          // 3. Downloads Tab
          _buildDownloadsTab(tokens, downloadsAsync, audioHandler, currentTrack, isPlaying),

          // 4. Device Music Tab
          _buildDeviceMusicTab(tokens, localTracksAsync, audioHandler, currentTrack, isPlaying),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab(
    AppTokens tokens,
    AsyncValue<List<Playlist>> playlistsAsync,
    bool isDesktop,
    AsyncValue<List<Track>> likedAsync,
    AsyncValue<List<DownloadItem>> downloadsAsync,
    dynamic audioHandler,
  ) {
    return playlistsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ShimmerSkeleton(
                width: 52,
                height: 52,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(
                      width: 140,
                      height: 14,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    const SizedBox(height: 6),
                    ShimmerSkeleton(
                      width: 80,
                      height: 12,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: TextStyle(color: tokens.textSecondary, fontFamily: AppTheme.fontUi, fontSize: 13)),
      ),
      data: (playlists) {
        final likedTracks = likedAsync.value ?? const <Track>[];
        final completedDownloads = (downloadsAsync.value ?? const <DownloadItem>[])
            .where((d) => d.isCompleted)
            .toList();
        final downloadedTracks =
            completedDownloads.map((d) => d.track).whereType<Track>().toList();

        if (playlists.isEmpty) {
          if (isDesktop) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 56,
                    color: tokens.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No playlists yet',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppPillButton(
                        label: 'New Playlist',
                        icon: const Icon(Icons.add_rounded, size: 18),
                        variant: AppPillButtonVariant.primary,
                        onPressed: () => _showCreatePlaylistDialog(context),
                      ),
                      const SizedBox(width: 12),
                      AppPillButton(
                        label: 'Import Spotify',
                        icon: const Icon(Icons.cloud_download_rounded, size: 18),
                        variant: AppPillButtonVariant.secondary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SpotifyImportScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildSmartPlaylistsSection(tokens),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    AppPillButton(
                      label: 'New Playlist',
                      icon: const Icon(Icons.add_rounded, size: 16),
                      variant: AppPillButtonVariant.secondary,
                      height: 32,
                      onPressed: () => _showCreatePlaylistDialog(context),
                    ),
                    const SizedBox(width: 10),
                    AppPillButton(
                      label: 'Import Spotify',
                      icon: const Icon(Icons.cloud_download_rounded, size: 16),
                      variant: AppPillButtonVariant.secondary,
                      height: 32,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SpotifyImportScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                  children: [
                    _buildPinnedLikedRow(tokens, likedTracks, audioHandler),
                    _buildPinnedDownloadedRow(tokens, downloadedTracks, completedDownloads.length, audioHandler),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'No custom playlists yet. Tap "+ New Playlist" to create one.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          color: tokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildSmartPlaylistsSection(tokens),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  AppPillButton(
                    label: 'New Playlist',
                    icon: const Icon(Icons.add_rounded, size: 16),
                    variant: AppPillButtonVariant.secondary,
                    height: 32,
                    onPressed: () => _showCreatePlaylistDialog(context),
                  ),
                  const SizedBox(width: 10),
                  AppPillButton(
                    label: 'Import Spotify',
                    icon: const Icon(Icons.cloud_download_rounded, size: 16),
                    variant: AppPillButtonVariant.secondary,
                    height: 32,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SpotifyImportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: isDesktop
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final pl = playlists[index];
                        return MediaCard(
                          title: pl.name,
                          subtitle: '${pl.trackCount} tracks${pl.isImported ? ' • Spotify' : ''}',
                          imageUrl: null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PlaylistDetailScreen(playlistId: pl.id),
                              ),
                            );
                          },
                          onPlayTap: () async {
                            final data = await ref
                                .read(libraryRepositoryProvider)
                                .getPlaylistWithTracks(pl.id);
                            final tracks = data?.entries
                                    .map((e) => e.track)
                                    .whereType<Track>()
                                    .toList() ??
                                [];
                            if (tracks.isNotEmpty) {
                              ref
                                  .read(audioHandlerProvider)
                                  .setQueue(tracks);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Playing "${pl.name}" (${tracks.length} tracks)'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor:
                                        tokens.surfaceElevated,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                      itemCount: 2 + playlists.length,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildPinnedLikedRow(tokens, likedTracks, audioHandler);
                        }
                        if (index == 1) {
                          return _buildPinnedDownloadedRow(
                            tokens,
                            downloadedTracks,
                            completedDownloads.length,
                            audioHandler,
                          );
                        }
                        final pl = playlists[index - 2];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(tokens.radiusCard),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailScreen(playlistId: pl.id),
                                ),
                              );
                            },
                            child: AppSurface(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              withBlur: true,
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceElevated,
                                      borderRadius:
                                          BorderRadius.circular(tokens.radiusSm),
                                    ),
                                    child: Icon(
                                      pl.isImported
                                          ? Icons.cloud_download_rounded
                                          : Icons.music_note_rounded,
                                      color: pl.isImported
                                          ? tokens.accent
                                          : tokens.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pl.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontUi,
                                            color: tokens.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${pl.trackCount} tracks${pl.isImported ? ' • Spotify' : ''}',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontUi,
                                            color: tokens.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  BouncingScaleButton(
                                    scaleFactor: 0.88,
                                    onTap: () async {
                                      final data = await ref
                                          .read(libraryRepositoryProvider)
                                          .getPlaylistWithTracks(pl.id);
                                      final tracks = data?.entries
                                              .map((e) => e.track)
                                              .whereType<Track>()
                                              .toList() ??
                                          [];
                                      if (tracks.isNotEmpty) {
                                        ref
                                            .read(audioHandlerProvider)
                                            .setQueue(tracks);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Playing "${pl.name}" (${tracks.length} tracks)'),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor:
                                                  tokens.surfaceElevated,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: AppTheme.accent,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  BouncingScaleButton(
                                    scaleFactor: 0.88,
                                    onTap: () {
                                      ref
                                          .read(libraryRepositoryProvider)
                                          .deletePlaylist(pl.id);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: tokens.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPinnedLikedRow(
    AppTokens tokens,
    List<Track> likedTracks,
    dynamic audioHandler,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        onTap: () => setState(() => _tabController.animateTo(1)),
        child: AppSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          withBlur: true,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4527A0), Color(0xFF7B1FA2), Color(0xFF311B92)],
                  ),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liked Songs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '📌 Playlist • ${likedTracks.length} ${likedTracks.length == 1 ? "song" : "songs"}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (likedTracks.isNotEmpty)
                BouncingScaleButton(
                  scaleFactor: 0.88,
                  onTap: () {
                    audioHandler.setQueue(likedTracks);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppTheme.accent,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedDownloadedRow(
    AppTokens tokens,
    List<Track> downloadedTracks,
    int completedCount,
    dynamic audioHandler,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        onTap: () => setState(() => _tabController.animateTo(2)),
        child: AppSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          withBlur: true,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: Icon(
                  Icons.download_done_rounded,
                  color: tokens.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Downloaded Tracks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '📌 Auto-playlist • $completedCount ${completedCount == 1 ? "song" : "songs"}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (downloadedTracks.isNotEmpty)
                BouncingScaleButton(
                  scaleFactor: 0.88,
                  onTap: () {
                    audioHandler.setQueue(downloadedTracks);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppTheme.accent,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikedSongsTab(
    AppTokens tokens,
    AsyncValue<List<Track>> likedAsync,
    dynamic audioHandler,
    Track? currentTrack,
    bool isPlaying,
  ) {
    return likedAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ShimmerSkeleton(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(
                      width: double.infinity,
                      height: 14,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    const SizedBox(height: 6),
                    ShimmerSkeleton(
                      width: 110,
                      height: 10,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: TextStyle(color: tokens.textSecondary)),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  'No liked songs yet',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final sortedTracks = _sortTracks(tracks, _likedSort);

        return Column(
          children: [
            _buildLibraryActionHeader(
              tokens: tokens,
              trackCount: sortedTracks.length,
              currentSort: _likedSort,
              onSortChanged: (newSort) => setState(() => _likedSort = newSort),
              onPlayAll: () {
                audioHandler.setQueue(sortedTracks, startIndex: 0);
              },
              onShuffle: () {
                final shuffled = List<Track>.from(sortedTracks)..shuffle();
                audioHandler.setQueue(shuffled, startIndex: 0);
              },
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                itemCount: sortedTracks.length,
                itemBuilder: (context, index) {
                  final track = sortedTracks[index];
                  final isCurrentTrack = currentTrack?.id == track.id;
                  return TrackRow(
                    track: track.copyWith(isLiked: true),
                    index: index + 1,
                    isPlaying: isCurrentTrack && isPlaying,
                    isSelected: isCurrentTrack,
                    showArtwork: true,
                    showIndex: false,
                    showDuration: true,
                    showLikeButton: true,
                    showOptionsButton: true,
                    onTap: () {
                      audioHandler.setQueue(sortedTracks, startIndex: index);
                    },
                    onPlayTap: () {
                      audioHandler.setQueue(sortedTracks, startIndex: index);
                    },
                    onLikeTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(libraryRepositoryProvider)
                          .setLiked(track.id, false, track: track);
                    },
                    onOptionsTap: () {
                      TrackOptionsBottomSheet.show(context, track: track);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDownloadsTab(
    AppTokens tokens,
    AsyncValue<List<DownloadItem>> downloadsAsync,
    dynamic audioHandler,
    Track? currentTrack,
    bool isPlaying,
  ) {
    return downloadsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ShimmerSkeleton(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(
                      width: double.infinity,
                      height: 14,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    const SizedBox(height: 6),
                    ShimmerSkeleton(
                      width: 90,
                      height: 10,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: TextStyle(color: tokens.textSecondary)),
      ),
      data: (downloads) {
        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_done_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  'No offline downloads yet',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                AppPillButton(
                  label: 'Open Downloads Folder',
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  variant: AppPillButtonVariant.secondary,
                  onPressed: () =>
                      FolderLauncherService.openDownloadsFolder(context),
                ),
              ],
            ),
          );
        }

        final completed =
            downloads.where((d) => d.isCompleted && d.track != null).toList();
        final sortedDownloads = _sortDownloads(downloads, _downloadsSort);
        final completedTracks = sortedDownloads
            .where((d) => d.isCompleted && d.track != null)
            .map((d) => d.track!)
            .toList();
        final totalBytes =
            completed.fold<int>(0, (sum, d) => sum + d.fileSizeBytes);
        final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

        return Column(
          children: [
            // Storage Stats Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AppSurface(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderRadius: BorderRadius.circular(tokens.radiusCard),
                withBlur: true,
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded,
                        size: 18, color: tokens.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${completed.length} tracks offline • $totalMb MB storage used',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.health_and_safety_outlined, size: 20),
                      color: tokens.accent,
                      tooltip: 'Verify & Repair Offline Library',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final res = await ref.read(downloadRepositoryProvider).verifyAndRepairDownloads();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res.pruned > 0
                                    ? 'Repaired ${res.pruned} missing tracks. ${res.verified} verified offline.'
                                    : 'Verified ${res.verified} offline tracks. Library healthy!',
                              ),
                              backgroundColor: tokens.card,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      color: tokens.accent,
                      tooltip: 'Open Downloads Folder',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          FolderLauncherService.openDownloadsFolder(context),
                    ),
                  ],
                ),
              ),
            ),

            if (completed.isNotEmpty)
              _buildLibraryActionHeader(
                tokens: tokens,
                trackCount: completed.length,
                currentSort: _downloadsSort,
                onSortChanged: (newSort) => setState(() => _downloadsSort = newSort),
                onPlayAll: () {
                  if (completedTracks.isNotEmpty) {
                    audioHandler.setQueue(completedTracks, startIndex: 0);
                  }
                },
                onShuffle: () {
                  if (completedTracks.isNotEmpty) {
                    final shuffled = List<Track>.from(completedTracks)..shuffle();
                    audioHandler.setQueue(shuffled, startIndex: 0);
                  }
                },
              ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                itemCount: sortedDownloads.length,
                itemBuilder: (context, index) {
                  final dl = sortedDownloads[index];
                  final track = dl.track;
                  if (track == null) return const SizedBox.shrink();

                  final isCompleted = dl.isCompleted;
                  final isDownloading = dl.status ==
                          DownloadStatus.downloading ||
                      dl.status == DownloadStatus.queued;
                  final progress = (dl.fileSizeBytes > 0 &&
                          dl.bytesDownloaded > 0)
                      ? (dl.bytesDownloaded / dl.fileSizeBytes).clamp(0.0, 1.0)
                      : null;

                  if (isCompleted) {
                    final isCurrentTrack = currentTrack?.id == track.id;
                    return TrackRow(
                      track: track,
                      index: index + 1,
                      isPlaying: isCurrentTrack && isPlaying,
                      isSelected: isCurrentTrack,
                      showArtwork: true,
                      showIndex: false,
                      showDuration: true,
                      showLikeButton: false,
                      showOptionsButton: true,
                      onTap: () {
                        final compIdx = completedTracks
                            .indexWhere((t) => t.id == track.id);
                        audioHandler.setQueue(completedTracks,
                            startIndex: compIdx >= 0 ? compIdx : 0);
                      },
                      onPlayTap: () {
                        final compIdx = completedTracks
                            .indexWhere((t) => t.id == track.id);
                        audioHandler.setQueue(completedTracks,
                            startIndex: compIdx >= 0 ? compIdx : 0);
                      },
                      onOptionsTap: () {
                        TrackOptionsBottomSheet.show(context, track: track);
                      },
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: tokens.textMuted,
                          size: 20,
                        ),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Delete download',
                        onPressed: () {
                          ref
                              .read(downloadRepositoryProvider)
                              .deleteDownload(dl.trackId);
                        },
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AppSurface(
                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      withBlur: false,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            child: AppNetworkImage(
                              imageUrl: track.coverUrl,
                              width: 40,
                              height: 40,
                              cacheWidth: 120,
                              cacheHeight: 120,
                              fit: BoxFit.cover,
                              placeholderIcon: Icons.music_note_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isDownloading
                                      ? '${track.artist} • Downloading (${((progress ?? 0.0) * 100).toInt()}%)'
                                      : '${track.artist} • ${dl.status.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDownloading
                                        ? tokens.accent
                                        : tokens.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isDownloading) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(1),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.08),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              tokens.accent),
                                      minHeight: 2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: tokens.textMuted,
                              size: 20,
                            ),
                            splashRadius: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            tooltip: 'Cancel download',
                            onPressed: () {
                              ref
                                  .read(downloadRepositoryProvider)
                                  .cancelDownload(dl.trackId);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmartPlaylistsSection(AppTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Smart Playlists',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              BouncingScaleButton(
                scaleFactor: 0.94,
                onTap: () => _showListeningInsightsDialog(context),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: tokens.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Listening Insights',
                      style: TextStyle(
                        color: tokens.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildSmartCard(
                title: 'On Repeat',
                subtitle: 'Past 14 Days',
                icon: Icons.repeat_rounded,
                color: const Color(0xFF1DB954),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TracksListScreen(
                        title: 'On Repeat',
                        subtitle: 'Past 14 Days',
                        icon: Icons.repeat_rounded,
                        iconColor: const Color(0xFF1DB954),
                        tracksFuture: () => ref.read(onRepeatTracksProvider.future),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              _buildSmartCard(
                title: 'Most Played',
                subtitle: 'This Month',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TracksListScreen(
                        title: 'Most Played',
                        subtitle: 'This Month',
                        icon: Icons.trending_up_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        tracksFuture: () => ref.read(mostPlayedTracksProvider.future),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              _buildSmartCard(
                title: 'Forgotten Favorites',
                subtitle: 'Missed Songs',
                icon: Icons.history_toggle_off_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TracksListScreen(
                        title: 'Forgotten Favorites',
                        subtitle: 'Missed Songs',
                        icon: Icons.history_toggle_off_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        tracksFuture: () => ref.read(forgottenFavoritesProvider.future),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSmartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    return BouncingScaleButton(
      scaleFactor: 0.95,
      onTap: onTap,
      child: AppSurface(
        width: 155,
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        withBlur: true,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showListeningInsightsDialog(BuildContext context) {
    WrappedInsightsDialog.show(context);
  }

  Widget _buildDeviceMusicTab(
    AppTokens tokens,
    AsyncValue<List<Track>> localAsync,
    dynamic audioHandler,
    Track? currentTrack,
    bool isPlaying,
  ) {
    return localAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ShimmerSkeleton(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(
                      width: double.infinity,
                      height: 14,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    const SizedBox(height: 6),
                    ShimmerSkeleton(
                      width: 110,
                      height: 10,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: TextStyle(color: tokens.textSecondary)),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  'No local music discovered',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Scans device storage for .mp3, .m4a, .flac, .wav and .ogg files without uploading anything.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                AppPillButton(
                  label: _isScanningLocalAudio
                      ? 'Scanning...'
                      : 'Scan Device Storage',
                  icon: _isScanningLocalAudio
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.sync_rounded,
                          size: 18, color: Colors.black),
                  variant: AppPillButtonVariant.primary,
                  onPressed: _isScanningLocalAudio ? null : _scanDeviceAudio,
                ),
              ],
            ),
          );
        }

        final sortedTracks = _sortTracks(tracks, _deviceMusicSort);

        return Column(
          children: [
            _buildLibraryActionHeader(
              tokens: tokens,
              trackCount: sortedTracks.length,
              currentSort: _deviceMusicSort,
              onSortChanged: (newSort) =>
                  setState(() => _deviceMusicSort = newSort),
              onPlayAll: () {
                audioHandler.setQueue(sortedTracks, startIndex: 0);
              },
              onShuffle: () {
                final shuffled = List<Track>.from(sortedTracks)..shuffle();
                audioHandler.setQueue(shuffled, startIndex: 0);
              },
              trailingAction: AppPillButton(
                label: 'Scan',
                icon: _isScanningLocalAudio
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: tokens.accent),
                      )
                    : Icon(Icons.sync_rounded, size: 14, color: tokens.accent),
                variant: AppPillButtonVariant.ghost,
                height: 32,
                onPressed: _isScanningLocalAudio ? null : _scanDeviceAudio,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                itemCount: sortedTracks.length,
                itemBuilder: (context, index) {
                  final track = sortedTracks[index];
                  final isCurrentTrack = currentTrack?.id == track.id;
                  return TrackRow(
                    track: track,
                    index: index + 1,
                    isPlaying: isCurrentTrack && isPlaying,
                    isSelected: isCurrentTrack,
                    showArtwork: true,
                    showIndex: false,
                    showDuration: true,
                    showLikeButton: false,
                    showOptionsButton: true,
                    onTap: () {
                      audioHandler.setQueue(sortedTracks, startIndex: index);
                    },
                    onPlayTap: () {
                      audioHandler.setQueue(sortedTracks, startIndex: index);
                    },
                    onOptionsTap: () {
                      TrackOptionsBottomSheet.show(context, track: track);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }


}
