import 'dart:async';

/// Monotonic audio playback state tuple directly modeled after Spotify's
/// kernel reference timing tuple: <t_ref, P_ref, speed, isPaused, isBuffering>.
class AudioClockState {
  /// Monotonic timestamp (in microseconds) when this reference point was sampled.
  final int timestampMicros;

  /// Hardware sample position (in milliseconds) as of [timestampMicros].
  final int positionMs;

  /// Playback speed multiplier (1.0 = normal).
  final double speed;

  /// True if playback is paused.
  final bool isPaused;

  /// True if stream buffer is currently starving/rebuffering.
  final bool isBuffering;

  /// Track duration in milliseconds.
  final int durationMs;

  const AudioClockState({
    required this.timestampMicros,
    required this.positionMs,
    this.speed = 1.0,
    this.isPaused = false,
    this.isBuffering = false,
    this.durationMs = 0,
  });

  /// Initial idle state.
  static const AudioClockState idle = AudioClockState(
    timestampMicros: 0,
    positionMs: 0,
    isPaused: true,
  );
}

/// Known output sink categories corresponding to Spotify's
/// `output_connection_type` telemetry and latency compensation.
enum AudioOutputSinkCategory {
  /// Internal speakers (low DAC latency ~25ms).
  internalSpeaker,

  /// 3.5mm or USB-C wired headphones / DAC (~35ms latency).
  wiredHeadphones,

  /// Bluetooth A2DP (typical kernel transport delay ~100-200ms).
  bluetoothA2DP,

  /// Linux PipeWire / PulseAudio network sink or AirPlay (~150ms).
  networkSink,
}

/// High-resolution monotonic audio clock service for Softify.
/// Eliminates UI seekbar and lyric drift by anchoring playback
/// to monotonic kernel hardware time rather than periodic UI polling.
class AudioClockService {
  static final AudioClockService instance = AudioClockService._internal();

  AudioClockService._internal() {
    _stopwatch = Stopwatch()..start();
  }

  late final Stopwatch _stopwatch;
  AudioClockState _currentState = AudioClockState.idle;

  AudioOutputSinkCategory _currentSink = AudioOutputSinkCategory.internalSpeaker;
  int _manualSinkLatencyAdjustmentMs = 0;

  final _stateController = StreamController<AudioClockState>.broadcast();
  Stream<AudioClockState> get stateStream => _stateController.stream;

  AudioClockState get currentState => _currentState;
  AudioOutputSinkCategory get currentSink => _currentSink;

  /// Default latency compensation map in milliseconds per sink category.
  static const Map<AudioOutputSinkCategory, int> defaultSinkLatencies = {
    AudioOutputSinkCategory.internalSpeaker: 25,
    AudioOutputSinkCategory.wiredHeadphones: 35,
    AudioOutputSinkCategory.bluetoothA2DP: 130,
    AudioOutputSinkCategory.networkSink: 160,
  };

  /// Updates current active audio sink device category.
  void setOutputSink(AudioOutputSinkCategory sink, {int customLatencyMs = 0}) {
    _currentSink = sink;
    _manualSinkLatencyAdjustmentMs = customLatencyMs;
  }

  /// Calculates total hardware and transport delay to subtract from reference position.
  int get activeSinkDelayMs {
    final base = defaultSinkLatencies[_currentSink] ?? 35;
    return (base + _manualSinkLatencyAdjustmentMs).clamp(0, 1000);
  }

  /// Current monotonic time in microseconds.
  int get currentMonotonicMicros => _stopwatch.elapsedMicroseconds;

  /// Synchronizes a new reference anchor from the native audio engine.
  void updateAnchor({
    required int positionMs,
    required int durationMs,
    bool isPaused = false,
    bool isBuffering = false,
    double speed = 1.0,
  }) {
    _currentState = AudioClockState(
      timestampMicros: currentMonotonicMicros,
      positionMs: positionMs,
      durationMs: durationMs,
      isPaused: isPaused,
      isBuffering: isBuffering,
      speed: speed,
    );
    _stateController.add(_currentState);
  }

  /// Extrapolates current continuous playback position in milliseconds.
  ///
  /// Formula: P(t) = P_ref + (t - t_ref) * speed - sinkDelay
  double get extrapolatedPositionMs {
    if (_currentState.positionMs <= 0 && _currentState.timestampMicros == 0) {
      return 0.0;
    }

    if (_currentState.isPaused || _currentState.isBuffering) {
      return _currentState.positionMs.toDouble();
    }

    final elapsedMicros = currentMonotonicMicros - _currentState.timestampMicros;
    final elapsedMs = (elapsedMicros / 1000.0) * _currentState.speed;

    // Compensate for hardware DAC ring buffer and Bluetooth transport delay
    final rawPosition = _currentState.positionMs + elapsedMs - activeSinkDelayMs;

    // Clamp between 0 and duration (if known)
    if (_currentState.durationMs > 0) {
      return rawPosition.clamp(0.0, _currentState.durationMs.toDouble());
    }
    return rawPosition < 0.0 ? 0.0 : rawPosition;
  }

  /// Extrapolates playback progress fraction in [0.0, 1.0].
  double get extrapolatedProgress {
    if (_currentState.durationMs <= 0) return 0.0;
    return (extrapolatedPositionMs / _currentState.durationMs).clamp(0.0, 1.0);
  }

  void dispose() {
    _stateController.close();
  }
}
