import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';

/// Preset playback speed options supported by Softify.
const List<double> kPlaybackSpeedPresets = [
  0.5,
  0.75,
  0.9,
  1.0,
  1.1,
  1.25,
  1.5,
  2.0,
];

/// Helper formatting speed double into clean string representation (e.g. 1.0x, 1.25x).
String formatPlaybackSpeed(double speed) {
  if (speed == speed.roundToDouble()) {
    return '${speed.toStringAsFixed(1)}x';
  } else if ((speed * 10).roundToDouble() == speed * 10) {
    return '${speed.toStringAsFixed(1)}x';
  } else {
    return '${speed.toStringAsFixed(2)}x';
  }
}

/// State provider for pitch preservation toggle.
/// In Softify's audio pipeline, time-stretching DSP (Sonic/ExoPlayer/AudioEngine)
/// preserves musical pitch naturally while altering playback speed.
final pitchPreservationProvider = StateProvider<bool>((ref) => true);

/// Notifier managing current playback speed and keeping in sync with the audio player engine.
class PlaybackSpeedNotifier extends StateNotifier<double> {
  final Ref _ref;
  StreamSubscription<double>? _speedSub;

  PlaybackSpeedNotifier(this._ref) : super(1.0) {
    _init();
  }

  void _init() {
    try {
      final handler = _ref.read(audioHandlerProvider);
      state = handler.speed;
      _speedSub = handler.speedStream.listen((speed) {
        if (mounted && (state - speed).abs() > 0.001) {
          state = speed;
        }
      });
    } catch (_) {
      // audioHandlerProvider may be uninitialized in isolated widget tests
    }

    try {
      _ref.listen<AsyncValue<double>>(playbackSpeedStreamProvider, (prev, next) {
        next.whenData((speed) {
          if (mounted && (state - speed).abs() > 0.001) {
            state = speed;
          }
        });
      });
    } catch (_) {}
  }

  /// Sets playback speed on the underlying audio engine and updates local state.
  Future<void> setSpeed(double speed) async {
    final clamped = double.parse(speed.clamp(0.25, 4.0).toStringAsFixed(2));
    state = clamped;
    try {
      final handler = _ref.read(audioHandlerProvider);
      await handler.setSpeed(clamped);
    } catch (_) {
      // Handled gracefully
    }
  }

  /// Resets playback speed to the normal 1.0x tempo.
  Future<void> reset() async {
    await setSpeed(1.0);
  }

  @override
  void dispose() {
    _speedSub?.cancel();
    super.dispose();
  }
}

/// Riverpod provider exposing current playback speed.
final playbackSpeedProvider =
    StateNotifierProvider<PlaybackSpeedNotifier, double>((ref) {
  return PlaybackSpeedNotifier(ref);
});

/// Modal bottom sheet allowing users to select playback speed via preset chip buttons
/// and fine-tuning slider, with pitch preservation controls.
class PlaybackSpeedSelectorSheet extends ConsumerWidget {
  const PlaybackSpeedSelectorSheet({super.key});

