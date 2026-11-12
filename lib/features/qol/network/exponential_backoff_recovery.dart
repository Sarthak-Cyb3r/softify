// ============================================================================
// Softify Quality of Life (QoL) Feature 50: Auto-Recovery on Network Glitch
// Exponential Backoff Reconnection Engine & Stream State Preserver
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Persistent storage key for auto-recovery enabled preference.
const String kAutoRecoveryEnabledPrefKey = 'softify_auto_recovery_network_glitch_enabled';

/// Persistent storage key for max backoff retry attempts.
const String kAutoRecoveryMaxRetriesPrefKey = 'softify_auto_recovery_max_retries';

/// Persistent storage key for total successful auto-recoveries counter.
const String kAutoRecoveryStatsRecoveredKey = 'softify_auto_recovery_stats_recovered';

/// Persistent storage key for total network glitches detected counter.
const String kAutoRecoveryStatsGlitchesKey = 'softify_auto_recovery_stats_glitches';

/// Default exponential backoff delay sequence: 500ms -> 1000ms -> 2000ms -> 4000ms.
const List<Duration> kDefaultExponentialBackoffDelays = [
  Duration(milliseconds: 500),
  Duration(milliseconds: 1000),
  Duration(milliseconds: 2000),
  Duration(milliseconds: 4000),
];

/// Default maximum number of reconnection attempts before exhaustion.
const int kDefaultMaxRecoveryAttempts = 4;

// ============================================================================
// Storage & Persistence Contracts
// ============================================================================

/// Contract for persistent key-value storage compatible with SharedPreferences.
abstract class NetworkRecoveryPrefsStorage {
  /// Reads a boolean value by key.
  Future<bool?> getBool(String key);

  /// Stores a boolean value by key.
  Future<bool> setBool(String key, bool value);

  /// Reads an integer value by key.
  Future<int?> getInt(String key);

  /// Stores an integer value by key.
  Future<bool> setInt(String key, int value);
}

/// Disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class NetworkRecoverySharedPreferencesStore implements NetworkRecoveryPrefsStorage {
  static final NetworkRecoverySharedPreferencesStore _instance =
      NetworkRecoverySharedPreferencesStore._internal();
  factory NetworkRecoverySharedPreferencesStore() => _instance;
  NetworkRecoverySharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  /// Loads persisted key-values from disk into memory.
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'shared_preferences.json'));
      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache = Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {
      // Graceful fallback to memory cache in headless/test environments
    } finally {
      _isLoaded = true;
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        if (!await _cacheFile!.parent.exists()) {
          await _cacheFile!.parent.create(recursive: true);
        }
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {}
    return true;
  }

  @override
  Future<int?> getInt(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        if (!await _cacheFile!.parent.exists()) {
          await _cacheFile!.parent.create(recursive: true);
        }
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {}
    return true;
  }

  /// Clears in-memory cache and reloads next access (for testing).
  void clearForTesting() {
    _memoryCache.clear();
    _isLoaded = false;
    _cacheFile = null;
  }
}

// ============================================================================
// Network Glitch Classifier
// ============================================================================

/// Diagnostic classifier identifying network and streaming dropouts.
class NetworkGlitchClassifier {
  const NetworkGlitchClassifier._();

  /// Determines whether [error] is an eligible transient network glitch,
  /// connection drop, socket timeout, HTTP dropout, or streaming read failure.
  static bool isGlitch(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is TimeoutException ||
        error is TlsException ||
        error is WebSocketException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    const glitchKeywords = [
      'socket',
      'network',
      'connection',
      'timed out',
      'timeout',
      'offline',
      'handshake',
      'failed host lookup',
      'broken pipe',
      'reset by peer',
      'connection reset',
      'connection abort',
      'stream error',
      'source error',
      'demuxer',
      '403',
      '404',
      '408',
      '429',
      '500',
      '502',
      '503',
      '504',
      'http status',
      'clientexception',
      'playback error',
      'ffmpeg',
      'read error',
    ];

    return glitchKeywords.any((pattern) => message.contains(pattern));
  }

