import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/desktop_player_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/shared/app_network_image.dart';
import '../widgets/shared/app_pill_button.dart';
import '../widgets/shared/aurora_background.dart';
import '../widgets/shared/track_row.dart';
import '../widgets/track_options_bottom_sheet.dart';

/// Universal playlist / collection screen showing full track listings
/// for smart playlists (On Repeat, Most Played), downloads, history, and shelves.
class TracksListScreen extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final String? coverUrl;
  final List<Track>? initialTracks;
  final Future<List<Track>> Function()? tracksFuture;
  final bool isDownloads;

  const TracksListScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.coverUrl,
    this.initialTracks,
    this.tracksFuture,
    this.isDownloads = false,
  });

  @override
  ConsumerState<TracksListScreen> createState() => _TracksListScreenState();
}

class _TracksListScreenState extends ConsumerState<TracksListScreen> {
  List<Track> _tracks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialTracks != null) {
      _tracks = List<Track>.from(widget.initialTracks!);
    } else if (widget.tracksFuture != null) {
      _fetchTracks();
    }
  }

  Future<void> _fetchTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await widget.tracksFuture!();
      if (mounted) {
        setState(() {
          _tracks = res;
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

  void _playAll({bool shuffle = false, int startIndex = 0}) {
    if (_tracks.isEmpty) return;
    final audioHandler = ref.read(audioHandlerProvider);

    if (shuffle) {
      final shuffled = List<Track>.from(_tracks)..shuffle();
      audioHandler.setQueue(shuffled, startIndex: 0);
    } else {
      audioHandler.setQueue(_tracks, startIndex: startIndex);
    }
  }

  void _downloadAll() async {
    final downloadRepo = ref.read(downloadRepositoryProvider);
    int queuedCount = 0;

    for (final track in _tracks) {
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentTrack =
        ref.watch(currentTrackProvider).value ?? audioHandler.currentTrack;
    final isPlaying = ref.watch(isPlayingProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final accentColor = widget.iconColor ?? tokens.accent;

    // Resolve cover artwork if available
    String? effectiveCover = widget.coverUrl;
    if (effectiveCover == null || effectiveCover.isEmpty) {
      for (final t in _tracks) {
        if (t.coverUrl != null && t.coverUrl!.isNotEmpty) {
          effectiveCover = t.coverUrl;
          break;
        }
      }
    }

    return AuroraBackground(
      child: Scaffold(
        backgroundColor:
            tokens.isGlass ? Colors.transparent : tokens.background,
      bottomNavigationBar: !isDesktop
          ? const SafeArea(top: false, bottom: true, child: MiniPlayer())
          : const DesktopPlayerBar(),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: tokens.accent),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: tokens.textSecondary)),
                      const SizedBox(height: 12),
                      AppPillButton(
                        label: 'Retry',
                        onPressed: _fetchTracks,
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // 1. Collapsible Hero Header
                    SliverAppBar(
                      expandedHeight: 250,
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
                          widget.title,
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
                                accentColor.withValues(alpha: 0.28),
                                tokens.background,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 24),
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: tokens.card,
                                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: widget.icon != null && (effectiveCover == null || effectiveCover.isEmpty)
                                      ? Center(
                                          child: Icon(
                                            widget.icon,
                                            size: 56,
                                            color: accentColor,
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(tokens.radiusCard),
                                          child: AppNetworkImage(
                                            imageUrl: effectiveCover,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            fallbackIcon: widget.icon ?? Icons.music_note_rounded,
                                            backgroundColor: tokens.card,
                                          ),
                                        ),
                                ),
                                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontUi,
                                      fontSize: 13,
                                      color: tokens.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
                            Expanded(
                              child: Text(
                                '${_tracks.length} ${_tracks.length == 1 ? 'track' : 'tracks'}',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 13,
                                  fontFamily: AppTheme.fontUi,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (!widget.isDownloads)
                              IconButton(
                                icon: Icon(
                                  Icons.download_for_offline_outlined,
                                  color: tokens.textSecondary,
                                ),
                                tooltip: 'Download All Offline',
                                onPressed: _tracks.isNotEmpty ? _downloadAll : null,
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: tokens.textSecondary,
                              ),
                              tooltip: 'Shuffle Play',
                              onPressed: _tracks.isNotEmpty ? () => _playAll(shuffle: true) : null,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: tokens.accent,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 28,
                                  color: Color(0xFF000000),
                                ),
                                tooltip: 'Play',
                                onPressed: _tracks.isNotEmpty ? () => _playAll(startIndex: 0) : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Track List
                    if (_tracks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_off, size: 48, color: Colors.white24),
                              const SizedBox(height: 12),
                              Text(
                                'No tracks found in this playlist',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontFamily: AppTheme.fontUi,
                                ),
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
                              final track = _tracks[index];
                              final isCurrentTrack =
                                  currentTrack?.id == track.id;

                              return _buildTrackTile(
                                context: context,
                                tokens: tokens,
                                track: track,
                                index: index,
                                allTracks: _tracks,
                                isPlayingThis: isCurrentTrack && isPlaying,
                                isSelected: isCurrentTrack,
                              );
                            },
                            childCount: _tracks.length,
                          ),
                        ),
                      ),
                  ],
                ),
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
    bool isSelected = false,
  }) {
    final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
    final isDownloadedAsync = ref.watch(isTrackDownloadedProvider(track.id));
    final isLiked = isLikedAsync.value ?? track.isLiked;
    final isDownloaded = isDownloadedAsync.value ?? false;

    return TrackRow(
      track: track.copyWith(isLiked: isLiked),
      index: index + 1,
      isPlaying: isPlayingThis,
      isSelected: isSelected,
      onTap: () => _playAll(startIndex: index),
      onPlayTap: () => _playAll(startIndex: index),
      onLikeTap: () {
        ref.read(libraryRepositoryProvider).setLiked(track.id, !isLiked, track: track);
      },
      onOptionsTap: () {
        TrackOptionsBottomSheet.show(
          context,
          track: track,
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
