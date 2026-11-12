// ============================================================================
// Softify Quality of Life (QoL) - Feature 8:
// True Dual-Engine Overlapping Crossfade Diagnostic Controller
// ============================================================================
//
// Theoretical DSP Foundation:
// In professional digital audio workstations (DAWs) and audiophile playback
// systems, a linear crossfade suffers from a -3.01 dB acoustic power dip at
// the transition midpoint (where V_out = 0.5, V_in = 0.5 -> Power = 0.25 + 0.25 = 0.50).
//
// This True Dual-Engine Controller uses an authentic Constant-Power (Equal-Power)
// overlapping trigonometric curve:
//   theta = progress * (pi / 2)
//   V_out = cos(theta)
//   V_in  = sin(theta)
//
// At the midpoint (progress = 0.5, theta = pi / 4):
//   V_out = cos(pi / 4) = sqrt(2) / 2 ~= 0.70710678 (-3.01 dB)
//   V_in  = sin(pi / 4) = sqrt(2) / 2 ~= 0.70710678 (-3.01 dB)
//   P_tot = V_out^2 + V_in^2 = cos^2(theta) + sin^2(theta) = 1.00000000 (0.00 dB)
//
// Acoustic energy remains completely constant throughout the entire transition,
// eliminating perceptual loudness drops while two audio engines overlap simultaneously.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Preferences & Persistence Configuration
// ============================================================================

/// Preference key for default crossfade duration in milliseconds.
const String kTrueCrossfadeDurationPrefKey = 'softify_true_crossfade_duration_ms';

/// Preference key for crossfade curve mode enum index.
const String kTrueCrossfadeCurveModePrefKey = 'softify_true_crossfade_curve_mode';

/// Preference key for auto-trigger overlapping crossfade before track end.
const String kTrueCrossfadeAutoTriggerPrefKey = 'softify_true_crossfade_auto_trigger';

/// Default crossfade duration in seconds.
const int kTrueCrossfadeDefaultSeconds = 4;

/// Minimum and maximum supported crossfade duration in seconds.
const int kTrueCrossfadeMinSeconds = 1;
const int kTrueCrossfadeMaxSeconds = 12;

/// Quick preset durations for crossfade setup.
const List<int> kTrueCrossfadePresets = [2, 4, 6, 8, 10, 12];

/// Standalone, lightweight disk-persisted key-value store for crossfade settings,
/// fully mockable for headless tests.
class TrueCrossfadePrefs {
  static TrueCrossfadePrefs? _instance;
  static Map<String, Object>? _mockValues;

  final Map<String, Object> _store;
  final File? _file;

  TrueCrossfadePrefs._(this._store, this._file);

  /// Injects mock values for testing without file I/O.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockValues = Map<String, Object>.from(values);
    _instance = TrueCrossfadePrefs._(Map<String, Object>.from(values), null);
  }

  /// Resets instance for clean test execution.
  static void resetForTesting() {
    _instance = null;
    _mockValues = null;
  }

  /// Obtains singleton preferences store.
  static Future<TrueCrossfadePrefs> getInstance() async {
    if (_instance != null) return _instance!;
    if (_mockValues != null) {
      _instance = TrueCrossfadePrefs._(
        Map<String, Object>.from(_mockValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        file = File('${dir.path}/true_crossfade_prefs.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            final decoded = jsonDecode(content);
            if (decoded is Map) {
              decoded.forEach((key, value) {
                if (value != null) store[key.toString()] = value as Object;
              });
            }
          }
        }
      }
    } catch (_) {}

    _instance = TrueCrossfadePrefs._(store, file);
    return _instance!;
  }

  int? getInt(String key) {
    final val = _store[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _store[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) => _store[key]?.toString();

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    if (_file == null) return;
    try {
      await _file.writeAsString(jsonEncode(_store), flush: true);
    } catch (_) {}
  }
}

// ============================================================================
// DSP Mathematical Foundations
// ============================================================================

/// Mathematical calculations for constant-power overlapping crossfades
/// and decibel conversions.
class CrossfadeMath {
  /// Exact Half-Pi constant for trigonometric angle scaling: pi / 2.
  static const double halfPi = math.pi / 2;

  /// Pure trigonometric equal-power outgoing volume:
  /// V_out = cos(progress * pi / 2)
  static double equalPowerOut(double progress) {
    final p = progress.clamp(0.0, 1.0);
    final theta = p * halfPi;
    return math.cos(theta).clamp(0.0, 1.0);
  }

  /// Pure trigonometric equal-power incoming volume:
  /// V_in = sin(progress * pi / 2)
  static double equalPowerIn(double progress) {
    final p = progress.clamp(0.0, 1.0);
    final theta = p * halfPi;
    return math.sin(theta).clamp(0.0, 1.0);
  }

  /// Standard linear amplitude ramp out: 1 - progress.
  static double linearOut(double progress) {
    final p = progress.clamp(0.0, 1.0);
    return (1.0 - p).clamp(0.0, 1.0);
  }

  /// Standard linear amplitude ramp in: progress.
  static double linearIn(double progress) {
    final p = progress.clamp(0.0, 1.0);
    return p.clamp(0.0, 1.0);
  }

  /// Cubic smoothstep S-Curve out: 1 - (3p^2 - 2p^3).
  static double sCurveOut(double progress) {
    final p = progress.clamp(0.0, 1.0);
    final s = (3.0 * p * p) - (2.0 * p * p * p);
    return (1.0 - s).clamp(0.0, 1.0);
  }

  /// Cubic smoothstep S-Curve in: 3p^2 - 2p^3.
  static double sCurveIn(double progress) {
    final p = progress.clamp(0.0, 1.0);
    return ((3.0 * p * p) - (2.0 * p * p * p)).clamp(0.0, 1.0);
  }

  /// Calculates total combined acoustic power:
  /// P_tot = V_out^2 + V_in^2
  /// In an ideal equal-power crossfade, P_tot == 1.0 across the entire range.
  static double computeTotalPower(double vOut, double vIn) {
    return (vOut * vOut) + (vIn * vIn);
  }

  /// Converts amplitude gain (0.0 to 1.0) into decibels (dB).
  /// Clamped at [floorDb] (default -60.0 dB) to avoid -infinity.
  static double toDecibels(double gain, {double floorDb = -60.0}) {
    if (gain <= 0.0001) return floorDb;
    final db = 20.0 * (math.log(gain) / math.ln10);
    return db.clamp(floorDb, 0.0);
  }

  /// Converts decibels back to linear gain.
  static double fromDecibels(double db) {
    return math.pow(10.0, db / 20.0).toDouble().clamp(0.0, 1.0);
  }

