import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import 'lyrics_view.dart';
import 'queue_bottom_sheet.dart';

/// Cinematic Audio Workstation Bottom Playback Console adhering to Stitch design system:
/// - Surface: surface-glass (0xCC141414) with Gaussian backdrop blur & #1F1F1F top border
/// - Left: 52x52 thumbnail, Track title + FLAC 320k neon pill badge, Artist credit, Heart Like
/// - Center: Transport controls + Electric Neon Green Glowing Play Button + JetBrains Mono scrubber
/// - Right: Capsule LYRICS button, EQ ON badge, Queue trigger, Volume slider with % telemetry
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
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF08080C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F1F1F), width: 1),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: SizedBox(
            width: 880,
            height: 660,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF1F1F1F), width: 0.8),
      ),
      builder: (ctx) => const SizedBox(
        height: 520,
        child: QueueBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xEB141518),
            border: const Border(
              top: BorderSide(
                color: Color(0xFF1F1F23),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ==========================================
              // 1. Left Section: Track Info & Studio Badges
              // ==========================================
              SizedBox(
                width: 240,
                child: Row(
                  children: [
                    // Concentric Double-Bezel Album Art
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
                        child: Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F23),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF292A2D),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7), // Concentric: 10 - 3 = 7
                            child: currentTrack.coverUrl != null &&
                                    currentTrack.coverUrl!.isNotEmpty
                                ? Image.network(
                                    currentTrack.coverUrl!,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildFallbackArt(),
                                  )
                                : _buildFallbackArt(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title, Format Badge, and Artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currentTrack.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFFFFF),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F1F23),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF4EDEA3).withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'FLAC 320k',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4EDEA3),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentTrack.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFBBCABF),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Like Button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        iconSize: 20,
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked ? const Color(0xFF4EDEA3) : const Color(0xFF86948A),
                        ),
                        onPressed: () {
                          final libraryRepo = ref.read(libraryRepositoryProvider);
                          libraryRepo.setLiked(currentTrack.id, !isLiked, track: currentTrack);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 2. Center Section: Playback Controls & Scrubber
              // ==========================================
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Transport Controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Shuffle
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            iconSize: 19,
                            splashRadius: 16,
                            visualDensity: VisualDensity.compact,
                            tooltip: isShuffle ? 'Disable Shuffle' : 'Enable Shuffle',
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: isShuffle
                                  ? const Color(0xFF4EDEA3)
                                  : const Color(0xFF86948A),
                            ),
                            onPressed: () {
                              audioHandler.setShuffleEnabled(!isShuffle);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Skip Previous
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            iconSize: 22,
                            splashRadius: 16,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Previous Track',
                            icon: const Icon(
                              Icons.skip_previous_rounded,
                              color: Color(0xFFBBCABF),
                            ),
                            onPressed: () => audioHandler.skipToPrevious(),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Glowing Primary Play / Pause Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              if (isPlaying) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4EDEA3),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4EDEA3).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: const Color(0xFF003914),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Skip Next
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            iconSize: 22,
                            splashRadius: 16,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Next Track',
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: Color(0xFFBBCABF),
                            ),
                            onPressed: () => audioHandler.skipToNext(),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Repeat Mode Toggle
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            iconSize: 19,
                            splashRadius: 16,
                            visualDensity: VisualDensity.compact,
                            tooltip: repeatMode.label,
                            icon: Icon(
                              repeatMode == AudioRepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: repeatMode != AudioRepeatMode.off
                                  ? const Color(0xFF4EDEA3)
                                  : const Color(0xFF86948A),
                            ),
                            onPressed: () {
                              audioHandler.setAudioRepeatMode(repeatMode.next());
                            },
                          ),
                        ),
                      ],
                    ),

                    // Scrubber Progress Bar with Tabular Monospace Timestamps
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 38,
                            child: Text(
                              _formatDuration(
                                Duration(seconds: currentSec.toInt()),
                              ),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF86948A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2.5,
                                activeTrackColor: const Color(0xFF4EDEA3),
                                inactiveTrackColor: const Color(0xFF292A2D),
                                thumbColor: const Color(0xFFFFFFFF),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 4.5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 8,
                                ),
                                overlayColor:
                                    const Color(0xFF4EDEA3).withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: currentSec,
                                min: 0.0,
                                max: durationSec,
                                onChanged: (val) {
                                  setState(() {
                                    _dragPositionSeconds = val;
                                  });
                                },
                                onChangeEnd: (val) {
                                  audioHandler.seek(
                                    Duration(seconds: val.toInt()),
                                  );
                                  setState(() {
                                    _dragPositionSeconds = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 38,
                            child: Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF86948A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 3. Right Section: Lyrics, Queue, Speed, Volume
              // ==========================================
              SizedBox(
                width: 240,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Synced Lyrics Button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        iconSize: 19,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Lyrics',
                        icon: const Icon(
                          Icons.lyrics_rounded,
                          color: Color(0xFF4EDEA3),
                        ),
                        onPressed: () => _openLyricsDialog(context, currentTrack),
                      ),
                    ),

                    // Queue Button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        iconSize: 19,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Queue',
                        icon: const Icon(
                          Icons.queue_music_rounded,
                          color: Color(0xFFBBCABF),
                        ),
                        onPressed: () => _openQueueModal(context),
                      ),
                    ),

                    if (currentTrack.supportsSpeedPlayback) ...[
                      const SizedBox(width: 2),

                      // Playback Speed Button (YouTube & Podcasts only)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          onTap: () {
                            const speeds = [1.0, 1.5, 2.0, 2.5, 3.0];
                            int nextIdx = 0;
                            for (int i = 0; i < speeds.length; i++) {
                              if ((speed - speeds[i]).abs() < 0.05) {
                                nextIdx = (i + 1) % speeds.length;
                                break;
                              }
                            }
                            audioHandler.setSpeed(speeds[nextIdx]);
                          },
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: speed > 1.05
                                  ? const Color(0xFF4EDEA3).withValues(alpha: 0.15)
                                  : const Color(0xFF1F1F23),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: speed > 1.05
                                    ? const Color(0xFF4EDEA3).withValues(alpha: 0.4)
                                    : const Color(0xFF2E3035),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              speed == 1.0
                                  ? '1x'
                                  : (speed == 2.0
                                      ? '2x'
                                      : (speed == 3.0 ? '3x' : '${speed}x')),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: speed > 1.05
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: speed > 1.05
                                    ? const Color(0xFF4EDEA3)
                                    : const Color(0xFFBBCABF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 4),

                    // Volume Mute / Unmute Toggle Icon
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        iconSize: 19,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        tooltip: volume > 0 ? 'Mute' : 'Unmute',
                        icon: Icon(
                          volume == 0
                              ? Icons.volume_off_rounded
                              : (volume < 0.5
                                  ? Icons.volume_down_rounded
                                  : Icons.volume_up_rounded),
                          color: const Color(0xFFBBCABF),
                        ),
                        onPressed: () {
                          if (volume > 0) {
                            _lastVolumeBeforeMute = volume;
                            audioHandler.setVolume(0.0);
                          } else {
                            audioHandler.setVolume(
                              _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 0.7,
                            );
                          }
                        },
                      ),
                    ),

                    // Sleek Volume Slider
                    SizedBox(
                      width: 65,
                      child: SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 2.5,
                          activeTrackColor: Color(0xFFBBCABF),
                          inactiveTrackColor: Color(0xFF292A2D),
                          thumbColor: Color(0xFFFFFFFF),
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 3.5,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: volume.clamp(0.0, 1.0),
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) {
                            audioHandler.setVolume(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF18191D),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Color(0xFF86948A),
          size: 20,
        ),
      ),
    );
  }
}
