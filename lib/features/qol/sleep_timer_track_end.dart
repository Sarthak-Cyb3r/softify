import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player/softify_audio_handler.dart';
import '../../domain/entities/track.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Riverpod StateNotifierProvider tracking whether "Stop after current track"
/// sleep timer is currently active.
final endOfTrackSleepTimerProvider =
    StateNotifierProvider<EndOfTrackSleepController, bool>((ref) {
  final controller = EndOfTrackSleepController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Computes the exact remaining duration until the currently playing track
/// finishes if the "Stop after current track" sleep timer is active.
final endOfTrackRemainingProvider = Provider<Duration?>((ref) {
  final isActive = ref.watch(endOfTrackSleepTimerProvider);
  if (!isActive) return null;

  final currentTrack = ref.watch(currentTrackProvider).value;
  final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
  final duration = ref.watch(durationStreamProvider).value ?? currentTrack?.duration;

  if (duration == null || duration <= Duration.zero) return null;
  final remaining = duration - position;
  return remaining > Duration.zero ? remaining : Duration.zero;
});

// ============================================================================
// Controller / Handler
// ============================================================================

/// Controller managing the "Stop After Current Track" sleep timer functionality.
///
/// Listens to track stream events and native audio handler sleep state to
/// automatically pause audio playback when the song that was active during arming
/// completes or changes.
class EndOfTrackSleepController extends StateNotifier<bool> {
  final Ref? _ref;
  final SoftifyAudioHandler? _customHandler;

  StreamSubscription<Track?>? _trackSub;
  StreamSubscription<bool>? _sleepEndOfTrackSub;
  String? _armedTrackId;

  EndOfTrackSleepController([this._ref, this._customHandler]) : super(false) {
    _init();
  }

  /// The track ID that was playing when this sleep timer was armed.
  String? get armedTrackId => _armedTrackId;

  SoftifyAudioHandler? get _handler {
    if (_customHandler != null) return _customHandler;
    if (_ref != null) {
      try {
        return _ref.read(audioHandlerProvider);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _init() {
    final handler = _handler;
    if (handler != null) {
      // Synchronize with existing handler state if already armed
      if (handler.isSleepTimerEndOfTrack) {
        state = true;
        _armedTrackId = handler.currentTrack?.id;
      }

      // Listen to audio handler end-of-track sleep stream for external updates
      _sleepEndOfTrackSub = handler.sleepEndOfTrackStream.listen((isActive) {
        if (state != isActive) {
          state = isActive;
          if (isActive) {
            _armedTrackId = _armedTrackId ?? handler.currentTrack?.id;
          } else {
            _armedTrackId = null;
          }
        }
      });

      // Listen to track changes to detect when current song finishes
      _trackSub = handler.currentTrackStream.listen(_onTrackChanged);
    }
  }

  /// Handles incoming track stream updates.
  void _onTrackChanged(Track? track) async {
    if (!state) return;

    // If timer was armed while no track was loaded, latch onto first played track
    if (_armedTrackId == null) {
      if (track != null) {
        _armedTrackId = track.id;
      }
      return;
    }

    // When the playing track changes or ends, trigger pause and reset timer
    if (track == null || track.id != _armedTrackId) {
      await _triggerStopAfterCurrentTrack();
    }
  }

  /// Triggers playback pause upon current track completion.
  Future<void> _triggerStopAfterCurrentTrack() async {
    _armedTrackId = null;
    state = false;

    final handler = _handler;
    if (handler != null) {
      handler.cancelSleepTimer();
      await handler.pause();
    }
  }

  /// Enables the "Stop after current track" sleep timer.
  void enable() {
    final handler = _handler;
    _armedTrackId = handler?.currentTrack?.id;
    state = true;
    handler?.setSleepTimerEndOfTrack();
  }

  /// Disables the "Stop after current track" sleep timer.
  void disable() {
    _armedTrackId = null;
    state = false;
    _handler?.cancelSleepTimer();
  }

  /// Toggles the timer on or off.
  void toggle() {
    if (state) {
      disable();
    } else {
      enable();
    }
  }

  /// Explicitly sets the active state.
  void setEnabled(bool enabled) {
    if (enabled) {
      enable();
    } else {
      disable();
    }
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _sleepEndOfTrackSub?.cancel();
    super.dispose();
  }
}

// ============================================================================
// UI Component
// ============================================================================

/// A sleek tile widget with switch and dynamic countdown label to toggle
/// "Stop after current track".
///
/// Designed for drop-in use inside sleep timer dialogs, modal sheets,
/// or settings menus.
class EndOfTrackSleepTile extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final String title;
  final String? subtitle;
  final Color? activeColor;
  final bool showIcon;
  final IconData icon;
  final bool showBorder;
  final VoidCallback? onToggled;

  const EndOfTrackSleepTile({
    super.key,
    this.margin,
    this.padding,
    this.title = 'Stop after current track',
    this.subtitle,
    this.activeColor,
    this.showIcon = true,
    this.icon = Icons.music_note_rounded,
    this.showBorder = true,
    this.onToggled,
  });

  String _formatCountdown(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) return '0s';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes >= 60) {
      final hours = duration.inHours;
      final remMins = minutes % 60;
      return '${hours}h ${remMins}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isEnabled = ref.watch(endOfTrackSleepTimerProvider);
    final remaining = ref.watch(endOfTrackRemainingProvider);
    final accentColor = activeColor ?? tokens.accent;

    // Generate informative subtitle / countdown label
    final String statusLabel;
    if (subtitle != null) {
      statusLabel = subtitle!;
    } else if (isEnabled) {
      if (remaining != null && remaining > Duration.zero) {
        statusLabel = 'Active • ${_formatCountdown(remaining)} remaining';
      } else {
        statusLabel = 'Active • Stops at end of song';
      }
    } else {
      statusLabel = 'Pauses music when current song finishes';
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isEnabled
            ? accentColor.withValues(alpha: 0.08)
            : tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: showBorder
            ? Border.all(
                color: isEnabled
                    ? accentColor.withValues(alpha: 0.35)
                    : tokens.divider.withValues(alpha: 0.5),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(endOfTrackSleepTimerProvider.notifier).toggle();
            onToggled?.call();
          },
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (showIcon) ...[
                  AnimatedContainer(
                    duration: tokens.motionStandard,
                    curve: tokens.curveDecel,
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? accentColor.withValues(alpha: 0.2)
                          : tokens.cardHover,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Icon(
                      icon,
                      color: isEnabled ? accentColor : tokens.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          statusLabel,
                          key: ValueKey(statusLabel),
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            fontWeight: isEnabled ? FontWeight.w500 : FontWeight.w400,
                            color: isEnabled ? accentColor : tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: isEnabled,
                  activeColor: accentColor,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    ref.read(endOfTrackSleepTimerProvider.notifier).setEnabled(value);
                    onToggled?.call();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
