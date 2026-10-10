import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/bouncing_scale_button.dart';
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);
    final totalDurationSeconds =
        _tracks.fold<int>(0, (sum, t) => sum + t.duration.inSeconds);
    final totalMinutes = totalDurationSeconds ~/ 60;

    return Scaffold(
      backgroundColor: tokens.background,
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
                  boxShadow: [
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(tokens.radiusMd),
                          child: widget.coverUrl != null
                              ? Image.network(
                                  widget.coverUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 480,
                                  cacheHeight: 480,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) =>
                                      _fallbackCover(tokens),
                                )
                              : _fallbackCover(tokens),
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
                        fontSize: 22,
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // High-res audio pill badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                        border: Border.all(
                          color: tokens.accent.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'STUDIO MASTER 320K • FLAC LOSSLESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: tokens.accent,
                        ),
                      ),
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
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.accent.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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

                  final durationFormatted =
                      _formatDuration(track.duration);

                  return RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(tokens.radiusMd),
                          hoverColor:
                              tokens.surfaceHighlight.withValues(alpha: 0.35),
                          splashColor: tokens.accent.withValues(alpha: 0.08),
                          highlightColor:
                              tokens.surfaceHighlight.withValues(alpha: 0.2),
                          onTap: () {
                            audioHandler.setQueue(_tracks, startIndex: index);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // High-contrast track list numbers (tabular monospace)
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: tokens.textMuted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
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
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Duration Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceHighlight
                                        .withValues(alpha: 0.45),
                                    borderRadius:
                                        BorderRadius.circular(tokens.radiusSm),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    durationFormatted,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Like Button
                                BouncingScaleButton(
                                  scaleFactor: 0.88,
                                  minTouchTarget: 0,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(libraryRepositoryProvider)
                                        .setLiked(
                                          track.id,
                                          !isLiked,
                                          track: track,
                                        );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(7.0),
                                    child: Icon(
                                      isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: isLiked
                                          ? tokens.accent
                                          : tokens.textSecondary
                                              .withValues(alpha: 0.7),
                                      size: 19,
                                    ),
                                  ),
                                ),
                                // Download Button
                                BouncingScaleButton(
                                  scaleFactor: 0.88,
                                  minTouchTarget: 0,
                                  onTap: () async {
                                    if (!isDownloaded) {
                                      HapticFeedback.lightImpact();
                                      await ref
                                          .read(downloadRepositoryProvider)
                                          .queueDownload(track);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Downloading "${track.title}"...',
                                            ),
                                            duration: const Duration(seconds: 2),
                                            backgroundColor:
                                                tokens.surfaceElevated,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(7.0),
                                    child: Icon(
                                      isDownloaded
                                          ? Icons.download_done_rounded
                                          : Icons.download_for_offline_outlined,
                                      color: isDownloaded
                                          ? tokens.accent
                                          : tokens.textSecondary
                                              .withValues(alpha: 0.7),
                                      size: 19,
                                    ),
                                  ),
                                ),
                                // More Options
                                BouncingScaleButton(
                                  scaleFactor: 0.88,
                                  minTouchTarget: 0,
                                  onTap: () {
                                    TrackOptionsBottomSheet.show(
                                      context,
                                      track: track,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(7.0),
                                    child: Icon(
                                      Icons.more_vert_rounded,
                                      color: tokens.textSecondary
                                          .withValues(alpha: 0.7),
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _fallbackCover(AppTokens tokens) {
    return Container(
      color: tokens.surfaceHighlight,
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 60,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}
