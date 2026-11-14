// ============================================================================
// Softify Quality of Life (QoL): Silence Trimmer (Auto-Skip Silence DSP Engine)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Minimum silence threshold in milliseconds (200ms).
const int kSilenceThresholdMinMs = 200;

/// Maximum silence threshold in milliseconds (2000ms / 2.0s).
const int kSilenceThresholdMaxMs = 2000;

/// Default silence threshold in milliseconds (>500ms).
const int kSilenceThresholdDefaultMs = 500;

/// Default silence noise floor in decibels Full Scale (-60.0 dBFS).
const double kSilenceDefaultNoiseFloorDb = -60.0;

/// Quick preset durations for the silence detection threshold slider.
const List<int> kSilenceThresholdPresets = [200, 350, 500, 750, 1000, 1500, 2000];

/// Persistent storage key for Silence Trimmer enabled status.
const String kSilenceTrimmerEnabledKey = 'softify_silence_trimmer_enabled';

/// Persistent storage key for silence detection threshold in milliseconds.
const String kSilenceTrimmerThresholdMsKey = 'softify_silence_trimmer_threshold_ms';

/// Persistent storage key for trimming leading intro silence.
const String kSilenceTrimmerTrimLeadingKey = 'softify_silence_trimmer_trim_leading';

/// Persistent storage key for trimming trailing outro silence.
const String kSilenceTrimmerTrimTrailingKey = 'softify_silence_trimmer_trim_trailing';

/// Persistent storage key for silence noise floor in dBFS.
const String kSilenceTrimmerNoiseFloorDbKey = 'softify_silence_trimmer_noise_floor_db';

/// Tooltip message explaining silence auto-trim functionality.
const String kSilenceTrimmerTooltipDescription =
    'Automatically detects dead air at the beginning and ending of tracks '
    'exceeding the threshold (>500ms) and seeks past it for continuous, '
    'gap-free music playback.';

// ============================================================================
// Storage & Persistence Contracts
// ============================================================================

/// Contract for persistent storage compatible with SharedPreferences semantics.
abstract class SilenceTrimmerPrefsStorage {
  /// Reads a boolean value by key.
  Future<bool?> getBool(String key);

  /// Stores a boolean value by key.
  Future<bool> setBool(String key, bool value);

  /// Reads an integer value by key.
  Future<int?> getInt(String key);

  /// Stores an integer value by key.
  Future<bool> setInt(String key, int value);

  /// Reads a double value by key.
  Future<double?> getDouble(String key);

  /// Stores a double value by key.
  Future<bool> setDouble(String key, double value);
}

/// Disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class SilenceTrimmerSharedPreferencesStore implements SilenceTrimmerPrefsStorage {
  static final SilenceTrimmerSharedPreferencesStore _instance =
      SilenceTrimmerSharedPreferencesStore._internal();
  factory SilenceTrimmerSharedPreferencesStore() => _instance;
  SilenceTrimmerSharedPreferencesStore._internal();

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
      // In-memory fallback if file system access fails
      _resolveFallbackFile();
    } finally {
      _isLoaded = true;
    }
  }

  void _resolveFallbackFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory(p.join(userHome, '.softify'));
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _cacheFile = File(p.join(dir.path, 'shared_preferences.json'));
        if (_cacheFile!.existsSync()) {
          final content = _cacheFile!.readAsStringSync();
          if (content.trim().isNotEmpty) {
            final decoded = jsonDecode(content);
            if (decoded is Map<String, dynamic>) {
              _memoryCache = Map<String, dynamic>.from(decoded);
            }
          }
        }
      }
    } catch (_) {}
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
    await _persist();
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
    await _persist();
    return true;
  }

  @override
  Future<double?> getDouble(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {}
  }

  /// Sets mock values directly for testing and headless suites.
  void setMockValues(Map<String, dynamic> values) {
    _memoryCache = Map<String, dynamic>.from(values);
    _isLoaded = true;
  }

  /// Clears in-memory cache and reloads on next access.
  void clearForTesting() {
    _memoryCache.clear();
    _isLoaded = false;
    _cacheFile = null;
  }
}

// ============================================================================
// Data Models & Result Containers
// ============================================================================

/// Result of evaluating silence trimming on a track or audio buffer.
@immutable
class SilenceTrimResult {
  /// Detected duration of leading silence from track start.
  final Duration leadingSilenceDuration;

  /// Detected duration of trailing silence before track end.
  final Duration trailingSilenceDuration;

  /// Total duration of the unedited source track.
  final Duration originalDuration;

  /// Start offset where playback should begin (after leading silence).
  final Duration startOffset;

  /// Timestamp cutoff where playback should advance to the next track.
  final Duration endCutoff;

  /// Whether leading silence was trimmed (exceeded threshold and enabled).
  final bool leadingTrimmed;

  /// Whether trailing silence was trimmed (exceeded threshold and enabled).
  final bool trailingTrimmed;

  const SilenceTrimResult({
    required this.leadingSilenceDuration,
    required this.trailingSilenceDuration,
    required this.originalDuration,
    required this.startOffset,
    required this.endCutoff,
    required this.leadingTrimmed,
    required this.trailingTrimmed,
  });

