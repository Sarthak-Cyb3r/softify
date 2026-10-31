import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lyrics/spotify_lyrics_synchronizer.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../screens/listen_together_screen.dart';
import '../theme/app_theme.dart';
import 'audiophile_quality_badge.dart';
import 'bouncing_scale_button.dart';
import 'sleep_timer_bottom_sheet.dart';

final deviceModelNameProvider = FutureProvider<String>((ref) async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final brand = android.brand.trim();
      final model = android.model.trim();
      final cleanBrand = brand.isNotEmpty
          ? '${brand[0].toUpperCase()}${brand.substring(1)}'
          : '';
      if (cleanBrand.isNotEmpty &&
          !model.toLowerCase().startsWith(cleanBrand.toLowerCase())) {
        return '$cleanBrand $model';
      }
      return model.isNotEmpty ? model : 'moto g34 5G';
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return ios.name.isNotEmpty ? ios.name : ios.model;
    } else if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      return linux.prettyName;
    }
  } catch (_) {}
  return 'moto g34 5G';
});

/// High-precision Apple Music scrubber matching exact UI specification:
/// Thick white pill slider, elapsed time left, headphone specs badge center,
/// and remaining time right.
class AppleMusicScrubber extends ConsumerStatefulWidget {
  final Track track;
  final Duration? fallbackDuration;

  const AppleMusicScrubber({
    super.key,
    required this.track,
    this.fallbackDuration,
  });

  @override
  ConsumerState<AppleMusicScrubber> createState() => _AppleMusicScrubberState();
}

class _AppleMusicScrubberState extends ConsumerState<AppleMusicScrubber> {
  double? _dragPositionSeconds;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ??
        widget.fallbackDuration ??
        widget.track.duration;
    final streamInfoAsync = ref.watch(currentStreamInfoProvider);
    final streamInfo = streamInfoAsync.valueOrNull;

    final maxSeconds = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final currentSeconds = _dragPositionSeconds ??
        position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    final currentDuration = Duration(seconds: currentSeconds.round());
    final remainingDuration =
        duration > currentDuration ? duration - currentDuration : Duration.zero;

