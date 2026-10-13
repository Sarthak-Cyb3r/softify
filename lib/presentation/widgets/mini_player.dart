import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import '../theme/app_theme.dart';
import 'animated_music_wave_indicator.dart';

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

    final effectiveTrack = currentTrack ?? historyTrack ?? queueTrack;

    if (effectiveTrack == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = (currentTrack != null) && (playbackState?.playing ?? false);
    final isLikedAsync = ref.watch(isTrackLikedProvider(effectiveTrack.id));
    final isLiked = isLikedAsync.value ?? effectiveTrack.isLiked;

    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration =
        ref.watch(durationStreamProvider).value ?? effectiveTrack.duration;
    final progress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: 'Now Playing: ${effectiveTrack.title} by ${effectiveTrack.artist}',
      button: true,
      child: GestureDetector(
        onTap: () {
          if (currentTrack == null) {
            audioHandler.playTrack(effectiveTrack);
          }
          _openFullPlayer(context);
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -150) {
            if (currentTrack == null) {
              audioHandler.playTrack(effectiveTrack);
            }
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
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          decoration: BoxDecoration(
            color: tokens.card, // #181818
            borderRadius: BorderRadius.circular(tokens.radiusCard), // 8px
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Artwork 42x42 with 4px radius
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 42,
                          height: 42,
                          color: tokens.surfaceElevated,
                          child: effectiveTrack.coverUrl != null &&
                                  effectiveTrack.coverUrl!.isNotEmpty
                              ? Image.network(
                                  effectiveTrack.coverUrl!,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _fallbackCover(tokens),
                                )
                              : _fallbackCover(tokens),
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
                                if (isPlaying) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: AnimatedMusicWaveIndicator(
                                      isPlaying: true,
                                      size: 13,
                                      barCount: 3,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    effectiveTrack.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontUi,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              effectiveTrack.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 12, // Strict 12px min floor
                                fontWeight: FontWeight.w400,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Like Action
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked ? tokens.accent : tokens.textSecondary,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(libraryRepositoryProvider)
                              .setLiked(effectiveTrack.id, !isLiked, track: effectiveTrack);
                        },
                      ),

                      // Circular Play / Pause Button (#2EE66B)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 22,
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (currentTrack == null) {
                              audioHandler.playTrack(effectiveTrack);
                            } else if (isPlaying) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // 2px Progress Bar
                Container(
                  height: 2.0,
                  color: tokens.cardHover,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        color: tokens.accent,
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

  Widget _fallbackCover(AppTokens tokens) {
    return Container(
      color: tokens.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 20,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}
