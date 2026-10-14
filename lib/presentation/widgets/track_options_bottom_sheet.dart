import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/album_detail_screen.dart';
import '../screens/car_mode_screen.dart';
import '../screens/equalizer_screen.dart';
import '../theme/app_theme.dart';
import 'artist_chooser_bottom_sheet.dart';
import 'shared/app_dialog.dart';
import 'shared/app_network_image.dart';
import 'shared/app_pill_button.dart';
import 'sleep_timer_bottom_sheet.dart';

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
    final sleepRemainingAsync = ref.watch(sleepTimerRemainingProvider);
    final isSleepEndOfTrackAsync = ref.watch(sleepTimerEndOfTrackProvider);
    final sleepRemaining = sleepRemainingAsync.value;
    final isSleepEndOfTrack = isSleepEndOfTrackAsync.value ?? false;
    final isSleepActive = (sleepRemaining != null && sleepRemaining > Duration.zero) || isSleepEndOfTrack;

    final tokens = context.tokens;

    return Material(
      color: tokens.surfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
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
                    child: AppNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 52,
                      height: 52,
                      cacheWidth: 156,
                      cacheHeight: 156,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.music_note_rounded,
                    ),
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
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
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
                        color: isLiked ? tokens.accent : AppTheme.textPrimary,
                      ),
                      title: Text(
                        isLiked ? 'Liked' : 'Like',
                        style: TextStyle(
                          color: isLiked ? tokens.accent : AppTheme.textPrimary,
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

                    // 4b. Start Song Radio
                    ListTile(
                      leading: const Icon(Icons.radio_outlined, color: AppTheme.textPrimary),
                      title: const Text('Start song radio', style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: const Text(
                        'Continuous queue musically matched to this track',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Starting radio for "${track.title}"...'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        try {
                          final catalog = ref.read(catalogRepositoryProvider);
                          final related = await catalog.getRelatedTracks(track, limit: 25);
                          final queue = [track, ...related.where((t) => t.id != track.id)];
                          await audioHandler.setQueue(queue, startIndex: 0);
                        } catch (_) {}
                      },
                    ),

                    // 5. Download / Offline
                    ListTile(
                      leading: Icon(
                        isDownloaded ? Icons.check_circle : Icons.download_rounded,
                        color: isDownloaded ? tokens.accent : AppTheme.textPrimary,
                      ),
                      title: Text(
                        isDownloaded ? 'Downloaded' : 'Download song',
                        style: TextStyle(
                          color: isDownloaded ? tokens.accent : AppTheme.textPrimary,
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

                    // 6. Sleep Timer
                    ListTile(
                      leading: Icon(
                        Icons.bedtime_outlined,
                        color: isSleepActive ? tokens.accent : AppTheme.textPrimary,
                      ),
                      title: const Text('Sleep timer', style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: Text(
                        isSleepEndOfTrack
                            ? 'Active: Ends after current song'
                            : (isSleepActive && sleepRemaining != null
                                ? 'Active: ${sleepRemaining.inMinutes}m ${(sleepRemaining.inSeconds % 60).toString().padLeft(2, '0')}s remaining'
                                : 'Pause music automatically after a set time'),
                        style: TextStyle(
                          color: isSleepActive ? tokens.accent : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: isSleepActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSleepActive
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tokens.accent,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        SleepTimerBottomSheet.show(context);
                      },
                    ),

                    // 7. View Artist & Artist Radio
                    if (track.artist.isNotEmpty && track.artist != 'Unknown Artist') ...[
                      ListTile(
                        leading: const Icon(Icons.podcasts_rounded, color: AppTheme.textPrimary),
                        title: Text('Start artist radio (${track.artist})', style: const TextStyle(color: AppTheme.textPrimary)),
                        onTap: () async {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Starting artist radio for "${track.artist}"...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          try {
                            final catalog = ref.read(catalogRepositoryProvider);
                            final primaryArtist =
                                parseArtistNames(track.artist).firstOrNull ?? track.artist;
                            final artistTracks =
                                await catalog.getArtistTracks(primaryArtist, limit: 25);
                            if (artistTracks.isNotEmpty) {
                              await audioHandler.setQueue(artistTracks, startIndex: 0);
                            }
                          } catch (_) {}
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: AppTheme.textPrimary),
                        title: Text(
                          parseArtistNames(track.artist).length > 1
                              ? 'View artists (${track.artist})'
                              : 'View artist (${track.artist})',
                          style: const TextStyle(color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          showArtistChooserOrDetail(
                            context,
                            rawArtist: track.artist,
                            coverUrl: track.coverUrl,
                          );
                        },
                      ),
                    ],

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

                    // 7b. Car Mode Driving Interface
                    ListTile(
                      leading: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.textPrimary),
                      title: const Text('Car Mode', style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: const Text(
                        'Distraction-free driving interface with large touch targets',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CarModeScreen()),
                        );
                      },
                    ),

                    // 7c. Audio Equalizer & Sound FX
                    ListTile(
                      leading: const Icon(Icons.tune_rounded, color: AppTheme.textPrimary),
                      title: const Text('Equalizer & Audio FX', style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: const Text(
                        '10-band DSP, acoustic presets & bass boost',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                        );
                      },
                    ),

                    // 8. Remove from this Playlist (if applicable)
                    if (currentPlaylistId != null && currentPlaylistTrackIndex != null)
                      ListTile(
                        leading: Icon(Icons.remove_circle_outline, color: tokens.error),
                        title: Text('Remove from this playlist', style: TextStyle(color: tokens.error)),
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
    final tokens = context.tokens;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
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
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          AppPillButton(
            label: 'Create & Add',
            variant: AppPillButtonVariant.primary,
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
          ),
        ],
      ),
    );
  }
}
