import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import '../theme/app_tokens.dart';
import 'bouncing_scale_button.dart';
import 'play_pause_morph_button.dart';

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
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final audioHandler = ref.watch(audioHandlerProvider);

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = playbackState?.playing ?? false;
    final isLikedAsync = ref.watch(isTrackLikedProvider(currentTrack.id));
    final isLiked = isLikedAsync.value ?? currentTrack.isLiked;

    return RepaintBoundary(
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.03),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusLg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xE816171B),
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Album Artwork Hero Thumbnail with concentric bezel
                          Container(
                            decoration: BoxDecoration(
                              color: tokens.surfaceHighlight,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm + 3),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 0.8,
                              ),
                            ),
                            padding: const EdgeInsets.all(2.5),
                            child: Hero(
                              tag: 'now_playing_artwork_${currentTrack.id}',
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSm),
                                child: currentTrack.coverUrl != null
                                    ? Image.network(
                                        currentTrack.coverUrl!,
                                        width: 44,
                                        height: 44,
                                        cacheWidth: 132,
                                        cacheHeight: 132,
                                        gaplessPlayback: true,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _fallbackCover(tokens),
                                      )
                                    : _fallbackCover(tokens),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title & Artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentTrack.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentTrack.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Like Action (Bouncing)
                          BouncingScaleButton(
                            scaleFactor: 0.85,
                            onTap: () {
                              ref
                                  .read(libraryRepositoryProvider)
                                  .setLiked(currentTrack.id, !isLiked,
                                      track: currentTrack);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked
                                    ? tokens.accent
                                    : tokens.textSecondary.withValues(alpha: 0.7),
                                size: 22,
                              ),
                            ),
                          ),

                          const SizedBox(width: 2),

                          // Play/Pause Morph Action
                          PlayPauseMorphButton(
                            isPlaying: isPlaying,
                            size: 38,
                            iconSize: 20,
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
                        ],
                      ),
                    ),

                    // Ultra-thin Animated Progress Indicator (Isolated RepaintBoundary)
                    RepaintBoundary(
                      child: _MiniPlayerProgressBar(
                        trackFallbackDuration: currentTrack.duration,
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

  Widget _fallbackCover(AppTokens tokens) {
    return Container(
      width: 44,
      height: 44,
      color: tokens.surfaceHighlight,
      child: Icon(
        Icons.music_note,
        color: tokens.textMuted,
        size: 22,
      ),
    );
  }
}

/// Isolated progress bar widget that receives high-frequency position ticks
/// without triggering rebuilds or re-blurring of the parent MiniPlayer.
class _MiniPlayerProgressBar extends ConsumerWidget {
  final Duration? trackFallbackDuration;

  const _MiniPlayerProgressBar({this.trackFallbackDuration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ??
        trackFallbackDuration ??
        Duration.zero;

    final progress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 2.0,
      width: double.infinity,
      color: Colors.white.withValues(alpha: 0.05),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
