import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import '../theme/app_theme.dart';
import 'lyrics_view.dart';
import 'queue_bottom_sheet.dart';
import 'shared/app_slider.dart';
import 'shared/app_network_image.dart';

/// Desktop Bottom Player Bar adhering to Content-First Spotify-inspired design:
/// - Background: Chrome #000000
/// - Transport: Center controls with vibrant #2EE66B green circular play toggle
/// - Scrubber: Tabular Manrope timestamps (12px min) and #2EE66B progress slider
/// - Zero audio quality labels, zero monospace fonts, zero glowing outlines
class DesktopPlayerBar extends ConsumerStatefulWidget {
  const DesktopPlayerBar({super.key});

  @override
  ConsumerState<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends ConsumerState<DesktopPlayerBar> {
  double? _dragPositionSeconds;
  double _lastVolumeBeforeMute = 1.0;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _openLyricsDialog(BuildContext context, Track track) {
    final tokens = context.tokens;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: tokens.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusCard),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: SizedBox(
            width: 880,
            height: 660,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              child: LyricsView(
                track: track,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openQueueModal(BuildContext context) {
    final tokens = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusCard * 2),
        ),
      ),
      builder: (ctx) => const SizedBox(
        height: 520,
        child: QueueBottomSheet(),
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
    final repeatMode =
        ref.watch(repeatModeStreamProvider).value ?? AudioRepeatMode.off;
    final isShuffle = ref.watch(shuffleModeStreamProvider).value ?? false;
    final volume = ref.watch(volumeStreamProvider).value ?? 1.0;
    final audioHandler = ref.watch(audioHandlerProvider);
    final speed =
        ref.watch(playbackSpeedStreamProvider).value ?? audioHandler.speed;

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = playbackState?.playing ?? false;
    final isLikedAsync = ref.watch(isTrackLikedProvider(currentTrack.id));
    final isLiked = isLikedAsync.value ?? currentTrack.isLiked;

    final durationSec = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final currentSec = (_dragPositionSeconds ?? position.inSeconds.toDouble())
        .clamp(0.0, durationSec);

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: tokens.sidebar, // Pure #000000 (Chrome surface 0)
      child: Row(
        children: [
          // ==========================================
          // 1. Left Section: Track Info & Artwork
          // ==========================================
          SizedBox(
            width: 250,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FullScreenPlayerScreen(),
                      ),
                    );
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AppNetworkImage(
                      imageUrl: currentTrack.coverUrl,
                      width: 52,
                      height: 52,
                      borderRadius: BorderRadius.circular(6),
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.music_note_rounded,
                      backgroundColor: tokens.card,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        currentTrack.artist,
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
                IconButton(
                  iconSize: 20,
                  tooltip: isLiked ? 'Unlike' : 'Like',
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? tokens.accent : tokens.textSecondary,
                  ),
                  onPressed: () {
                    ref
                        .read(libraryRepositoryProvider)
                        .setLiked(currentTrack.id, !isLiked, track: currentTrack);
                  },
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. Center Section: Playback Controls & Slider
          // ==========================================
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Transport Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shuffle Toggle
                    IconButton(
                      iconSize: 18,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Shuffle',
                      icon: Icon(
                        isShuffle ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                        color: isShuffle ? tokens.accent : tokens.textSecondary,
                      ),
                      onPressed: () {
                        audioHandler.setShuffleEnabled(!isShuffle);
                      },
                    ),
                    const SizedBox(width: 4),

                    // Previous Button
                    IconButton(
                      iconSize: 22,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Previous',
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: AppTheme.textPrimary,
                      ),
                      onPressed: () => audioHandler.skipToPrevious(),
                    ),
                    const SizedBox(width: 6),

                    // Play / Pause Circle (Vibrant #2EE66B)
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
                        tooltip: isPlaying ? 'Pause' : 'Play',
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Next Button
                    IconButton(
                      iconSize: 22,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Next',
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: AppTheme.textPrimary,
                      ),
                      onPressed: () => audioHandler.skipToNext(),
                    ),
                    const SizedBox(width: 4),

                    // Repeat Button
                    IconButton(
                      iconSize: 18,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Repeat',
                      icon: Icon(
                        repeatMode == AudioRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: repeatMode != AudioRepeatMode.off
                            ? tokens.accent
                            : tokens.textSecondary,
                      ),
                      onPressed: () {
                        audioHandler.setAudioRepeatMode(repeatMode.next());
                      },
                    ),
                  ],
                ),

                // Scrubber Track Row
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Row(
                    children: [
                      // Elapsed Time (tabular numerals, 12px min)
                      Text(
                        _formatDuration(Duration(seconds: currentSec.toInt())),
                        style: AppTheme.tabularTimestamp(
                          fontSize: 12,
                          color: tokens.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Scrubber Slider
                      Expanded(
                        child: AppSlider(
                          value: currentSec,
                          min: 0.0,
                          max: durationSec,
                          trackHeight: 3.5,
                          activeColor: tokens.accent,
                          inactiveColor: tokens.cardHover,
                          onChangeStart: (val) {
                            setState(() => _dragPositionSeconds = val);
                          },
                          onChanged: (val) {
                            setState(() => _dragPositionSeconds = val);
                          },
                          onChangeEnd: (val) {
                            audioHandler.seek(Duration(seconds: val.toInt()));
                            setState(() => _dragPositionSeconds = null);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Duration Time (tabular numerals, 12px min)
                      Text(
                        _formatDuration(duration),
                        style: AppTheme.tabularTimestamp(
                          fontSize: 12,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // 3. Right Section: Speed, Lyrics, Queue, Volume
          // ==========================================
          SizedBox(
            width: 250,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Playback Speed Toggle (visible only if supported)
                if (currentTrack.supportsSpeedPlayback)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: const Size(36, 28),
                    ),
                    onPressed: () {
                      final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
                      final next = speeds[(speeds.indexOf(speed) + 1) % speeds.length];
                      audioHandler.setSpeed(next);
                    },
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12, // Strict 12px floor
                        fontWeight: FontWeight.w700,
                        color: speed != 1.0 ? tokens.accent : tokens.textSecondary,
                      ),
                    ),
                  ),

                // Lyrics Modal Launcher
                IconButton(
                  iconSize: 20,
                  tooltip: 'Lyrics',
                  icon: const Icon(
                    Icons.lyrics_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => _openLyricsDialog(context, currentTrack),
                ),

                // Queue Sheet Launcher
                IconButton(
                  iconSize: 20,
                  tooltip: 'Queue',
                  icon: const Icon(
                    Icons.queue_music_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => _openQueueModal(context),
                ),

                // Volume Icon & Slider
                IconButton(
                  iconSize: 20,
                  tooltip: volume == 0.0 ? 'Unmute' : 'Mute',
                  icon: Icon(
                    volume == 0.0
                        ? Icons.volume_off_rounded
                        : volume < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    color: tokens.textSecondary,
                  ),
                  onPressed: () {
                    if (volume > 0.0) {
                      _lastVolumeBeforeMute = volume;
                      audioHandler.setVolume(0.0);
                    } else {
                      audioHandler.setVolume(_lastVolumeBeforeMute);
                    }
                  },
                ),
                SizedBox(
                  width: 90,
                  child: AppSlider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    trackHeight: 3.5,
                    activeColor: tokens.accent,
                    inactiveColor: tokens.cardHover,
                    onChanged: (val) => audioHandler.setVolume(val),
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