  /// Factory constructor for tracks with zero silence trimmed.
  factory SilenceTrimResult.untrimmed(Duration totalDuration) {
    return SilenceTrimResult(
      leadingSilenceDuration: Duration.zero,
      trailingSilenceDuration: Duration.zero,
      originalDuration: totalDuration,
      startOffset: Duration.zero,
      endCutoff: totalDuration,
      leadingTrimmed: false,
      trailingTrimmed: false,
    );
  }

  /// Effective playback duration after trimming leading and trailing gaps.
  Duration get trimmedDuration {
    if (endCutoff <= startOffset) return Duration.zero;
    return endCutoff - startOffset;
  }

  /// Total dead air duration saved/eliminated by the silence trimmer.
  Duration get savedDuration {
    final diff = originalDuration - trimmedDuration;
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Whether any silence (leading or trailing) was trimmed.
  bool get hasAnyTrim => leadingTrimmed || trailingTrimmed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SilenceTrimResult &&
          runtimeType == other.runtimeType &&
          leadingSilenceDuration == other.leadingSilenceDuration &&
          trailingSilenceDuration == other.trailingSilenceDuration &&
          originalDuration == other.originalDuration &&
          startOffset == other.startOffset &&
          endCutoff == other.endCutoff &&
          leadingTrimmed == other.leadingTrimmed &&
          trailingTrimmed == other.trailingTrimmed;

  @override
  int get hashCode => Object.hash(
        leadingSilenceDuration,
        trailingSilenceDuration,
        originalDuration,
        startOffset,
        endCutoff,
        leadingTrimmed,
        trailingTrimmed,
      );

  @override
  String toString() => 'SilenceTrimResult('
      'startOffset: ${startOffset.inMilliseconds}ms, '
      'endCutoff: ${endCutoff.inMilliseconds}ms, '
      'saved: ${savedDuration.inMilliseconds}ms, '
      'leadingTrimmed: $leadingTrimmed, '
      'trailingTrimmed: $trailingTrimmed)';
}

/// Immutable state container managed by [SilenceTrimmerNotifier].
@immutable
class SilenceTrimmerState {
  /// Whether auto-skip silence trimming is actively enabled.
  final bool isEnabled;

  /// Silence duration threshold in milliseconds (200ms - 2000ms).
  /// Any silence exceeding this duration will be skipped. Defaults to 500ms.
  final int thresholdMs;

  /// Whether leading silence at track start is trimmed.
  final bool trimLeading;

  /// Whether trailing silence at track end is trimmed.
  final bool trimTrailing;

  /// Acoustic noise floor in dBFS below which audio is deemed silent (-60.0 dBFS).
  final double noiseFloorDb;

  /// Aggregate metric tracking count of tracks trimmed during current runtime.
  final int totalTracksTrimmed;

  /// Cumulative duration of silence saved across playback sessions.
  final Duration totalSilenceSaved;

  const SilenceTrimmerState({
    this.isEnabled = false,
    this.thresholdMs = kSilenceThresholdDefaultMs,
    this.trimLeading = true,
    this.trimTrailing = true,
    this.noiseFloorDb = kSilenceDefaultNoiseFloorDb,
    this.totalTracksTrimmed = 0,
    this.totalSilenceSaved = Duration.zero,
  });

  /// Formatted threshold label for UI display (e.g., "500 ms" or "1.5 s").
  String get formattedThreshold {
    if (thresholdMs < 1000) {
      return '$thresholdMs ms';
    }
    final seconds = thresholdMs / 1000.0;
    return seconds == seconds.roundToDouble()
        ? '${seconds.toInt()} s'
        : '${seconds.toStringAsFixed(1)} s';
  }

  /// Formatted cumulative time saved (e.g., "1m 12s saved" or "450ms saved").
  String get formattedSavedTime {
    if (totalSilenceSaved.inMinutes > 0) {
      final mins = totalSilenceSaved.inMinutes;
      final secs = totalSilenceSaved.inSeconds % 60;
      return '${mins}m ${secs}s saved';
    } else if (totalSilenceSaved.inSeconds > 0) {
      return '${totalSilenceSaved.inSeconds}s saved';
    } else if (totalSilenceSaved.inMilliseconds > 0) {
      return '${totalSilenceSaved.inMilliseconds}ms saved';
    }
    return '0s saved';
  }

