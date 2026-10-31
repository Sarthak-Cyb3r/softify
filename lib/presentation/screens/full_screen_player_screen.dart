import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/ui_style_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/artist_chooser_bottom_sheet.dart';
import '../widgets/animated_artwork_card.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../widgets/shared/app_network_image.dart';
import '../widgets/sleep_timer_bottom_sheet.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../widgets/vinyl_turntable_view.dart';
import '../widgets/wavy_slider.dart';
import '../widgets/shared/app_surface.dart';
import '../widgets/shared/aurora_background.dart';
import '../widgets/apple_music_lyrics_canvas.dart';
import '../widgets/apple_music_player_components.dart';

class FullScreenPlayerScreen extends ConsumerStatefulWidget {
  const FullScreenPlayerScreen({super.key});

  @override
  ConsumerState<FullScreenPlayerScreen> createState() =>
      _FullScreenPlayerScreenState();
}

enum _AppleMusicTab { main, lyrics, queue }

class _FullScreenPlayerScreenState
    extends ConsumerState<FullScreenPlayerScreen> {
  static final Map<String, Color> _paletteCache = {};

  bool _showLyrics = false;
  bool _showTurntable = false;
  bool _isFullScreenLyrics = false;
  _AppleMusicTab _appleMusicTab = _AppleMusicTab.main;
  Color _ambientColor = const Color(0xFF141A16);
  String? _lastExtractedCoverUrl;

  void _shareTrack(BuildContext context, Track track) {
    HapticFeedback.selectionClick();
    final rawId = track.id.startsWith('yt_')
        ? track.id.replaceFirst('yt_', '')
        : (track.sourceId.startsWith('yt_')
            ? track.sourceId.replaceFirst('yt_', '')
            : (track.id.length == 11
                ? track.id
                : (track.sourceId.length == 11 ? track.sourceId : '')));

    final String shareUrl = rawId.isNotEmpty
        ? 'https://music.youtube.com/watch?v=$rawId'
        : 'https://music.youtube.com/search?q=${Uri.encodeComponent('${track.artist} - ${track.title}')}';

    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Link copied to clipboard: $shareUrl',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white24, width: 0.8),
        ),
      ),
    );
  }

  void _extractArtworkPalette(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty || coverUrl == _lastExtractedCoverUrl) {
      return;
    }
    _lastExtractedCoverUrl = coverUrl;

    final raw = coverUrl.trim();
    if (_paletteCache.containsKey(raw)) {
      final color = _paletteCache[raw]!;
      setState(() {
        _ambientColor = color;
      });
      ref.read(dynamicThemeColorProvider.notifier).setManualSeed(color);
      return;
    }

    String primaryUrl = raw;
    if (primaryUrl.startsWith('http://')) {
      primaryUrl = 'https://${primaryUrl.substring(7)}';
    }

    ImageProvider? provider;
    if (primaryUrl.startsWith('file://')) {
      provider = FileImage(File(Uri.parse(primaryUrl).toFilePath()));
    } else if (primaryUrl.startsWith('/')) {
      provider = FileImage(File(primaryUrl));
    } else if (primaryUrl.startsWith('https://')) {
      provider = NetworkImage(primaryUrl);
    }

    if (provider == null) {
      final color = DynamicThemeNotifier.generateConsistentHashColor(raw);
      _paletteCache[raw] = color;
      if (mounted) {
        setState(() => _ambientColor = color);
        ref.read(dynamicThemeColorProvider.notifier).setManualSeed(color);
      }
      return;
    }

    PaletteGenerator.fromImageProvider(
      provider,
      size: const Size(48, 48), // Downscaled sample for 60fps performance on mobile
      maximumColorCount: 8,
    ).then((generator) {
      final color = generator.dominantColor?.color ??
          generator.vibrantColor?.color ??
          generator.mutedColor?.color ??
          DynamicThemeNotifier.generateConsistentHashColor(raw);

      _paletteCache[raw] = color;
      if (mounted) {
        setState(() {
          _ambientColor = color;
        });
        ref.read(dynamicThemeColorProvider.notifier).setManualSeed(color);
      }
    }).catchError((_) {
      final color = DynamicThemeNotifier.generateConsistentHashColor(raw);
      _paletteCache[raw] = color;
      if (mounted) {
        setState(() => _ambientColor = color);
        ref.read(dynamicThemeColorProvider.notifier).setManualSeed(color);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);
    final historyTrack =
        ref.watch(playHistoryStreamProvider).value?.firstOrNull?.track;
    final queueTrack = ref.watch(queueProvider).value?.firstOrNull;

    final mediaItem = ref.watch(mediaItemStreamProvider).value ?? audioHandler.mediaItem.value;
    final Track? mediaItemTrack = mediaItem != null
        ? Track(
            id: mediaItem.id,
            sourceId: (mediaItem.extras?['sourceId'] as String?) ?? mediaItem.id,
            title: mediaItem.title,
            artist: mediaItem.artist ?? '',
            album: mediaItem.album,
            duration: mediaItem.duration ?? Duration.zero,
            coverUrl: mediaItem.artUri?.toString(),
            isLiked: (mediaItem.extras?['isLiked'] as bool?) ?? false,
          )
        : null;

    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final isPlaying = (playbackState?.playing ?? false) || audioHandler.playbackState.value.playing;
    final isBuffering = (playbackState?.processingState == AudioProcessingState.buffering) ||
        (playbackState?.processingState == AudioProcessingState.loading) ||
        audioHandler.playbackState.value.processingState == AudioProcessingState.buffering;

    final activePlayingTrack = ref.watch(currentTrackProvider).value ??
        audioHandler.currentTrack ??
        mediaItemTrack;
    final fallbackTrack = (!isPlaying && !isBuffering) ? (historyTrack ?? queueTrack) : null;
    final resolvedTrack = activePlayingTrack ?? fallbackTrack;

    final repeatMode =
        ref.watch(repeatModeStreamProvider).value ?? audioHandler.repeatMode;
    final isShuffle = ref.watch(shuffleModeStreamProvider).value ?? audioHandler.isShuffleEnabled;

    final bool isPlaceholder = resolvedTrack == null;
    final Track effectiveTrack = resolvedTrack ??
        const Track(
          id: 'placeholder_loading',
          title: 'Softify',
          artist: 'Select a song to start listening',
          duration: Duration(minutes: 3),
          sourceId: '',
        );

    if (!isPlaceholder && effectiveTrack.coverUrl != null) {
      _extractArtworkPalette(effectiveTrack.coverUrl!);
    }

    final isLikedAsync = isPlaceholder ? null : ref.watch(isTrackLikedProvider(effectiveTrack.id));
    final isLiked = isLikedAsync?.value ?? effectiveTrack.isLiked;

    final sleepRemainingAsync = ref.watch(sleepTimerRemainingProvider);
    final isSleepEndOfTrackAsync = ref.watch(sleepTimerEndOfTrackProvider);
    final sleepRemaining = sleepRemainingAsync.value;
    final isSleepEndOfTrack = isSleepEndOfTrackAsync.value ?? false;
    final isSleepActive =
        (sleepRemaining != null && sleepRemaining > Duration.zero) ||
            isSleepEndOfTrack;

    final nowPlayingStyle = ref.watch(nowPlayingStyleProvider);

    final playerScaffold = Scaffold(
      backgroundColor: tokens.isGlass ? Colors.transparent : tokens.background,
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
              if (!tokens.isGlass) Container(color: tokens.background),

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
        child: nowPlayingStyle == NowPlayingStyle.appleMusic
            ? _buildAppleMusicPlayerLayout(
                context: context,
                tokens: tokens,
                effectiveTrack: effectiveTrack,
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                isPlaceholder: isPlaceholder,
                isLiked: isLiked,
                isSleepActive: isSleepActive,
                isSleepEndOfTrack: isSleepEndOfTrack,
                sleepRemaining: sleepRemaining,
                audioHandler: audioHandler,
                repeatMode: repeatMode,
                isShuffle: isShuffle,
                activePlayingTrack: activePlayingTrack,
                resolvedTrack: resolvedTrack,
              )
            : SafeArea(
                child: Column(
            children: [
              // 1. Top Bar (Dismiss, Album title, Options)
              if (!_isFullScreenLyrics)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BouncingScaleButton(
                        scaleFactor: 0.9,
                        onTap: () => Navigator.of(context).pop(),
                        child: tokens.isGlass
                            ? AppSurface(
                                withBlur: true,
                                width: 38,
                                height: 38,
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(color: tokens.glassBorder, width: 1.0),
                                child: const Center(
                                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.white),
                                ),
                              )
                            : const Padding(
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
                      if (isSleepActive)
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
                        )
                      else
                        const SizedBox(width: 38),
                    ],
                  ),
                ),

              // 2. Main Hero Artwork / Lyrics View with gesture
              Expanded(
                child: AnimatedSwitcher(
                  duration: tokens.motionStandard,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: (_showLyrics && !isPlaceholder)
                      ? Padding(
                          key: ValueKey('lyrics_${effectiveTrack.id}'),
                          padding: _isFullScreenLyrics
                              ? const EdgeInsets.fromLTRB(16, 4, 16, 8)
                              : const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(tokens.radiusXl),
                            child: LyricsView(
                              key: ValueKey('lyrics_view_${effectiveTrack.id}'),
                              track: effectiveTrack,
                              ambientColor: _ambientColor,
                              isFullScreen: _isFullScreenLyrics,
                              onToggleFullscreen: () => setState(() => _isFullScreenLyrics = !_isFullScreenLyrics),
                              onClose: () => setState(() {
                                _isFullScreenLyrics = false;
                                _showLyrics = false;
                              }),
                            ),
                          ),
                        )
                      : (_showTurntable && !isPlaceholder)
                          ? Padding(
                              key: ValueKey('turntable_${effectiveTrack.id}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: VinylTurntableView(
                                key: ValueKey('turntable_view_${effectiveTrack.id}'),
                                coverUrl: effectiveTrack.coverUrl,
                                isPlaying: isPlaying,
                                ambientColor: _ambientColor,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _showTurntable = false);
                                },
                              ),
                            )
                          : GestureDetector(
                              key: ValueKey('artwork_${effectiveTrack.id}'),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _showTurntable = true);
                              },
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
                                          : AnimatedArtworkCard(
                                              track: effectiveTrack,
                                              isPlaying: isPlaying,
                                              ambientColor: _ambientColor,
                                              borderRadius: 8,
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

              // 3. Track Metadata (Metrolist: Compact on lyrics, Full on artwork)
              if (_showLyrics && !_isFullScreenLyrics)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: AppNetworkImage(
                            imageUrl: effectiveTrack.coverUrl,
                            fit: BoxFit.cover,
                            placeholderIcon: Icons.music_note_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              effectiveTrack.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              effectiveTrack.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BouncingScaleButton(
                        scaleFactor: 0.9,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isFullScreenLyrics = !_isFullScreenLyrics);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _isFullScreenLyrics
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BouncingScaleButton(
                        scaleFactor: 0.9,
                        onTap: () => TrackOptionsBottomSheet.show(context, track: effectiveTrack),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (!_isFullScreenLyrics)
                Padding(
                  key: ValueKey('track_info_${effectiveTrack.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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

                      // Share Action in Metrolist Squircle
                      BouncingScaleButton(
                        scaleFactor: 0.88,
                        onTap: isPlaceholder
                            ? null
                            : () => _shareTrack(context, effectiveTrack),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.share_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Like Action in Metrolist Squircle
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
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? tokens.accent : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. Scrubber Slider & Timestamps (Isolated RepaintBoundary)
              if (!_isFullScreenLyrics)
                RepaintBoundary(
                  child: _FullScreenPlayerScrubber(
                    fallbackDuration: effectiveTrack.duration,
                    trackId: effectiveTrack.id,
                  ),
                ),

              // 5. Metrolist M3 Expressive Playback Controls (Prev 68dp, Wide Capsule Play/Pause 68dp, Next 68dp)
              if (!_isFullScreenLyrics)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      // Skip Previous Button (68x68 Circle)
                      BouncingScaleButton(
                        scaleFactor: 0.92,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioHandler.skipToPrevious();
                        },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Wide Capsule Play/Pause Pill (White Container, Black Icon + Text)
                      Expanded(
                        child: BouncingScaleButton(
                          scaleFactor: 0.95,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (isPlaying) {
                              audioHandler.pause();
                            } else if (activePlayingTrack != null) {
                              audioHandler.play();
                            } else if (resolvedTrack != null && !isPlaceholder) {
                              audioHandler.playTrack(resolvedTrack);
                            } else {
                              audioHandler.play();
                            }
                          },
                          child: Container(
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(34),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isBuffering)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.8,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  )
                                else
                                  Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 32,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  isPlaying ? 'Pause' : 'Play',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Skip Next Button (68x68 Circle)
                      BouncingScaleButton(
                        scaleFactor: 0.92,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioHandler.skipToNext();
                        },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 6. Metrolist Bottom Action Toolbar (Queue, Bedtime, Shuffle, Eq/Lyrics, Repeat | More Menu)
              if (!_isFullScreenLyrics)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Row(
                    children: [
                      _buildToolbarSquareButton(
                        icon: Icons.queue_music_rounded,
                        isActive: false,
                        tokens: tokens,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(21),
                          bottomLeft: Radius.circular(21),
                          topRight: Radius.circular(3),
                          bottomRight: Radius.circular(3),
                        ),
                        onTap: () => _openQueueSheet(context),
                      ),
                      const SizedBox(width: 2.5),
                      _buildToolbarSquareButton(
                        icon: Icons.bedtime_outlined,
                        isActive: isSleepActive,
                        tokens: tokens,
                        borderRadius: BorderRadius.circular(3),
                        onTap: () => SleepTimerBottomSheet.show(context),
                      ),
                      const SizedBox(width: 2.5),
                      _buildToolbarSquareButton(
                        icon: Icons.shuffle_rounded,
                        isActive: isShuffle,
                        tokens: tokens,
                        borderRadius: BorderRadius.circular(3),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioHandler.setShuffleEnabled(!isShuffle);
                        },
                      ),
                      const SizedBox(width: 2.5),
                      _buildToolbarSquareButton(
                        icon: _showLyrics ? Icons.mic_rounded : Icons.mic_none_rounded,
                        isActive: _showLyrics,
                        tokens: tokens,
                        borderRadius: BorderRadius.circular(3),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _showLyrics = !_showLyrics;
                            if (!_showLyrics) _isFullScreenLyrics = false;
                          });
                        },
                      ),
                      const SizedBox(width: 2.5),
                      _buildToolbarSquareButton(
                        icon: repeatMode == AudioRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        isActive: repeatMode != AudioRepeatMode.off,
                        tokens: tokens,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          bottomLeft: Radius.circular(3),
                          topRight: Radius.circular(21),
                          bottomRight: Radius.circular(21),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioHandler.setAudioRepeatMode(repeatMode.next());
                        },
                      ),

                      const Spacer(),

                      // White Circle More Menu Button (42x42dp circle, solid white with black more_vert icon)
                      BouncingScaleButton(
                        scaleFactor: 0.9,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          TrackOptionsBottomSheet.show(context, track: effectiveTrack);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.black,
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

    if (tokens.isGlass) {
      return AuroraBackground(child: playerScaffold);
    }
    return playerScaffold;
  }

  Widget _buildToolbarSquareButton({
    required IconData icon,
    required bool isActive,
    required AppTokens tokens,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
  }) {
    final shape = borderRadius ?? BorderRadius.circular(3);
    return BouncingScaleButton(
      scaleFactor: 0.92,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.08),
          borderRadius: shape,
          border: Border.all(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.22),
            width: 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 22,
          color: isActive ? Colors.black : Colors.white.withValues(alpha: 0.85),
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

  Widget _buildAppleMusicPlayerLayout({
    required BuildContext context,
    required AppTokens tokens,
    required Track effectiveTrack,
    required bool isPlaying,
    required bool isBuffering,
    required bool isPlaceholder,
    required bool isLiked,
    required bool isSleepActive,
    required bool isSleepEndOfTrack,
    required Duration? sleepRemaining,
    required dynamic audioHandler,
    required AudioRepeatMode repeatMode,
    required bool isShuffle,
    required Track? activePlayingTrack,
    required Track? resolvedTrack,
  }) {
    final bool isLyricsTab = _appleMusicTab == _AppleMusicTab.lyrics;
    final bool isQueueTab = _appleMusicTab == _AppleMusicTab.queue;

    Widget bodyContent;
    switch (_appleMusicTab) {
      case _AppleMusicTab.lyrics:
        bodyContent = Column(
          children: [
            // Mini Track Header Row (Screenshot 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 16, 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: isPlaceholder
                          ? Container(
                              color: tokens.surfaceElevated,
                              child: const Icon(Icons.music_note_rounded,
                                  size: 24, color: Colors.white54),
                            )
                          : AppNetworkImage(
                              imageUrl: effectiveTrack.coverUrl,
                              fit: BoxFit.cover,
                              placeholderIcon: Icons.music_note_rounded,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          effectiveTrack.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          effectiveTrack.artist.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    onTap: isPlaceholder
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            ref.read(libraryRepositoryProvider).setLiked(
                                  effectiveTrack.id,
                                  !isLiked,
                                  track: effectiveTrack,
                                );
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        isLiked ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isLiked ? const Color(0xFFFFD700) : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    onTap: () =>
                        TrackOptionsBottomSheet.show(context, track: effectiveTrack),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AppleMusicLyricsCanvas(
                key: ValueKey('am_lyrics_${effectiveTrack.id}'),
                track: effectiveTrack,
                audioHandler: audioHandler,
                isFullScreen: _isFullScreenLyrics,
                onToggleFullscreen: () {
                  setState(() => _isFullScreenLyrics = !_isFullScreenLyrics);
                },
              ),
            ),
          ],
        );
        break;

      case _AppleMusicTab.queue:
        bodyContent = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 16, 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: isPlaceholder
                          ? Container(
                              color: tokens.surfaceElevated,
                              child: const Icon(Icons.music_note_rounded,
                                  size: 24, color: Colors.white54),
                            )
                          : AppNetworkImage(
                              imageUrl: effectiveTrack.coverUrl,
                              fit: BoxFit.cover,
                              placeholderIcon: Icons.music_note_rounded,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PLAYING NEXT',
                          style: TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          effectiveTrack.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () =>
                        setState(() => _appleMusicTab = _AppleMusicTab.main),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final queueAsync = ref.watch(queueProvider);
                  final queue = queueAsync.value ?? [];
                  if (queue.isEmpty) {
                    return const Center(
                      child: Text(
                        'Queue is empty',
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: queue.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, i) {
                      final t = queue[i];
                      final isCurrent = t.id == effectiveTrack.id;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: AppNetworkImage(
                              imageUrl: t.coverUrl,
                              fit: BoxFit.cover,
                              placeholderIcon: Icons.music_note_rounded,
                            ),
                          ),
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? tokens.accent : Colors.white,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        trailing: isCurrent
                            ? Icon(Icons.equalizer_rounded,
                                color: tokens.accent, size: 20)
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioHandler.skipToQueueItem(i);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
        break;

      case _AppleMusicTab.main:
      default:
        bodyContent = LayoutBuilder(
          builder: (context, constraints) {
            final maxArtSize = (constraints.maxHeight - 120).clamp(240.0, 360.0);

            return Column(
              children: [
                const Spacer(),
                // Centered Hero Artwork (Screenshot 2)
                Center(
                  child: Container(
                    width: maxArtSize,
                    height: maxArtSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.38),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: isPlaceholder
                          ? Container(
                              color: tokens.surfaceElevated,
                              child: const Center(
                                child: Icon(Icons.music_note_rounded,
                                    size: 64, color: Colors.white54),
                              ),
                            )
                          : AppNetworkImage(
                              imageUrl: effectiveTrack.coverUrl,
                              fit: BoxFit.cover,
                              placeholderIcon: Icons.music_note_rounded,
                            ),
                    ),
                  ),
                ),
                const Spacer(),

                // Metadata Row: Title, Artist, Star, More (Screenshot 2)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              effectiveTrack.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontDisplay,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              effectiveTrack.artist.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xB3FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      BouncingScaleButton(
                        scaleFactor: 0.88,
                        onTap: isPlaceholder
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ref.read(libraryRepositoryProvider).setLiked(
                                      effectiveTrack.id,
                                      !isLiked,
                                      track: effectiveTrack,
                                    );
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            isLiked
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color:
                                isLiked ? const Color(0xFFFFD700) : Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      BouncingScaleButton(
                        scaleFactor: 0.88,
                        onTap: () => TrackOptionsBottomSheet.show(context,
                            track: effectiveTrack),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Synced Lyric Teaser Line (Screenshot 2: "Aaja na thoda sa jee le tu")
                AppleMusicLyricTeaser(
                  track: effectiveTrack,
                  onTap: () {
                    setState(() => _appleMusicTab = _AppleMusicTab.lyrics);
                  },
                ),
                const SizedBox(height: 4),
              ],
            );
          },
        );
        break;
    }

    return SafeArea(
      child: Column(
        children: [
          // Top Center Drag Handle
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 200) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                width: 36,
                height: 4.5,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),

          // Central Dynamic Canvas
          Expanded(child: bodyContent),

          // Persistent Anchored Bottom Controls (Screenshot 1 & Screenshot 2)
          if (!_isFullScreenLyrics)
            AppleMusicPersistentBottomPanel(
              track: effectiveTrack,
              audioHandler: audioHandler,
              isPlaying: isPlaying,
              isBuffering: isBuffering,
              activeTabIndex: isLyricsTab ? 1 : (isQueueTab ? 2 : 0),
              onTabChanged: (idx) {
                setState(() {
                  if (idx == 1) {
                    _appleMusicTab = _AppleMusicTab.lyrics;
                  } else if (idx == 2) {
                    _appleMusicTab = _AppleMusicTab.queue;
                  } else {
                    _appleMusicTab = _AppleMusicTab.main;
                  }
                });
              },
            ),
        ],
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
    final isPlaying =
        ref.watch(playbackStateStreamProvider).value?.playing ?? false;

    final bool isPlaceholder = widget.trackId == 'placeholder_loading';
    final maxSeconds =
        duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final currentSeconds = _dragPositionSeconds ??
        position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Metrolist M3 Clean Slider Track matching 1000096510.png
          WavySlider(
            value: isPlaceholder ? 0.0 : currentSeconds.clamp(0.0, maxSeconds),
            max: maxSeconds,
            isPlaying: isPlaying,
            enabled: !isPlaceholder,
            activeColor: Colors.white,
            inactiveColor: const Color(0x33FFFFFF),
            thumbColor: Colors.white,
            waveAmplitude: 0.0,
            trackHeight: 4.5,
            thumbRadius: isPlaceholder ? 0 : 6.0,
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

