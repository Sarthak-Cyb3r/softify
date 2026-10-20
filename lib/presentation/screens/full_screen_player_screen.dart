import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/artist_chooser_bottom_sheet.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/play_pause_morph_button.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../widgets/shared/app_network_image.dart';
import '../widgets/sleep_timer_bottom_sheet.dart';
import '../widgets/track_options_bottom_sheet.dart';
import 'equalizer_screen.dart';

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
    final audioHandler = ref.watch(audioHandlerProvider);
    final historyTrack =
        ref.watch(playHistoryStreamProvider).value?.firstOrNull?.track;
    final queueTrack = ref.watch(queueProvider).value?.firstOrNull;

    final currentTrack = ref.watch(currentTrackProvider).value ??
        audioHandler.currentTrack ??
        historyTrack ??
        queueTrack;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final repeatMode =
        ref.watch(repeatModeStreamProvider).value ?? audioHandler.repeatMode;
    final isShuffle = ref.watch(shuffleModeStreamProvider).value ?? audioHandler.isShuffleEnabled;

    final isPlaying = (playbackState?.playing ?? false) || audioHandler.playbackState.value.playing;
    final currentSpeed =
        ref.watch(playbackSpeedStreamProvider).value ?? audioHandler.speed;

    final isBuffering = (playbackState?.processingState == AudioProcessingState.buffering) ||
        (playbackState?.processingState == AudioProcessingState.loading) ||
        audioHandler.playbackState.value.processingState == AudioProcessingState.buffering;

    final bool isPlaceholder = currentTrack == null;
    final Track effectiveTrack = currentTrack ??
        const Track(
          id: 'placeholder_loading',
          title: 'Loading audio...',
          artist: 'Buffering studio master stream...',
          duration: Duration(minutes: 3),
          sourceId: '',
        );

    if (!isPlaceholder && effectiveTrack.coverUrl != null) {
      _extractArtworkPalette(effectiveTrack.coverUrl!);
    }

    final isLikedAsync = isPlaceholder ? null : ref.watch(isTrackLikedProvider(effectiveTrack.id));
    final isLiked = isLikedAsync?.value ?? effectiveTrack.isLiked;

    final isDownloadedAsync =
        isPlaceholder ? null : ref.watch(isTrackDownloadedProvider(effectiveTrack.id));
    final isDownloaded = isDownloadedAsync?.value ?? false;

    final sleepRemainingAsync = ref.watch(sleepTimerRemainingProvider);
    final isSleepEndOfTrackAsync = ref.watch(sleepTimerEndOfTrackProvider);
    final sleepRemaining = sleepRemainingAsync.value;
    final isSleepEndOfTrack = isSleepEndOfTrackAsync.value ?? false;
    final isSleepActive =
        (sleepRemaining != null && sleepRemaining > Duration.zero) ||
            isSleepEndOfTrack;

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

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Root OLED Obsidian Canvas
              Container(color: tokens.background),

              // 2. Primary ambient color mesh glow node behind artwork
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.38),
                      radius: 1.25,
                      colors: [
                        effectiveColor.withValues(alpha: 0.44),
                        effectiveColor.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Secondary subtle offset mesh node for natural chromatic dispersion
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.55, -0.15),
                      radius: 0.95,
                      colors: [
                        effectiveColor.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.85],
                    ),
                  ),
                ),
              ),

              // 4. Downward vignette ensuring high-contrast controls readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        tokens.background.withValues(alpha: 0.65),
                        tokens.background.withValues(alpha: 0.96),
                      ],
                      stops: const [0.3, 0.72, 1.0],
                    ),
                  ),
                ),
              ),

              // 5. Forefront Player Interface
              child!,
            ],
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
                            isPlaceholder ? 'SOFTIFY' : 'PLAYING FROM',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.5,
                              color: tokens.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPlaceholder
                                ? 'CONNECTING...'
                                : (effectiveTrack.album ?? effectiveTrack.artist),
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
                    if (isSleepActive) ...[
                      BouncingScaleButton(
                        scaleFactor: 0.9,
                        onTap: () => SleepTimerBottomSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(tokens.radiusFull),
                            border: Border.all(
                              color: tokens.accent.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bedtime_rounded, color: tokens.accent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isSleepEndOfTrack
                                    ? 'End'
                                    : '${sleepRemaining?.inMinutes ?? 0}m',
                                style: TextStyle(
                                  color: tokens.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: isPlaceholder
                          ? null
                          : () => TrackOptionsBottomSheet.show(context, track: effectiveTrack),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 24,
                          color: isPlaceholder ? tokens.textSecondary.withValues(alpha: 0.3) : null,
                        ),
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
                  child: _showLyrics && !isPlaceholder
                      ? Padding(
                          key: const ValueKey('lyrics_active'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(tokens.radiusXl),
                            child: LyricsView(
                              track: effectiveTrack,
                              ambientColor: _ambientColor,
                              onClose: () => setState(() => _showLyrics = false),
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('artwork_active'),
                          onVerticalDragEnd: (details) {
                            if (!isPlaceholder &&
                                details.primaryVelocity != null &&
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
                                child: Hero(
                                  tag: 'now_playing_artwork_${effectiveTrack.id}',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          blurRadius: 32,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 16),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: isPlaceholder
                                          ? Container(
                                              color: tokens.surfaceElevated,
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 38,
                                                      height: 38,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.8,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          tokens.accent,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Buffering studio master...',
                                                      style: TextStyle(
                                                        color: tokens.textSecondary,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : AppNetworkImage(
                                              imageUrl: effectiveTrack.coverUrl,
                                              fit: BoxFit.cover,
                                              cacheWidth: 800,
                                              cacheHeight: 800,
                                              placeholderIcon: Icons.music_note_rounded,
                                            ),
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
                            effectiveTrack.title,
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
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: isPlaceholder
                                ? null
                                : () {
                                    showArtistChooserOrDetail(
                                      context,
                                      rawArtist: effectiveTrack.artist,
                                      coverUrl: effectiveTrack.coverUrl,
                                    );
                                  },
                            child: Text(
                              effectiveTrack.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Download Action
                    BouncingScaleButton(
                      scaleFactor: 0.88,
                      onTap: (isDownloaded || isPlaceholder)
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(downloadRepositoryProvider)
                                  .queueDownload(effectiveTrack);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Downloading "${effectiveTrack.title}"...'),
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
                              : tokens.textSecondary.withValues(alpha: isPlaceholder ? 0.3 : 0.8),
                          size: 26,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Like Action
                    BouncingScaleButton(
                      scaleFactor: 0.88,
                      onTap: isPlaceholder
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(libraryRepositoryProvider)
                                  .setLiked(effectiveTrack.id, !isLiked, track: effectiveTrack);
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked
                              ? tokens.accent
                              : tokens.textSecondary.withValues(alpha: isPlaceholder ? 0.3 : 0.8),
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
                  fallbackDuration: effectiveTrack.duration,
                  trackId: effectiveTrack.id,
                ),
              ),

              // 5. Playback Controls (Shuffle, Prev, Morph Play/Pause, Next, Repeat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Shuffle Button with signature emerald active dot
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.setShuffleEnabled(!isShuffle);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shuffle_rounded,
                              color: isShuffle
                                  ? tokens.accent
                                  : const Color(0xFFB3B3B3),
                              size: 24,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isShuffle ? tokens.accent : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Skip Previous Button with frosted glass touch target
                    BouncingScaleButton(
                      scaleFactor: 0.92,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.skipToPrevious();
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),

                    // Center Play/Pause Morphing Button (Glow + Smooth Loading Spinner when Buffering)
                    PlayPauseMorphButton(
                      isPlaying: isPlaying,
                      isLoading: isBuffering || isPlaceholder,
                      size: 68,
                      iconSize: 36,
                      backgroundColor: Colors.white,
                      iconColor: Colors.black,
                      showGlow: true,
                      onTap: () {
                        if (currentTrack == null && !isPlaceholder) {
                          audioHandler.playTrack(effectiveTrack);
                        } else if (isPlaying) {
                          audioHandler.pause();
                        } else {
                          audioHandler.play();
                        }
                      },
                    ),

                    // Skip Next Button with frosted glass touch target
                    BouncingScaleButton(
                      scaleFactor: 0.92,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.skipToNext();
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),

                    // Repeat Button with signature emerald active dot
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final next = repeatMode.next();
                        audioHandler.setAudioRepeatMode(next);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    next == AudioRepeatMode.one
                                        ? Icons.repeat_one_rounded
                                        : Icons.repeat_rounded,
                                    color: next != AudioRepeatMode.off
                                        ? tokens.accent
                                        : Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    next.label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(milliseconds: 1400),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1F1F23),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(tokens.radiusFull),
                              ),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              repeatMode == AudioRepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: repeatMode != AudioRepeatMode.off
                                  ? tokens.accent
                                  : const Color(0xFFB3B3B3),
                              size: 24,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: repeatMode != AudioRepeatMode.off
                                    ? tokens.accent
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Bottom Bar: Devices, Synced Lyrics Toggle, Playback Speed, & Queue
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Devices / Sound DSP (Spotify Signature bottom-left)
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EqualizerScreen(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.devices_rounded,
                          color: Color(0xFFB3B3B3),
                          size: 22,
                        ),
                      ),
                    ),

                    // Lyrics Toggle Pill
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
                              ? tokens.accent.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(tokens.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lyrics_rounded,
                              size: 18,
                              color: _showLyrics ? tokens.accent : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lyrics',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _showLyrics ? tokens.accent : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Playback Speed Button (YouTube & Podcasts only)
                    if (!isPlaceholder && effectiveTrack.supportsSpeedPlayback)
                      BouncingScaleButton(
                        scaleFactor: 0.9,
                        onTap: _cycleSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: (currentSpeed > 1.05)
                                ? tokens.accent.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(tokens.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                size: 16,
                                color: (currentSpeed > 1.05)
                                    ? tokens.accent
                                    : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                currentSpeed == 1.0
                                    ? '1x'
                                    : (currentSpeed == 2.0
                                        ? '2x'
                                        : (currentSpeed == 3.0
                                            ? '3x'
                                            : '${currentSpeed}x')),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (currentSpeed > 1.05)
                                      ? tokens.accent
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Queue Action (Spotify Signature bottom-right)
                    BouncingScaleButton(
                      scaleFactor: 0.9,
                      onTap: () => _openQueueSheet(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: Color(0xFFB3B3B3),
                          size: 24,
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

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    const speeds = [1.0, 1.5, 2.0, 2.5, 3.0];
    final current = ref.read(playbackSpeedStreamProvider).value ??
        ref.read(audioHandlerProvider).speed;
    int nextIdx = 0;
    for (int i = 0; i < speeds.length; i++) {
      if ((current - speeds[i]).abs() < 0.05) {
        nextIdx = (i + 1) % speeds.length;
        break;
      }
    }
    ref.read(audioHandlerProvider).setSpeed(speeds[nextIdx]);
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


}

/// Isolated scrubber widget that handles high-frequency position ticks
/// and dragging locally, keeping the parent FullScreenPlayerScreen completely free
/// from frame-by-frame rebuilds.
class _FullScreenPlayerScrubber extends ConsumerStatefulWidget {
  final Duration? fallbackDuration;
  final String? trackId;

  const _FullScreenPlayerScrubber({this.fallbackDuration, this.trackId});

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
    final audioHandler = ref.watch(audioHandlerProvider);
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ??
        widget.fallbackDuration ??
        Duration.zero;

    final bool isPlaceholder = widget.trackId == 'placeholder_loading';
    final maxSeconds =
        duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final currentSeconds = _dragPositionSeconds ??
        position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Authentic Spotify Seek Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              trackShape: const RectangularSliderTrackShape(),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: isPlaceholder ? 0 : 4.5,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: RoundSliderOverlayShape(overlayRadius: isPlaceholder ? 0 : 10),
              activeTrackColor: Colors.white,
              inactiveTrackColor: const Color(0x33FFFFFF),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: isPlaceholder ? 0.0 : currentSeconds.clamp(0.0, maxSeconds),
              max: maxSeconds,
              onChangeStart: isPlaceholder
                  ? null
                  : (_) {
                      HapticFeedback.lightImpact();
                    },
              onChanged: isPlaceholder
                  ? null
                  : (val) {
                      if (_dragPositionSeconds != null &&
                          (val ~/ 10) != (_dragPositionSeconds! ~/ 10)) {
                        HapticFeedback.selectionClick();
                      }
                      setState(() {
                        _dragPositionSeconds = val;
                      });
                    },
              onChangeEnd: isPlaceholder
                  ? null
                  : (val) {
                      HapticFeedback.mediumImpact();
                      audioHandler.seek(Duration(seconds: val.round()));
                      setState(() {
                        _dragPositionSeconds = null;
                      });
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(
                    Duration(seconds: isPlaceholder ? 0 : currentSeconds.round()),
                  ),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB3B3B3),
                  ),
                ),
                Text(
                  isPlaceholder ? '--:--' : _formatDuration(duration),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB3B3B3),
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

