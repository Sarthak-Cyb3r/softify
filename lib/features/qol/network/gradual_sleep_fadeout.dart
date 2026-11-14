// ============================================================================
// Softify Quality of Life (QoL) - Feature 48:
// Sleep Timer 60s Gradual Fade-Out
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/player/softify_audio_handler.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Storage Keys
// ============================================================================

const String kSleepFadeoutEnabledKey = 'softify_sleep_fadeout_enabled';
const String kSleepFadeoutSlopeKey = 'softify_sleep_fadeout_slope';
const String kSleepFadeoutDurationSecKey = 'softify_sleep_fadeout_duration_sec';

// ============================================================================
// Enums & Math Curves
// ============================================================================

/// Mathematical slope curve used to attenuate volume during sleep timer fade-out.
enum FadeoutSlope {
  /// Smooth S-curve attenuation based on a half-period cosine wave:
  /// `V(p) = V_0 * 0.5 * (1 + cos(pi * p))`
  ///
  /// Offers zero initial derivative for seamless start (no sudden dip when
  /// the 60-second window begins) and zero final derivative for imperceptible
  /// glide into total silence without audible pop or abrupt cutoff.
  sinusoidal('Sinusoidal (Natural)', 'Smooth S-curve cosine glide'),

  /// Linear attenuation:
  /// `V(p) = V_0 * (1 - p)`
  ///
  /// Decreases volume at a strictly uniform rate over the entire duration.
  linear('Linear', 'Strict constant-rate reduction');

  final String displayName;
  final String description;
  const FadeoutSlope(this.displayName, this.description);

  /// Computes attenuation multiplier in range `[0.0, 1.0]` for [progress] in `[0.0, 1.0]`.
  double computeFactor(double progress) {
    final p = progress.clamp(0.0, 1.0);
    switch (this) {
      case FadeoutSlope.sinusoidal:
        return 0.5 * (1.0 + math.cos(p * math.pi));
      case FadeoutSlope.linear:
        return 1.0 - p;
    }
  }

  /// Calculates effective target volume given initial volume before fade started.
  double calculateVolume({
    required double initialVolume,
    required double progress,
  }) {
    if (initialVolume <= 0.0) return 0.0;
    final factor = computeFactor(progress);
    return (initialVolume * factor).clamp(0.0, 1.0);
  }

  /// Parses an enum value by its string name, falling back to [FadeoutSlope.sinusoidal].
  static FadeoutSlope fromName(String? name) {
    if (name == null) return FadeoutSlope.sinusoidal;
    final trimmed = name.trim().toLowerCase();
    for (final val in FadeoutSlope.values) {
      if (val.name.toLowerCase() == trimmed) return val;
    }
    return FadeoutSlope.sinusoidal;
  }
}

/// The operational phase of the sleep timer gradual fade-out mechanism.
enum FadeoutPhase {
  /// Monitoring sleep timer; no fade active.
  idle,

  /// Actively interpolating volume attenuation toward zero.
  fading,

  /// Fade completed; playback paused and initial volume restored.
  completed,

  /// Fade was prematurely interrupted or cancelled by user action.
  cancelled,
}

// ============================================================================
// State Model
// ============================================================================

/// Immutable snapshot representing the state of the 60s sleep timer fade-out.
@immutable
class SleepFadeoutState {
  /// Whether the user has enabled gradual fade-out for sleep timers.
  final bool isEnabled;

  /// Selected attenuation curve (sinusoidal S-curve or linear).
  final FadeoutSlope slope;

  /// Duration over which playback will fade to zero before stopping.
  /// Defaults to 60 seconds.
  final Duration fadeDuration;

  /// Current lifecycle phase of the fader.
  final FadeoutPhase phase;

  /// Volume level captured immediately before fade attenuation started.
  final double initialVolume;

  /// Current interpolated volume being fed to the audio player (0.0 to 1.0).
  final double currentVolume;

  /// Normalized fade progress from 0.0 (start of fade) to 1.0 (silence).
  final double progress;

  /// Remaining duration in the current fade window.
  final Duration remainingDuration;

