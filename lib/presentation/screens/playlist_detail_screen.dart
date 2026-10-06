import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
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

  void _confirmDeletePlaylist(BuildContext context, Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Playlist?'),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistWithTracksStreamProvider(widget.playlistId));
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: playlistAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
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
                backgroundColor: AppTheme.surface,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          playlist.isImported
                              ? const Color(0xFF1DB954).withValues(alpha: 0.35)
                              : Colors.deepPurple.shade900.withValues(alpha: 0.5),
                          AppTheme.background,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 32),
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: coverUrl != null
                                  ? Image.network(
                                      coverUrl,
                                      fit: BoxFit.cover,
                                      cacheWidth: 420,
                                      cacheHeight: 420,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) => _defaultPlaylistCover(playlist),
                                    )
                                  : _defaultPlaylistCover(playlist),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (playlist.isImported)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1DB954), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: Color(0xFF1DB954)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Spotify Imported',
                                    style: TextStyle(
                                      color: Color(0xFF1DB954),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
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
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            if (playlist.description != null && playlist.description!.isNotEmpty)
                              Text(
                                playlist.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Download All Button
                      IconButton(
                        icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white70),
                        tooltip: 'Download All Offline',
                        onPressed: tracks.isNotEmpty ? () => _downloadAll(tracks) : null,
                      ),

                      // Shuffle Button
                      IconButton(
                        icon: const Icon(Icons.shuffle, color: Colors.white70),
                        tooltip: 'Shuffle Play',
                        onPressed: tracks.isNotEmpty ? () => _playAll(tracks, shuffle: true) : null,
                      ),

                      const SizedBox(width: 8),

                      // Big Play Button
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        onPressed: tracks.isNotEmpty ? () => _playAll(tracks, startIndex: 0) : null,
                        child: const Icon(Icons.play_arrow, size: 28),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Track List
              if (tracks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_off, size: 48, color: Colors.white24),
                        SizedBox(height: 12),
                        Text(
                          'No tracks in this playlist yet',
                          style: TextStyle(color: AppTheme.textSecondary),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      onTap: () => _playAll(allTracks, startIndex: index),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isPlayingThis ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.coverUrl != null
                ? Image.network(
                    track.coverUrl!,
                    width: 44,
                    height: 44,
                    cacheWidth: 132,
                    cacheHeight: 132,
                    gaplessPlayback: true,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _trackCoverFallback(),
                  )
                : _trackCoverFallback(),
          ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlayingThis ? AppTheme.primary : AppTheme.textPrimary,
          fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        '${track.artist} • ${_formatDuration(track.duration)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Download button
          IconButton(
            icon: Icon(
              isDownloaded ? Icons.download_done : Icons.download_for_offline_outlined,
              color: isDownloaded ? AppTheme.primary : Colors.white38,
              size: 20,
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

          // Favorite / Liked toggle
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? AppTheme.primary : Colors.white38,
              size: 20,
            ),
            tooltip: isLiked ? 'Unlike' : 'Like',
            onPressed: () {
              ref.read(libraryRepositoryProvider).setLiked(track.id, !isLiked, track: track);
            },
          ),

          // Track options
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
            tooltip: 'Track Options',
            onPressed: () {
              TrackOptionsBottomSheet.show(
                context,
                track: track,
                currentPlaylistId: playlistId,
                currentPlaylistTrackIndex: index,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _defaultPlaylistCover(Playlist playlist) {
    return Container(
      color: AppTheme.surfaceElevated,
      child: Icon(
        playlist.isImported ? Icons.cloud_download : Icons.queue_music,
        color: playlist.isImported ? const Color(0xFF1DB954) : AppTheme.primary,
        size: 54,
      ),
    );
  }

  Widget _trackCoverFallback() {
    return Container(
      width: 44,
      height: 44,
      color: AppTheme.surfaceElevated,
      child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '--:--';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
