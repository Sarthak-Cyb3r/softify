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
    final isLikedAsync = isPlaceholder ? null : ref.watch(isTrackLikedProvider(displayTrack.id));
    final isLiked = isLikedAsync?.value ?? displayTrack.isLiked;

    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration =
        ref.watch(durationStreamProvider).value ?? displayTrack.duration;
    final progress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : (isBuffering ? 0.35 : 0.0);

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
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xF0252528),
                Color(0xF018181B),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 16,
                spreadRadius: 0,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      // Artwork 42x42 with 6px radius
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: isPlaceholder
                            ? Container(
                                width: 42,
                                height: 42,
                                color: tokens.surfaceElevated,
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                                    ),
                                  ),
                                ),
                              )
                            : AppNetworkImage(
                                imageUrl: displayTrack.coverUrl,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.music_note_rounded,
                                backgroundColor: tokens.surfaceElevated,
                              ),
                      ),
                      const SizedBox(width: 10),

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
                                        valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
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
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontUi,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
                              style: const TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFFB3B3B3),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Like Action
                      BouncingScaleButton(
                        scaleFactor: 0.88,
                        onTap: isPlaceholder
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(libraryRepositoryProvider)
                                    .setLiked(displayTrack.id, !isLiked, track: displayTrack);
                              },
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isLiked ? tokens.accent : const Color(0xFFB3B3B3),
                            size: 21,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // Borderless Play / Pause Icon Button with spinner when buffering
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: isBuffering
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Skip Next Action
                      BouncingScaleButton(
                        scaleFactor: 0.90,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioHandler.skipToNext();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2.5px Hairline Progress Bar
                Container(
                  height: 2.5,
                  color: const Color(0x22FFFFFF),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


}