  const SleepFadeoutState({
    this.isEnabled = true,
    this.slope = FadeoutSlope.sinusoidal,
    this.fadeDuration = const Duration(seconds: 60),
    this.phase = FadeoutPhase.idle,
    this.initialVolume = 1.0,
    this.currentVolume = 1.0,
    this.progress = 0.0,
    this.remainingDuration = Duration.zero,
  });

  /// True when the volume is actively in the process of fading out.
  bool get isFading => phase == FadeoutPhase.fading;

  /// Creates a copy with optionally updated fields.
  SleepFadeoutState copyWith({
    bool? isEnabled,
    FadeoutSlope? slope,
    Duration? fadeDuration,
    FadeoutPhase? phase,
    double? initialVolume,
    double? currentVolume,
    double? progress,
    Duration? remainingDuration,
  }) {
    return SleepFadeoutState(
      isEnabled: isEnabled ?? this.isEnabled,
      slope: slope ?? this.slope,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      phase: phase ?? this.phase,
      initialVolume: initialVolume ?? this.initialVolume,
      currentVolume: currentVolume ?? this.currentVolume,
      progress: progress ?? this.progress,
      remainingDuration: remainingDuration ?? this.remainingDuration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepFadeoutState &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          slope == other.slope &&
          fadeDuration == other.fadeDuration &&
          phase == other.phase &&
          (initialVolume - other.initialVolume).abs() < 0.001 &&
          (currentVolume - other.currentVolume).abs() < 0.001 &&
          (progress - other.progress).abs() < 0.001 &&
          remainingDuration == other.remainingDuration;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        slope,
        fadeDuration,
        phase,
        initialVolume,
        currentVolume,
        progress,
        remainingDuration,
      );

  @override
  String toString() =>
      'SleepFadeoutState(isEnabled: $isEnabled, slope: $slope, phase: $phase, '
      'vol: ${currentVolume.toStringAsFixed(2)}/${initialVolume.toStringAsFixed(2)}, '
      'progress: ${(progress * 100).toStringAsFixed(1)}%, remaining: ${remainingDuration.inSeconds}s)';
}

// ============================================================================
// Storage Abstraction & Implementations
// ============================================================================

/// Key-value storage contract for persisting sleep fade-out preferences.
abstract class SleepFadeoutPrefsStorage {
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
}

/// In-memory implementation of [SleepFadeoutPrefsStorage] ideal for headless unit tests.
class InMemorySleepFadeoutPrefsStorage implements SleepFadeoutPrefsStorage {
  final Map<String, dynamic> _data = {};

  @override
  Future<bool?> getBool(String key) async => _data[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<String?> getString(String key) async => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }
}

/// Persistent database adapter for [SleepFadeoutPrefsStorage] using Softify's [AppDatabase].
class DatabaseSleepFadeoutPrefsStorage implements SleepFadeoutPrefsStorage {
  final AppDatabase _db;

  DatabaseSleepFadeoutPrefsStorage(this._db);

  @override
  Future<bool?> getBool(String key) async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      if (row == null) return null;
      return row.value.trim().toLowerCase() == 'true';
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    try {
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: key, value: value.toString()),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getString(String key) async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      return row?.value;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> setString(String key, String value) async {
    try {
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: key, value: value),
          );
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// Audio Player Adapter Abstraction & Implementations
// ============================================================================

/// Decouples volume adjustments, playback pause, and sleep timer telemetry
/// from the concrete audio engine for testability and portability.
abstract class SleepFadeoutAudioAdapter {
  /// Sets output playback volume in normalized range `[0.0, 1.0]`.
  Future<void> setVolume(double volume);

  /// Current playback volume in range `[0.0, 1.0]`.
  double get volume;

  /// Stream of current playback volume events.
  Stream<double> get volumeStream;

  /// Pauses active playback.
  Future<void> pause();

  /// Whether playback is currently active.
  bool get isPlaying;

  /// Stream emitting remaining sleep timer duration, or null when inactive.
  Stream<Duration?> get sleepTimerRemainingStream;

  /// Current snapshot of remaining sleep timer duration.
  Duration? get sleepTimerRemaining;

  /// Disposes internal resources.
  void dispose();
}

/// Production adapter bridging [SoftifyAudioHandler] to [SleepFadeoutAudioAdapter].
class SoftifyAudioFadeoutAdapter implements SleepFadeoutAudioAdapter {
  final SoftifyAudioHandler _handler;

