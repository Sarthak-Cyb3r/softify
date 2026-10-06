import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/album_detail_screen.dart';
import '../screens/artist_detail_screen.dart';
import '../theme/app_theme.dart';

class TrackOptionsBottomSheet extends ConsumerWidget {
  final Track track;
  final String? currentPlaylistId;
  final int? currentPlaylistTrackIndex;

  const TrackOptionsBottomSheet({
    super.key,
    required this.track,
    this.currentPlaylistId,
    this.currentPlaylistTrackIndex,
  });

  static Future<void> show(
    BuildContext context, {
    required Track track,
    String? currentPlaylistId,
    int? currentPlaylistTrackIndex,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TrackOptionsBottomSheet(
        track: track,
        currentPlaylistId: currentPlaylistId,
        currentPlaylistTrackIndex: currentPlaylistTrackIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
    final isLiked = isLikedAsync.value ?? track.isLiked;
    final isDownloadedAsync = ref.watch(isTrackDownloadedProvider(track.id));
    final isDownloaded = isDownloadedAsync.value ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Track Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: track.coverUrl != null
                        ? Image.network(
                            track.coverUrl!,
                            width: 52,
                            height: 52,
                            cacheWidth: 156,
                            cacheHeight: 156,
                            gaplessPlayback: true,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackCover(),
                          )
                        : _fallbackCover(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Colors.white12),

            // Options List
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Add to Playlist
                    ListTile(
                      leading: const Icon(Icons.playlist_add, color: AppTheme.textPrimary),
                      title: const Text('Add to playlist', style: TextStyle(color: AppTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(context);
                        _showAddToPlaylistSheet(context, ref, track);
                      },
                    ),

                    // 2. Like / Unlike
                    ListTile(
                      leading: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                      title: Text(
                        isLiked ? 'Liked' : 'Like',
                        style: TextStyle(
                          color: isLiked ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      onTap: () {
                        ref
                            .read(libraryRepositoryProvider)
                            .setLiked(track.id, !isLiked, track: track);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !isLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    // 3. Play Next
                    ListTile(
                      leading: const Icon(Icons.queue_music, color: AppTheme.textPrimary),
                      title: const Text('Play next', style: TextStyle(color: AppTheme.textPrimary)),
                      onTap: () {
                        audioHandler.playNext(track);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Playing "${track.title}" next'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    // 4. Add to Queue
                    ListTile(
                      leading: const Icon(Icons.add_to_photos_outlined, color: AppTheme.textPrimary),
                      title: const Text('Add to queue', style: TextStyle(color: AppTheme.textPrimary)),
                      onTap: () {
                        audioHandler.addToQueue(track);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${track.title}" to queue'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    // 5. Download / Offline
                    ListTile(
                      leading: Icon(
                        isDownloaded ? Icons.check_circle : Icons.download_rounded,
                        color: isDownloaded ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                      title: Text(
                        isDownloaded ? 'Downloaded' : 'Download song',
                        style: TextStyle(
                          color: isDownloaded ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        if (!isDownloaded) {
                          await ref.read(downloadRepositoryProvider).queueDownload(track);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloading "${track.title}"...'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${track.title}" is already downloaded'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),

                    // 6. View Artist
                    if (track.artist.isNotEmpty && track.artist != 'Unknown Artist')
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: AppTheme.textPrimary),
                        title: Text('View artist (${track.artist})', style: const TextStyle(color: AppTheme.textPrimary)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArtistDetailScreen(
                                artistName: track.artist,
                                coverUrl: track.coverUrl,
                              ),
                            ),
                          );
                        },
                      ),

                    // 7. View Album
                    if (track.album != null && track.album!.trim().isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.album_outlined, color: AppTheme.textPrimary),
                        title: Text('View album (${track.album})', style: const TextStyle(color: AppTheme.textPrimary)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                albumName: track.album!,
                                artistName: track.artist,
                                coverUrl: track.coverUrl,
                              ),
                            ),
                          );
                        },
                      ),

                    // 8. Remove from this Playlist (if applicable)
                    if (currentPlaylistId != null && currentPlaylistTrackIndex != null)
                      ListTile(
                        leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        title: const Text('Remove from this playlist', style: TextStyle(color: Colors.redAccent)),
                        onTap: () async {
                          await ref
                              .read(libraryRepositoryProvider)
                              .removeTrackFromPlaylist(currentPlaylistId!, currentPlaylistTrackIndex!);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Removed "${track.title}" from playlist'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      width: 52,
      height: 52,
      color: AppTheme.surfaceHighlight,
      child: const Icon(Icons.music_note, color: Colors.white24, size: 28),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, WidgetRef ref, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _AddToPlaylistModal(track: track),
    );
  }
}

class _AddToPlaylistModal extends ConsumerWidget {
  final Track track;

  const _AddToPlaylistModal({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Add to Playlist',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            const Divider(height: 1, color: Colors.white12),

            // New Playlist Button
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: AppTheme.primary, size: 26),
              ),
              title: const Text(
                'New playlist',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Create a new playlist for this track',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              onTap: () => _showCreatePlaylistDialog(context, ref),
            ),

            const Divider(height: 1, color: Colors.white12),

            // Existing Playlists
            Expanded(
              child: playlistsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error loading playlists: $e', style: const TextStyle(color: Colors.white54)),
                ),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const Center(
                      child: Text(
                        'No playlists yet.\nCreate one above!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final pl = playlists[index];
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceHighlight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.playlist_play,
                            color: AppTheme.primary,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${pl.trackCount} ${pl.trackCount == 1 ? 'song' : 'songs'}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        onTap: () async {
                          await ref
                              .read(libraryRepositoryProvider)
                              .addTrackToPlaylist(pl.id, track);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added "${track.title}" to "${pl.name}"'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newPl = await ref.read(libraryRepositoryProvider).createPlaylist(name);
                await ref.read(libraryRepositoryProvider).addTrackToPlaylist(newPl.id, track);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created "$name" and added "${track.title}"'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Create & Add'),
          ),
        ],
      ),
    );
  }
}