  /// Calculates acoustic power fluctuation in dB relative to unity power (1.0).
  /// Ideally 0.0 dB for equal power curves.
  static double powerFluxDb(double totalPower) {
    if (totalPower <= 0.0001) return -60.0;
    return 10.0 * (math.log(totalPower) / math.ln10);
  }
}

// ============================================================================
// Enums & Models
// ============================================================================

/// Active lifecycle phase of a dual-engine crossfade transition.
enum CrossfadePhase {
  /// Idle state: normal single-engine playback, no transition active.
  idle('Idle', Icons.stop_circle_outlined),

  /// Priming state: incoming player initialized, buffered and positioned.
  priming('Priming', Icons.hourglass_top_rounded),

  /// Active crossfading: dual audio engines playing simultaneously with live volume curves.
  fading('Fading', Icons.sync_alt_rounded),

  /// Finishing state: progress >= 0.95, outgoing engine completing shutdown.
  finishing('Finishing', Icons.hourglass_bottom_rounded),

  /// Completed state: transition finished, secondary player promoted to primary.
  completed('Completed', Icons.check_circle_rounded);

  final String label;
  final IconData icon;
  const CrossfadePhase(this.label, this.icon);
}

/// Curve algorithm options for crossfade volume computation.
enum CrossfadeCurveMode {
  /// Equal-Power trigonometric curve: V_out = cos(theta), V_in = sin(theta).
  /// Preserves constant acoustic energy without loudness dips.
  equalPower('Equal Power (cos/sin)', 'Preserves 0 dB energy across overlap'),

  /// Linear gain ramp: V_out = 1 - p, V_in = p.
  /// Subject to a -3.01 dB power loss dip at center.
  linear('Linear Amplitude', 'Subject to -3dB dip at midpoint'),

  /// Cubic S-Curve smoothstep: smooth deceleration at transitions.
  sCurve('Smooth S-Curve', 'Smoothstep cubic easing curve');

  final String displayName;
  final String description;
  const CrossfadeCurveMode(this.displayName, this.description);
}

/// Real-time diagnostic state model representing the dual-engine crossfade engine.
@immutable
class TrueCrossfadeState {
  /// Whether a crossfade operation is currently in flight or primed.
  final bool isActive;

  /// Current lifecycle transition phase.
  final CrossfadePhase phase;

  /// Overlapping power curve progress ranging precisely from 0.0 to 1.0.
  final double progress;

  /// Instantaneous computed volume for outgoing engine (V_out = cos(theta)).
  final double outgoingVolume;

  /// Instantaneous computed volume for incoming engine (V_in = sin(theta)).
  final double incomingVolume;

  /// Combined acoustic power (V_out^2 + V_in^2).
  final double totalPower;

  /// Decibels readout for outgoing player (20 * log10(V_out)).
  final double decibelsOut;

  /// Decibels readout for incoming player (20 * log10(V_in)).
  final double decibelsIn;

  /// Total configured duration of crossfade transition.
  final Duration duration;

  /// Elapsed duration in current crossfade.
  final Duration elapsed;

  /// Outgoing engine identifier (e.g., 'engine_primary' or 'engine_A').
  final String outgoingEngineId;

  /// Incoming engine identifier (e.g., 'engine_secondary' or 'engine_B').
  final String incomingEngineId;

  /// Display title of the outgoing track.
  final String outgoingTrackTitle;

  /// Display title of the incoming track.
  final String incomingTrackTitle;

  /// Mathematical curve algorithm currently engaged.
  final CrossfadeCurveMode curveMode;

  /// Whether both engines are simultaneously actively generating audio output.
  final bool isDualEngineActive;

  /// Whether active crossfade playback is temporarily paused.
  final bool isPaused;

  /// Timestamp when active crossfade was initiated.
  final DateTime? startedAt;

  const TrueCrossfadeState({
    this.isActive = false,
    this.phase = CrossfadePhase.idle,
    this.progress = 0.0,
    this.outgoingVolume = 1.0,
    this.incomingVolume = 0.0,
    this.totalPower = 1.0,
    this.decibelsOut = 0.0,
    this.decibelsIn = -60.0,
    this.duration = const Duration(seconds: kTrueCrossfadeDefaultSeconds),
    this.elapsed = Duration.zero,
    this.outgoingEngineId = 'Engine-A',
    this.incomingEngineId = 'Engine-B',
    this.outgoingTrackTitle = 'Current Track',
    this.incomingTrackTitle = 'Next Track',
    this.curveMode = CrossfadeCurveMode.equalPower,
    this.isDualEngineActive = false,
    this.isPaused = false,
    this.startedAt,
  });

  /// Factory creating an idle initial state.
  factory TrueCrossfadeState.initial({
    Duration duration = const Duration(seconds: kTrueCrossfadeDefaultSeconds),
    CrossfadeCurveMode curveMode = CrossfadeCurveMode.equalPower,
  }) {
    return TrueCrossfadeState(
      isActive: false,
      phase: CrossfadePhase.idle,
      progress: 0.0,
      outgoingVolume: 1.0,
      incomingVolume: 0.0,
      totalPower: 1.0,
      decibelsOut: 0.0,
      decibelsIn: -60.0,
      duration: duration,
      elapsed: Duration.zero,
      outgoingEngineId: 'Engine-A',
      incomingEngineId: 'Engine-B',
      outgoingTrackTitle: 'Track 1 (Outgoing)',
      incomingTrackTitle: 'Track 2 (Incoming)',
      curveMode: curveMode,
      isDualEngineActive: false,
      isPaused: false,
    );
  }

  /// True if transition is currently actively moving through the overlap curve.
  bool get isFading => phase == CrossfadePhase.fading;

  /// True if crossfade has finished full transition.
  bool get isCompleted => phase == CrossfadePhase.completed;

  /// Remaining duration before crossfade reaches completion.
  Duration get remaining => duration > elapsed ? duration - elapsed : Duration.zero;

  /// Percentage progress string representation (e.g., "50.0%").
  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';

  /// Power fluctuation in decibels relative to unity.
  double get powerFluxDb => CrossfadeMath.powerFluxDb(totalPower);