  SoftifyAudioFadeoutAdapter(this._handler);

  @override
  Future<void> setVolume(double volume) => _handler.setVolume(volume);

  @override
  double get volume => _handler.volume;

  @override
  Stream<double> get volumeStream => _handler.volumeStream;

  @override
  Future<void> pause() => _handler.pause();

  @override
  bool get isPlaying => _handler.playbackState.value.playing;

  @override
  Stream<Duration?> get sleepTimerRemainingStream =>
      _handler.sleepTimerRemainingStream;

  @override
  Duration? get sleepTimerRemaining => _handler.sleepTimerRemaining;

  @override
  void dispose() {}
}

/// Test double simulating audio handler behavior without platform dependencies.
class MockSleepFadeoutAudioAdapter implements SleepFadeoutAudioAdapter {
  double currentVolume;
  bool isPlayingState;
  Duration? remainingDuration;
  int pauseCallCount = 0;
  final List<double> volumeHistory = [];

  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();
  final StreamController<Duration?> _sleepRemainingController =
      StreamController<Duration?>.broadcast();

  MockSleepFadeoutAudioAdapter({
    this.currentVolume = 1.0,
    this.isPlayingState = true,
    this.remainingDuration,
  }) {
    volumeHistory.add(currentVolume);
  }

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume.clamp(0.0, 1.0);
    volumeHistory.add(currentVolume);
    _volumeController.add(currentVolume);
  }

  @override
  double get volume => currentVolume;

  @override
  Stream<double> get volumeStream => _volumeController.stream;

  @override
  Future<void> pause() async {
    pauseCallCount++;
    isPlayingState = false;
  }

  @override
  bool get isPlaying => isPlayingState;

  @override
  Stream<Duration?> get sleepTimerRemainingStream =>
      _sleepRemainingController.stream;

  @override
  Duration? get sleepTimerRemaining => remainingDuration;

  /// Emits a mock remaining duration update on the sleep timer stream.
  void emitRemaining(Duration? remaining) {
    remainingDuration = remaining;
    _sleepRemainingController.add(remaining);
  }

  @override
  void dispose() {
    _volumeController.close();
    _sleepRemainingController.close();
  }
}

// ============================================================================
// Controller
// ============================================================================

/// Controller governing the 60s gradual fade-out volume interpolation.
///
/// Listens to [SleepFadeoutAudioAdapter.sleepTimerRemainingStream]. When remaining
/// duration enters the final 60 seconds (or [SleepFadeoutState.fadeDuration]), it
/// smoothly reduces the output volume along the selected [FadeoutSlope].
///
/// When sleep timer elapses to 0, it pauses playback, resets the fader, and
/// safely restores the volume back to [initialVolume] so subsequent playback starts
/// at the user's expected level.
class SleepTimerVolumeFaderController extends StateNotifier<SleepFadeoutState> {
  final SleepFadeoutAudioAdapter? _audioAdapter;
  final SleepFadeoutPrefsStorage? _storage;

  StreamSubscription<Duration?>? _sleepRemainingSub;
  Timer? _manualFadeTimer;
  double? _capturedInitialVolume;
  bool _isDisposed = false;

  SleepTimerVolumeFaderController({
    SleepFadeoutAudioAdapter? audioAdapter,
    SleepFadeoutPrefsStorage? storage,
    SleepFadeoutState? initialState,
  })  : _audioAdapter = audioAdapter,
        _storage = storage,
        super(initialState ?? const SleepFadeoutState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadPreferences();
    _subscribeSleepTimer();
  }

  Future<void> _loadPreferences() async {
    if (_storage == null) return;
    try {
      final savedEnabled = await _storage!.getBool(kSleepFadeoutEnabledKey);
      final savedSlopeName = await _storage!.getString(kSleepFadeoutSlopeKey);

      if (_isDisposed) return;
      state = state.copyWith(
        isEnabled: savedEnabled ?? state.isEnabled,
        slope: savedSlopeName != null
            ? FadeoutSlope.fromName(savedSlopeName)
            : state.slope,
      );
    } catch (_) {
      // Non-fatal fallback to defaults
    }
  }

