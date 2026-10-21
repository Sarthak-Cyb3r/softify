import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/audio_repeat_mode.dart';
import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import '../theme/app_theme.dart';
import 'animated_music_wave_indicator.dart';
import 'bouncing_scale_button.dart';
import 'play_pause_morph_button.dart';
import 'shared/app_network_image.dart';

/// Ultra-refined, UI/UX PRO MAX mobile pull-down playback controlling panel.
/// Activates when the user swipes down from the top edge on mobile, delivering:
/// - OLED Frosted Glass aesthetics with 24px backdrop blur and emerald hairline border
/// - 48x48 Album cover with subtle vinyl lighting
/// - Live singing lyric ticker capsule with millisecond-synced lyrics
/// - Micro-scrubber with tabular timestamps
/// - Tactile transport controls (Play/Pause emerald glow, Prev, Next, Shuffle, Repeat)
class QuickPlaybackPanel extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;

  const QuickPlaybackPanel({
    super.key,
    required this.onDismiss,
  });

  @override
  ConsumerState<QuickPlaybackPanel> createState() => _QuickPlaybackPanelState();
}

class _QuickPlaybackPanelState extends ConsumerState<QuickPlaybackPanel> {
  double? _dragPositionSeconds;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _openFullPlayer(BuildContext context) {
    widget.onDismiss();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const FullScreenPlayerScreen(),
        transitionsBuilder: (context, anim, secAnim, child) {
          final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          final slide = Tween<Offset>(
            begin: const Offset(0.0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: const Cubic(0.2, 0.0, 0.0, 1.0)));
          return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration =
        ref.watch(durationStreamProvider).value ?? currentTrack?.duration ?? Duration.zero;
    final isShuffle = ref.watch(shuffleModeStreamProvider).value ?? false;
    final repeatMode =
        ref.watch(repeatModeStreamProvider).value ?? AudioRepeatMode.off;
    final audioHandler = ref.watch(audioHandlerProvider);
    final activeLyric = ref.watch(activeLyricStreamProvider).value;

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = playbackState?.playing ?? false;
    final isLikedAsync = ref.watch(isTrackLikedProvider(currentTrack.id));
    final isLiked = isLikedAsync.value ?? currentTrack.isLiked;

    final durationSec = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final currentSec = (_dragPositionSeconds ?? position.inSeconds.toDouble())
        .clamp(0.0, durationSec);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Upward drag closes panel
        if ((details.primaryVelocity ?? 0) < -200) {
          widget.onDismiss();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 18,
                  right: 18,
                  bottom: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF00D0E12),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Drag Indicator Bar
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Row 1: Artwork, Track Metadata, Like & Expand Actions
                    Row(
                      children: [
                        // 48x48 Album Art with subtle vinyl border
                        GestureDetector(
                          onTap: () => _openFullPlayer(context),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.accent.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AppNetworkImage(
                                imageUrl: currentTrack.coverUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title & Artist
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openFullPlayer(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentTrack.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  currentTrack.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Like Button
                        IconButton(
                          iconSize: 20,
                          tooltip: isLiked ? 'Unlike' : 'Like',
                          icon: Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? tokens.accent : Colors.white60,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(libraryRepositoryProvider)
                                .setLiked(currentTrack.id, !isLiked, track: currentTrack);
                          },
                        ),

                        // Close Panel Button
                        IconButton(
                          iconSize: 20,
                          tooltip: 'Close Panel',
                          icon: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white60,
                          ),
                          onPressed: widget.onDismiss,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: Live Singing Lyrics Ticker Capsule
                    GestureDetector(
                      onTap: () => _openFullPlayer(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tokens.accent.withValues(alpha: 0.2),
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedMusicWaveIndicator(
                              isPlaying: isPlaying,
                              size: 13,
                              barCount: 3,
                              color: tokens.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (activeLyric != null && activeLyric.trim().isNotEmpty)
                                    ? activeLyric.trim()
                                    : '♪ Softify Lossless Master Audio',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontUi,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: (activeLyric != null && activeLyric.trim().isNotEmpty)
                                      ? tokens.accent
                                      : Colors.white70,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.lyrics_rounded,
                              size: 14,
                              color: tokens.accent.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Row 3: Scrubber Slider & Timers
                    Row(
                      children: [
                        Text(
                          _formatDuration(Duration(seconds: currentSec.round())),
                          style: AppTheme.tabularTimestamp(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                              activeTrackColor: tokens.accent,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                              overlayColor: tokens.accent.withValues(alpha: 0.2),
                            ),
                            child: Slider(
                              value: currentSec,
                              min: 0.0,
                              max: durationSec,
                              onChanged: (val) {
                                setState(() => _dragPositionSeconds = val);
                              },
                              onChangeEnd: (val) {
                                audioHandler.seek(Duration(seconds: val.round()));
                                setState(() => _dragPositionSeconds = null);
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: AppTheme.tabularTimestamp(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),

                    // Row 4: Transport Controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Shuffle
                          IconButton(
                            iconSize: 19,
                            tooltip: isShuffle ? 'Shuffle On' : 'Shuffle Off',
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: isShuffle ? tokens.accent : Colors.white54,
                            ),
                            onPressed: () => audioHandler.setShuffleEnabled(!isShuffle),
                          ),

                          // Previous
                          BouncingScaleButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              audioHandler.skipToPrevious();
                            },
                            child: const Icon(
                              Icons.skip_previous_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),

                          // Play / Pause Morph Action
                          PlayPauseMorphButton(
                            isPlaying: isPlaying,
                            size: 46,
                            iconSize: 22,
                            backgroundColor: tokens.accent,
                            iconColor: Colors.black,
                            showGlow: true,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (isPlaying) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                          ),

                          // Next
                          BouncingScaleButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              audioHandler.skipToNext();
                            },
                            child: const Icon(
                              Icons.skip_next_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),

                          // Repeat
                          IconButton(
                            iconSize: 19,
                            tooltip: 'Repeat: ${repeatMode.name}',
                            icon: Icon(
                              repeatMode == AudioRepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: repeatMode != AudioRepeatMode.off
                                  ? tokens.accent
                                  : Colors.white54,
                            ),
                            onPressed: () {
                              audioHandler.setAudioRepeatMode(repeatMode.next());
                            },
                          ),

                          // Expand Fullscreen
                          IconButton(
                            iconSize: 19,
                            tooltip: 'Full Screen Player',
                            icon: const Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white54,
                            ),
                            onPressed: () => _openFullPlayer(context),
                          ),
                        ],
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