  TrueCrossfadeState copyWith({
    bool? isActive,
    CrossfadePhase? phase,
    double? progress,
    double? outgoingVolume,
    double? incomingVolume,
    double? totalPower,
    double? decibelsOut,
    double? decibelsIn,
    Duration? duration,
    Duration? elapsed,
    String? outgoingEngineId,
    String? incomingEngineId,
    String? outgoingTrackTitle,
    String? incomingTrackTitle,
    CrossfadeCurveMode? curveMode,
    bool? isDualEngineActive,
    bool? isPaused,
    DateTime? startedAt,
  }) {
    return TrueCrossfadeState(
      isActive: isActive ?? this.isActive,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      outgoingVolume: outgoingVolume ?? this.outgoingVolume,
      incomingVolume: incomingVolume ?? this.incomingVolume,
      totalPower: totalPower ?? this.totalPower,
      decibelsOut: decibelsOut ?? this.decibelsOut,
      decibelsIn: decibelsIn ?? this.decibelsIn,
      duration: duration ?? this.duration,
      elapsed: elapsed ?? this.elapsed,
      outgoingEngineId: outgoingEngineId ?? this.outgoingEngineId,
      incomingEngineId: incomingEngineId ?? this.incomingEngineId,
      outgoingTrackTitle: outgoingTrackTitle ?? this.outgoingTrackTitle,
      incomingTrackTitle: incomingTrackTitle ?? this.incomingTrackTitle,
      curveMode: curveMode ?? this.curveMode,
      isDualEngineActive: isDualEngineActive ?? this.isDualEngineActive,
      isPaused: isPaused ?? this.isPaused,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrueCrossfadeState &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          phase == other.phase &&
          progress == other.progress &&
          outgoingVolume == other.outgoingVolume &&
          incomingVolume == other.incomingVolume &&
          totalPower == other.totalPower &&
          duration == other.duration &&
          elapsed == other.elapsed &&
          outgoingEngineId == other.outgoingEngineId &&
          incomingEngineId == other.incomingEngineId &&
          curveMode == other.curveMode &&
          isDualEngineActive == other.isDualEngineActive &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(
        isActive,
        phase,
        progress,
        outgoingVolume,
        incomingVolume,
        totalPower,
        duration,
        elapsed,
        outgoingEngineId,
        incomingEngineId,
        curveMode,
        isDualEngineActive,
        isPaused,
      );

  @override
  String toString() =>
      'TrueCrossfadeState(phase: ${phase.name}, progress: $formattedProgress, '
      'V_out: ${outgoingVolume.toStringAsFixed(3)}, V_in: ${incomingVolume.toStringAsFixed(3)}, '
      'P_tot: ${totalPower.toStringAsFixed(4)})';
}

// ============================================================================
// Dual-Engine Audio Port Interface & Simulation Implementation
// ============================================================================

/// Hardware/software port abstraction for coordinating dual independent audio engines.
abstract class DualEngineAudioPort {
  /// Sets master volume on specified engine (0.0 to 1.0).
  Future<void> setVolume(String engineId, double volume);

  /// Initiates audio playback on specified engine.
  Future<void> play(String engineId, String trackTitle, {Duration startOffset = Duration.zero});

  /// Pauses playback on specified engine.
  Future<void> pause(String engineId);

  /// Stops and releases playback on specified engine.
  Future<void> stop(String engineId);

  /// Preloads and arms incoming engine for instant overlap.
  Future<void> prepare(String engineId, String trackTitle);
}

/// Simulated in-memory dual audio engine port for diagnostic verification and headless tests.
class SimulatedDualEngineAudioPort implements DualEngineAudioPort {
  final Map<String, double> volumes = {
    'Engine-A': 1.0,
    'Engine-B': 0.0,
  };

  final Map<String, bool> playing = {
    'Engine-A': true,
    'Engine-B': false,
  };

  final Map<String, String> currentTracks = {
    'Engine-A': 'Track 1',
    'Engine-B': 'Track 2',
  };

  final List<String> eventLog = [];

  void _log(String message) {
    eventLog.add('[${DateTime.now().toIso8601String()}] $message');
  }

  @override
  Future<void> setVolume(String engineId, double volume) async {
    volumes[engineId] = volume.clamp(0.0, 1.0);
    _log('setVolume($engineId, ${volume.toStringAsFixed(3)})');
  }

  @override
  Future<void> play(String engineId, String trackTitle, {Duration startOffset = Duration.zero}) async {
    playing[engineId] = true;
    currentTracks[engineId] = trackTitle;
    _log('play($engineId, "$trackTitle", offset: $startOffset)');
  }

  @override
  Future<void> pause(String engineId) async {
    playing[engineId] = false;
    _log('pause($engineId)');
  }

  @override
  Future<void> stop(String engineId) async {
    playing[engineId] = false;
    volumes[engineId] = 0.0;
    _log('stop($engineId)');
  }

  @override
  Future<void> prepare(String engineId, String trackTitle) async {
    currentTracks[engineId] = trackTitle;
    volumes[engineId] = 0.0;
    _log('prepare($engineId, "$trackTitle")');
  }

  /// Clears log history.
  void clearLog() => eventLog.clear();
}

// ============================================================================
// Riverpod StateNotifier: TrueCrossfadeEngineNotifier
// ============================================================================

/// Riverpod StateNotifier orchestrating true dual-engine overlapping crossfades.
///
/// Features:
/// - Real-time overlapping power curve computation:
///   V_out = cos(theta), V_in = sin(theta) where theta = progress * (pi / 2).
/// - Constant 1.0 acoustic power preservation.
/// - Active transition phases: idle, priming, fading, finishing, completed.
/// - Step-by-step diagnostic scrubbing and automated smooth timer transitions.
/// - Persistent settings synchronization to SharedPreferences.
class TrueCrossfadeEngineNotifier extends StateNotifier<TrueCrossfadeState> {
  final DualEngineAudioPort audioPort;
  final TrueCrossfadePrefs? _prefs;

  Timer? _tickerTimer;
  bool _initialized = false;

  TrueCrossfadeEngineNotifier({
    DualEngineAudioPort? audioPort,
    TrueCrossfadePrefs? prefs,
  })  : audioPort = audioPort ?? SimulatedDualEngineAudioPort(),
        _prefs = prefs,
        super(TrueCrossfadeState.initial()) {
    _loadPreferences();
  }

  /// Loads stored configuration from disk/mock preferences.
  Future<void> _loadPreferences() async {
    try {
      final p = _prefs ?? await TrueCrossfadePrefs.getInstance();
      final storedMs = p.getInt(kTrueCrossfadeDurationPrefKey);
      final storedCurveIndex = p.getInt(kTrueCrossfadeCurveModePrefKey);

      Duration duration = state.duration;
      if (storedMs != null && storedMs > 0) {
        duration = Duration(milliseconds: storedMs);
      }

      CrossfadeCurveMode curve = state.curveMode;
      if (storedCurveIndex != null &&
          storedCurveIndex >= 0 &&
          storedCurveIndex < CrossfadeCurveMode.values.length) {
        curve = CrossfadeCurveMode.values[storedCurveIndex];
      }

      if (!_initialized) {
        state = state.copyWith(
          duration: duration,
          curveMode: curve,
        );
      }
    } catch (_) {} finally {
      _initialized = true;
    }
  }

  /// Computes volume gains and power for a given [progress] (0.0 to 1.0).
  ({double vOut, double vIn, double totalPower, double dbOut, double dbIn})
      _computeVolumes(double progress, CrossfadeCurveMode mode) {
    final p = progress.clamp(0.0, 1.0);
    double vOut;
    double vIn;

    switch (mode) {
      case CrossfadeCurveMode.equalPower:
        // Theoretical Equal-Power Trigonometric Formulation:
        // V_out = cos(theta), V_in = sin(theta)
        vOut = CrossfadeMath.equalPowerOut(p);
        vIn = CrossfadeMath.equalPowerIn(p);
        break;
      case CrossfadeCurveMode.linear:
        vOut = CrossfadeMath.linearOut(p);
        vIn = CrossfadeMath.linearIn(p);
        break;
      case CrossfadeCurveMode.sCurve:
        vOut = CrossfadeMath.sCurveOut(p);
        vIn = CrossfadeMath.sCurveIn(p);
        break;
    }

    final totalPower = CrossfadeMath.computeTotalPower(vOut, vIn);
    final dbOut = CrossfadeMath.toDecibels(vOut);
    final dbIn = CrossfadeMath.toDecibels(vIn);

    return (
      vOut: vOut,
      vIn: vIn,
      totalPower: totalPower,
      dbOut: dbOut,
      dbIn: dbIn,
    );
  }

  /// Starts a real-time dual-engine crossfade transition.
  ///
  /// Engages dual engines simultaneously, starts periodic volume curve updates,
  /// and moves through transition phases.
  Future<void> startCrossfade({
    String? outgoingTrack,
    String? incomingTrack,
    Duration? duration,
    String? outgoingEngine,
    String? incomingEngine,
  }) async {
    _tickerTimer?.cancel();

    final dur = duration ?? state.duration;
    final outEngine = outgoingEngine ?? state.outgoingEngineId;
    final inEngine = incomingEngine ?? state.incomingEngineId;
    final outTitle = outgoingTrack ?? state.outgoingTrackTitle;
    final inTitle = incomingTrack ?? state.incomingTrackTitle;

    final initialMetrics = _computeVolumes(0.0, state.curveMode);

    state = state.copyWith(
      isActive: true,
      phase: CrossfadePhase.fading,
      progress: 0.0,
      outgoingVolume: initialMetrics.vOut,
      incomingVolume: initialMetrics.vIn,
      totalPower: initialMetrics.totalPower,
      decibelsOut: initialMetrics.dbOut,
      decibelsIn: initialMetrics.dbIn,
      duration: dur,
      elapsed: Duration.zero,
      outgoingEngineId: outEngine,
      incomingEngineId: inEngine,
      outgoingTrackTitle: outTitle,
      incomingTrackTitle: inTitle,
      isDualEngineActive: true,
      isPaused: false,
      startedAt: DateTime.now(),
    );

    // 1. Prime incoming engine
    await audioPort.prepare(inEngine, inTitle);
    if (!mounted || state.phase != CrossfadePhase.fading) return;
    await audioPort.setVolume(inEngine, 0.0);
    if (!mounted || state.phase != CrossfadePhase.fading) return;
    await audioPort.setVolume(outEngine, 1.0);
    if (!mounted || state.phase != CrossfadePhase.fading) return;

    // 2. Play incoming engine concurrently (simultaneous dual playback)
    await audioPort.play(inEngine, inTitle);
    if (!mounted || state.phase != CrossfadePhase.fading) return;

    // 3. Start high-frequency ticker (approx 30 updates per second)
    const tickInterval = Duration(milliseconds: 33);
    _tickerTimer = Timer.periodic(tickInterval, (timer) {
      if (state.isPaused) return;

      final newElapsed = state.elapsed + tickInterval;
      if (newElapsed >= state.duration) {
        timer.cancel();
        completeCrossfade();
      } else {
        final newProgress = newElapsed.inMilliseconds / state.duration.inMilliseconds;
        _applyProgress(newProgress, elapsed: newElapsed);
      }
    });
  }

  /// Directly sets or scrubs [newProgress] (0.0 to 1.0) for manual diagnostic inspection.
  void stepProgress(double newProgress) {
    final clamped = newProgress.clamp(0.0, 1.0);
    final calculatedElapsed = Duration(
      milliseconds: (clamped * state.duration.inMilliseconds).round(),
    );

    if (clamped >= 1.0) {
      completeCrossfade();
    } else {
      CrossfadePhase phase;
      if (clamped <= 0.0) {
        phase = CrossfadePhase.idle;
      } else if (clamped >= 0.95) {
        phase = CrossfadePhase.finishing;
      } else {
        phase = CrossfadePhase.fading;
      }

      final metrics = _computeVolumes(clamped, state.curveMode);

      audioPort.setVolume(state.outgoingEngineId, metrics.vOut);
      audioPort.setVolume(state.incomingEngineId, metrics.vIn);

      state = state.copyWith(
        isActive: clamped > 0.0 && clamped < 1.0,
        phase: phase,
        progress: clamped,
        outgoingVolume: metrics.vOut,
        incomingVolume: metrics.vIn,
        totalPower: metrics.totalPower,
        decibelsOut: metrics.dbOut,
        decibelsIn: metrics.dbIn,
        elapsed: calculatedElapsed,
        isDualEngineActive: clamped > 0.0 && clamped < 1.0,
      );
    }
  }

  /// Deterministic step method advancing transition by [delta].
  void tick(Duration delta) {
    if (!state.isActive || state.isPaused) return;

    final newElapsed = state.elapsed + delta;
    if (newElapsed >= state.duration) {
      completeCrossfade();
    } else {
      final newProgress = newElapsed.inMilliseconds / state.duration.inMilliseconds;
      _applyProgress(newProgress, elapsed: newElapsed);
    }
  }

  void _applyProgress(double progress, {required Duration elapsed}) {
    final clamped = progress.clamp(0.0, 1.0);
    final metrics = _computeVolumes(clamped, state.curveMode);

    CrossfadePhase phase;
    if (clamped >= 0.95) {
      phase = CrossfadePhase.finishing;
    } else {
      phase = CrossfadePhase.fading;
    }

    // Apply live volume curves to both audio engines
    audioPort.setVolume(state.outgoingEngineId, metrics.vOut);
    audioPort.setVolume(state.incomingEngineId, metrics.vIn);

    state = state.copyWith(
      phase: phase,
      progress: clamped,
      outgoingVolume: metrics.vOut,
      incomingVolume: metrics.vIn,
      totalPower: metrics.totalPower,
      decibelsOut: metrics.dbOut,
      decibelsIn: metrics.dbIn,
      elapsed: elapsed,
      isDualEngineActive: true,
    );
  }

  /// Pauses live animated crossfade progress.
  void pauseCrossfade() {
    if (state.isActive && !state.isPaused) {
      state = state.copyWith(isPaused: true);
    }
  }

  /// Resumes paused crossfade progress.
  void resumeCrossfade() {
    if (state.isActive && state.isPaused) {
      state = state.copyWith(isPaused: false);
    }
  }

  /// Gracefully finishes and completes the crossfade, swapping primary engine.
  void completeCrossfade() {
    _tickerTimer?.cancel();
    _tickerTimer = null;

    final finalMetrics = _computeVolumes(1.0, state.curveMode);

    // Shut down outgoing engine and maximize incoming engine
    audioPort.setVolume(state.outgoingEngineId, 0.0);
    audioPort.stop(state.outgoingEngineId);
    audioPort.setVolume(state.incomingEngineId, 1.0);

    state = state.copyWith(
      isActive: false,
      phase: CrossfadePhase.completed,
      progress: 1.0,
      outgoingVolume: finalMetrics.vOut,
      incomingVolume: finalMetrics.vIn,
      totalPower: finalMetrics.totalPower,
      decibelsOut: finalMetrics.dbOut,
      decibelsIn: finalMetrics.dbIn,
      elapsed: state.duration,
      isDualEngineActive: false,
      isPaused: false,
    );
  }

  /// Immediately cancels an in-flight crossfade, restoring primary engine.
  Future<void> cancelCrossfade() async {
    _tickerTimer?.cancel();
    _tickerTimer = null;

    // Restore outgoing engine to full volume and stop incoming engine
    await audioPort.setVolume(state.outgoingEngineId, 1.0);
    await audioPort.setVolume(state.incomingEngineId, 0.0);
    await audioPort.stop(state.incomingEngineId);

    final initialMetrics = _computeVolumes(0.0, state.curveMode);

    state = state.copyWith(
      isActive: false,
      phase: CrossfadePhase.idle,
      progress: 0.0,
      outgoingVolume: initialMetrics.vOut,
      incomingVolume: initialMetrics.vIn,
      totalPower: initialMetrics.totalPower,
      decibelsOut: initialMetrics.dbOut,
      decibelsIn: initialMetrics.dbIn,
      elapsed: Duration.zero,
      isDualEngineActive: false,
      isPaused: false,
    );
  }

  /// Resets state and engines back to initial idle defaults.
  Future<void> reset() async {
    await cancelCrossfade();
    state = TrueCrossfadeState.initial(
      duration: state.duration,
      curveMode: state.curveMode,
    );
  }

  /// Updates configured crossfade duration (clamped 1s to 12s) and persists it.
  Future<void> setDuration(Duration newDuration) async {
    final seconds = newDuration.inSeconds.clamp(
      kTrueCrossfadeMinSeconds,
      kTrueCrossfadeMaxSeconds,
    );
    final clampedDuration = Duration(seconds: seconds);

    state = state.copyWith(duration: clampedDuration);

    try {
      final p = _prefs ?? await TrueCrossfadePrefs.getInstance();
      await p.setInt(kTrueCrossfadeDurationPrefKey, clampedDuration.inMilliseconds);
    } catch (_) {}
  }

  /// Changes the curve algorithm mode and recalculates instantaneous volumes.
  Future<void> setCurveMode(CrossfadeCurveMode mode) async {
    final metrics = _computeVolumes(state.progress, mode);

    audioPort.setVolume(state.outgoingEngineId, metrics.vOut);
    audioPort.setVolume(state.incomingEngineId, metrics.vIn);

    state = state.copyWith(
      curveMode: mode,
      outgoingVolume: metrics.vOut,
      incomingVolume: metrics.vIn,
      totalPower: metrics.totalPower,
      decibelsOut: metrics.dbOut,
      decibelsIn: metrics.dbIn,
    );

    try {
      final p = _prefs ?? await TrueCrossfadePrefs.getInstance();
      await p.setInt(kTrueCrossfadeCurveModePrefKey, mode.index);
    } catch (_) {}
  }

  /// Swaps engine identities (e.g., promotional handoff after crossfade).
  void swapEngines() {
    final oldOutEngine = state.outgoingEngineId;
    final oldInEngine = state.incomingEngineId;
    final oldInTrack = state.incomingTrackTitle;

    state = state.copyWith(
      outgoingEngineId: oldInEngine,
      incomingEngineId: oldOutEngine,
      outgoingTrackTitle: oldInTrack,
      incomingTrackTitle: 'Next Upcoming Track',
      phase: CrossfadePhase.idle,
      progress: 0.0,
      outgoingVolume: 1.0,
      incomingVolume: 0.0,
      totalPower: 1.0,
      decibelsOut: 0.0,
      decibelsIn: -60.0,
      elapsed: Duration.zero,
      isDualEngineActive: false,
    );
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    super.dispose();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Singleton provider for the simulated dual audio engine port.
final dualEngineAudioPortProvider = Provider<DualEngineAudioPort>((ref) {
  return SimulatedDualEngineAudioPort();
});

/// Riverpod StateNotifierProvider exposing the true dual-engine crossfade controller.
final trueCrossfadeNotifierProvider =
    StateNotifierProvider<TrueCrossfadeEngineNotifier, TrueCrossfadeState>((ref) {
  final audioPort = ref.watch(dualEngineAudioPortProvider);
  return TrueCrossfadeEngineNotifier(audioPort: audioPort);
});

/// Provider exposing live overlapping progress (0.0 to 1.0).
final crossfadeProgressProvider = Provider<double>((ref) {
  return ref.watch(trueCrossfadeNotifierProvider).progress;
});

/// Provider exposing current transition phase.
final crossfadePhaseProvider = Provider<CrossfadePhase>((ref) {
  return ref.watch(trueCrossfadeNotifierProvider).phase;
});

/// Provider exposing outgoing engine volume (V_out = cos(theta)).
final crossfadeOutgoingVolumeProvider = Provider<double>((ref) {
  return ref.watch(trueCrossfadeNotifierProvider).outgoingVolume;
});

/// Provider exposing incoming engine volume (V_in = sin(theta)).
final crossfadeIncomingVolumeProvider = Provider<double>((ref) {
  return ref.watch(trueCrossfadeNotifierProvider).incomingVolume;
});

/// Provider exposing total combined acoustic power (V_out^2 + V_in^2).
final crossfadeTotalPowerProvider = Provider<double>((ref) {
  return ref.watch(trueCrossfadeNotifierProvider).totalPower;
});

/// Provider exposing whether dual audio engines are simultaneously active.
final crossfadeIsDualActiveProvider = Provider<bool>((ref) {
  return ref.watch(trueCrossfadeNotifierProvider).isDualEngineActive;
});

// ============================================================================
// Custom Painter: Dual-Engine Volume Curves Visualizer
// ============================================================================

/// CustomPainter rendering simultaneous dual player volume curves with
/// mathematical precision, grid lines, energy overlap area, and live progress needle.
class DualEngineCurvePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final CrossfadeCurveMode curveMode;
  final Color outgoingColor;
  final Color incomingColor;
  final Color gridColor;
  final Color needleColor;
  final bool showMidpoint;
  final bool showFill;

  const DualEngineCurvePainter({
    required this.progress,
    required this.curveMode,
    this.outgoingColor = const Color(0xFFFF5376), // Vibrant Coral Rose
    this.incomingColor = const Color(0xFF2DD4BF), // Vibrant Teal Cyan
    this.gridColor = const Color(0xFF2E313D),
    this.needleColor = Colors.white,
    this.showMidpoint = true,
    this.showFill = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final w = size.width;
    final h = size.height;
    const paddingLeft = 4.0;
    const paddingRight = 4.0;
    const paddingTop = 8.0;
    const paddingBottom = 16.0;

    final chartW = w - paddingLeft - paddingRight;
    final chartH = h - paddingTop - paddingBottom;
    if (chartW <= 0 || chartH <= 0) return;

    final baseLeft = paddingLeft;
    final baseTop = paddingTop;
    final baseBottom = paddingTop + chartH;

    // 1. Draw Background Grid Lines (dB markers & progress quarters)
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashPaint = Paint()
      ..color = gridColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Horizontal grid lines: 1.0 (0 dB), 0.707 (-3 dB), 0.5 (-6 dB), 0.0
    final levels = [0.0, 0.5, 0.70710678, 1.0];
    for (final level in levels) {
      final y = baseBottom - (level * chartH);
      canvas.drawLine(
        Offset(baseLeft, y),
        Offset(baseLeft + chartW, y),
        (level == 0.70710678) ? dashPaint : gridPaint,
      );
    }

    // Vertical grid lines: 0%, 25%, 50%, 75%, 100%
    for (int i = 0; i <= 4; i++) {
      final x = baseLeft + (i * 0.25 * chartW);
      canvas.drawLine(
        Offset(x, baseTop),
        Offset(x, baseBottom),
        gridPaint,
      );
    }

    // 2. Generate Points for Outgoing and Incoming Curves
    const steps = 100;
    final outPoints = <Offset>[];
    final inPoints = <Offset>[];

    for (int i = 0; i <= steps; i++) {
      final p = i / steps;
      final x = baseLeft + (p * chartW);

      double vOut;
      double vIn;
      switch (curveMode) {
        case CrossfadeCurveMode.equalPower:
          vOut = CrossfadeMath.equalPowerOut(p);
          vIn = CrossfadeMath.equalPowerIn(p);
          break;
        case CrossfadeCurveMode.linear:
          vOut = CrossfadeMath.linearOut(p);
          vIn = CrossfadeMath.linearIn(p);
          break;
        case CrossfadeCurveMode.sCurve:
          vOut = CrossfadeMath.sCurveOut(p);
          vIn = CrossfadeMath.sCurveIn(p);
          break;
      }

      final yOut = baseBottom - (vOut * chartH);
      final yIn = baseBottom - (vIn * chartH);

      outPoints.add(Offset(x, yOut));
      inPoints.add(Offset(x, yIn));
    }

    // 3. Draw Gradient Area Fills (if enabled)
    if (showFill && outPoints.isNotEmpty && inPoints.isNotEmpty) {
      // Outgoing curve fill
      final outPath = Path()..moveTo(baseLeft, baseBottom);
      for (final pt in outPoints) {
        outPath.lineTo(pt.dx, pt.dy);
      }
      outPath.lineTo(baseLeft + chartW, baseBottom);
      outPath.close();

      final outGradPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            outgoingColor.withOpacity(0.25),
            outgoingColor.withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(baseLeft, baseTop, chartW, chartH))
        ..style = PaintingStyle.fill;
      canvas.drawPath(outPath, outGradPaint);

      // Incoming curve fill
      final inPath = Path()..moveTo(baseLeft, baseBottom);
      for (final pt in inPoints) {
        inPath.lineTo(pt.dx, pt.dy);
      }
      inPath.lineTo(baseLeft + chartW, baseBottom);
      inPath.close();

      final inGradPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            incomingColor.withOpacity(0.25),
            incomingColor.withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(baseLeft, baseTop, chartW, chartH))
        ..style = PaintingStyle.fill;
      canvas.drawPath(inPath, inGradPaint);
    }

    // 4. Draw Stroke Paths for Outgoing and Incoming Curves
    final outStrokePath = Path()..moveTo(outPoints.first.dx, outPoints.first.dy);
    for (int i = 1; i < outPoints.length; i++) {
      outStrokePath.lineTo(outPoints[i].dx, outPoints[i].dy);
    }
    final outStrokePaint = Paint()
      ..color = outgoingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(outStrokePath, outStrokePaint);

    final inStrokePath = Path()..moveTo(inPoints.first.dx, inPoints.first.dy);
    for (int i = 1; i < inPoints.length; i++) {
      inStrokePath.lineTo(inPoints[i].dx, inPoints[i].dy);
    }
    final inStrokePaint = Paint()
      ..color = incomingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(inStrokePath, inStrokePaint);

    // 5. Highlight Midpoint Intersection (0.50 Progress, ~0.707 V)
    if (showMidpoint) {
      final midX = baseLeft + (0.5 * chartW);
      final midLevel = (curveMode == CrossfadeCurveMode.equalPower)
          ? 0.70710678
          : (curveMode == CrossfadeCurveMode.linear ? 0.5 : 0.5);
      final midY = baseBottom - (midLevel * chartH);

      final midDotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final midRingPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(Offset(midX, midY), 5.0, midRingPaint);
      canvas.drawCircle(Offset(midX, midY), 3.0, midDotPaint);
    }

    // 6. Draw Real-time Progress Scrub Needle & Active Cursor Node Dots
    final currentProgress = progress.clamp(0.0, 1.0);
    final needleX = baseLeft + (currentProgress * chartW);

    // Vertical scrub line
    final needlePaint = Paint()
      ..color = needleColor.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(needleX, baseTop),
      Offset(needleX, baseBottom),
      needlePaint,
    );

    // Live node on Outgoing curve
    double currentVOut;
    double currentVIn;
    switch (curveMode) {
      case CrossfadeCurveMode.equalPower:
        currentVOut = CrossfadeMath.equalPowerOut(currentProgress);
        currentVIn = CrossfadeMath.equalPowerIn(currentProgress);
        break;
      case CrossfadeCurveMode.linear:
        currentVOut = CrossfadeMath.linearOut(currentProgress);
        currentVIn = CrossfadeMath.linearIn(currentProgress);
        break;
      case CrossfadeCurveMode.sCurve:
        currentVOut = CrossfadeMath.sCurveOut(currentProgress);
        currentVIn = CrossfadeMath.sCurveIn(currentProgress);
        break;
    }

    final curOutY = baseBottom - (currentVOut * chartH);
    final curInY = baseBottom - (currentVIn * chartH);

    // Outgoing node dot with glow ring
    final curOutGlow = Paint()
      ..color = outgoingColor.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final curOutDot = Paint()
      ..color = outgoingColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, curOutY), 6.0, curOutGlow);
    canvas.drawCircle(Offset(needleX, curOutY), 3.5, curOutDot);