  void _subscribeSleepTimer() {
    if (_audioAdapter == null) return;
    _sleepRemainingSub = _audioAdapter!.sleepTimerRemainingStream.listen(
      onSleepRemainingUpdated,
    );
  }

  /// Evaluates sleep timer remaining duration and drives gradual fade-out.
  Future<void> onSleepRemainingUpdated(Duration? remaining) async {
    if (_isDisposed) return;

    // 1. Sleep timer was cancelled or expired
    if (remaining == null) {
      if (state.isFading) {
        await cancelFade();
      }
      return;
    }

    // 2. Feature disabled by user preference
    if (!state.isEnabled) {
      if (state.isFading) {
        await cancelFade();
      }
      return;
    }

    // 3. Audio adapter check
    final adapter = _audioAdapter;
    if (adapter == null) return;

    final fadeLimit = state.fadeDuration;

    // 4. Outside of the fade window (> 60s)
    if (remaining > fadeLimit) {
      if (state.isFading) {
        await cancelFade();
      }
      return;
    }

    // 5. Inactive playback: do not attenuate if nothing is playing
    if (!adapter.isPlaying && !state.isFading) {
      return;
    }

    // 6. Enter fade window (remaining <= fadeLimit)
    if (!state.isFading) {
      // Capture baseline volume
      _capturedInitialVolume = adapter.volume;
      // Guard against already muted volume
      if (_capturedInitialVolume! <= 0.001) {
        _capturedInitialVolume = 1.0;
      }
    }

    final initialVol = _capturedInitialVolume ?? state.initialVolume;
    final totalMs = fadeLimit.inMilliseconds;
    final remMs = remaining.inMilliseconds.clamp(0, totalMs);
    final progress = totalMs > 0 ? (1.0 - (remMs / totalMs)).clamp(0.0, 1.0) : 1.0;

    // Calculate volume based on active slope
    final targetVol = state.slope.calculateVolume(
      initialVolume: initialVol,
      progress: progress,
    );

    // Apply volume smoothly
    await adapter.setVolume(targetVol);

    if (_isDisposed) return;

    // 7. Check if sleep countdown has completed
    if (remaining <= Duration.zero || progress >= 1.0) {
      await _completeFade(initialVol);
    } else {
      state = state.copyWith(
        phase: FadeoutPhase.fading,
        initialVolume: initialVol,
        currentVolume: targetVol,
        progress: progress,
        remainingDuration: remaining,
      );
    }
  }

  /// Finalizes fade-out: pauses playback and restores baseline volume for next session.
  Future<void> _completeFade(double originalVolume) async {
    final adapter = _audioAdapter;
    if (adapter != null) {
      // Guarantee zero volume before pause
      await adapter.setVolume(0.0);
      await adapter.pause();
      // Restore initial volume so subsequent playback starts cleanly
      await adapter.setVolume(originalVolume);
    }

    _capturedInitialVolume = null;
    if (_isDisposed) return;

    state = state.copyWith(
      phase: FadeoutPhase.completed,
      currentVolume: originalVolume,
      progress: 1.0,
      remainingDuration: Duration.zero,
    );
  }

  /// Cancels an in-progress fade-out and restores the pre-fade volume immediately.
  Future<void> cancelFade() async {
    _manualFadeTimer?.cancel();
    _manualFadeTimer = null;

    final originalVol = _capturedInitialVolume;
    _capturedInitialVolume = null;

    if (originalVol != null && _audioAdapter != null) {
      await _audioAdapter!.setVolume(originalVol);
    }

    if (_isDisposed) return;
    state = state.copyWith(
      phase: FadeoutPhase.cancelled,
      currentVolume: originalVol ?? state.initialVolume,
      progress: 0.0,
      remainingDuration: Duration.zero,
    );
  }