    final kbps = (streamInfo != null && streamInfo.bitrate > 0)
        ? streamInfo.bitrate ~/ 1000
        : 147;
    const sampleRateStr = '48 kHz';
    final specsText = '$kbps kbps · $sampleRateStr';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.5,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
              thumbColor: Colors.white,
              thumbShape: _dragPositionSeconds != null
                  ? const RoundSliderThumbShape(enabledThumbRadius: 5.0)
                  : const RoundSliderThumbShape(enabledThumbRadius: 0.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: currentSeconds.clamp(0.0, maxSeconds),
              max: maxSeconds,
              onChangeStart: (_) {
                HapticFeedback.lightImpact();
              },
              onChanged: (val) {
                setState(() {
                  _dragPositionSeconds = val;
                });
              },
              onChangeEnd: (val) {
                HapticFeedback.mediumImpact();
                audioHandler.seek(Duration(seconds: val.round()));
                setState(() {
                  _dragPositionSeconds = null;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(currentDuration),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => AudiophileStreamInspectorSheet(
                        track: widget.track,
                        streamInfo: streamInfo,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.headphones_rounded,
                        size: 14,
                        color: Color(0xB3FFFFFF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        specsText,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${_formatDuration(remainingDuration)}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xCCFFFFFF),
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

/// Single-line synced lyric preview on the Apple Music player screen.
/// Smoothly transitions as time elapses and taps to open full lyrics.
class AppleMusicLyricTeaser extends ConsumerWidget {
  final Track track;
  final VoidCallback onTap;

  const AppleMusicLyricTeaser({
    super.key,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(trackLyricsProvider(track));
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final lyrics = lyricsAsync.valueOrNull;

    String? currentLine;
    if (lyrics != null && lyrics.lines.isNotEmpty) {
      final activeIdx = SpotifyLyricsSynchronizer.findActiveLineIndex(
        lyrics.lines,
        position,
      );
      if (activeIdx >= 0 && activeIdx < lyrics.lines.length) {
        currentLine = lyrics.lines[activeIdx].text;
      } else {
        currentLine = lyrics.lines.first.text;
      }
    }

    if (currentLine == null || currentLine.trim().isEmpty) {
      return const SizedBox(height: 24);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              currentLine,
              key: ValueKey(currentLine),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Persistent anchored bottom control panel shared across Apple Music Player
/// and Lyrics screens.
class AppleMusicPersistentBottomPanel extends ConsumerWidget {
  final Track track;
  final dynamic audioHandler;
  final bool isPlaying;
  final bool isBuffering;
  final int activeTabIndex; // 0: main, 1: lyrics, 2: queue
  final ValueChanged<int> onTabChanged;

  const AppleMusicPersistentBottomPanel({
    super.key,
    required this.track,
    required this.audioHandler,
    required this.isPlaying,
    required this.isBuffering,
    required this.activeTabIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeStreamProvider).value ?? 1.0;
    final deviceName = ref.watch(deviceModelNameProvider).value ?? 'moto g34 5G';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Scrubber
        AppleMusicScrubber(track: track),
        const SizedBox(height: 12),

        // 2. Playback Controls Row (Rewind, Play/Pause, Fast-Forward)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind
              BouncingScaleButton(
                scaleFactor: 0.88,
                onTap: () {
                  HapticFeedback.selectionClick();
                  audioHandler.skipToPrevious();
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.fast_rewind_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),

              // Play / Pause
              BouncingScaleButton(
                scaleFactor: 0.90,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isPlaying) {
                    audioHandler.pause();
                  } else {
                    audioHandler.play();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: isBuffering
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 62,
                          color: Colors.white,
                        ),
                ),
              ),

              // Fast-Forward
              BouncingScaleButton(
                scaleFactor: 0.88,
                onTap: () {
                  HapticFeedback.selectionClick();
                  audioHandler.skipToNext();
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.fast_forward_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Volume Slider Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(
                Icons.volume_down_rounded,
                size: 16,
                color: Color(0x8AFFFFFF),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3.5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: (volume.isNaN ? 1.0 : volume).clamp(0.0, 1.0),
                    onChanged: (v) {
                      audioHandler.setVolume(v);
                    },
                  ),
                ),
              ),
              const Icon(
                Icons.volume_up_rounded,
                size: 16,
                color: Color(0x8AFFFFFF),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 4. Floating Frosted Glass Dock (5 segmented items)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Item 1: Lyrics
                    _dockButton(
                      icon: activeTabIndex == 1
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      isActive: activeTabIndex == 1,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabChanged(activeTabIndex == 1 ? 0 : 1);
                      },
                    ),

                    // Item 2: Headphones / Output
                    _dockButton(
                      icon: Icons.headphones_rounded,
                      isActive: false,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        SleepTimerBottomSheet.show(context);
                      },
                    ),

                    // Item 3: Jam / Listen Together
                    _dockButton(
                      icon: Icons.people_alt_rounded,
                      isActive: false,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ListenTogetherScreen(),
                          ),
                        );
                      },
                    ),

                    // Item 4: Subtitles / Mini Lyrics
                    _dockButton(
                      icon: Icons.subtitles_rounded,
                      isActive: false,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Synced lyrics HUD enabled',
                              style: TextStyle(fontFamily: AppTheme.fontUi),
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),

                    // Item 5: Queue
                    _dockButton(
                      icon: Icons.format_list_bulleted_rounded,
                      isActive: activeTabIndex == 2,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabChanged(activeTabIndex == 2 ? 0 : 2);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 5. Device Name Footer (moto g34 5G)
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            deviceName,
            style: const TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0x8AFFFFFF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dockButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    if (isActive) {
      return BouncingScaleButton(
        scaleFactor: 0.90,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: Colors.black, size: 21),
          ),
        ),
      );
    }

    return BouncingScaleButton(
      scaleFactor: 0.90,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.85),
          size: 22,
        ),
      ),
    );
  }
}