  SilenceTrimmerState copyWith({
    bool? isEnabled,
    int? thresholdMs,
    bool? trimLeading,
    bool? trimTrailing,
    double? noiseFloorDb,
    int? totalTracksTrimmed,
    Duration? totalSilenceSaved,
  }) {
    return SilenceTrimmerState(
      isEnabled: isEnabled ?? this.isEnabled,
      thresholdMs: (thresholdMs ?? this.thresholdMs).clamp(
        kSilenceThresholdMinMs,
        kSilenceThresholdMaxMs,
      ),
      trimLeading: trimLeading ?? this.trimLeading,
      trimTrailing: trimTrailing ?? this.trimTrailing,
      noiseFloorDb: noiseFloorDb ?? this.noiseFloorDb,
      totalTracksTrimmed: totalTracksTrimmed ?? this.totalTracksTrimmed,
      totalSilenceSaved: totalSilenceSaved ?? this.totalSilenceSaved,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SilenceTrimmerState &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          thresholdMs == other.thresholdMs &&
          trimLeading == other.trimLeading &&
          trimTrailing == other.trimTrailing &&
          noiseFloorDb == other.noiseFloorDb &&
          totalTracksTrimmed == other.totalTracksTrimmed &&
          totalSilenceSaved == other.totalSilenceSaved;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        thresholdMs,
        trimLeading,
        trimTrailing,
        noiseFloorDb,
        totalTracksTrimmed,
        totalSilenceSaved,
      );

  @override
  String toString() => 'SilenceTrimmerState('
      'enabled: $isEnabled, '
      'threshold: ${thresholdMs}ms, '
      'trimLeading: $trimLeading, '
      'trimTrailing: $trimTrailing, '
      'noiseFloor: ${noiseFloorDb}dBFS)';
}

// ============================================================================
// DSP Silence Detection & Trimming Engine
// ============================================================================

/// Software-defined Digital Signal Processing (DSP) engine for acoustic silence
/// detection, noise floor energy computation, and sample buffer trimming.
///
/// Features:
/// - Mathematical Root Mean Square (RMS) frame energy calculation.
/// - Linear amplitude to dBFS conversion ($dB = 20 \log_{10}(RMS / peak)$).
/// - Precise leading and trailing silence detection across PCM buffers.
/// - Track-level time-boundary evaluation for media player auto-skipping.
class SilenceTrimmerEngine {
  final int thresholdMs;
  final double noiseFloorDb;
  final bool trimLeading;
  final bool trimTrailing;

  const SilenceTrimmerEngine({
    this.thresholdMs = kSilenceThresholdDefaultMs,
    this.noiseFloorDb = kSilenceDefaultNoiseFloorDb,
    this.trimLeading = true,
    this.trimTrailing = true,
  });

  /// Converts a decibel Full Scale (dBFS) value to a normalized linear amplitude [0.0, 1.0].
  @pragma('vm:prefer-inline')
  static double dbToLinear(double db) {
    if (db <= -120.0) return 0.0;
    return math.pow(10.0, db / 20.0).toDouble();
  }

  /// Converts a normalized linear amplitude [0.0, 1.0] to decibels Full Scale (dBFS).
  @pragma('vm:prefer-inline')
  static double linearToDb(double linear) {
    if (linear <= 1e-9) return -100.0;
    return 20.0 * (math.log(linear) / math.ln10);
  }

  /// Computes Root Mean Square (RMS) energy for a range of 32-bit float PCM samples [-1.0, 1.0].
  @pragma('vm:prefer-inline')
  static double computeRmsFloat32(Float32List samples, [int start = 0, int? end]) {
    final int finish = math.min(end ?? samples.length, samples.length);
    final int count = finish - start;
    if (count <= 0) return 0.0;

    double sumSquares = 0.0;
    for (int i = start; i < finish; i++) {
      final double s = samples[i];
      sumSquares += s * s;
    }
    return math.sqrt(sumSquares / count);
  }

  /// Computes Root Mean Square (RMS) energy for 16-bit integer PCM samples [-32768, 32767].
  @pragma('vm:prefer-inline')
  static double computeRmsInt16(Int16List samples, [int start = 0, int? end]) {
    final int finish = math.min(end ?? samples.length, samples.length);
    final int count = finish - start;
    if (count <= 0) return 0.0;

    double sumSquares = 0.0;
    for (int i = start; i < finish; i++) {
      final double normalized = samples[i] / 32768.0;
      sumSquares += normalized * normalized;
    }
    return math.sqrt(sumSquares / count);
  }

  /// Detects leading silence duration in 32-bit floating-point interleaved stereo or mono PCM.
  ///
  /// Analyzes window frames (default 10ms) from the start of the buffer until the
  /// RMS energy reaches or exceeds [noiseFloorDb] (default -60 dBFS).
  Duration detectLeadingSilence(
    Float32List buffer, {
    int sampleRate = 44100,
    int channels = 2,
    double? noiseFloorDb,
    int frameSizeMs = 10,
  }) {
    if (buffer.isEmpty || sampleRate <= 0 || channels <= 0) {
      return Duration.zero;
    }

    final double effectiveNoiseFloor = noiseFloorDb ?? this.noiseFloorDb;
    final double linearThreshold = dbToLinear(effectiveNoiseFloor);

    final int samplesPerFrame = math.max(
      channels,
      (sampleRate * frameSizeMs ~/ 1000) * channels,
    );

    final int totalSamples = buffer.length;
    int firstAudibleSampleIndex = totalSamples;

    for (int i = 0; i < totalSamples; i += samplesPerFrame) {
      final int end = math.min(i + samplesPerFrame, totalSamples);
      final double rms = computeRmsFloat32(buffer, i, end);
      if (rms >= linearThreshold) {
        firstAudibleSampleIndex = i;
        break;
      }
    }

    final int audioFrames = firstAudibleSampleIndex ~/ channels;
    final int microseconds = ((audioFrames * 1000000) / sampleRate).round();
    return Duration(microseconds: microseconds);
  }