  /// Generates a concise, user-friendly diagnostic description of the error.
  static String friendlyErrorMessage(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('timed out') || str.contains('timeout')) {
      return 'Stream read timed out';
    }
    if (str.contains('403') || str.contains('forbidden')) {
      return 'Stream URL expired or forbidden (403)';
    }
    if (str.contains('failed host lookup') || str.contains('offline')) {
      return 'Network connection unreachable';
    }
    if (str.contains('broken pipe') || str.contains('reset by peer') || str.contains('connection reset')) {
      return 'Audio stream disconnected abruptly';
    }
    if (str.contains('502') || str.contains('503') || str.contains('504')) {
      return 'Streaming server temporarily unavailable';
    }
    return 'Network glitch interrupted audio stream';
  }
}

// ============================================================================
// Enums & Models
// ============================================================================

/// Status phases of the exponential backoff recovery lifecycle.
enum NetworkRecoveryStatus {
  /// Normal playback; no network glitch present.
  idle,

  /// Stream error detected; playback position and active queue captured.
  glitchDetected,

  /// Waiting through the exponential backoff delay interval before attempting reconnect.
  waitingBackoff,

  /// Actively issuing reconnection attempt and restoring stream position.
  reconnecting,

  /// Reconnection succeeded; stream resumed transparently at preserved position.
  recovered,

  /// Reconnection attempts exhausted after maximum backoff retries.
  exhausted,

  /// Recovery aborted by user or active playback action.
  cancelled,
}

/// Immutable snapshot preserving playback position, track metadata,
/// and queue integrity when a network glitch occurs.
@immutable
class RecoverySnapshot {
  /// The active track playing when the glitch occurred.
  final Track track;

  /// The exact playback position when playback dropped out.
  final Duration position;

  /// The full active playlist queue preserved intact.
  final List<Track> queue;

  /// The current track index in the active queue.
  final int queueIndex;

  /// Whether playback was active when the glitch occurred.
  final bool wasPlaying;

  /// Playback speed at the time of failure.
  final double playbackSpeed;

  /// The raw error object that caused the stream drop.
  final Object error;

  /// Optional stack trace associated with the glitch.
  final StackTrace? stackTrace;

  /// Exact timestamp when the glitch snapshot was recorded.
  final DateTime timestamp;

  const RecoverySnapshot({
    required this.track,
    required this.position,
    required this.queue,
    required this.queueIndex,
    this.wasPlaying = true,
    this.playbackSpeed = 1.0,
    required this.error,
    this.stackTrace,
    required this.timestamp,
  });