    // Incoming node dot with glow ring
    final curInGlow = Paint()
      ..color = incomingColor.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final curInDot = Paint()
      ..color = incomingColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, curInY), 6.0, curInGlow);
    canvas.drawCircle(Offset(needleX, curInY), 3.5, curInDot);
  }

  @override
  bool shouldRepaint(covariant DualEngineCurvePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.curveMode != curveMode ||
        oldDelegate.outgoingColor != outgoingColor ||
        oldDelegate.incomingColor != incomingColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.needleColor != needleColor;
  }
}

// ============================================================================
// Widget: CrossfadeLiveVisualizer
// ============================================================================

/// Production-grade live visualizer widget displaying simultaneous dual player
/// volume curves, real-time constant-power acoustic diagnostics, and interactive controls.
class CrossfadeLiveVisualizer extends ConsumerWidget {
  /// Whether to show the card header with title and status badge.
  final bool showHeader;

  /// Whether to display live interactive diagnostic buttons and scrub slider.
  final bool showControls;

  /// Whether to show quick duration preset chips.
  final bool showPresets;

  /// Whether to show curve algorithm selection dropdown.
  final bool showCurveSelector;

  /// Custom height for the waveform curve chart canvas.
  final double chartHeight;

  const CrossfadeLiveVisualizer({
    super.key,
    this.showHeader = true,
    this.showControls = true,
    this.showPresets = true,
    this.showCurveSelector = true,
    this.chartHeight = 160.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trueCrossfadeNotifierProvider);
    final notifier = ref.read(trueCrossfadeNotifierProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF16171B) : theme.colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF262830) : theme.colorScheme.outlineVariant;
    const outgoingColor = Color(0xFFFF5376); // Vibrant Coral Rose
    const incomingColor = Color(0xFF2DD4BF); // Vibrant Teal Cyan

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Diagnostic Header
          if (showHeader) ...[
            _buildHeader(context, state),
            const SizedBox(height: 14),
          ],