  /// Detects trailing silence duration in 32-bit floating-point PCM audio.
  ///
  /// Analyzes window frames backwards from the end of the buffer until audible audio
  /// exceeding [noiseFloorDb] is encountered.
  Duration detectTrailingSilence(
    Float32List buffer, {
    int sampleRate = 44100,
    int channels = 2,
    double? noiseFloorDb,
    int frameSizeMs = 10,
  }) {
    if (buffer.isEmpty || sampleRate <= 0 || channels <= 0) {
      return Duration.zero;
    }

    final double effectiveNoiseFloor = noiseFloorDb ?? this.noiseFloorDb;
    final double linearThreshold = dbToLinear(effectiveNoiseFloor);

    final int samplesPerFrame = math.max(
      channels,
      (sampleRate * frameSizeMs ~/ 1000) * channels,
    );

    final int totalSamples = buffer.length;
    int lastAudibleSampleIndex = 0;

    for (int i = totalSamples; i > 0; i -= samplesPerFrame) {
      final int start = math.max(0, i - samplesPerFrame);
      final double rms = computeRmsFloat32(buffer, start, i);
      if (rms >= linearThreshold) {
        lastAudibleSampleIndex = i;
        break;
      }
    }

    final int silentSamples = totalSamples - lastAudibleSampleIndex;
    final int silentFrames = silentSamples ~/ channels;
    final int microseconds = ((silentFrames * 1000000) / sampleRate).round();
    return Duration(microseconds: microseconds);
  }

  /// Detects leading silence in 16-bit integer PCM audio buffers.
  Duration detectLeadingSilenceInt16(
    Int16List buffer, {
    int sampleRate = 44100,
    int channels = 2,
    double? noiseFloorDb,
    int frameSizeMs = 10,
  }) {
    if (buffer.isEmpty || sampleRate <= 0 || channels <= 0) {
      return Duration.zero;
    }

    final double effectiveNoiseFloor = noiseFloorDb ?? this.noiseFloorDb;
    final double linearThreshold = dbToLinear(effectiveNoiseFloor);

    final int samplesPerFrame = math.max(
      channels,
      (sampleRate * frameSizeMs ~/ 1000) * channels,
    );

    final int totalSamples = buffer.length;
    int firstAudibleSampleIndex = totalSamples;

    for (int i = 0; i < totalSamples; i += samplesPerFrame) {
      final int end = math.min(i + samplesPerFrame, totalSamples);
      final double rms = computeRmsInt16(buffer, i, end);
      if (rms >= linearThreshold) {
        firstAudibleSampleIndex = i;
        break;
      }
    }

    final int audioFrames = firstAudibleSampleIndex ~/ channels;
    final int microseconds = ((audioFrames * 1000000) / sampleRate).round();
    return Duration(microseconds: microseconds);
  }

  /// Detects trailing silence in 16-bit integer PCM audio buffers.
  Duration detectTrailingSilenceInt16(
    Int16List buffer, {
    int sampleRate = 44100,
    int channels = 2,
    double? noiseFloorDb,
    int frameSizeMs = 10,
  }) {
    if (buffer.isEmpty || sampleRate <= 0 || channels <= 0) {
      return Duration.zero;
    }

    final double effectiveNoiseFloor = noiseFloorDb ?? this.noiseFloorDb;
    final double linearThreshold = dbToLinear(effectiveNoiseFloor);

    final int samplesPerFrame = math.max(
      channels,
      (sampleRate * frameSizeMs ~/ 1000) * channels,
    );

    final int totalSamples = buffer.length;
    int lastAudibleSampleIndex = 0;

    for (int i = totalSamples; i > 0; i -= samplesPerFrame) {
      final int start = math.max(0, i - samplesPerFrame);
      final double rms = computeRmsInt16(buffer, start, i);
      if (rms >= linearThreshold) {
        lastAudibleSampleIndex = i;
        break;
      }
    }

    final int silentSamples = totalSamples - lastAudibleSampleIndex;
    final int silentFrames = silentSamples ~/ channels;
    final int microseconds = ((silentFrames * 1000000) / sampleRate).round();
    return Duration(microseconds: microseconds);
  }

  /// Evaluates track metadata and silence durations to determine exact trim boundaries.
  ///
  /// Leading silence is trimmed if [trimLeading] is true and [leadingSilence] >= [thresholdMs].
  /// Trailing silence is trimmed if [trimTrailing] is true and [trailingSilence] >= [thresholdMs].
  SilenceTrimResult evaluateTrack({
    required Duration totalDuration,
    required Duration leadingSilence,
    required Duration trailingSilence,
    int? thresholdMsOverride,
    bool? trimLeadingOverride,
    bool? trimTrailingOverride,
  }) {
    final int effectiveThreshold = thresholdMsOverride ?? thresholdMs;
    final bool effectiveTrimLeading = trimLeadingOverride ?? trimLeading;
    final bool effectiveTrimTrailing = trimTrailingOverride ?? trimTrailing;

    if (totalDuration <= Duration.zero) {
      return SilenceTrimResult.untrimmed(Duration.zero);
    }

    final bool shouldTrimLeading = effectiveTrimLeading &&
        leadingSilence.inMilliseconds >= effectiveThreshold &&
        leadingSilence < totalDuration;

    final bool shouldTrimTrailing = effectiveTrimTrailing &&
        trailingSilence.inMilliseconds >= effectiveThreshold &&
        trailingSilence < totalDuration;

    Duration startOffset = shouldTrimLeading ? leadingSilence : Duration.zero;
    Duration endCutoff = shouldTrimTrailing
        ? (totalDuration - trailingSilence)
        : totalDuration;

    // Safety guard against completely silent files or overlapping cutoffs
    if (startOffset >= endCutoff) {
      startOffset = Duration.zero;
      endCutoff = totalDuration;
      return SilenceTrimResult(
        leadingSilenceDuration: leadingSilence,
        trailingSilenceDuration: trailingSilence,
        originalDuration: totalDuration,
        startOffset: startOffset,
        endCutoff: endCutoff,
        leadingTrimmed: false,
        trailingTrimmed: false,
      );
    }

    return SilenceTrimResult(
      leadingSilenceDuration: leadingSilence,
      trailingSilenceDuration: trailingSilence,
      originalDuration: totalDuration,
      startOffset: startOffset,
      endCutoff: endCutoff,
      leadingTrimmed: shouldTrimLeading,
      trailingTrimmed: shouldTrimTrailing,
    );
  }

