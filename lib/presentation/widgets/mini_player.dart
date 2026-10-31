import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import '../theme/app_theme.dart';
import '../theme/metrolist_dimensions.dart';
import 'bouncing_scale_button.dart';
import 'shared/app_network_image.dart';
import 'shared/app_surface.dart';

/// Metrolist Canonical MiniPlayer (com.metrolist.music.ui.player.NewMiniPlayer):
/// - Pill Container: Height 64.0, 32.0 radius, 12px horizontal padding, 8px bottom spacing
/// - Left Play/Pause: 48x48 box with concentric circular progress arc (3px stroke)
///   surrounding a 40x40 circular album thumbnail with play/pause overlay when paused
/// - Middle Info: 14sp SemiBold title with 12sp artist name
/// - Right Transport: Like toggle heart button and skip next
/// - Gestures: Horizontal swipe to skip songs, vertical drag/tap to expand Full Player
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FullScreenPlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
          );
          final slide = Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.2, 0.0, 0.0, 1.0),
            ),
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final audioHandler = ref.watch(audioHandlerProvider);
    final historyTrack =
        ref.watch(playHistoryStreamProvider).value?.firstOrNull?.track;
    final queueTrack = ref.watch(queueProvider).value?.firstOrNull;

    final isBuffering = (playbackState?.processingState == AudioProcessingState.buffering) ||
        (playbackState?.processingState == AudioProcessingState.loading) ||
        audioHandler.playbackState.value.processingState == AudioProcessingState.buffering;

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

    final isPlaying = (playbackState?.playing ?? false) || audioHandler.playbackState.value.playing;
    final activePlayingTrack = currentTrack ?? audioHandler.currentTrack ?? mediaItemTrack;
    final fallbackTrack = (!isPlaying && !isBuffering) ? (historyTrack ?? queueTrack) : null;
    final effectiveTrack = activePlayingTrack ?? fallbackTrack;

    if (effectiveTrack == null && !isBuffering) {
      return const SizedBox.shrink();
    }

    final isPlaceholder = effectiveTrack == null;
    final displayTrack = effectiveTrack ??
        const Track(
          id: 'mini_loading',
          title: 'Loading audio...',
          artist: 'Buffering studio stream...',
          duration: Duration(minutes: 3),
          sourceId: '',
        );

    // Watch liked status for the favorite heart button
    final isLiked = !isPlaceholder &&
        (ref.watch(isTrackLikedProvider(displayTrack.id)).value ??
            displayTrack.isLiked);

    return Semantics(
      label: 'Now Playing: ${displayTrack.title} by ${displayTrack.artist}',
      button: true,
      child: GestureDetector(
        onTap: () => _openFullPlayer(context),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -150) {
            _openFullPlayer(context);
          }
        },
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity;
          if (v != null) {
            if (v < -180) {
              HapticFeedback.selectionClick();
              audioHandler.skipToNext();
            } else if (v > 180) {
              HapticFeedback.selectionClick();
              audioHandler.skipToPrevious();
            }
          }
        },
        child: AppSurface(
          margin: const EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MetrolistDimensions.miniPlayerBottomSpacing,
          ),
          borderRadius: BorderRadius.circular(MetrolistDimensions.modernPillRadius),
          withBlur: true,
          blurSigma: 16.0,
          interactive: true,
          pressedScale: 1.04,
          color: tokens.card.withValues(alpha: 0.94),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          child: SizedBox(
            height: MetrolistDimensions.miniPlayerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // 1. Concentric Play/Pause Button with Circular Progress Arc
                  _MetrolistMiniPlayButton(
                    track: displayTrack,
                    isPlaying: isPlaying,
                    isBuffering: isBuffering,
                    isPlaceholder: isPlaceholder,
                    accentColor: tokens.accent,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (isPlaceholder) return;
                      if (isPlaying) {
                        audioHandler.pause();
                      } else {
                        audioHandler.play();
                      }
                    },
                  ),
                  const SizedBox(width: 12),

                  // 2. Song Information (14sp SemiBold title & 12sp artist)
                  Expanded(
                    child: Column(
                      key: ValueKey('mini_info_${displayTrack.id}'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTrack.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayTrack.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Metrolist Favorite Heart Button
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    onTap: isPlaceholder
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            final newLiked = !isLiked;
                            ref
                                .read(libraryRepositoryProvider)
                                .setLiked(displayTrack.id, newLiked, track: displayTrack.copyWith(isLiked: newLiked));
                            ref.read(audioHandlerProvider).updateTrackLikedState(displayTrack.id, newLiked);
                          },
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      child: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? tokens.accent : tokens.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),

                  // 4. Skip Next Button
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.skipToNext();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.skip_next_rounded,
                        color: tokens.textSecondary,
                        size: 24,
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
  }
}

/// Concentric Play/Pause button reverse-engineered from NewMiniPlayerPlayButton in Metrolist:
/// Outer 48x48 box with custom-painted progress arc, enclosing a 40x40 circular artwork thumbnail.
class _MetrolistMiniPlayButton extends ConsumerWidget {
  final Track track;
  final bool isPlaying;
  final bool isBuffering;
  final bool isPlaceholder;
  final Color accentColor;
  final VoidCallback onTap;

  const _MetrolistMiniPlayButton({
    required this.track,
    required this.isPlaying,
    required this.isBuffering,
    required this.isPlaceholder,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(positionStreamProvider);
    final durationAsync = ref.watch(durationStreamProvider);

    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? track.duration;

    final progress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return BouncingScaleButton(
      scaleFactor: 0.92,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: CustomPaint(
          painter: _CircularProgressArcPainter(
            progress: progress,
            accentColor: accentColor,
            trackColor: Colors.white.withValues(alpha: 0.15),
            strokeWidth: 3.0,
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Artwork Thumbnail
                    if (isPlaceholder)
                      Container(color: const Color(0xFF1F1F24))
                    else
                      AppNetworkImage(
                        imageUrl: track.coverUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.music_note_rounded,
                        backgroundColor: const Color(0xFF1F1F24),
                      ),

                    // Overlay icon when paused or buffering
                    if (isBuffering)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),
                        ),
                      )
                    else if (!isPlaying)
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Canvas painter that draws the concentric 3px progress arc around the circular thumbnail.
class _CircularProgressArcPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color trackColor;
  final double strokeWidth;

  _CircularProgressArcPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background Track (Full 360 circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Active Progress Arc
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      const startAngle = -math.pi / 2; // -90 degrees (Top center)
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