          // 2. Dual-Engine Volume Curves Canvas
          _buildCurvesCanvas(
            context,
            state,
            outgoingColor: outgoingColor,
            incomingColor: incomingColor,
          ),
          const SizedBox(height: 12),

          // 3. Curve Legend & Midpoint Callout
          _buildLegendRow(context, state, outgoingColor, incomingColor),
          const SizedBox(height: 14),

          // 4. Real-time Dual Player Metric Cards
          _buildDualMetricsRow(context, state, outgoingColor, incomingColor),
          const SizedBox(height: 14),

          // 5. Total Acoustic Power Gauge
          _buildPowerGauge(context, state),

          // 6. Interactive Diagnostic Controls
          if (showControls) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF262830), height: 1),
            const SizedBox(height: 14),
            _buildDiagnosticScrubber(context, state, notifier),
            const SizedBox(height: 12),
            _buildActionButtons(context, state, notifier),
          ],

          // 7. Duration Presets & Curve Mode Selectors
          if (showPresets || showCurveSelector) ...[
            const SizedBox(height: 12),
            _buildConfigurationRow(context, state, notifier),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TrueCrossfadeState state) {
    final theme = Theme.of(context);

    Color badgeColor;
    Color badgeTextColor;
    switch (state.phase) {
      case CrossfadePhase.idle:
        badgeColor = const Color(0xFF2E313D);
        badgeTextColor = const Color(0xFF9E9E9E);
        break;
      case CrossfadePhase.priming:
        badgeColor = const Color(0xFF5A4A1E);
        badgeTextColor = const Color(0xFFFFD54F);
        break;
      case CrossfadePhase.fading:
        badgeColor = const Color(0xFF1B4332);
        badgeTextColor = const Color(0xFF52B788);
        break;
      case CrossfadePhase.finishing:
        badgeColor = const Color(0xFF3A1F4D);
        badgeTextColor = const Color(0xFFCE93D8);
        break;
      case CrossfadePhase.completed:
        badgeColor = const Color(0xFF1C3A5A);
        badgeTextColor = const Color(0xFF64B5F6);
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFED5564).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFFED5564),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dual-Engine Crossfade Visualizer',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Constant-Power Overlap (Equal-Power DSP)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF938F99),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Phase Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeTextColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(state.phase.icon, color: badgeTextColor, size: 14),
              const SizedBox(width: 5),
              Text(
                state.phase.label.toUpperCase(),
                style: TextStyle(
                  color: badgeTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurvesCanvas(
    BuildContext context,
    TrueCrossfadeState state, {
    required Color outgoingColor,
    required Color incomingColor,
  }) {
    return Container(
      height: chartHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0F12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262830)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: DualEngineCurvePainter(
              progress: state.progress,
              curveMode: state.curveMode,
              outgoingColor: outgoingColor,
              incomingColor: incomingColor,
              gridColor: const Color(0xFF262830),
              needleColor: Colors.white,
            ),
          ),
          // Progress & Decibel Scale Labels
          Positioned(
            left: 8,
            top: 6,
            child: Text(
              '0 dB (1.0)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: (chartHeight * 0.28),
            child: Text(
              '-3.01 dB (0.707)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 4,
            child: Text(
              'Progress: ${state.formattedProgress}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(
    BuildContext context,
    TrueCrossfadeState state,
    Color outgoingColor,
    Color incomingColor,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        // Outgoing legend
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: outgoingColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'V_out = cos(theta)',
              style: TextStyle(
                color: outgoingColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        // Center Midpoint callout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2025),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2E313D)),
          ),
          child: const Text(
            'Midpoint: sqrt(2)/2 ~= 0.707 (-3dB)',
            style: TextStyle(
              color: Color(0xFFE6E1E5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Incoming legend
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: incomingColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'V_in = sin(theta)',
              style: TextStyle(
                color: incomingColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDualMetricsRow(
    BuildContext context,
    TrueCrossfadeState state,
    Color outgoingColor,
    Color incomingColor,
  ) {
    return Row(
      children: [
        // Outgoing Player Engine Card
        Expanded(
          child: _buildEngineCard(
            context,
            engineId: state.outgoingEngineId,
            roleLabel: 'OUTGOING',
            trackTitle: state.outgoingTrackTitle,
            volume: state.outgoingVolume,
            decibels: state.decibelsOut,
            accentColor: outgoingColor,
            formula: 'cos(theta)',
            isActive: state.outgoingVolume > 0.001,
          ),
        ),
        const SizedBox(width: 10),
        // Incoming Player Engine Card
        Expanded(
          child: _buildEngineCard(
            context,
            engineId: state.incomingEngineId,
            roleLabel: 'INCOMING',
            trackTitle: state.incomingTrackTitle,
            volume: state.incomingVolume,
            decibels: state.decibelsIn,
            accentColor: incomingColor,
            formula: 'sin(theta)',
            isActive: state.incomingVolume > 0.001,
          ),
        ),
      ],
    );
  }

  Widget _buildEngineCard(
    BuildContext context, {
    required String engineId,
    required String roleLabel,
    required String trackTitle,
    required double volume,
    required double decibels,
    required Color accentColor,
    required String formula,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? accentColor.withOpacity(0.5) : const Color(0xFF2E313D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                roleLabel,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                formula,
                style: const TextStyle(
                  color: Color(0xFF938F99),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            engineId,
            style: const TextStyle(
              color: Color(0xFFE6E1E5),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            trackTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF938F99),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          // Volume progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: volume.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF2E313D),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gain: ${volume.toStringAsFixed(3)}',
                style: const TextStyle(
                  color: Color(0xFFE6E1E5),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                decibels <= -59.0 ? '-inf dB' : '${decibels.toStringAsFixed(1)} dB',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerGauge(BuildContext context, TrueCrossfadeState state) {
    final power = state.totalPower;
    final fluxDb = state.powerFluxDb;
    final isPreserved = (power - 1.0).abs() < 0.05;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0F12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPreserved ? const Color(0xFF1B4332) : const Color(0xFF4A1F1F),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPreserved ? Icons.verified_rounded : Icons.warning_amber_rounded,
                  color: isPreserved ? const Color(0xFF52B788) : const Color(0xFFFF8592),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Combined Acoustic Power (V_out² + V_in²)',
                        style: TextStyle(
                          color: Color(0xFFE6E1E5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isPreserved
                            ? 'Equal-power curve preserves unity acoustic energy (0.0 dB flux)'
                            : 'Power fluctuation detected: ${fluxDb.toStringAsFixed(2)} dB',
                        style: TextStyle(
                          color: isPreserved ? const Color(0xFF938F99) : const Color(0xFFFF8592),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPreserved ? const Color(0xFF1B4332) : const Color(0xFF3E181D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              power.toStringAsFixed(4),
              style: TextStyle(
                color: isPreserved ? const Color(0xFF52B788) : const Color(0xFFFF8592),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticScrubber(
    BuildContext context,
    TrueCrossfadeState state,
    TrueCrossfadeEngineNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Diagnostic Progress Scrubber',
              style: TextStyle(
                color: Color(0xFFE6E1E5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Progress: ${(state.progress * 100).toStringAsFixed(1)}% (${state.elapsed.inSeconds}s / ${state.duration.inSeconds}s)',
              style: const TextStyle(
                color: Color(0xFFED5564),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFED5564),
            inactiveTrackColor: const Color(0xFF2E313D),
            thumbColor: const Color(0xFFED5564),
            overlayColor: const Color(0xFFED5564).withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: state.progress.clamp(0.0, 1.0),
            onChanged: (value) {
              HapticFeedback.selectionClick();
              notifier.stepProgress(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    TrueCrossfadeState state,
    TrueCrossfadeEngineNotifier notifier,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Simulate / Start Crossfade Button
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            notifier.startCrossfade();
          },
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Simulate Crossfade'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFED5564),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        // Pause / Resume Button
        OutlinedButton.icon(
          onPressed: state.isActive
              ? () {
                  HapticFeedback.lightImpact();
                  if (state.isPaused) {
                    notifier.resumeCrossfade();
                  } else {
                    notifier.pauseCrossfade();
                  }
                }
              : null,
          icon: Icon(
            state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: 18,
          ),
          label: Text(state.isPaused ? 'Resume' : 'Pause'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE6E1E5),
            side: const BorderSide(color: Color(0xFF2E313D)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        // Reset Button
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            notifier.reset();
          },
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF938F99),
            side: const BorderSide(color: Color(0xFF2E313D)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        // Swap Engines Button
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            notifier.swapEngines();
          },
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Swap Engines'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF938F99),
            side: const BorderSide(color: Color(0xFF2E313D)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationRow(
    BuildContext context,
    TrueCrossfadeState state,
    TrueCrossfadeEngineNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPresets) ...[
          const Text(
            'Transition Duration Presets',
            style: TextStyle(
              color: Color(0xFF938F99),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: kTrueCrossfadePresets.map((sec) {
              final isSelected = state.duration.inSeconds == sec;
              return ChoiceChip(
                label: Text('${sec}s'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    HapticFeedback.selectionClick();
                    notifier.setDuration(Duration(seconds: sec));
                  }
                },
                selectedColor: const Color(0xFFED5564),
                backgroundColor: const Color(0xFF1E2025),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFE6E1E5),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: isSelected ? const Color(0xFFED5564) : const Color(0xFF2E313D),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],

        if (showCurveSelector) ...[
          const Text(
            'Curve Algorithm Mode',
            style: TextStyle(
              color: Color(0xFF938F99),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2025),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2E313D)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CrossfadeCurveMode>(
                value: state.curveMode,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E2025),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE6E1E5)),
                items: CrossfadeCurveMode.values.map((mode) {
                  return DropdownMenuItem<CrossfadeCurveMode>(
                    value: mode,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mode.displayName,
                          style: const TextStyle(
                            color: Color(0xFFE6E1E5),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          mode == CrossfadeCurveMode.equalPower
                              ? '(0 dB energy flux)'
                              : '(-3.01 dB dip)',
                          style: const TextStyle(
                            color: Color(0xFF938F99),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (mode) {
                  if (mode != null) {
                    HapticFeedback.selectionClick();
                    notifier.setCurveMode(mode);
                  }
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