  /// Excision of leading and trailing silence directly from a 32-bit float PCM buffer.
  ///
  /// Returns a trimmed [Float32List] sub-buffer. Original buffer is unmodified.
  Float32List trimFloat32Buffer(
    Float32List buffer, {
    int sampleRate = 44100,
    int channels = 2,
    int? thresholdMsOverride,
    double? noiseFloorDb,
  }) {
    if (buffer.isEmpty || sampleRate <= 0 || channels <= 0) {
      return buffer;
    }

    final leading = detectLeadingSilence(
      buffer,
      sampleRate: sampleRate,
      channels: channels,
      noiseFloorDb: noiseFloorDb,
    );
    final trailing = detectTrailingSilence(
      buffer,
      sampleRate: sampleRate,
      channels: channels,
      noiseFloorDb: noiseFloorDb,
    );

    final int totalFrames = buffer.length ~/ channels;
    final totalDuration = Duration(
      microseconds: ((totalFrames * 1000000) / sampleRate).round(),
    );

    final result = evaluateTrack(
      totalDuration: totalDuration,
      leadingSilence: leading,
      trailingSilence: trailing,
      thresholdMsOverride: thresholdMsOverride,
    );

    if (!result.hasAnyTrim) {
      return buffer;
    }

    final int startFrame =
        ((result.startOffset.inMicroseconds * sampleRate) / 1000000).round();
    final int endFrame =
        ((result.endCutoff.inMicroseconds * sampleRate) / 1000000).round();

    final int startSample = (startFrame * channels).clamp(0, buffer.length);
    final int endSample = (endFrame * channels).clamp(startSample, buffer.length);

    if (startSample >= endSample) {
      return Float32List(0);
    }

    return Float32List.sublistView(buffer, startSample, endSample);
  }

  /// Excision of leading and trailing silence directly from a 16-bit integer PCM buffer.
  Int16List trimInt16Buffer(
    Int16List buffer, {
    int sampleRate = 44100,
    int channels = 2,
    int? thresholdMsOverride,
    double? noiseFloorDb,
  }) {
    if (buffer.isEmpty || sampleRate <= 0 || channels <= 0) {
      return buffer;
    }

    final leading = detectLeadingSilenceInt16(
      buffer,
      sampleRate: sampleRate,
      channels: channels,
      noiseFloorDb: noiseFloorDb,
    );
    final trailing = detectTrailingSilenceInt16(
      buffer,
      sampleRate: sampleRate,
      channels: channels,
      noiseFloorDb: noiseFloorDb,
    );

    final int totalFrames = buffer.length ~/ channels;
    final totalDuration = Duration(
      microseconds: ((totalFrames * 1000000) / sampleRate).round(),
    );

    final result = evaluateTrack(
      totalDuration: totalDuration,
      leadingSilence: leading,
      trailingSilence: trailing,
      thresholdMsOverride: thresholdMsOverride,
    );

    if (!result.hasAnyTrim) {
      return buffer;
    }

    final int startFrame =
        ((result.startOffset.inMicroseconds * sampleRate) / 1000000).round();
    final int endFrame =
        ((result.endCutoff.inMicroseconds * sampleRate) / 1000000).round();

    final int startSample = (startFrame * channels).clamp(0, buffer.length);
    final int endSample = (endFrame * channels).clamp(startSample, buffer.length);

    if (startSample >= endSample) {
      return Int16List(0);
    }

    return Int16List.sublistView(buffer, startSample, endSample);
  }

  /// Whether current playback position falls within trimmable leading silence.
  bool shouldSkipLeading({
    required Duration currentPosition,
    required Duration leadingSilence,
    int? thresholdMsOverride,
  }) {
    if (!trimLeading) return false;
    final threshold = thresholdMsOverride ?? thresholdMs;
    if (leadingSilence.inMilliseconds < threshold) return false;
    return currentPosition < leadingSilence;
  }

  /// Whether current playback position has entered trimmable trailing silence.
  bool shouldAdvanceTrailing({
    required Duration currentPosition,
    required Duration totalDuration,
    required Duration trailingSilence,
    int? thresholdMsOverride,
  }) {
    if (!trimTrailing) return false;
    final threshold = thresholdMsOverride ?? thresholdMs;
    if (trailingSilence.inMilliseconds < threshold) return false;
    if (totalDuration <= trailingSilence) return false;
    final cutoff = totalDuration - trailingSilence;
    return currentPosition >= cutoff;
  }

  /// Computes target initial seek timestamp when beginning track playback.
  Duration getPlayheadStartOffset(Duration leadingSilence) {
    if (!trimLeading || leadingSilence.inMilliseconds < thresholdMs) {
      return Duration.zero;
    }
    return leadingSilence;
  }

