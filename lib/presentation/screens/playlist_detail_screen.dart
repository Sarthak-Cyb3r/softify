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
import '../widgets/shared/track_row.dart';
import '../widgets/track_options_bottom_sheet.dart';

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

    return Scaffold(
      backgroundColor: tokens.background,
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
          final tracks = data.entries
              .map((e) => e.track)
              .whereType<Track>()
              .toList();

          // Find first available cover URL for artwork header
          String? coverUrl;
          for (final t in tracks) {
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
                backgroundColor: tokens.surface,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    tooltip: 'Delete Playlist',
                    onPressed: () => _confirmDeletePlaylist(context, playlist),
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
                              ? tokens.accent.withValues(alpha: 0.25)
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
                            child: AppNetworkImage(
                              imageUrl: coverUrl,
                              width: 140,
                              height: 140,
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              fit: BoxFit.cover,
                              fallbackIcon: playlist.isImported ? Icons.cloud_download : Icons.queue_music,
                              backgroundColor: tokens.card,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (playlist.isImported)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(tokens.radiusPill),
                                border: Border.all(color: tokens.accent.withValues(alpha: 0.35), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 14, color: tokens.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Spotify Imported',
                                    style: TextStyle(
                                      color: tokens.accent,
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
                              '${tracks.length} tracks',
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

                      // Download All Button
                      IconButton(
                        icon: Icon(Icons.download_for_offline_outlined, color: tokens.textSecondary),
                        tooltip: 'Download All Offline',
                        onPressed: tracks.isNotEmpty ? () => _downloadAll(tracks) : null,
                      ),

                      // Shuffle Button
                      IconButton(
                        icon: Icon(Icons.shuffle_rounded, color: tokens.textSecondary),
                        tooltip: 'Shuffle Play',
                        onPressed: tracks.isNotEmpty ? () => _playAll(tracks, shuffle: true) : null,
                      ),

                      const SizedBox(width: 8),

                      // Big Play Button (56px circle)
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
                        final isPlayingThis = audioHandler.currentTrack?.id == track.id;

                        return _buildTrackTile(
                          context: context,
                          tokens: tokens,
                          track: track,
                          index: index,
                          allTracks: tracks,
                          isPlayingThis: isPlayingThis,
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
    );
  }

  Widget _buildTrackTile({
    required BuildContext context,
    required AppTokens tokens,
    required Track track,
    required int index,
    required List<Track> allTracks,
    required bool isPlayingThis,
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
      onTap: () => _playAll(allTracks, startIndex: index),
      onPlayTap: () => _playAll(allTracks, startIndex: index),
      onLikeTap: () {
        ref.read(libraryRepositoryProvider).setLiked(track.id, !isLiked, track: track);
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
