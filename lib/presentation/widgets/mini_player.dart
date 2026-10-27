import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import '../theme/app_theme.dart';
import 'animated_music_wave_indicator.dart';
import 'bouncing_scale_button.dart';
import 'shared/app_network_image.dart';
import 'shared/app_surface.dart';

/// Floating mini player adhering to Content-First Stitch mobile design:
/// - Surface: #181818 card surface with 8px radius
/// - Progress: 2px bottom bar with #2EE66B green fill
/// - Transport: Direct play/pause and like controls, swipe gestures
/// - Zero audio quality labels, strict 12px floor
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
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
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

    final effectiveTrack = currentTrack ?? audioHandler.currentTrack ?? historyTrack ?? queueTrack;

    if (effectiveTrack == null && !isBuffering) {
      return const SizedBox.shrink();
    }

    final isPlaceholder = effectiveTrack == null;
    final displayTrack = effectiveTrack ??
        const Track(
          id: 'mini_loading',
          title: 'Loading audio...',
          artist: 'Buffering studio master stream...',
          duration: Duration(minutes: 3),
          sourceId: '',
        );

    final isPlaying = (currentTrack != null) && (playbackState?.playing ?? false);

    return Semantics(
      label: 'Now Playing: ${displayTrack.title} by ${displayTrack.artist}',
      button: true,
      child: GestureDetector(
        onTap: () {
          _openFullPlayer(context);
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -150) {
            _openFullPlayer(context);
          }
        },
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity;
          if (v != null) {
            if (v < -200) {
              HapticFeedback.selectionClick();
              audioHandler.skipToNext();
            } else if (v > 200) {
              HapticFeedback.selectionClick();
              audioHandler.skipToPrevious();
            }
          }
        },
        child: AppSurface(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          borderRadius: BorderRadius.circular(18),
          withBlur: true,
          blurSigma: 14.0,
          color: tokens.card,
          border: Border.all(
            color: tokens.cardHover.withValues(alpha: 0.6),
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 18,
              spreadRadius: 0,
              offset: Offset(0, 6),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Artwork 46x46 with 12px Metrolist M3 rounded radius
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isPlaceholder
                          ? Container(
                              width: 46,
                              height: 46,
                              color: tokens.surfaceElevated,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      tokens.accent,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : AppNetworkImage(
                              imageUrl: displayTrack.coverUrl,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              fallbackIcon: Icons.music_note_rounded,
                              backgroundColor: tokens.surfaceElevated,
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (isBuffering) ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        tokens.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (isPlaying) ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: AnimatedMusicWaveIndicator(
                                    isPlaying: true,
                                    size: 11,
                                    barCount: 3,
                                    color: tokens.accent,
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  displayTrack.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
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

                    // Metrolist Previous Track Button
                    BouncingScaleButton(
                      scaleFactor: 0.88,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.skipToPrevious();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.skip_previous_rounded,
                          color: tokens.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),

                    // Metrolist Signature Circular Filled Play / Pause Button
                    BouncingScaleButton(
                      scaleFactor: 0.90,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (isPlaying) {
                          audioHandler.pause();
                        } else if (currentTrack != null) {
                          audioHandler.play();
                        } else if (effectiveTrack != null && !isPlaceholder) {
                          audioHandler.playTrack(effectiveTrack);
                        } else {
                          audioHandler.play();
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: isBuffering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 2),

                    // Metrolist Next Track Button
                    BouncingScaleButton(
                      scaleFactor: 0.88,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.skipToNext();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: tokens.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2.5px Isolated Hairline Progress Bar
              Consumer(
                builder: (context, ref, _) {
                  final position =
                      ref.watch(positionStreamProvider).value ?? Duration.zero;
                  final duration =
                      ref.watch(durationStreamProvider).value ??
                          displayTrack.duration;
                  final progress = (duration.inMilliseconds > 0)
                      ? (position.inMilliseconds / duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : (isBuffering ? 0.35 : 0.0);
                  return Container(
                    height: 2.5,
                    color: const Color(0x22FFFFFF),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


}