  /// Computes target timestamp cutoff for advancing to the next queued item.
  Duration getPlayheadEndCutoff(Duration totalDuration, Duration trailingSilence) {
    if (!trimTrailing ||
        trailingSilence.inMilliseconds < thresholdMs ||
        totalDuration <= trailingSilence) {
      return totalDuration;
    }
    return totalDuration - trailingSilence;
  }
}

// ============================================================================
// Riverpod StateNotifier
// ============================================================================

/// Riverpod StateNotifier managing auto-trim silence state, persistent user
/// preferences, and DSP silence detection configurations.
///
/// Handles auto-skipping leading and trailing dead air (>500ms threshold)
/// with full persistence through [SilenceTrimmerPrefsStorage].
class SilenceTrimmerNotifier extends StateNotifier<SilenceTrimmerState> {
  final SilenceTrimmerPrefsStorage _storage;

  /// Test storage override hook for zero-IO testing.
  static SilenceTrimmerPrefsStorage? customStorage;

  /// Initial state override hook for test harnesses.
  static SilenceTrimmerState? initialOverride;

  SilenceTrimmerNotifier({
    SilenceTrimmerPrefsStorage? storage,
    SilenceTrimmerState? initial,
  })  : _storage = storage ?? customStorage ?? SilenceTrimmerSharedPreferencesStore(),
        super(initial ?? initialOverride ?? const SilenceTrimmerState()) {
    _loadPersistedPreferences();
  }

  /// Loads persisted settings from storage asynchronously.
  Future<void> _loadPersistedPreferences() async {
    try {
      final isEnabled = await _storage.getBool(kSilenceTrimmerEnabledKey);
      final thresholdMs = await _storage.getInt(kSilenceTrimmerThresholdMsKey);
      final trimLeading = await _storage.getBool(kSilenceTrimmerTrimLeadingKey);
      final trimTrailing = await _storage.getBool(kSilenceTrimmerTrimTrailingKey);
      final noiseFloorDb = await _storage.getDouble(kSilenceTrimmerNoiseFloorDbKey);

      if (mounted) {
        state = state.copyWith(
          isEnabled: isEnabled ?? state.isEnabled,
          thresholdMs: thresholdMs ?? state.thresholdMs,
          trimLeading: trimLeading ?? state.trimLeading,
          trimTrailing: trimTrailing ?? state.trimTrailing,
          noiseFloorDb: noiseFloorDb ?? state.noiseFloorDb,
        );
      }
    } catch (_) {}
  }

  /// Toggles the silence trimmer enable/disable state.
  Future<void> toggle() async {
    await setEnabled(!state.isEnabled);
  }

  /// Sets whether the silence trimmer is enabled, persisting user preference.
  Future<void> setEnabled(bool enabled) async {
    if (state.isEnabled == enabled) return;
    state = state.copyWith(isEnabled: enabled);
    try {
      await _storage.setBool(kSilenceTrimmerEnabledKey, enabled);
    } catch (_) {}
  }

  /// Sets the silence duration threshold in milliseconds (clamped to 200ms - 2000ms).
  Future<void> setThresholdMs(int ms) async {
    final clamped = ms.clamp(kSilenceThresholdMinMs, kSilenceThresholdMaxMs);
    if (state.thresholdMs == clamped) return;
    state = state.copyWith(thresholdMs: clamped);
    try {
      await _storage.setInt(kSilenceTrimmerThresholdMsKey, clamped);
    } catch (_) {}
  }

  /// Sets whether leading intro silence is automatically skipped.
  Future<void> setTrimLeading(bool trim) async {
    if (state.trimLeading == trim) return;
    state = state.copyWith(trimLeading: trim);
    try {
      await _storage.setBool(kSilenceTrimmerTrimLeadingKey, trim);
    } catch (_) {}
  }

  /// Sets whether trailing outro silence is automatically skipped.
  Future<void> setTrimTrailing(bool trim) async {
    if (state.trimTrailing == trim) return;
    state = state.copyWith(trimTrailing: trim);
    try {
      await _storage.setBool(kSilenceTrimmerTrimTrailingKey, trim);
    } catch (_) {}
  }

  /// Sets the acoustic noise floor in dBFS (e.g. -60.0 dBFS).
  Future<void> setNoiseFloorDb(double db) async {
    if (state.noiseFloorDb == db) return;
    state = state.copyWith(noiseFloorDb: db);
    try {
      await _storage.setDouble(kSilenceTrimmerNoiseFloorDbKey, db);
    } catch (_) {}
  }

  /// Records a successful track trim event for runtime telemetry and UI feedback.
  void recordTrimEvent({
    required Duration leadingTrimmed,
    required Duration trailingTrimmed,
  }) {
    final saved = leadingTrimmed + trailingTrimmed;
    if (saved > Duration.zero) {
      state = state.copyWith(
        totalTracksTrimmed: state.totalTracksTrimmed + 1,
        totalSilenceSaved: state.totalSilenceSaved + saved,
      );
    }
  }

  /// Resets state and persistent preferences back to application defaults.
  Future<void> resetToDefaults() async {
    state = const SilenceTrimmerState(
      isEnabled: false,
      thresholdMs: kSilenceThresholdDefaultMs,
      trimLeading: true,
      trimTrailing: true,
      noiseFloorDb: kSilenceDefaultNoiseFloorDb,
    );
    try {
      await _storage.setBool(kSilenceTrimmerEnabledKey, false);
      await _storage.setInt(kSilenceTrimmerThresholdMsKey, kSilenceThresholdDefaultMs);
      await _storage.setBool(kSilenceTrimmerTrimLeadingKey, true);
      await _storage.setBool(kSilenceTrimmerTrimTrailingKey, true);
      await _storage.setDouble(kSilenceTrimmerNoiseFloorDbKey, kSilenceDefaultNoiseFloorDb);
    } catch (_) {}
  }

