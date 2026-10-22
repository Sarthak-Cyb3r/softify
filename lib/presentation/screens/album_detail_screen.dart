import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/desktop_player_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/shared/app_network_image.dart';
import '../widgets/shared/track_row.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final String albumName;
  final String artistName;
  final String? coverUrl;
  final String? albumUriOrId;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.artistName,
    this.coverUrl,
    this.albumUriOrId,
  });

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  List<Track> _tracks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbumTracks();
  }

  Future<void> _loadAlbumTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Track> tracks = [];
      if (widget.albumUriOrId != null && widget.albumUriOrId!.isNotEmpty) {
        try {
          final spotifyApi = ref.read(spotifyApiServiceProvider);
          tracks = await spotifyApi.getAlbumTracks(widget.albumUriOrId!);
        } catch (_) {}
      }

      if (tracks.isEmpty) {
        final catalog = ref.read(catalogRepositoryProvider);
        tracks = await catalog.getAlbumTracks(widget.albumName, widget.artistName);
      }

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
          _error = 'Failed to load album tracks: $e';
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentTrack =
        ref.watch(currentTrackProvider).value ?? audioHandler.currentTrack;
    final isPlaying = ref.watch(isPlayingProvider);
    final totalDurationSeconds =
        _tracks.fold<int>(0, (sum, t) => sum + t.duration.inSeconds);
    final totalMinutes = totalDurationSeconds ~/ 60;

    return Scaffold(
      backgroundColor: tokens.background,
      bottomNavigationBar: MediaQuery.of(context).size.width < 800
          ? const SafeArea(top: false, bottom: true, child: MiniPlayer())
          : const DesktopPlayerBar(),
      floatingActionButton: _tracks.isNotEmpty
          ? BouncingScaleButton(
              scaleFactor: 0.94,
              minTouchTarget: 0,
              onTap: () {
                audioHandler.setQueue(_tracks);
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 24,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Play All',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // Cinematic Album Hero Header
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            backgroundColor: tokens.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Padding(
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
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 14, left: 56, right: 56),
              title: Text(
                widget.albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                  color: tokens.textPrimary,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Ambient blurred backdrop if cover exists
                  if (widget.coverUrl != null) ...[
                    Image.network(
                      widget.coverUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      cacheHeight: 300,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(
                        color: tokens.background.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  // Dark Vignette & Gradient wash
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          tokens.background.withValues(alpha: 0.2),
                          tokens.background.withValues(alpha: 0.75),
                          tokens.background,
                        ],
                      ),
                    ),
                  ),
                  // Centered double-bezel concentric artwork card
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 20),
                      child: Container(
                        width: 160,
                        height: 160,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated,
                          borderRadius: BorderRadius.circular(tokens.radiusLg),
                          border: Border.all(
                            color: tokens.surfaceHighlight.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: AppNetworkImage(
                          imageUrl: widget.coverUrl,
                          borderRadius: BorderRadius.circular(tokens.radiusMd),
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.album_rounded,
                          backgroundColor: tokens.surfaceElevated,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Album Meta & Controls
          if (!_isLoading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.albumName,
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          widget.artistName,
                          style: TextStyle(
                            color: tokens.accent,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            fontFamily: AppTheme.fontUi,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: tokens.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_tracks.length} tracks${totalMinutes > 0 ? ' • $totalMinutes mins' : ''}',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            fontFamily: AppTheme.fontUi,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: BouncingScaleButton(
                            scaleFactor: 0.95,
                            minTouchTarget: 0,
                            onTap: () {
                              audioHandler.setQueue(_tracks);
                            },
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: tokens.accent,
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusFull),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Play All',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BouncingScaleButton(
                            scaleFactor: 0.95,
                            minTouchTarget: 0,
                            onTap: () {
                              final shuffled = List<Track>.from(_tracks)
                                ..shuffle();
                              audioHandler.setQueue(shuffled);
                            },
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: tokens.surfaceElevated,
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusFull),
                                border: Border.all(
                                  color: tokens.surfaceHighlight,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shuffle_rounded,
                                    color: tokens.textPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Shuffle',
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Track Listing
          if (_isLoading)
            SliverFillRemaining(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 8,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ShimmerSkeleton(
                        width: 24,
                        height: 16,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerSkeleton(
                              width: double.infinity,
                              height: 14,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                            ),
                            const SizedBox(height: 6),
                            ShimmerSkeleton(
                              width: 120,
                              height: 10,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFE91429)),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = _tracks[index];
                  final isLikedAsync =
                      ref.watch(isTrackLikedProvider(track.id));
                  final isLiked = isLikedAsync.value ?? track.isLiked;

                  final isDownloadedAsync =
                      ref.watch(isTrackDownloadedProvider(track.id));
                  final isDownloaded = isDownloadedAsync.value ?? false;

                  final isCurrent = currentTrack?.id == track.id;

                  return TrackRow(
                    track: track.copyWith(isLiked: isLiked),
                    index: index + 1,
                    showArtwork: false,
                    isPlaying: isCurrent && isPlaying,
                    isSelected: isCurrent,
                    onTap: () {
                      audioHandler.setQueue(_tracks, startIndex: index);
                    },
                    onPlayTap: () {
                      audioHandler.setQueue(_tracks, startIndex: index);
                    },
                    onLikeTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(libraryRepositoryProvider)
                          .setLiked(track.id, !isLiked, track: track);
                    },
                    onOptionsTap: () {
                      HapticFeedback.selectionClick();
                      TrackOptionsBottomSheet.show(context, track: track);
                    },
                    trailing: IconButton(
                      iconSize: 18.0,
                      splashRadius: 18.0,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        isDownloaded
                            ? Icons.download_done_rounded
                            : Icons.download_for_offline_outlined,
                        color: isDownloaded ? tokens.accent : tokens.textMuted,
                      ),
                      tooltip: isDownloaded ? 'Downloaded' : 'Download Offline',
                      onPressed: isDownloaded
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(downloadRepositoryProvider)
                                  .queueDownload(track);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Downloading "${track.title}"...'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: tokens.surfaceElevated,
                                  ),
                                );
                              }
                            },
                    ),
                  );
                },
                childCount: _tracks.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }


}
