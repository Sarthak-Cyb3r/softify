import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import '../theme/app_theme.dart';
import 'animated_music_wave_indicator.dart';
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
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          decoration: BoxDecoration(
            color: const Color(0xFF242424), // Spotify MiniPlayer surface
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      // Artwork 40x40 with 4px radius
                      AppNetworkImage(
                        imageUrl: effectiveTrack.coverUrl,
                        width: 40,
                        height: 40,
                        borderRadius: BorderRadius.circular(4),
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.music_note_rounded,
                        backgroundColor: tokens.surfaceElevated,
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
                                if (isPlaying) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(right: 5),
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
                                    effectiveTrack.title,
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
                            const SizedBox(height: 1),
                            Text(
                              effectiveTrack.artist,
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

                      // Devices Action (Spotify signature)
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        icon: const Icon(
                          Icons.devices_rounded,
                          color: Color(0xFFB3B3B3),
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _openFullPlayer(context);
                        },
                      ),

                      // Like Action
                      IconButton(
                        iconSize: 21,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        icon: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked ? tokens.accent : const Color(0xFFB3B3B3),
                          size: 21,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(libraryRepositoryProvider)
                              .setLiked(effectiveTrack.id, !isLiked, track: effectiveTrack);
                        },
                      ),

                      // Borderless Play / Pause Icon Button (Spotify authentic)
                      IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 28,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
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
                    ],
                  ),
                ),

                // 2px Hairline Progress Bar
                Container(
                  height: 2.0,
                  color: const Color(0x26FFFFFF),
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


}
