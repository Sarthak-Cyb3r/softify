import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/search_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/desktop_player_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/shared/app_network_image.dart';
import '../widgets/shared/app_pill_button.dart';
import '../widgets/shared/track_row.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../widgets/artist_chooser_bottom_sheet.dart';
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
  String? _resolvedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _resolvedAvatarUrl = widget.coverUrl;
    if (_resolvedAvatarUrl == null || _resolvedAvatarUrl!.isEmpty) {
      ArtistAvatarResolver.getArtistImageUrl(widget.artistName).then((url) {
        if (mounted && url != null) {
          setState(() {
            _resolvedAvatarUrl = url;
          });
        }
      });
    }
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
          ? const SafeArea(top: false, bottom: true, child: MiniPlayer())
          : const DesktopPlayerBar(),
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
                      tokens.accent.withValues(alpha: 0.25),
                      tokens.background,
                    ],
                  ),
                ),
                child: Center(
                  child: AppNetworkImage(
                    imageUrl: _resolvedAvatarUrl,
                    width: 120,
                    height: 120,
                    isCircle: true,
                    placeholderIcon: Icons.person,
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons: Play All, Shuffle & Discography
          if (!_isLoading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
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
                        onPressed: () {
                          audioHandler.setQueue(_tracks);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    AppPillButton(
                      label: 'Shuffle',
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      variant: AppPillButtonVariant.secondary,
                      onPressed: () {
                        final shuffled = List<Track>.from(_tracks)..shuffle();
                        audioHandler.setQueue(shuffled);
                      },
                    ),
                    const SizedBox(width: 10),
                    AppPillButton(
                      label: 'Discography',
                      icon: const Icon(Icons.album_rounded, size: 18),
                      variant: AppPillButtonVariant.secondary,
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

          // Popular Section Header
          if (!_isLoading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Popular',
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
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
                  final isPlaying = ref.watch(isPlayingProvider);
                  final isCurrent = currentTrack?.id == track.id;

                  return TrackRow(
                    track: track.copyWith(isLiked: isLiked),
                    index: index + 1,
                    showArtwork: true,
                    isPlaying: isCurrent && isPlaying,
                    isSelected: isCurrent,
                    onTap: () {
                      audioHandler.setQueue(_tracks, startIndex: index);
                    },
                    onPlayTap: () {
                      audioHandler.setQueue(_tracks, startIndex: index);
                    },
                    onLikeTap: () {
                      final newLiked = !isLiked;
                      ref
                          .read(libraryRepositoryProvider)
                          .setLiked(track.id, newLiked, track: track.copyWith(isLiked: newLiked));
                      ref.read(audioHandlerProvider).updateTrackLikedState(track.id, newLiked);
                    },
                    onOptionsTap: () {
                      TrackOptionsBottomSheet.show(context, track: track);
                    },
                    trailing: IconButton(
                      iconSize: 18.0,
                      splashRadius: 18.0,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        Icons.download_for_offline_outlined,
                        color: tokens.textMuted,
                      ),
                      tooltip: 'Download Offline',
                      onPressed: () {
                        ref.read(downloadRepositoryProvider).queueDownload(track);
                      },
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