  /// Evaluates track silence against the active configuration.
  SilenceTrimResult evaluateTrack({
    required Duration totalDuration,
    required Duration leadingSilence,
    required Duration trailingSilence,
  }) {
    if (!state.isEnabled) {
      return SilenceTrimResult.untrimmed(totalDuration);
    }
    final engine = SilenceTrimmerEngine(
      thresholdMs: state.thresholdMs,
      noiseFloorDb: state.noiseFloorDb,
      trimLeading: state.trimLeading,
      trimTrailing: state.trimTrailing,
    );
    return engine.evaluateTrack(
      totalDuration: totalDuration,
      leadingSilence: leadingSilence,
      trailingSilence: trailingSilence,
    );
  }

  /// Returns true if playhead should advance past leading silence.
  bool shouldSkipLeading(Duration currentPosition, Duration leadingSilence) {
    if (!state.isEnabled) return false;
    final engine = SilenceTrimmerEngine(
      thresholdMs: state.thresholdMs,
      noiseFloorDb: state.noiseFloorDb,
      trimLeading: state.trimLeading,
      trimTrailing: state.trimTrailing,
    );
    return engine.shouldSkipLeading(
      currentPosition: currentPosition,
      leadingSilence: leadingSilence,
    );
  }

  /// Returns true if playhead should advance to next track past trailing silence.
  bool shouldAdvanceTrailing(
    Duration currentPosition,
    Duration totalDuration,
    Duration trailingSilence,
  ) {
    if (!state.isEnabled) return false;
    final engine = SilenceTrimmerEngine(
      thresholdMs: state.thresholdMs,
      noiseFloorDb: state.noiseFloorDb,
      trimLeading: state.trimLeading,
      trimTrailing: state.trimTrailing,
    );
    return engine.shouldAdvanceTrailing(
      currentPosition: currentPosition,
      totalDuration: totalDuration,
      trailingSilence: trailingSilence,
    );
  }

  /// Resets test overrides.
  static void resetForTesting() {
    customStorage = null;
    initialOverride = null;
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary Riverpod StateNotifier provider for silence trimming configuration.
final silenceTrimmerProvider =
    StateNotifierProvider<SilenceTrimmerNotifier, SilenceTrimmerState>((ref) {
  return SilenceTrimmerNotifier();
});

/// Readable provider exposing whether the silence trimmer is active (`bool`).
final isSilenceTrimmerEnabledProvider = Provider<bool>((ref) {
  return ref.watch(silenceTrimmerProvider.select((s) => s.isEnabled));
});

/// Readable provider exposing silence detection threshold in milliseconds (`int`).
final silenceThresholdMsProvider = Provider<int>((ref) {
  return ref.watch(silenceTrimmerProvider.select((s) => s.thresholdMs));
});

/// Readable provider exposing whether leading intro silence trimming is active.
final silenceTrimLeadingProvider = Provider<bool>((ref) {
  return ref.watch(silenceTrimmerProvider.select((s) => s.trimLeading));
});

/// Readable provider exposing whether trailing outro silence trimming is active.
final silenceTrimTrailingProvider = Provider<bool>((ref) {
  return ref.watch(silenceTrimmerProvider.select((s) => s.trimTrailing));
});

/// Provider exposing the configured [SilenceTrimmerEngine] reflecting current state.
final silenceTrimmerEngineProvider = Provider<SilenceTrimmerEngine>((ref) {
  final state = ref.watch(silenceTrimmerProvider);
  return SilenceTrimmerEngine(
    thresholdMs: state.thresholdMs,
    noiseFloorDb: state.noiseFloorDb,
    trimLeading: state.trimLeading,
    trimTrailing: state.trimTrailing,
  );
});

// ============================================================================
// UI Widget: SilenceTrimmerSettingsCard
// ============================================================================

/// Material 3 Card Widget providing controls for the Silence Trimmer:
/// - Enable/Disable toggle switch.
/// - Silence threshold slider (200ms - 2000ms, default 500ms).
/// - Preset buttons (200ms, 350ms, 500ms, 1000ms, 1500ms).
/// - Leading and trailing trim checkboxes.
/// - Cumulative stats badge and descriptive tooltip.
class SilenceTrimmerSettingsCard extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool showHeader;
  final bool showPresets;
  final bool showSubToggles;
  final bool showStats;
  final ValueChanged<bool>? onToggled;
  final ValueChanged<int>? onThresholdChanged;

  const SilenceTrimmerSettingsCard({
    super.key,
    this.margin,
    this.padding,
    this.showHeader = true,
    this.showPresets = true,
    this.showSubToggles = true,
    this.showStats = true,
    this.onToggled,
    this.onThresholdChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(silenceTrimmerProvider);
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    // Design Tokens & Fallbacks
    final cardColor = tokens?.card ?? theme.cardColor;
    final primaryAccent = tokens?.accent ?? theme.colorScheme.primary;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final textMuted = tokens?.textMuted ??
        theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final dividerColor = tokens?.divider ?? theme.dividerColor;
    final surfaceHighlight = tokens?.surfaceHighlight ??
        theme.colorScheme.surfaceContainerHighest;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens?.radiusCard ?? 16),
        border: Border.all(
          color: state.isEnabled
              ? primaryAccent.withValues(alpha: 0.35)
              : dividerColor.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Icon, Title, Badge, Info, and Toggle
          if (showHeader)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: state.isEnabled
                        ? primaryAccent.withValues(alpha: 0.15)
                        : textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.speed_rounded,
                    color: state.isEnabled ? primaryAccent : textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Silence Trimmer',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: state.isEnabled
                                  ? primaryAccent.withValues(alpha: 0.18)
                                  : textSecondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              state.isEnabled
                                  ? 'Active (${state.formattedThreshold})'
                                  : 'Off',
                              style: TextStyle(
                                color: state.isEnabled
                                  ? primaryAccent
                                  : textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Auto-skip silent intro & outro gaps (>500ms)',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Info Tooltip
                Tooltip(
                  message: kSilenceTrimmerTooltipDescription,
                  waitDuration: const Duration(milliseconds: 300),
                  showDuration: const Duration(seconds: 4),
                  triggerMode: TooltipTriggerMode.tap,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: textSecondary.withValues(alpha: 0.8),
                    ),
                    tooltip: 'Information',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {},
                  ),
                ),

                // Master Toggle Switch
                Semantics(
                  label: 'Silence Trimmer Auto-Skip Toggle',
                  hint: 'Enables auto-skipping of leading and trailing silence',
                  toggled: state.isEnabled,
                  child: Switch(
                    value: state.isEnabled,
                    activeTrackColor: primaryAccent,
                    onChanged: (newValue) {
                      ref.read(silenceTrimmerProvider.notifier).setEnabled(newValue);
                      onToggled?.call(newValue);
                    },
                  ),
                ),
              ],
            ),

