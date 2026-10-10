import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_options_bottom_sheet.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistName;
  final String? coverUrl;

  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    this.coverUrl,
  });

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  List<Track> _tracks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final tracks = await catalog.getArtistTracks(widget.artistName);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load tracks: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: MediaQuery.of(context).size.width < 800
          ? const SafeArea(top: false, child: MiniPlayer())
          : null,
      body: CustomScrollView(
        slivers: [
          // Collapsible App Bar with Artist Visual
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artistName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.purple.shade900.withValues(alpha: 0.6),
                      AppTheme.background,
                    ],
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.surfaceElevated,
                    backgroundImage: widget.coverUrl != null
                        ? NetworkImage(widget.coverUrl!)
                        : null,
                    child: widget.coverUrl == null
                        ? const Icon(Icons.person, size: 60, color: Colors.white24)
                        : null,
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons: Play All & Shuffle
          if (!_isLoading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Play All',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        audioHandler.setQueue(_tracks);
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                      onPressed: () {
                        final shuffled = List<Track>.from(_tracks)..shuffle();
                        audioHandler.setQueue(shuffled);
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Track List
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.error),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = _tracks[index];
                  final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
                  final isLiked = isLikedAsync.value ?? track.isLiked;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onTap: () {
                      audioHandler.setQueue(_tracks, startIndex: index);
                    },
                    leading: Text(
                      '${index + 1}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      track.album ?? widget.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? AppTheme.primary : AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            ref
                                .read(libraryRepositoryProvider)
                                .setLiked(track.id, !isLiked, track: track);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_for_offline_outlined, color: AppTheme.textSecondary, size: 20),
                          onPressed: () {
                            ref.read(downloadRepositoryProvider).queueDownload(track);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                          onPressed: () {
                            TrackOptionsBottomSheet.show(context, track: track);
                          },
                        ),
                      ],
                    ),
                  );
                },
                childCount: _tracks.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}
