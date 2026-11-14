import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player/softify_audio_handler.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

/// Immutable state holding mute status, current volume, and previous non-zero volume.
class QuickMuteState {
  final bool isMuted;
  final double volume;
  final double previousVolume;

  const QuickMuteState({
    this.isMuted = false,
    this.volume = 1.0,
    this.previousVolume = 0.7,
  });

  QuickMuteState copyWith({
    bool? isMuted,
    double? volume,
    double? previousVolume,
  }) {
    return QuickMuteState(
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      previousVolume: previousVolume ?? this.previousVolume,
    );
  }

  /// Dynamic icon corresponding to volume and mute state:
  /// - `Icons.volume_off_rounded` when muted or volume is 0
  /// - `Icons.volume_mute_rounded` for low volume (0 < vol < 0.25)
  /// - `Icons.volume_down_rounded` for moderate volume (0.25 <= vol < 0.65)
  /// - `Icons.volume_up_rounded` for higher volume (vol >= 0.65)
  IconData get dynamicIcon {
    if (isMuted || volume <= 0.0) {
      return Icons.volume_off_rounded;
    } else if (volume < 0.25) {
      return Icons.volume_mute_rounded;
    } else if (volume < 0.65) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickMuteState &&
          runtimeType == other.runtimeType &&
          isMuted == other.isMuted &&
          volume == other.volume &&
          previousVolume == other.previousVolume;

  @override
  int get hashCode => Object.hash(isMuted, volume, previousVolume);

  @override
  String toString() =>
      'QuickMuteState(isMuted: $isMuted, volume: $volume, previousVolume: $previousVolume)';
}

/// StateNotifier that manages quick mute toggling and non-zero volume memory.
class QuickMuteNotifier extends StateNotifier<QuickMuteState> {
  final SoftifyAudioHandler? _audioHandler;
  StreamSubscription<double>? _volumeSubscription;

  QuickMuteNotifier({SoftifyAudioHandler? audioHandler})
      : _audioHandler = audioHandler,
        super(
          QuickMuteState(
            isMuted: (audioHandler?.volume ?? 1.0) <= 0.0,
            volume: audioHandler?.volume ?? 1.0,
            previousVolume:
                (audioHandler?.volume != null && audioHandler!.volume > 0.0)
                    ? audioHandler.volume
                    : 0.7,
          ),
        ) {
    if (_audioHandler != null) {
      _volumeSubscription = _audioHandler.volumeStream.listen(onVolumeChanged);
    }
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    super.dispose();
  }

  /// Reacts to volume updates from external controllers/sliders.
  void onVolumeChanged(double newVolume) {
    final clamped = newVolume.clamp(0.0, 1.0);
    if (clamped <= 0.0) {
      if (!state.isMuted || state.volume != 0.0) {
        state = state.copyWith(
          isMuted: true,
          volume: 0.0,
        );
      }
    } else {
      if (state.isMuted ||
          state.volume != clamped ||
          state.previousVolume != clamped) {
        state = state.copyWith(
          isMuted: false,
          volume: clamped,
          previousVolume: clamped,
        );
      }
    }
  }

  /// Toggles mute state.
  /// When unmuted: saves previous non-zero volume and mutes to 0.0.
  /// When muted: restores previous volume (or defaults to 0.7 if previous was 0).
  Future<void> toggleMute() async {
    if (state.isMuted || state.volume <= 0.0) {
      // Restore previous volume
      final restoreVol =
          state.previousVolume > 0.0 ? state.previousVolume : 0.7;
      state = state.copyWith(
        isMuted: false,
        volume: restoreVol,
        previousVolume: restoreVol,
      );
      try {
        await _audioHandler?.setVolume(restoreVol);
      } catch (e) {
        debugPrint('QuickMuteNotifier: error restoring volume: $e');
      }
    } else {
      // Mute and save current non-zero volume
      final prevVol = state.volume > 0.0
          ? state.volume
          : (state.previousVolume > 0.0 ? state.previousVolume : 0.7);
      state = state.copyWith(
        isMuted: true,
        volume: 0.0,
        previousVolume: prevVol,
      );
      try {
        await _audioHandler?.setVolume(0.0);
      } catch (e) {
        debugPrint('QuickMuteNotifier: error muting volume: $e');
      }
    }
  }

  /// Mutes audio, storing current volume.
  Future<void> mute() async {
    if (!state.isMuted && state.volume > 0.0) {
      await toggleMute();
    }
  }

  /// Restores audio to previous non-zero volume level.
  Future<void> unmute() async {
    if (state.isMuted || state.volume <= 0.0) {
      await toggleMute();
    }
  }

  /// Explicitly sets volume to a given level [0.0 - 1.0].
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped <= 0.0) {
      state = state.copyWith(
        isMuted: true,
        volume: 0.0,
      );
      try {
        await _audioHandler?.setVolume(0.0);
      } catch (e) {
        debugPrint('QuickMuteNotifier: error setting volume to 0: $e');
      }
    } else {
      state = state.copyWith(
        isMuted: false,
        volume: clamped,
        previousVolume: clamped,
      );
      try {
        await _audioHandler?.setVolume(clamped);
      } catch (e) {
        debugPrint('QuickMuteNotifier: error setting volume: $e');
      }
    }
  }
}

/// Riverpod provider tracking quick mute state and previous volume memory.
final quickMuteProvider =
    StateNotifierProvider<QuickMuteNotifier, QuickMuteState>((ref) {
  SoftifyAudioHandler? handler;
  try {
    handler = ref.watch(audioHandlerProvider);
  } catch (_) {
    // Allows testing QuickMuteNotifier in isolation when audioHandlerProvider is not registered
  }
  return QuickMuteNotifier(audioHandler: handler);
});

/// One-click quick mute / unmute button with dynamic volume icon.
class QuickMuteButton extends ConsumerWidget {
  final double? iconSize;
  final Color? color;
  final Color? mutedColor;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;
  final VoidCallback? onToggled;
  final ButtonStyle? style;

  const QuickMuteButton({
    super.key,
    this.iconSize,
    this.color,
    this.mutedColor,
    this.padding,
    this.tooltip,
    this.onToggled,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muteState = ref.watch(quickMuteProvider);
    final isMuted = muteState.isMuted || muteState.volume <= 0.0;
    final effectiveTooltip = tooltip ?? (isMuted ? 'Unmute' : 'Mute');

    Color effectiveColor;
    try {
      final tokens = context.tokens;
      effectiveColor = isMuted
          ? (mutedColor ?? tokens.textMuted)
          : (color ?? tokens.textSecondary);
    } catch (_) {
      effectiveColor = isMuted
          ? (mutedColor ?? Theme.of(context).disabledColor)
          : (color ?? Theme.of(context).iconTheme.color ?? Colors.white);
    }

    return IconButton(
      style: style ??
          IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            padding: padding ?? const EdgeInsets.all(4),
          ),
      iconSize: iconSize ?? 18,
      tooltip: effectiveTooltip,
      icon: Icon(
        muteState.dynamicIcon,
        color: effectiveColor,
      ),
      onPressed: () {
        ref.read(quickMuteProvider.notifier).toggleMute();
        onToggled?.call();
      },
    );
  }
}