          // Slider & Detail Controls (visible when enabled)
          if (state.isEnabled) ...[
            const SizedBox(height: 16),
            Divider(color: dividerColor.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 16),

            // Threshold Header Row with Current Value
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timelapse_rounded,
                      size: 16,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Silence Threshold',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: primaryAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    state.formattedThreshold,
                    style: TextStyle(
                      color: primaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Material 3 Expressive Slider
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4.0,
                activeTrackColor: primaryAccent,
                inactiveTrackColor: surfaceHighlight,
                thumbColor: Colors.white,
                overlayColor: primaryAccent.withValues(alpha: 0.16),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7.0,
                  elevation: 2.0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
                activeTickMarkColor: Colors.white.withValues(alpha: 0.6),
                inactiveTickMarkColor: Colors.white.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: state.thresholdMs.toDouble(),
                min: kSilenceThresholdMinMs.toDouble(),
                max: kSilenceThresholdMaxMs.toDouble(),
                divisions: (kSilenceThresholdMaxMs - kSilenceThresholdMinMs) ~/ 100,
                onChanged: (val) {
                  final ms = val.round();
                  if (ms != state.thresholdMs) {
                    HapticFeedback.selectionClick();
                  }
                  ref.read(silenceTrimmerProvider.notifier).setThresholdMs(ms);
                  onThresholdChanged?.call(ms);
                },
              ),
            ),

            // Slider Range Indicator Labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '200ms (Fast)',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '500ms (Default)',
                    style: TextStyle(
                      color: state.thresholdMs == 500 ? primaryAccent : textMuted,
                      fontSize: 11,
                      fontWeight: state.thresholdMs == 500
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  Text(
                    '2.0s (Relaxed)',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Quick Preset Chips
            if (showPresets) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: kSilenceThresholdPresets.map((presetMs) {
                  final isSelected = state.thresholdMs == presetMs;
                  final label = presetMs < 1000
                      ? '${presetMs}ms'
                      : '${(presetMs / 1000).toStringAsFixed(1)}s';

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(silenceTrimmerProvider.notifier)
                          .setThresholdMs(presetMs);
                      onThresholdChanged?.call(presetMs);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryAccent.withValues(alpha: 0.18)
                            : surfaceHighlight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? primaryAccent
                              : dividerColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        presetMs == 500 ? '$label (Def)' : label,
                        style: TextStyle(
                          color: isSelected ? primaryAccent : textSecondary,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Leading & Trailing Independent Sub-Toggles
            if (showSubToggles) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  // Leading Toggle
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ref
                            .read(silenceTrimmerProvider.notifier)
                            .setTrimLeading(!state.trimLeading);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: state.trimLeading,
                              activeColor: primaryAccent,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(silenceTrimmerProvider.notifier)
                                      .setTrimLeading(val);
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Trim intro silence',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Trailing Toggle
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ref
                            .read(silenceTrimmerProvider.notifier)
                            .setTrimTrailing(!state.trimTrailing);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: state.trimTrailing,
                              activeColor: primaryAccent,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(silenceTrimmerProvider.notifier)
                                      .setTrimTrailing(val);
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Trim outro silence',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Cumulative Telemetry / Saved Time Banner
            if (showStats && state.totalSilenceSaved > Duration.zero) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: primaryAccent.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: primaryAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Eliminated ${state.formattedSavedTime} of dead air across ${state.totalTracksTrimmed} tracks.',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
