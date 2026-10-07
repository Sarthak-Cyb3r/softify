import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/full_screen_player_screen.dart';
import 'lyrics_view.dart';
import 'queue_bottom_sheet.dart';

/// Full-width Linux desktop bottom playback bar adhering to ui-ux-pro-max guidelines:
/// - Surface color: #1B1B30
/// - Border: #27273B top border
/// - Accent/CTA: #22C55E (Emerald)
/// - Left: 54x54 Album art thumbnail + Track Title + Artist + Heart Like button
/// - Center: Playback controls + Scrubber slider with current/total timestamps
/// - Right: Synced Lyrics trigger + Queue trigger + Volume slider with mute toggle
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
          backgroundColor: const Color(0xFF0F0F23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF312E81), width: 1),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: SizedBox(
            width: 580,
            height: 640,
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
      backgroundColor: const Color(0xFF1B1B30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF312E81), width: 0.8),
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
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B30),
        border: Border(
          top: BorderSide(
            color: Color(0xFF27273B),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ==========================================
          // 1. Left Section: Track Info & Heart
          // ==========================================
          SizedBox(
            width: 220,
            child: Row(
              children: [
                // Album Art
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: currentTrack.coverUrl != null &&
                              currentTrack.coverUrl!.isNotEmpty
                          ? Image.network(
                              currentTrack.coverUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackArt(),
                            )
                          : _buildFallbackArt(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Title and Artist
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentTrack.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Like Button
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    iconSize: 19,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
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
                // Top Button Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        iconSize: 18,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        tooltip: isShuffle ? 'Disable Shuffle' : 'Enable Shuffle',
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: isShuffle
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
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
                        splashRadius: 18,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Previous Track (Ctrl + Left)',
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Color(0xFFF8FAFC),
                        ),
                        onPressed: () => audioHandler.skipToPrevious(),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Play / Pause Emerald Button
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
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: const Color(0xFF0F172A),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Skip Next
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        iconSize: 22,
                        splashRadius: 18,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Next Track (Ctrl + Right)',
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Color(0xFFF8FAFC),
                        ),
                        onPressed: () => audioHandler.skipToNext(),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Repeat Mode Toggle
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        iconSize: 18,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Repeat: ${repeatMode.name.toUpperCase()}',
                        icon: Icon(
                          repeatMode == AudioRepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: repeatMode != AudioRepeatMode.off
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          final nextMode = switch (repeatMode) {
                            AudioRepeatMode.off => AudioRepeatMode.all,
                            AudioRepeatMode.all => AudioRepeatMode.one,
                            AudioRepeatMode.one => AudioRepeatMode.off,
                          };
                          audioHandler.setAudioRepeatMode(nextMode);
                        },
                      ),
                    ),
                  ],
                ),

                // Scrubber Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(
                          Duration(seconds: currentSec.toInt()),
                        ),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3.5,
                            activeTrackColor: const Color(0xFF22C55E),
                            inactiveTrackColor: const Color(0xFF27273B),
                            thumbColor: const Color(0xFFF8FAFC),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5.5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                            overlayColor:
                                const Color(0xFF22C55E).withValues(alpha: 0.2),
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
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // 3. Right Section: Lyrics, Queue, Volume
          // ==========================================
          SizedBox(
            width: 220,
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
                      color: Color(0xFF94A3B8),
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
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () => _openQueueModal(context),
                  ),
                ),

                const SizedBox(width: 2),

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
                      color: const Color(0xFF94A3B8),
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
                  width: 75,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3.0,
                      activeTrackColor: const Color(0xFF22C55E),
                      inactiveTrackColor: const Color(0xFF27273B),
                      thumbColor: const Color(0xFFF8FAFC),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4.5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 8,
                      ),
                      overlayColor:
                          const Color(0xFF22C55E).withValues(alpha: 0.15),
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
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF27273B),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Color(0xFF94A3B8),
          size: 26,
        ),
      ),
    );
  }
}