  /// Simulates or executes a manual smooth fade-out over [duration].
  ///
  /// Useful for previewing the fade curve in settings or programmatic stop.
  Future<void> startManualFade({
    Duration duration = const Duration(seconds: 3),
    double? fromVolume,
    VoidCallback? onComplete,
  }) async {
    final adapter = _audioAdapter;
    if (adapter == null) return;

    await cancelFade();

    _capturedInitialVolume = fromVolume ?? adapter.volume;
    final initialVol = _capturedInitialVolume!;
    final totalMs = duration.inMilliseconds;
    const stepMs = 50;
    final totalSteps = (totalMs / stepMs).round();
    int currentStep = 0;

    state = state.copyWith(
      phase: FadeoutPhase.fading,
      fadeDuration: duration,
      initialVolume: initialVol,
      currentVolume: initialVol,
      progress: 0.0,
      remainingDuration: duration,
    );

    _manualFadeTimer?.cancel();
    _manualFadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) async {
      currentStep++;
      final progress = (currentStep / totalSteps).clamp(0.0, 1.0);
      final remMs = ((1.0 - progress) * totalMs).round();

      final currentVol = state.slope.calculateVolume(
        initialVolume: initialVol,
        progress: progress,
      );

      await adapter.setVolume(currentVol);

      if (_isDisposed) {
        timer.cancel();
        return;
      }

      state = state.copyWith(
        currentVolume: currentVol,
        progress: progress,
        remainingDuration: Duration(milliseconds: remMs),
      );

      if (progress >= 1.0) {
        timer.cancel();
        _manualFadeTimer = null;
        await _completeFade(initialVol);
        onComplete?.call();
      }
    });
  }

  /// Sets whether 60s gradual fade-out is enabled and persists choice.
  Future<void> setEnabled(bool enabled) async {
    if (state.isEnabled == enabled) return;

    if (!enabled && state.isFading) {
      await cancelFade();
    }

    state = state.copyWith(isEnabled: enabled);
    await _storage?.setBool(kSleepFadeoutEnabledKey, enabled);
  }

  /// Toggles the enabled state.
  Future<void> toggleEnabled() => setEnabled(!state.isEnabled);

  /// Updates the attenuation curve slope (sinusoidal or linear) and persists choice.
  Future<void> setSlope(FadeoutSlope slope) async {
    if (state.slope == slope) return;
    state = state.copyWith(slope: slope);
    await _storage?.setString(kSleepFadeoutSlopeKey, slope.name);
  }

  /// Updates the configured fade duration window. Defaults to 60s.
  void setFadeDuration(Duration duration) {
    if (state.fadeDuration == duration) return;
    state = state.copyWith(fadeDuration: duration);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sleepRemainingSub?.cancel();
    _manualFadeTimer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Safe accessor for [AppDatabase] from Riverpod [Ref].
AppDatabase? _safeGetDb(Ref ref) {
  try {
    return ref.read(databaseProvider);
  } catch (_) {
    return null;
  }
}

/// Provider supplying the [SleepFadeoutAudioAdapter].
final sleepFadeoutAudioAdapterProvider =
    Provider<SleepFadeoutAudioAdapter>((ref) {
  try {
    final handler = ref.watch(audioHandlerProvider);
    final adapter = SoftifyAudioFadeoutAdapter(handler);
    ref.onDispose(adapter.dispose);
    return adapter;
  } catch (_) {
    final mock = MockSleepFadeoutAudioAdapter();
    ref.onDispose(mock.dispose);
    return mock;
  }
});

/// Provider supplying the storage engine for fade-out preferences.
final sleepFadeoutStorageProvider = Provider<SleepFadeoutPrefsStorage>((ref) {
  final db = _safeGetDb(ref);
  if (db != null) {
    return DatabaseSleepFadeoutPrefsStorage(db);
  }
  return InMemorySleepFadeoutPrefsStorage();
});

/// Riverpod [StateNotifierProvider] managing 60s gradual sleep timer fade-out state.
final sleepFadeoutControllerProvider = StateNotifierProvider<
    SleepTimerVolumeFaderController, SleepFadeoutState>((ref) {
  final adapter = ref.watch(sleepFadeoutAudioAdapterProvider);
  final storage = ref.watch(sleepFadeoutStorageProvider);

  final controller = SleepTimerVolumeFaderController(
    audioAdapter: adapter,
    storage: storage,
  );
  return controller;
});

/// Convenient boolean provider indicating if volume fade-out is currently running.
final isSleepFadeoutActiveProvider = Provider<bool>((ref) {
  return ref.watch(sleepFadeoutControllerProvider).isFading;
});

/// Provider exposing normalized fade-out progress `[0.0, 1.0]`.
final sleepFadeoutProgressProvider = Provider<double>((ref) {
  return ref.watch(sleepFadeoutControllerProvider).progress;
});

// ============================================================================
// UI Component: SleepTimerFadeoutToggleTile
// ============================================================================

/// Settings and sleep dialog tile widget allowing users to toggle the 60s
/// gradual fade-out feature and select between sinusoidal and linear slopes.
///
/// Designed to blend seamlessly with Softify's Material 3 desktop aesthetics.
class SleepTimerFadeoutToggleTile extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final String title;
  final String? subtitle;
  final Color? activeColor;
  final bool showIcon;
  final IconData icon;
  final bool showBorder;
  final bool showSlopeSelector;
  final ValueChanged<bool>? onToggled;
  final ValueChanged<FadeoutSlope>? onSlopeChanged;

  const SleepTimerFadeoutToggleTile({
    super.key,
    this.margin,
    this.padding,
    this.title = '60s Gradual Fade-Out',
    this.subtitle,
    this.activeColor,
    this.showIcon = true,
    this.icon = Icons.nightlight_round,
    this.showBorder = true,
    this.showSlopeSelector = true,
    this.onToggled,
    this.onSlopeChanged,
  });

  String _formatDurationSeconds(Duration d) {
    final secs = d.inSeconds;
    if (secs <= 0) return '0s';
    final mins = secs ~/ 60;
    final remSecs = secs % 60;
    if (mins > 0) {
      return '${mins}m ${remSecs.toString().padLeft(2, '0')}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(sleepFadeoutControllerProvider);
    final isEnabled = state.isEnabled;
    final isFading = state.isFading;
    final accentColor = activeColor ?? tokens.accent;

    // Subtitle generation
    final String statusLabel;
    if (subtitle != null) {
      statusLabel = subtitle!;
    } else if (isFading) {
      statusLabel =
          'Fading out • ${_formatDurationSeconds(state.remainingDuration)} left (${(state.currentVolume * 100).round()}% vol)';
    } else if (isEnabled) {
      statusLabel =
          'Gradually lowers volume over final 60s (${state.slope.displayName})';
    } else {
      statusLabel = 'Pauses immediately when sleep timer finishes';
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
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Toggle Row
              InkWell(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                onTap: () {
                  HapticFeedback.lightImpact();
                  final next = !isEnabled;
                  ref.read(sleepFadeoutControllerProvider.notifier).setEnabled(next);
                  onToggled?.call(next);
                },
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
                          borderRadius:
                              BorderRadius.circular(tokens.radiusSm),
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
                                fontWeight: isEnabled
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: isFading
                                    ? accentColor
                                    : (isEnabled
                                        ? tokens.textPrimary
                                        : tokens.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      key: const Key('sleep_timer_fadeout_switch'),
                      value: isEnabled,
                      activeColor: accentColor,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        ref
                            .read(sleepFadeoutControllerProvider.notifier)
                            .setEnabled(value);
                        onToggled?.call(value);
                      },
                    ),
                  ],
                ),
              ),

              // Optional Slope Selector (Visible when enabled)
              if (showSlopeSelector && isEnabled) ...[
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tokens.divider.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Curve Slope:',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SegmentedButton<FadeoutSlope>(
                        segments: const [
                          ButtonSegment<FadeoutSlope>(
                            value: FadeoutSlope.sinusoidal,
                            label: Text('Sinusoidal'),
                            icon: Icon(Icons.waves_rounded, size: 16),
                            tooltip: 'Natural cosine ease-out S-curve',
                          ),
                          ButtonSegment<FadeoutSlope>(
                            value: FadeoutSlope.linear,
                            label: Text('Linear'),
                            icon: Icon(Icons.trending_down_rounded, size: 16),
                            tooltip: 'Constant-rate linear attenuation',
                          ),
                        ],
                        selected: {state.slope},
                        onSelectionChanged: (Set<FadeoutSlope> selection) {
                          if (selection.isNotEmpty) {
                            HapticFeedback.lightImpact();
                            final chosen = selection.first;
                            ref
                                .read(sleepFadeoutControllerProvider.notifier)
                                .setSlope(chosen);
                            onSlopeChanged?.call(chosen);
                          }
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          textStyle: WidgetStatePropertyAll(
                            TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
