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
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../widgets/wrapped_insights_dialog.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';
import 'spotify_import_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanningLocalAudio = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  void _showCreatePlaylistDialog(BuildContext context) {
    final tokens = context.tokens;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
        title: Text(
          'New Playlist',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: tokens.textMuted),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.accent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
          ),
          BouncingScaleButton(
            scaleFactor: 0.94,
            onTap: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await ref.read(libraryRepositoryProvider).createPlaylist(name);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: BorderRadius.circular(tokens.radiusFull),
              ),
              child: const Text(
                'Create',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final likedAsync = ref.watch(likedTracksStreamProvider);
    final downloadsAsync = ref.watch(downloadsStreamProvider);
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final localTracksAsync = ref.watch(localTracksStreamProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(
          'Your Library',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
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
            onTap: () => _showCreatePlaylistDialog(context),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.add_rounded, size: 24),
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
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: tokens.accent,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: tokens.textPrimary,
              unselectedLabelColor: tokens.textMuted,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Playlists'),
                Tab(text: 'Liked Songs'),
                Tab(text: 'Downloads'),
                Tab(text: 'Device Music'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Playlists Tab
          _buildPlaylistsTab(tokens, playlistsAsync),

          // 2. Liked Songs Tab
          _buildLikedSongsTab(tokens, likedAsync, audioHandler),

          // 3. Downloads Tab
          _buildDownloadsTab(tokens, downloadsAsync, audioHandler),

          // 4. Device Music Tab
          _buildDeviceMusicTab(tokens, localTracksAsync, audioHandler),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab(
      AppTokens tokens, AsyncValue<List<Playlist>> playlistsAsync) {
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
      data: (playlists) {
        if (playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  'No playlists yet',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BouncingScaleButton(
                      scaleFactor: 0.94,
                      onTap: () => _showCreatePlaylistDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          borderRadius:
                              BorderRadius.circular(tokens.radiusFull),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_rounded, size: 18, color: Colors.black),
                            SizedBox(width: 6),
                            Text(
                              'New Playlist',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    BouncingScaleButton(
                      scaleFactor: 0.94,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SpotifyImportScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(tokens.radiusFull),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_download_rounded,
                                size: 18, color: tokens.textPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'Import Spotify',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
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
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  BouncingScaleButton(
                    scaleFactor: 0.94,
                    onTap: () => _showCreatePlaylistDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(tokens.radiusFull),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_rounded,
                              size: 16, color: tokens.textPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'New Playlist',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  BouncingScaleButton(
                    scaleFactor: 0.94,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SpotifyImportScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(tokens.radiusFull),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_download_rounded,
                              size: 16, color: tokens.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Import Spotify',
                            style: TextStyle(
                              color: tokens.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final pl = playlists[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaylistDetailScreen(playlistId: pl.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: tokens.surfaceHighlight,
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
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: tokens.accent,
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

  Widget _buildLikedSongsTab(AppTokens tokens,
      AsyncValue<List<Track>> likedAsync, dynamic audioHandler) {
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

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                onTap: () {
                  audioHandler.setQueue(tracks, startIndex: index);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        child: track.coverUrl != null
                            ? Image.network(
                                track.coverUrl!,
                                width: 48,
                                height: 48,
                                cacheWidth: 144,
                                cacheHeight: 144,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _fallbackCover(tokens),
                              )
                            : _fallbackCover(tokens),
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
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BouncingScaleButton(
                        scaleFactor: 0.88,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(libraryRepositoryProvider)
                              .setLiked(track.id, false, track: track);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.favorite_rounded,
                            color: tokens.accent,
                            size: 20,
                          ),
                        ),
                      ),
                      BouncingScaleButton(
                        scaleFactor: 0.88,
                        onTap: () {
                          TrackOptionsBottomSheet.show(context, track: track);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: tokens.textSecondary.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        );
      },
    );
  }

  Widget _buildDownloadsTab(
    AppTokens tokens,
    AsyncValue<List<DownloadItem>> downloadsAsync,
    dynamic audioHandler,
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
                OutlinedButton.icon(
                  onPressed: () =>
                      FolderLauncherService.openDownloadsFolder(context),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Open Downloads Folder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.accent,
                    side: BorderSide(
                        color: tokens.accent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final completed =
            downloads.where((d) => d.isCompleted && d.track != null).toList();
        final totalBytes =
            completed.fold<int>(0, (sum, d) => sum + d.fileSizeBytes);
        final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

        return Column(
          children: [
            // Storage Stats Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 0.8,
                  ),
                ),
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
                              backgroundColor: AppTheme.primary,
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

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                itemCount: downloads.length,
                itemBuilder: (context, index) {
                  final dl = downloads[index];
                  final track = dl.track;
                  if (track == null) return const SizedBox.shrink();

                  final isCompleted = dl.isCompleted;
                  final isDownloading = dl.status ==
                          DownloadStatus.downloading ||
                      dl.status == DownloadStatus.queued;
                  final sizeMb = dl.fileSizeBytes > 0
                      ? (dl.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)
                      : null;
                  final progress = (dl.fileSizeBytes > 0 &&
                          dl.bytesDownloaded > 0)
                      ? (dl.bytesDownloaded / dl.fileSizeBytes).clamp(0.0, 1.0)
                      : null;

                  return RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      onTap: isCompleted
                          ? () {
                              final completedTracks =
                                  completed.map((d) => d.track!).toList();
                              final compIdx = completedTracks
                                  .indexWhere((t) => t.id == track.id);
                              audioHandler.setQueue(completedTracks,
                                  startIndex: compIdx >= 0 ? compIdx : 0);
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              child: track.coverUrl != null
                                  ? Image.network(
                                      track.coverUrl!,
                                      width: 48,
                                      height: 48,
                                      cacheWidth: 144,
                                      cacheHeight: 144,
                                      gaplessPlayback: true,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackCover(tokens),
                                    )
                                  : _fallbackCover(tokens),
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
                                    isCompleted
                                        ? '${track.artist} • ${sizeMb ?? "0.0"} MB'
                                        : isDownloading
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
                                    // Ultra-thin animated progress line
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(1),
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
                            BouncingScaleButton(
                              scaleFactor: 0.88,
                              onTap: () {
                                if (isCompleted) {
                                  ref
                                      .read(downloadRepositoryProvider)
                                      .deleteDownload(dl.trackId);
                                } else {
                                  ref
                                      .read(downloadRepositoryProvider)
                                      .cancelDownload(dl.trackId);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  isCompleted
                                      ? Icons.delete_outline_rounded
                                      : Icons.close_rounded,
                                  color: tokens.textMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                            BouncingScaleButton(
                              scaleFactor: 0.88,
                              onTap: () {
                                TrackOptionsBottomSheet.show(context,
                                    track: track);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  color: tokens.textSecondary
                                      .withValues(alpha: 0.7),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final tracks = await ref.read(onRepeatTracksProvider.future);
                  if (tracks.isNotEmpty) {
                    ref.read(audioHandlerProvider).setQueue(tracks);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Playing "On Repeat" (${tracks.length} tracks)'),
                        backgroundColor: tokens.surfaceElevated,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              _buildSmartCard(
                title: 'Most Played',
                subtitle: 'This Month',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final tracks = await ref.read(mostPlayedTracksProvider.future);
                  if (tracks.isNotEmpty) {
                    ref.read(audioHandlerProvider).setQueue(tracks);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Playing "Most Played" (${tracks.length} tracks)'),
                        backgroundColor: tokens.surfaceElevated,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              _buildSmartCard(
                title: 'Forgotten Favorites',
                subtitle: 'Missed Songs',
                icon: Icons.history_toggle_off_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final tracks = await ref.read(forgottenFavoritesProvider.future);
                  if (tracks.isNotEmpty) {
                    ref.read(audioHandlerProvider).setQueue(tracks);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Playing "Forgotten Favorites" (${tracks.length} tracks)'),
                        backgroundColor: tokens.surfaceElevated,
                      ),
                    );
                  }
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
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
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
                      fontSize: 10,
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
                BouncingScaleButton(
                  scaleFactor: 0.94,
                  onTap: _isScanningLocalAudio ? null : _scanDeviceAudio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isScanningLocalAudio)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        else
                          const Icon(Icons.sync_rounded, size: 18, color: Colors.black),
                        const SizedBox(width: 8),
                        const Text(
                          'Scan Device Storage',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tracks.length} local files indexed',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isScanningLocalAudio ? null : _scanDeviceAudio,
                    icon: _isScanningLocalAudio
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
                          )
                        : Icon(Icons.refresh_rounded, size: 16, color: tokens.accent),
                    label: Text('Rescan', style: TextStyle(color: tokens.accent, fontSize: 13)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final minutes = track.duration.inMinutes;
                  final seconds = (track.duration.inSeconds % 60).toString().padLeft(2, '0');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      onTap: () {
                        audioHandler.setQueue(tracks, startIndex: index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: tokens.surfaceHighlight,
                                borderRadius: BorderRadius.circular(tokens.radiusSm),
                              ),
                              child: Icon(
                                Icons.audio_file_rounded,
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
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${track.artist} • $minutes:$seconds',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            BouncingScaleButton(
                              scaleFactor: 0.88,
                              onTap: () {
                                TrackOptionsBottomSheet.show(context, track: track);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  color: tokens.textSecondary.withValues(alpha: 0.7),
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

  Widget _fallbackCover(AppTokens tokens) {
    return Container(
      width: 48,
      height: 48,
      color: tokens.surfaceHighlight,
      child: Icon(
        Icons.music_note_rounded,
        color: tokens.textMuted,
        size: 22,
      ),
    );
  }
}
