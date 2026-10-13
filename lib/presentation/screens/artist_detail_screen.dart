import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/search_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_music_wave_indicator.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_options_bottom_sheet.dart';
import 'artist_discography_screen.dart';

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
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      bottomNavigationBar: MediaQuery.of(context).size.width < 800
          ? const SafeArea(top: false, child: MiniPlayer())
          : null,
      body: CustomScrollView(
        slivers: [
          // Collapsible App Bar with Artist Visual
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: tokens.surface,
            leading: Navigator.of(context).canPop()
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: BouncingScaleButton(
                      scaleFactor: 0.90,
                      minTouchTarget: 0,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tokens.surfaceHighlight.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: tokens.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artistName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.accent.withValues(alpha: 0.25),
                      tokens.background,
                    ],
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: tokens.surfaceElevated,
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
                        backgroundColor: tokens.accent,
                        foregroundColor: const Color(0xFF080F11),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusFull),
                        ),
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
                        foregroundColor: tokens.textPrimary,
                        side: BorderSide(color: tokens.surfaceHighlight),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusFull),
                        ),
                      ),
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                      onPressed: () {
                        final shuffled = List<Track>.from(_tracks)..shuffle();
                        audioHandler.setQueue(shuffled);
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.textPrimary,
                        side: BorderSide(color: tokens.surfaceHighlight),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusFull),
                        ),
                      ),
                      icon: const Icon(Icons.album_rounded, size: 18),
                      label: const Text('Discography'),
                      onPressed: () async {
                        final disco = await ref.read(
                            artistDiscographySearchProvider(widget.artistName).future);
                        if (disco != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArtistDiscographyScreen(disco: disco),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Track List
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: tokens.accent),
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
                  final currentTrack = ref.watch(currentTrackProvider).value;
                  final isCurrent = currentTrack?.id == track.id;
                  final isPlaying = ref.watch(isPlayingProvider);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onTap: () {
                      audioHandler.setQueue(_tracks, startIndex: index);
                    },
                    leading: SizedBox(
                      width: 24,
                      child: Center(
                        child: isCurrent
                            ? AnimatedMusicWaveIndicator(
                                isPlaying: isPlaying,
                                color: tokens.accent,
                                size: 16,
                                barCount: 3,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                              ),
                      ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? tokens.accent : tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      track.album ?? widget.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? tokens.accent : tokens.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            ref
                                .read(libraryRepositoryProvider)
                                .setLiked(track.id, !isLiked, track: track);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.download_for_offline_outlined, color: tokens.textSecondary, size: 20),
                          onPressed: () {
                            ref.read(downloadRepositoryProvider).queueDownload(track);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.more_vert, color: tokens.textSecondary, size: 20),
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
