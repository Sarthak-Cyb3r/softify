import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../domain/entities/audio_repeat_mode.dart';
import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/play_pause_morph_button.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../widgets/track_options_bottom_sheet.dart';

class FullScreenPlayerScreen extends ConsumerStatefulWidget {
  const FullScreenPlayerScreen({super.key});

  @override
  ConsumerState<FullScreenPlayerScreen> createState() =>
      _FullScreenPlayerScreenState();
}

class _FullScreenPlayerScreenState
    extends ConsumerState<FullScreenPlayerScreen> {
  static final Map<String, Color> _paletteCache = {};

  bool _showLyrics = false;
  Color _ambientColor = const Color(0xFF141A16);
  String? _lastExtractedCoverUrl;

  void _extractArtworkPalette(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty || coverUrl == _lastExtractedCoverUrl) {
      return;
    }
    _lastExtractedCoverUrl = coverUrl;

    if (_paletteCache.containsKey(coverUrl)) {
      setState(() {
        _ambientColor = _paletteCache[coverUrl]!;
      });
      return;
    }

    PaletteGenerator.fromImageProvider(
      NetworkImage(coverUrl),
      size: const Size(48, 48), // Downscaled sample for 60fps performance on Moto G34
      maximumColorCount: 8,
    ).then((generator) {
      final color = generator.dominantColor?.color ??
          generator.vibrantColor?.color ??
          generator.mutedColor?.color ??
          const Color(0xFF1E2822);

      _paletteCache[coverUrl] = color;
      if (mounted) {
        setState(() {
          _ambientColor = color;
        });
      }
    }).catchError((_) {
      // Keep existing ambient fallback
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final repeatMode =
        ref.watch(repeatModeStreamProvider).value ?? AudioRepeatMode.off;
    final isShuffle = ref.watch(shuffleModeStreamProvider).value ?? false;
    final audioHandler = ref.watch(audioHandlerProvider);

    final isPlaying = playbackState?.playing ?? false;

    if (currentTrack == null) {
      return Scaffold(
        backgroundColor: tokens.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Nothing playing',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    _extractArtworkPalette(currentTrack.coverUrl);

    final isLikedAsync = ref.watch(isTrackLikedProvider(currentTrack.id));
    final isLiked = isLikedAsync.value ?? currentTrack.isLiked;

    final isDownloadedAsync =
        ref.watch(isTrackDownloadedProvider(currentTrack.id));
    final isDownloaded = isDownloadedAsync.value ?? false;

    return Scaffold(
      backgroundColor: tokens.background,
      body: TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          begin: const Color(0xFF0A0A0A),
          end: _ambientColor,
        ),
        duration: tokens.motionCinematic,
        curve: Curves.easeOutCubic,
        builder: (context, animatedColor, child) {
          final effectiveColor = animatedColor ?? const Color(0xFF0A0A0A);

          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 1.15,
                colors: [
                  effectiveColor.withValues(alpha: 0.42),
                  tokens.background.withValues(alpha: 0.92),
                  tokens.background,
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar (Dismiss, Album title, Options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'PLAYING FROM',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: tokens.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentTrack.album ?? currentTrack.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () => TrackOptionsBottomSheet.show(context, track: currentTrack),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.more_vert_rounded, size: 24),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Main Hero Artwork / Lyrics View with gesture
              Expanded(
                child: AnimatedSwitcher(
                  duration: tokens.motionStandard,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _showLyrics
                      ? Padding(
                          key: const ValueKey('lyrics_active'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(tokens.radiusXl),
                            child: LyricsView(
                              track: currentTrack,
                              onClose: () => setState(() => _showLyrics = false),
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('artwork_active'),
                          onVerticalDragEnd: (details) {
                            if (details.primaryVelocity != null &&
                                details.primaryVelocity! < -180) {
                              // Swipe up reveals synced lyrics
                              setState(() => _showLyrics = true);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36,
                              vertical: 16,
                            ),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(tokens.radiusXl),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _ambientColor.withValues(alpha: 0.38),
                                        blurRadius: 40,
                                        spreadRadius: 4,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Hero(
                                    tag: 'now_playing_artwork_${currentTrack.id}',
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(tokens.radiusXl),
                                      child: currentTrack.coverUrl != null
                                          ? Image.network(
                                              currentTrack.coverUrl!,
                                              fit: BoxFit.cover,
                                              cacheWidth: 800,
                                              cacheHeight: 800,
                                              gaplessPlayback: true,
                                              errorBuilder: (_, __, ___) =>
                                                  _artworkFallback(tokens),
                                            )
                                          : _artworkFallback(tokens),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              // 3. Track Metadata (Title, Artist, Like, Download)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTrack.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentTrack.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Download Action
                    BouncingScaleButton(
                      scaleFactor: 0.88,
                      onTap: isDownloaded
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(downloadRepositoryProvider)
                                  .queueDownload(currentTrack);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Downloading "${currentTrack.title}"...'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: tokens.surfaceElevated,
                                  ),
                                );
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          isDownloaded
                              ? Icons.download_done_rounded
                              : Icons.download_for_offline_outlined,
                          color: isDownloaded
                              ? tokens.accent
                              : tokens.textSecondary.withValues(alpha: 0.8),
                          size: 26,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Like Action
                    BouncingScaleButton(
                      scaleFactor: 0.88,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(libraryRepositoryProvider)
                            .setLiked(currentTrack.id, !isLiked, track: currentTrack);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked ? tokens.accent : tokens.textSecondary.withValues(alpha: 0.8),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Scrubber Slider & Timestamps (Isolated RepaintBoundary)
              RepaintBoundary(
                child: _FullScreenPlayerScrubber(
                  fallbackDuration: currentTrack.duration,
                ),
              ),

              // 5. Playback Controls (Shuffle, Prev, Morph Play/Pause, Next, Repeat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.setShuffleEnabled(!isShuffle);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.shuffle_rounded,
                          color: isShuffle ? tokens.accent : tokens.textSecondary.withValues(alpha: 0.7),
                          size: 24,
                        ),
                      ),
                    ),
                    BouncingScaleButton(
                      scaleFactor: 0.92,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.skipToPrevious();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),

                    // Center Play/Pause Morphing Button
                    PlayPauseMorphButton(
                      isPlaying: isPlaying,
                      size: 64,
                      iconSize: 34,
                      backgroundColor: Colors.white,
                      iconColor: Colors.black,
                      showGlow: true,
                      onTap: () {
                        if (isPlaying) {
                          audioHandler.pause();
                        } else {
                          audioHandler.play();
                        }
                      },
                    ),

                    BouncingScaleButton(
                      scaleFactor: 0.92,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.skipToNext();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.setAudioRepeatMode(repeatMode.next());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          repeatMode == AudioRepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: repeatMode != AudioRepeatMode.off
                              ? tokens.accent
                              : tokens.textSecondary.withValues(alpha: 0.7),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Bottom Bar: Synced Lyrics Toggle & Queue Sheet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BouncingScaleButton(
                      scaleFactor: 0.95,
                      onTap: () {
                        setState(() {
                          _showLyrics = !_showLyrics;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _showLyrics
                              ? tokens.accent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(tokens.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lyrics_rounded,
                              size: 18,
                              color: _showLyrics ? tokens.accent : tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lyrics',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _showLyrics ? tokens.accent : tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () => _openQueueSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: tokens.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.75,
        child: QueueBottomSheet(),
      ),
    );
  }

  Widget _artworkFallback(AppTokens tokens) {
    return Container(
      color: tokens.surfaceHighlight,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: tokens.textMuted,
          size: 72,
        ),
      ),
    );
  }
}

/// Isolated scrubber widget that handles high-frequency position ticks
/// and dragging locally, keeping the parent FullScreenPlayerScreen completely free
/// from frame-by-frame rebuilds.
class _FullScreenPlayerScrubber extends ConsumerStatefulWidget {
  final Duration? fallbackDuration;

  const _FullScreenPlayerScrubber({this.fallbackDuration});

  @override
  ConsumerState<_FullScreenPlayerScrubber> createState() =>
      _FullScreenPlayerScrubberState();
}

class _FullScreenPlayerScrubberState
    extends ConsumerState<_FullScreenPlayerScrubber> {
  double? _dragPositionSeconds;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ??
        widget.fallbackDuration ??
        Duration.zero;

    final maxSeconds =
        duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final currentSeconds = _dragPositionSeconds ??
        position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: tokens.textPrimary,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: tokens.textPrimary,
            ),
            child: Slider(
              value: currentSeconds.clamp(0.0, maxSeconds),
              max: maxSeconds,
              onChanged: (val) {
                setState(() {
                  _dragPositionSeconds = val;
                });
              },
              onChangeEnd: (val) {
                audioHandler.seek(Duration(seconds: val.round()));
                setState(() {
                  _dragPositionSeconds = null;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(
                    Duration(seconds: currentSeconds.round()),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