  /// Displays the [PlaybackSpeedSelectorSheet] bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const PlaybackSpeedSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSpeed = ref.watch(playbackSpeedProvider);
    final isPitchPreserved = ref.watch(pitchPreservationProvider);
    final isNormal = (currentSpeed - 1.0).abs() < 0.001;
    final tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: tokens.divider.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.speed_rounded,
                        color: tokens.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Playback Speed',
                            style: TextStyle(
                              fontFamily: AppTheme.fontPageTitle,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Adjust tempo with natural pitch correction',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12,
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isNormal)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(playbackSpeedProvider.notifier).reset();
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Reset'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: tokens.textSecondary,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                // 3. Current Speed Readout Banner
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isNormal
                          ? tokens.divider.withValues(alpha: 0.15)
                          : tokens.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatPlaybackSpeed(currentSpeed),
                        style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: isNormal ? tokens.textPrimary : tokens.accent,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isNormal
                            ? 'Normal Speed (1.0x)'
                            : currentSpeed > 1.0
                                ? '${((currentSpeed - 1.0) * 100).round()}% Faster'
                                : '${((1.0 - currentSpeed) * 100).round()}% Slower',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isNormal ? tokens.textSecondary : tokens.accent,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Chip Presets
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'SPEED PRESETS',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPlaybackSpeedPresets.map((preset) {
                    final isSelected = (currentSpeed - preset).abs() < 0.001;
                    return BouncingScaleButton(
                      scaleFactor: 0.94,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(playbackSpeedProvider.notifier).setSpeed(preset);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.accent
                              : tokens.surfaceHighlight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? tokens.accent
                                : tokens.divider.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          preset == 1.0
                              ? '1.0x Normal'
                              : formatPlaybackSpeed(preset),
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color:
                                isSelected ? Colors.white : tokens.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // 5. Fine-Tuning Slider
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'FINE-TUNE TEMPO',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.slow_motion_video_rounded,
                      size: 20,
                      color: tokens.textSecondary,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: tokens.accent,
                          inactiveTrackColor: tokens.surfaceHighlight,
                          thumbColor: tokens.accent,
                          overlayColor: tokens.accent.withValues(alpha: 0.2),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                        ),
                        child: Slider(
                          value: currentSpeed.clamp(0.5, 2.0),
                          min: 0.5,
                          max: 2.0,
                          divisions: 30, // 0.05 step
                          onChanged: (val) {
                            final rounded = (val * 100).round() / 100.0;
                            ref
                                .read(playbackSpeedProvider.notifier)
                                .setSpeed(rounded);
                          },
                        ),
                      ),
                    ),
                    Icon(
                      Icons.fast_forward_rounded,
                      size: 20,
                      color: tokens.textSecondary,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0.5x',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                      Text(
                        '1.0x (Normal)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                      Text(
                        '2.0x',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // 6. Pitch Preservation Card
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tokens.divider.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: tokens.accentCyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: tokens.accentCyan,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pitch Preservation',
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Preserves natural vocals and musical pitch',
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isPitchPreserved,
                        activeColor: tokens.accent,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          ref.read(pitchPreservationProvider.notifier).state = val;
                        },
                      ),
                    ],
                  ),
                ),

                // 7. Done Button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

/// Quick badge button widget for the player bar showing the current playback speed.
/// Automatically hidden when speed is 1.0x, visible when speed != 1.0x.
/// Tapping opens [PlaybackSpeedSelectorSheet]. Long pressing resets speed to 1.0x.
class PlaybackSpeedBadge extends ConsumerWidget {
  /// Whether to force the badge to be visible even at normal 1.0x speed. Defaults to false.
  final bool alwaysVisible;

  /// Optional custom callback when the badge is tapped. Defaults to opening [PlaybackSpeedSelectorSheet].
  final VoidCallback? onTap;

  /// Optional custom padding.
  final EdgeInsetsGeometry? padding;

  /// Compact rendering mode for narrow player bars.
  final bool compact;

  const PlaybackSpeedBadge({
    super.key,
    this.alwaysVisible = false,
    this.onTap,
    this.padding,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playbackSpeedProvider);
    final isNormal = (speed - 1.0).abs() < 0.001;

    // Hidden if 1.0x, visible if != 1.0x (unless alwaysVisible is requested)
    if (isNormal && !alwaysVisible) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final formattedSpeed = formatPlaybackSpeed(speed);

    return BouncingScaleButton(
      scaleFactor: 0.92,
      onTap: onTap ?? () => PlaybackSpeedSelectorSheet.show(context),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        ref.read(playbackSpeedProvider.notifier).reset();
      },
      child: Tooltip(
        message: 'Playback Speed: $formattedSpeed (Tap to change, hold to reset)',
        child: Container(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 2 : 4,
              ),
          decoration: BoxDecoration(
            color: isNormal
                ? tokens.surfaceHighlight
                : tokens.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: Border.all(
              color: isNormal
                  ? tokens.divider.withValues(alpha: 0.2)
                  : tokens.accent.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.speed_rounded,
                size: compact ? 12 : 13,
                color: isNormal ? tokens.textSecondary : tokens.accent,
              ),
              const SizedBox(width: 4),
              Text(
                formattedSpeed,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: isNormal ? tokens.textSecondary : tokens.accent,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