  /// Formatted position string (e.g., "02:34").
  String get formattedPosition {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Human-readable summary of the preserved playback state.
  String get summary =>
      '${track.title} by ${track.artist} at $formattedPosition (Queue: ${queueIndex + 1}/${queue.length})';

  RecoverySnapshot copyWith({
    Track? track,
    Duration? position,
    List<Track>? queue,
    int? queueIndex,
    bool? wasPlaying,
    double? playbackSpeed,
    Object? error,
    StackTrace? stackTrace,
    DateTime? timestamp,
  }) {
    return RecoverySnapshot(
      track: track ?? this.track,
      position: position ?? this.position,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      wasPlaying: wasPlaying ?? this.wasPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoverySnapshot &&
          runtimeType == other.runtimeType &&
          track == other.track &&
          position == other.position &&
          queueIndex == other.queueIndex &&
          wasPlaying == other.wasPlaying &&
          playbackSpeed == other.playbackSpeed &&
          listEquals(queue, other.queue);

  @override
  int get hashCode => Object.hash(
        track,
        position,
        queueIndex,
        wasPlaying,
        playbackSpeed,
        Object.hashAll(queue),
      );

  @override
  String toString() =>
      'RecoverySnapshot(track: ${track.title}, position: $formattedPosition, queueLength: ${queue.length}, index: $queueIndex)';
}

/// Cumulative telemetry and session statistics for network recovery performance.
@immutable
class NetworkRecoveryStats {
  final int totalGlitchesDetected;
  final int totalRecoveriesSucceeded;
  final int totalRecoveriesExhausted;
  final int totalRecoveriesCancelled;

  const NetworkRecoveryStats({
    this.totalGlitchesDetected = 0,
    this.totalRecoveriesSucceeded = 0,
    this.totalRecoveriesExhausted = 0,
    this.totalRecoveriesCancelled = 0,
  });

  /// Success rate percentage of attempted recoveries (0.0% to 100.0%).
  double get successRatePercent {
    final finished = totalRecoveriesSucceeded + totalRecoveriesExhausted;
    if (finished == 0) return 100.0;
    return (totalRecoveriesSucceeded / finished) * 100.0;
  }

  NetworkRecoveryStats copyWith({
    int? totalGlitchesDetected,
    int? totalRecoveriesSucceeded,
    int? totalRecoveriesExhausted,
    int? totalRecoveriesCancelled,
  }) {
    return NetworkRecoveryStats(
      totalGlitchesDetected: totalGlitchesDetected ?? this.totalGlitchesDetected,
      totalRecoveriesSucceeded:
          totalRecoveriesSucceeded ?? this.totalRecoveriesSucceeded,
      totalRecoveriesExhausted:
          totalRecoveriesExhausted ?? this.totalRecoveriesExhausted,
      totalRecoveriesCancelled:
          totalRecoveriesCancelled ?? this.totalRecoveriesCancelled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkRecoveryStats &&
          runtimeType == other.runtimeType &&
          totalGlitchesDetected == other.totalGlitchesDetected &&
          totalRecoveriesSucceeded == other.totalRecoveriesSucceeded &&
          totalRecoveriesExhausted == other.totalRecoveriesExhausted &&
          totalRecoveriesCancelled == other.totalRecoveriesCancelled;

  @override
  int get hashCode => Object.hash(
        totalGlitchesDetected,
        totalRecoveriesSucceeded,
        totalRecoveriesExhausted,
        totalRecoveriesCancelled,
      );

  @override
  String toString() =>
      'NetworkRecoveryStats(glitches: $totalGlitchesDetected, recovered: $totalRecoveriesSucceeded, exhausted: $totalRecoveriesExhausted, rate: ${successRatePercent.toStringAsFixed(1)}%)';
}

/// Primary immutable state for exponential backoff network glitch recovery.
@immutable
class NetworkRecoveryState {
  /// Current recovery lifecycle phase.
  final NetworkRecoveryStatus status;

  /// Current attempt number (1-based, 0 when idle).
  final int currentAttempt;

  /// Maximum number of attempts allowed before exhaustion.
  final int maxAttempts;

  /// Active exponential delay applied before current/next attempt (e.g. 500ms, 1000ms, 2000ms, 4000ms).
  final Duration? currentBackoffDelay;

  /// Preserved playback snapshot captured at the moment of failure.
  final RecoverySnapshot? snapshot;

  /// User-friendly error message describing the failure.
  final String? lastErrorMessage;

  /// Projected wall-clock time when the next reconnection attempt will fire.
  final DateTime? nextAttemptAt;

  /// Whether automatic recovery is globally enabled in user settings.
  final bool isAutoRecoveryEnabled;

  /// Cumulative session performance statistics.
  final NetworkRecoveryStats stats;

  const NetworkRecoveryState({
    this.status = NetworkRecoveryStatus.idle,
    this.currentAttempt = 0,
    this.maxAttempts = kDefaultMaxRecoveryAttempts,
    this.currentBackoffDelay,
    this.snapshot,
    this.lastErrorMessage,
    this.nextAttemptAt,
    this.isAutoRecoveryEnabled = true,
    this.stats = const NetworkRecoveryStats(),
  });

  /// Whether a recovery cycle is currently in progress (waiting delay or reconnecting).
  bool get isRecovering =>
      status == NetworkRecoveryStatus.waitingBackoff ||
      status == NetworkRecoveryStatus.reconnecting;

  /// Whether recovery attempts were exhausted without success.
  bool get isExhausted => status == NetworkRecoveryStatus.exhausted;

  /// Whether a manual retry can be issued with the preserved snapshot.
  bool get canRetryManual => isExhausted && snapshot != null;

  /// Whether any active glitch state exists (non-idle and not finished).
  bool get isGlitchActive =>
      status != NetworkRecoveryStatus.idle &&
      status != NetworkRecoveryStatus.recovered;

  NetworkRecoveryState copyWith({
    NetworkRecoveryStatus? status,
    int? currentAttempt,
    int? maxAttempts,
    Duration? currentBackoffDelay,
    RecoverySnapshot? snapshot,
    String? lastErrorMessage,
    DateTime? nextAttemptAt,
    bool? isAutoRecoveryEnabled,
    NetworkRecoveryStats? stats,
  }) {
    return NetworkRecoveryState(
      status: status ?? this.status,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      currentBackoffDelay: currentBackoffDelay ?? this.currentBackoffDelay,
      snapshot: snapshot ?? this.snapshot,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      isAutoRecoveryEnabled:
          isAutoRecoveryEnabled ?? this.isAutoRecoveryEnabled,
      stats: stats ?? this.stats,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkRecoveryState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          currentAttempt == other.currentAttempt &&
          maxAttempts == other.maxAttempts &&
          currentBackoffDelay == other.currentBackoffDelay &&
          snapshot == other.snapshot &&
          lastErrorMessage == other.lastErrorMessage &&
          nextAttemptAt == other.nextAttemptAt &&
          isAutoRecoveryEnabled == other.isAutoRecoveryEnabled &&
          stats == other.stats;

  @override
  int get hashCode => Object.hash(
        status,
        currentAttempt,
        maxAttempts,
        currentBackoffDelay,
        snapshot,
        lastErrorMessage,
        nextAttemptAt,
        isAutoRecoveryEnabled,
        stats,
      );

  @override
  String toString() =>
      'NetworkRecoveryState(status: $status, attempt: $currentAttempt/$maxAttempts, delay: $currentBackoffDelay, pos: ${snapshot?.formattedPosition})';
}

// ============================================================================
// Stream Reconnect Action Callback
// ============================================================================

/// Signature for transparent stream reconnection actions.
///
/// Implementations must re-resolve the audio source for [track] and restore
/// playback seamlessly at [position] while preserving [queue] and [queueIndex].
/// Returns `true` if reconnect and seek succeeded, or `false` on failure.
typedef StreamReconnectHandler = Future<bool> Function({
  required Track track,
  required Duration position,
  required List<Track> queue,
  required int queueIndex,
  required int attemptNumber,
});

// ============================================================================
// ExponentialBackoffRecoveryManager Service
// ============================================================================

/// Enterprise-grade stream error recovery manager that attempts transparent
/// reconnects with exponential backoff (500ms, 1000ms, 2000ms, 4000ms) while
/// strictly preserving active track position and queue integrity.
class ExponentialBackoffRecoveryManager {
  static final ExponentialBackoffRecoveryManager instance =
      ExponentialBackoffRecoveryManager();

  final List<Duration> backoffDelays;
  final Future<void> Function(Duration delay) _delayFn;
  final DateTime Function() _clock;
  final NetworkRecoveryPrefsStorage _storage;

  StreamReconnectHandler? defaultReconnectHandler;
  bool _isEnabled;
  NetworkRecoveryState _state;
  bool _isCancelled = false;

  final StreamController<NetworkRecoveryState> _stateController =
      StreamController<NetworkRecoveryState>.broadcast();
  final List<void Function(NetworkRecoveryState)> _listeners = [];

  ExponentialBackoffRecoveryManager({
    List<Duration>? backoffDelays,
    Future<void> Function(Duration delay)? delayFn,
    DateTime Function()? clock,
    NetworkRecoveryPrefsStorage? storage,
    StreamReconnectHandler? defaultReconnectHandler,
    bool initialEnabled = true,
  })  : backoffDelays = List.unmodifiable(
            backoffDelays ?? kDefaultExponentialBackoffDelays),
        _delayFn = delayFn ?? Future.delayed,
        _clock = clock ?? DateTime.now,
        _storage = storage ?? NetworkRecoverySharedPreferencesStore(),
        defaultReconnectHandler = defaultReconnectHandler,
        _isEnabled = initialEnabled,
        _state = NetworkRecoveryState(
          isAutoRecoveryEnabled: initialEnabled,
          maxAttempts: (backoffDelays ?? kDefaultExponentialBackoffDelays).length,
        ) {
    _loadPersistedPreferences();
  }

  /// The active recovery state.
  NetworkRecoveryState get state => _state;

  /// Broadcast stream of recovery state updates.
  Stream<NetworkRecoveryState> get stateStream => _stateController.stream;

  /// Whether automatic recovery is enabled.
  bool get isEnabled => _isEnabled;

  /// Total maximum reconnection attempts configured.
  int get maxAttempts => backoffDelays.length;

  /// Returns the exponential backoff delay for the given [attempt] (1-based).
  ///
  /// Attempt 1: 500ms
  /// Attempt 2: 1000ms
  /// Attempt 3: 2000ms
  /// Attempt 4: 4000ms
  Duration getBackoffDelayForAttempt(int attempt) {
    if (backoffDelays.isEmpty) return Duration.zero;
    final index = (attempt - 1).clamp(0, backoffDelays.length - 1);
    return backoffDelays[index];
  }

  /// Loads persisted user configuration asynchronously.
  Future<void> _loadPersistedPreferences() async {
    try {
      final savedEnabled =
          await _storage.getBool(kAutoRecoveryEnabledPrefKey);
      if (savedEnabled != null) {
        _isEnabled = savedEnabled;
        _updateState(_state.copyWith(isAutoRecoveryEnabled: savedEnabled));
      }
    } catch (_) {}
  }

  /// Registers a synchronous listener for state changes.
  void addListener(void Function(NetworkRecoveryState) listener) {
    _listeners.add(listener);
  }

  /// Removes a registered listener.
  void removeListener(void Function(NetworkRecoveryState) listener) {
    _listeners.remove(listener);
  }

  void _updateState(NetworkRecoveryState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
    for (final listener in List.of(_listeners)) {
      listener(newState);
    }
  }

  /// Enables or disables automatic recovery, persisting the preference.
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    _updateState(_state.copyWith(isAutoRecoveryEnabled: enabled));
    try {
      await _storage.setBool(kAutoRecoveryEnabledPrefKey, enabled);
    } catch (_) {}
  }

  /// Handles a stream error or playback glitch by snapshotting track position
  /// and active queue, and executing transparent reconnects with exponential backoff:
  /// 500ms -> 1000ms -> 2000ms -> 4000ms.
  ///
  /// Preserves:
  /// - [track]: Active track entity.
  /// - [position]: Exact playback duration when error occurred.
  /// - [queue]: Full active playlist tracks list.
  /// - [queueIndex]: Active track index within [queue].
  ///
  /// Returns `true` if transparent reconnection was successful, or `false`
  /// if exhausted/cancelled.
  Future<bool> handleStreamGlitch({
    required Track track,
    required Duration position,
    required List<Track> queue,
    required int queueIndex,
    required Object error,
    bool wasPlaying = true,
    double playbackSpeed = 1.0,
    StackTrace? stackTrace,
    StreamReconnectHandler? reconnectHandler,
  }) async {
    _isCancelled = false;

    // Record glitch telemetry
    final updatedStats = _state.stats.copyWith(
      totalGlitchesDetected: _state.stats.totalGlitchesDetected + 1,
    );

    final snapshot = RecoverySnapshot(
      track: track,
      position: position,
      queue: List<Track>.unmodifiable(queue),
      queueIndex: queueIndex,
      wasPlaying: wasPlaying,
      playbackSpeed: playbackSpeed,
      error: error,
      stackTrace: stackTrace,
      timestamp: _clock(),
    );

    final friendlyMessage = NetworkGlitchClassifier.friendlyErrorMessage(error);

    // If auto-recovery is disabled, immediately exhaust and exit
    if (!_isEnabled) {
      _updateState(_state.copyWith(
        status: NetworkRecoveryStatus.exhausted,
        snapshot: snapshot,
        lastErrorMessage: '$friendlyMessage (Auto-recovery disabled)',
        stats: updatedStats.copyWith(
          totalRecoveriesExhausted: updatedStats.totalRecoveriesExhausted + 1,
        ),
      ));
      return false;
    }

    _updateState(_state.copyWith(
      status: NetworkRecoveryStatus.glitchDetected,
      snapshot: snapshot,
      lastErrorMessage: friendlyMessage,
      stats: updatedStats,
    ));

    final effectiveHandler = reconnectHandler ?? defaultReconnectHandler;
    if (effectiveHandler == null) {
      // No reconnect handler attached; preserve snapshot and exhaust
      _updateState(_state.copyWith(
        status: NetworkRecoveryStatus.exhausted,
        stats: updatedStats.copyWith(
          totalRecoveriesExhausted: updatedStats.totalRecoveriesExhausted + 1,
        ),
      ));
      return false;
    }

    // Exponential Backoff Loop: Attempt 1 to 4
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_isCancelled) {
        return false;
      }

      final delay = getBackoffDelayForAttempt(attempt);
      final scheduledTime = _clock().add(delay);

      // Phase: Waiting Backoff
      _updateState(_state.copyWith(
        status: NetworkRecoveryStatus.waitingBackoff,
        currentAttempt: attempt,
        currentBackoffDelay: delay,
        nextAttemptAt: scheduledTime,
      ));

      // Wait exponential delay (500ms, 1000ms, 2000ms, 4000ms)
      await _delayFn(delay);

      if (_isCancelled) {
        return false;
      }

      // Phase: Actively Reconnecting
      _updateState(_state.copyWith(
        status: NetworkRecoveryStatus.reconnecting,
        currentAttempt: attempt,
        nextAttemptAt: null,
      ));

      bool success = false;
      try {
        success = await effectiveHandler(
          track: snapshot.track,
          position: snapshot.position,
          queue: snapshot.queue,
          queueIndex: snapshot.queueIndex,
          attemptNumber: attempt,
        );
      } catch (e) {
        success = false;
      }

      if (_isCancelled) {
        return false;
      }

      if (success) {
        // Recovery successful! Position restored, queue preserved intact.
        final successStats = _state.stats.copyWith(
          totalRecoveriesSucceeded: _state.stats.totalRecoveriesSucceeded + 1,
        );
        _updateState(_state.copyWith(
          status: NetworkRecoveryStatus.recovered,
          currentBackoffDelay: null,
          nextAttemptAt: null,
          stats: successStats,
        ));

        // Persist recovery stats asynchronously
        try {
          await _storage.setInt(
            kAutoRecoveryStatsRecoveredKey,
            successStats.totalRecoveriesSucceeded,
          );
        } catch (_) {}

        return true;
      }
    }

    // All attempts exhausted (4 retries failed)
    final exhaustedStats = _state.stats.copyWith(
      totalRecoveriesExhausted: _state.stats.totalRecoveriesExhausted + 1,
    );

    _updateState(_state.copyWith(
      status: NetworkRecoveryStatus.exhausted,
      currentBackoffDelay: null,
      nextAttemptAt: null,
      stats: exhaustedStats,
    ));

    return false;
  }

  /// Issues a manual reconnection attempt using the preserved [RecoverySnapshot].
  ///
  /// Useful when backoff retries have exhausted and the user taps "Retry" in the UI.
  Future<bool> retryManual({StreamReconnectHandler? reconnectHandler}) async {
    final snapshot = _state.snapshot;
    if (snapshot == null) return false;

    _isCancelled = false;
    final effectiveHandler = reconnectHandler ?? defaultReconnectHandler;
    if (effectiveHandler == null) return false;

    _updateState(_state.copyWith(
      status: NetworkRecoveryStatus.reconnecting,
      currentAttempt: 1,
      currentBackoffDelay: Duration.zero,
    ));

    bool success = false;
    try {
      success = await effectiveHandler(
        track: snapshot.track,
        position: snapshot.position,
        queue: snapshot.queue,
        queueIndex: snapshot.queueIndex,
        attemptNumber: 1,
      );
    } catch (_) {
      success = false;
    }

    if (success) {
      final successStats = _state.stats.copyWith(
        totalRecoveriesSucceeded: _state.stats.totalRecoveriesSucceeded + 1,
      );
      _updateState(_state.copyWith(
        status: NetworkRecoveryStatus.recovered,
        stats: successStats,
      ));
      return true;
    } else {
      _updateState(_state.copyWith(
        status: NetworkRecoveryStatus.exhausted,
      ));
      return false;
    }
  }

  /// Cancels an active recovery in progress (e.g., when the user skips track or stops).
  void cancelRecovery() {
    _isCancelled = true;
    final cancelledStats = _state.stats.copyWith(
      totalRecoveriesCancelled: _state.stats.totalRecoveriesCancelled + 1,
    );
    _updateState(_state.copyWith(
      status: NetworkRecoveryStatus.cancelled,
      currentBackoffDelay: null,
      nextAttemptAt: null,
      stats: cancelledStats,
    ));
  }

  /// Resets the manager state to idle.
  void reset() {
    _isCancelled = true;
    _updateState(_state.copyWith(
      status: NetworkRecoveryStatus.idle,
      currentAttempt: 0,
      currentBackoffDelay: null,
      snapshot: null,
      lastErrorMessage: null,
      nextAttemptAt: null,
    ));
  }

  /// Disposes controller and resources.
  void dispose() {
    cancelRecovery();
    _listeners.clear();
    _stateController.close();
  }
}

// ============================================================================
// Riverpod StateNotifier & Providers
// ============================================================================

/// StateNotifier wrapping the [ExponentialBackoffRecoveryManager] for Riverpod.
class NetworkRecoveryNotifier extends StateNotifier<NetworkRecoveryState> {
  final ExponentialBackoffRecoveryManager _manager;

  /// Custom manager override for unit tests.
  static ExponentialBackoffRecoveryManager? customManager;

  NetworkRecoveryNotifier([ExponentialBackoffRecoveryManager? manager])
      : _manager = manager ?? customManager ?? ExponentialBackoffRecoveryManager.instance,
        super((manager ?? customManager ?? ExponentialBackoffRecoveryManager.instance).state) {
    _manager.addListener(_onManagerStateChanged);
  }

  void _onManagerStateChanged(NetworkRecoveryState newState) {
    if (mounted) {
      state = newState;
    }
  }

  /// Triggers stream recovery for a caught glitch.
  Future<bool> handleStreamGlitch({
    required Track track,
    required Duration position,
    required List<Track> queue,
    required int queueIndex,
    required Object error,
    bool wasPlaying = true,
    double playbackSpeed = 1.0,
    StackTrace? stackTrace,
    StreamReconnectHandler? reconnectHandler,
  }) {
    return _manager.handleStreamGlitch(
      track: track,
      position: position,
      queue: queue,
      queueIndex: queueIndex,
      error: error,
      wasPlaying: wasPlaying,
      playbackSpeed: playbackSpeed,
      stackTrace: stackTrace,
      reconnectHandler: reconnectHandler,
    );
  }

  /// Manually retries connection using the preserved snapshot.
  Future<bool> retryManual({StreamReconnectHandler? reconnectHandler}) {
    return _manager.retryManual(reconnectHandler: reconnectHandler);
  }

  /// Cancels any active recovery operation.
  void cancelRecovery() {
    _manager.cancelRecovery();
  }

  /// Resets recovery state back to idle.
  void reset() {
    _manager.reset();
  }

  /// Toggles automatic recovery on/off.
  Future<void> toggleAutoRecovery() async {
    await _manager.setEnabled(!state.isAutoRecoveryEnabled);
  }

  /// Sets auto recovery enabled explicitly.
  Future<void> setAutoRecoveryEnabled(bool enabled) async {
    await _manager.setEnabled(enabled);
  }

  /// Resets test overrides and state.
  static void resetForTesting() {
    customManager = null;
    ExponentialBackoffRecoveryManager.instance.reset();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerStateChanged);
    super.dispose();
  }
}

/// Primary Riverpod StateNotifierProvider for network recovery state.
final networkRecoveryStateProvider =
    StateNotifierProvider<NetworkRecoveryNotifier, NetworkRecoveryState>((ref) {
  return NetworkRecoveryNotifier();
});

/// Riverpod provider for accessing the singleton [ExponentialBackoffRecoveryManager].
final exponentialBackoffRecoveryManagerProvider =
    Provider<ExponentialBackoffRecoveryManager>((ref) {
  return ExponentialBackoffRecoveryManager.instance;
});

/// Convenience readable provider checking if auto recovery is enabled.
final isAutoRecoveryEnabledProvider = Provider<bool>((ref) {
  return ref.watch(networkRecoveryStateProvider).isAutoRecoveryEnabled;
});

/// Convenience readable provider checking if stream reconnect is in progress.
final isNetworkGlitchRecoveringProvider = Provider<bool>((ref) {
  return ref.watch(networkRecoveryStateProvider).isRecovering;
});

/// Convenience readable provider for the active [RecoverySnapshot].
final activeRecoverySnapshotProvider = Provider<RecoverySnapshot?>((ref) {
  return ref.watch(networkRecoveryStateProvider).snapshot;
});

/// Convenience readable provider for cumulative recovery telemetry.
final networkRecoveryStatsProvider = Provider<NetworkRecoveryStats>((ref) {
  return ref.watch(networkRecoveryStateProvider).stats;
});

// ============================================================================
// Material 3 UI Components
// ============================================================================

/// Interactive Material 3 docked/floating banner displaying network glitch
/// auto-recovery status with live attempt counter, preserved track position,
/// cancel button, and manual retry options when exhausted.
class NetworkGlitchRecoveryBanner extends ConsumerWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onManualRetry;
  final VoidCallback? onCancel;

  const NetworkGlitchRecoveryBanner({
    super.key,
    this.onDismiss,
    this.onManualRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recoveryState = ref.watch(networkRecoveryStateProvider);

    if (!recoveryState.isGlitchActive) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isExhausted = recoveryState.isExhausted;
    final snapshot = recoveryState.snapshot;

    final containerColor = isExhausted
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceVariant;
    final onContainerColor = isExhausted
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExhausted
              ? theme.colorScheme.error.withOpacity(0.4)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isExhausted) ...[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(
                  Icons.wifi_off_rounded,
                  color: theme.colorScheme.error,
                  size: 22,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  isExhausted
                      ? 'Reconnection Failed'
                      : 'Network Glitch Detected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onContainerColor,
                  ),
                ),
              ),
              if (!isExhausted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Attempt ${recoveryState.currentAttempt} of ${recoveryState.maxAttempts}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isExhausted
                ? (recoveryState.lastErrorMessage ??
                    'Unable to resume audio stream after 4 backoff attempts.')
                : (recoveryState.currentBackoffDelay != null
                    ? 'Reconnecting in ${(recoveryState.currentBackoffDelay!.inMilliseconds)}ms • Resuming at ${snapshot?.formattedPosition ?? "current position"}...'
                    : 'Re-establishing stream at ${snapshot?.formattedPosition ?? "current position"}...'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: onContainerColor.withOpacity(0.9),
            ),
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_note_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${snapshot.track.title} • Preserved at ${snapshot.formattedPosition}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isExhausted) ...[
                TextButton(
                  onPressed: () {
                    ref
                        .read(networkRecoveryStateProvider.notifier)
                        .cancelRecovery();
                    onCancel?.call();
                  },
                  child: const Text('Cancel'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () {
                    ref.read(networkRecoveryStateProvider.notifier).reset();
                    onDismiss?.call();
                  },
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    if (onManualRetry != null) {
                      onManualRetry!();
                    } else {
                      await ref
                          .read(networkRecoveryStateProvider.notifier)
                          .retryManual();
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry Now'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact status indicator badge showing live reconnection progress.
class NetworkRecoveryStatusIndicator extends ConsumerWidget {
  const NetworkRecoveryStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recoveryState = ref.watch(networkRecoveryStateProvider);

    if (!recoveryState.isRecovering) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Reconnecting (${recoveryState.currentAttempt}/${recoveryState.maxAttempts})',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Material 3 Settings SwitchListTile for toggling network auto-recovery.
class NetworkRecoverySettingsTile extends ConsumerWidget {
  const NetworkRecoverySettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(isAutoRecoveryEnabledProvider);
    final theme = Theme.of(context);

    return SwitchListTile(
      secondary: Icon(
        Icons.wifi_protected_setup_rounded,
        color: isEnabled ? theme.colorScheme.primary : null,
      ),
      title: const Text('Auto-Recover on Network Glitch'),
      subtitle: const Text(
        'Automatically reconnects and restores track position with exponential backoff (500ms, 1s, 2s, 4s)',
      ),
      value: isEnabled,
      onChanged: (value) {
        ref
            .read(networkRecoveryStateProvider.notifier)
            .setAutoRecoveryEnabled(value);
      },
    );
  }
}

/// Card component rendering recovery performance statistics and telemetry.
class NetworkRecoveryStatsCard extends ConsumerWidget {
  const NetworkRecoveryStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(networkRecoveryStatsProvider);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Network Recovery Telemetry',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatItem(
                  label: 'Glitches Caught',
                  value: '${stats.totalGlitchesDetected}',
                ),
                _StatItem(
                  label: 'Recovered',
                  value: '${stats.totalRecoveriesSucceeded}',
                  valueColor: Colors.greenAccent.shade700,
                ),
                _StatItem(
                  label: 'Success Rate',
                  value: '${stats.successRatePercent.toStringAsFixed(0)}%',
                  valueColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
