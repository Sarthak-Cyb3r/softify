// ============================================================================
// Softify - Quality of Life (QoL) Features
// Feature 52: Configurable Audio Lookahead Buffer
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/database/app_database.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/shared/app_surface.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Minimum audio lookahead buffer duration in seconds (10s).
const int kMinLookaheadBufferSeconds = 10;

/// Maximum audio lookahead buffer duration in seconds (60s).
const int kMaxLookaheadBufferSeconds = 60;

/// Default audio lookahead buffer duration in seconds (30s).
const int kDefaultLookaheadBufferSeconds = 30;

/// Buffer duration used for underground transit / subway mode (60s).
const int kSubwayModeBufferSeconds = 60;

/// Buffer duration used for commuter transit routes (45s).
const int kTransitBufferSeconds = 45;

/// SharedPreferences persistent storage key for audio lookahead buffer.
const String kLookaheadBufferPrefKey = 'softify_lookahead_buffer_seconds';

/// SharedPreferences persistent storage key for subway/tunnel mode toggle.
const String kLookaheadSubwayModePrefKey = 'softify_lookahead_subway_mode';

/// Drift database settings table key for lookahead buffer persistence.
const String kLookaheadBufferDbKey = 'audio_lookahead_buffer_seconds';

/// Step divisions for the lookahead buffer slider (5-second increments).
const int kLookaheadSliderStep = 5;

// ============================================================================
// Presets
// ============================================================================

/// Preset lookahead buffer configurations tailored for common listening environments.
enum LookaheadPreset {
  /// 10 seconds: Minimal lookahead buffer for rapid track initiation and low memory.
  minimal(
    seconds: 10,
    label: '10s Minimal',
    subtitle: 'Fast start & lowest RAM',
    icon: Icons.flash_on_rounded,
  ),

  /// 30 seconds: Standard balanced buffer for everyday home Wi-Fi and 4G/5G mobile data.
  standard(
    seconds: 30,
    label: '30s Default',
    subtitle: 'Balanced for Wi-Fi & 4G/5G',
    icon: Icons.network_check_rounded,
  ),

  /// 45 seconds: Extended buffer for buses, trains, and spotty surface transit routes.
  transit(
    seconds: 45,
    label: '45s Transit',
    subtitle: 'Trains & spotty transit',
    icon: Icons.directions_transit_rounded,
  ),

  /// 60 seconds: Aggressive buffer for deep underground subway commutes and dead zones.
  subway(
    seconds: 60,
    label: '60s Subway',
    subtitle: 'Deep subway & dead zones',
    icon: Icons.subway_rounded,
  );

  final int seconds;
  final String label;
  final String subtitle;
  final IconData icon;

  const LookaheadPreset({
    required this.seconds,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

// ============================================================================
// Pure Calculation Helper: LookaheadBufferCalculator
// ============================================================================

/// Pure functions for buffer math, memory estimations, and lookahead coverage.
class LookaheadBufferCalculator {
  const LookaheadBufferCalculator._();

  /// Clamps [seconds] to the valid lookahead range [10s, 60s].
  static int clampSeconds(int seconds) {
    if (seconds < kMinLookaheadBufferSeconds) return kMinLookaheadBufferSeconds;
    if (seconds > kMaxLookaheadBufferSeconds) return kMaxLookaheadBufferSeconds;
    return seconds;
  }

  /// Calculates estimated uncompressed audio buffer footprint in bytes
  /// assuming constant bitrate [bitrateKbps] (default 320 kbps High Quality MP3/AAC).
  static int estimateBufferBytes(int seconds, {int bitrateKbps = 320}) {
    final clamped = clampSeconds(seconds);
    return ((bitrateKbps * 1000) / 8 * clamped).round();
  }

  /// Calculates estimated audio buffer footprint in Megabytes (MB).
  static double estimateBufferMb(int seconds, {int bitrateKbps = 320}) {
    return estimateBufferBytes(seconds, bitrateKbps: bitrateKbps) / (1024 * 1024);
  }

  /// Computes the lookahead coverage ratio between [0.0] and [1.0] representing
  /// how much of the desired [targetBuffer] is currently buffered ahead of [currentPosition].
  static double calculateCoverageRatio({
    required Duration currentPosition,
    required Duration bufferedPosition,
    required Duration targetBuffer,
  }) {
    if (targetBuffer <= Duration.zero) return 1.0;
    final cushion = bufferedPosition - currentPosition;
    if (cushion <= Duration.zero) return 0.0;
    final ratio = cushion.inMilliseconds / targetBuffer.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  /// Computes remaining time cushion between [bufferedPosition] and [currentPosition].
  static Duration calculateCushion({
    required Duration currentPosition,
    required Duration bufferedPosition,
  }) {
    final diff = bufferedPosition - currentPosition;
    return diff < Duration.zero ? Duration.zero : diff;
  }

  /// Checks whether buffered position provides sufficient lookahead margin
  /// to satisfy [targetBuffer].
  static bool isBufferSufficient({
    required Duration currentPosition,
    required Duration bufferedPosition,
    required Duration targetBuffer,
  }) {
    return (bufferedPosition - currentPosition) >= targetBuffer;
  }

  /// Matches [seconds] to a known [LookaheadPreset], if applicable.
  static LookaheadPreset? matchPreset(int seconds) {
    for (final preset in LookaheadPreset.values) {
      if (preset.seconds == seconds) return preset;
    }
    return null;
  }

  /// Returns user-facing recommendation text based on lookahead duration.
  static String getRecommendation(int seconds) {
    if (seconds <= 15) {
      return 'Instant playback start with negligible memory usage. Ideal for high-speed fiber or metered mobile connections.';
    } else if (seconds <= 35) {
      return 'Standard balanced lookahead buffer. Recommended for steady Wi-Fi and everyday 4G/5G mobile streaming.';
    } else if (seconds <= 50) {
      return 'Extended buffer cushion. Recommended for train routes, highway driving, and intermittent cellular connectivity.';
    } else {
      return 'Maximum preloading cushion. Pre-caches up to 60 seconds of audio to survive underground subway tunnels and deep dead zones.';
    }
  }
}

// ============================================================================
// Self-Contained SharedPreferences Persistence Layer
// ============================================================================

/// Self-contained, durable SharedPreferences engine matching the standard
/// `package:shared_preferences` interface.
///
/// Enables seamless local disk persistence for settings across desktop sessions
/// without requiring external native plugin dependencies in test/headless runs.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Synchronously accessible cached singleton instance if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock initial values for test suites and unit harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Resolves or initializes the SharedPreferences singleton instance.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;
    try {
      file = await _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key.toString()] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // In-memory fallback if file system access fails
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static Future<File?> _resolveStorageFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final targetDir = Directory(dir.path);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return File(p.join(dir.path, 'shared_preferences.json'));
    } catch (_) {
      try {
        final home = Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            Platform.environment['LOCALAPPDATA'];
        if (home != null && home.isNotEmpty) {
          final dir = Directory(p.join(home, '.softify'));
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return File(p.join(dir.path, 'shared_preferences.json'));
        }
      } catch (_) {}
      return File('.softify_shared_preferences.json');
    }
  }

  Future<void> _persist() async {
    final file = _storageFile;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_preferenceStore);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  int? getInt(String key) {
    final val = _preferenceStore[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _preferenceStore[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final val = _preferenceStore[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  bool containsKey(String key) => _preferenceStore.containsKey(key);

  Future<bool> remove(String key) async {
    _preferenceStore.remove(key);
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _preferenceStore.clear();
    await _persist();
    return true;
  }
}

// ============================================================================
// Immutable State: LookaheadBufferState
// ============================================================================

/// Immutable state encapsulating lookahead buffer configuration, subway mode,
/// and live memory/coverage telemetry.
@immutable
class LookaheadBufferState {
  /// Current audio lookahead buffer in seconds (clamped between 10s and 60s).
  final int bufferSeconds;

  /// Whether aggressive subway / tunnel mode is actively overriding the buffer.
  final bool isSubwayMode;

  /// Preserved buffer duration in seconds prior to entering subway mode,
  /// used to restore user preference when exiting subway mode.
  final int previousNonSubwaySeconds;

  const LookaheadBufferState({
    this.bufferSeconds = kDefaultLookaheadBufferSeconds,
    this.isSubwayMode = false,
    this.previousNonSubwaySeconds = kDefaultLookaheadBufferSeconds,
  });

  /// The buffer duration represented as a [Duration] object.
  Duration get bufferDuration => Duration(seconds: bufferSeconds);

  /// Estimated RAM footprint in Megabytes for this buffer duration at 320 kbps.
  double get estimatedMemoryMb =>
      LookaheadBufferCalculator.estimateBufferMb(bufferSeconds);

  /// Formatted memory footprint string (e.g., '~1.2 MB').
  String get formattedMemoryEstimate =>
      '~${estimatedMemoryMb.toStringAsFixed(1)} MB';

  /// Human-readable buffer duration label (e.g., '30s').
  String get formattedDuration => '${bufferSeconds}s';

  /// Active preset matching the current buffer seconds, if any.
  LookaheadPreset? get currentPreset =>
      LookaheadBufferCalculator.matchPreset(bufferSeconds);

  /// True if current configuration matches the default 30-second buffer.
  bool get isDefault =>
      bufferSeconds == kDefaultLookaheadBufferSeconds && !isSubwayMode;

  /// True if buffer is set to the minimum limit (10s).
  bool get isMin => bufferSeconds == kMinLookaheadBufferSeconds;

  /// True if buffer is set to the maximum limit (60s).
  bool get isMax => bufferSeconds == kMaxLookaheadBufferSeconds;

  /// User-facing recommendation for current buffer duration.
  String get recommendationText =>
      LookaheadBufferCalculator.getRecommendation(bufferSeconds);

  LookaheadBufferState copyWith({
    int? bufferSeconds,
    bool? isSubwayMode,
    int? previousNonSubwaySeconds,
  }) {
    return LookaheadBufferState(
      bufferSeconds: bufferSeconds ?? this.bufferSeconds,
      isSubwayMode: isSubwayMode ?? this.isSubwayMode,
      previousNonSubwaySeconds:
          previousNonSubwaySeconds ?? this.previousNonSubwaySeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookaheadBufferState &&
          runtimeType == other.runtimeType &&
          bufferSeconds == other.bufferSeconds &&
          isSubwayMode == other.isSubwayMode &&
          previousNonSubwaySeconds == other.previousNonSubwaySeconds;

  @override
  int get hashCode => Object.hash(
        bufferSeconds,
        isSubwayMode,
        previousNonSubwaySeconds,
      );

  @override
  String toString() =>
      'LookaheadBufferState(bufferSeconds: $bufferSeconds, isSubwayMode: $isSubwayMode, previous: $previousNonSubwaySeconds)';
}

// ============================================================================
// StateNotifier & Riverpod State Management
// ============================================================================

/// Manages lookahead buffer duration and subway mode state, coordinating
/// persistence across [SharedPreferences] and the local [AppDatabase].
class LookaheadBufferNotifier extends StateNotifier<LookaheadBufferState> {
  final Ref? _ref;
  final AppDatabase? _db;

  LookaheadBufferNotifier([this._ref, this._db])
      : super(const LookaheadBufferState()) {
    _loadPersistedSettings();
  }

  AppDatabase? get _effectiveDb {
    if (_db != null) return _db;
    try {
      if (_ref != null) {
        return _ref!.read(databaseProvider);
      }
    } catch (_) {}
    return null;
  }

  /// Loads persisted lookahead buffer and subway mode states from SharedPreferences
  /// or fallback Drift database settings table.
  Future<void> _loadPersistedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      int initialSeconds = kDefaultLookaheadBufferSeconds;
      bool initialSubway = false;
      int initialPrevious = kDefaultLookaheadBufferSeconds;

      // 1. Read SharedPreferences
      final savedSeconds = prefs.getInt(kLookaheadBufferPrefKey);
      final savedSubway = prefs.getBool(kLookaheadSubwayModePrefKey);

      if (savedSeconds != null) {
        initialSeconds = LookaheadBufferCalculator.clampSeconds(savedSeconds);
      }
      if (savedSubway != null) {
        initialSubway = savedSubway;
      }

      // 2. Fallback to Drift AppDatabase settings if SharedPreferences not populated
      final db = _effectiveDb;
      if (db != null && savedSeconds == null) {
        final row = await (db.select(db.settings)
              ..where((t) => t.key.equals(kLookaheadBufferDbKey)))
            .getSingleOrNull();
        if (row != null) {
          final parsed = int.tryParse(row.value.trim());
          if (parsed != null) {
            initialSeconds = LookaheadBufferCalculator.clampSeconds(parsed);
          }
        }
      }

      if (initialSubway) {
        initialPrevious = initialSeconds == kSubwayModeBufferSeconds
            ? kDefaultLookaheadBufferSeconds
            : initialSeconds;
        initialSeconds = kSubwayModeBufferSeconds;
      } else {
        initialPrevious = initialSeconds;
      }

      if (mounted) {
        state = LookaheadBufferState(
          bufferSeconds: initialSeconds,
          isSubwayMode: initialSubway,
          previousNonSubwaySeconds: initialPrevious,
        );
      }
    } catch (_) {
      // Graceful fallback to default state
    }
  }

  /// Sets lookahead buffer duration in seconds, clamped between 10s and 60s.
  /// Automatically resets subway mode if a custom value different from 60s is chosen.
  Future<void> setBufferSeconds(int seconds) async {
    final clamped = LookaheadBufferCalculator.clampSeconds(seconds);
    final isSubway = clamped == kSubwayModeBufferSeconds && state.isSubwayMode;

    state = state.copyWith(
      bufferSeconds: clamped,
      isSubwayMode: isSubway,
      previousNonSubwaySeconds:
          clamped == kSubwayModeBufferSeconds ? state.previousNonSubwaySeconds : clamped,
    );

    await _persist();
  }

  /// Sets lookahead buffer duration via a [Duration] object.
  Future<void> setBufferDuration(Duration duration) async {
    await setBufferSeconds(duration.inSeconds);
  }

  /// Toggles subway/tunnel mode. When enabled, sets lookahead buffer to 60s
  /// and saves the previous setting. When disabled, restores previous buffer duration.
  Future<void> toggleSubwayMode() async {
    await setSubwayMode(!state.isSubwayMode);
  }

  /// Enables or disables subway/tunnel mode.
  Future<void> setSubwayMode(bool enabled) async {
    if (state.isSubwayMode == enabled) return;

    if (enabled) {
      final prev = state.bufferSeconds;
      state = state.copyWith(
        bufferSeconds: kSubwayModeBufferSeconds,
        isSubwayMode: true,
        previousNonSubwaySeconds: prev,
      );
    } else {
      final restored = state.previousNonSubwaySeconds == kSubwayModeBufferSeconds
          ? kDefaultLookaheadBufferSeconds
          : state.previousNonSubwaySeconds;
      state = state.copyWith(
        bufferSeconds: restored,
        isSubwayMode: false,
      );
    }

    await _persist();
  }

  /// Applies a predefined lookahead preset.
  Future<void> applyPreset(LookaheadPreset preset) async {
    if (preset == LookaheadPreset.subway) {
      await setSubwayMode(true);
    } else {
      state = state.copyWith(
        bufferSeconds: preset.seconds,
        isSubwayMode: false,
        previousNonSubwaySeconds: preset.seconds,
      );
      await _persist();
    }
  }

  /// Resets lookahead buffer to default (30s) and turns off subway mode.
  Future<void> resetToDefault() async {
    state = const LookaheadBufferState(
      bufferSeconds: kDefaultLookaheadBufferSeconds,
      isSubwayMode: false,
      previousNonSubwaySeconds: kDefaultLookaheadBufferSeconds,
    );
    await _persist();
  }

  /// Steps buffer duration up by [step] seconds (default 5s).
  Future<void> stepIncrease([int step = kLookaheadSliderStep]) async {
    await setBufferSeconds(state.bufferSeconds + step);
  }

  /// Steps buffer duration down by [step] seconds (default 5s).
  Future<void> stepDecrease([int step = kLookaheadSliderStep]) async {
    await setBufferSeconds(state.bufferSeconds - step);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLookaheadBufferPrefKey, state.bufferSeconds);
      await prefs.setBool(kLookaheadSubwayModePrefKey, state.isSubwayMode);

      final db = _effectiveDb;
      if (db != null) {
        await db.into(db.settings).insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: kLookaheadBufferDbKey,
                value: state.bufferSeconds.toString(),
              ),
            );
      }
    } catch (_) {}
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Central state notifier provider for lookahead buffer configuration.
final lookaheadBufferProvider =
    StateNotifierProvider<LookaheadBufferNotifier, LookaheadBufferState>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {
    // Allows testing in isolation without databaseProvider registered
  }
  return LookaheadBufferNotifier(ref, db);
});

/// Exposes the current lookahead buffer seconds (10s to 60s).
final lookaheadBufferSecondsProvider = Provider<int>((ref) {
  return ref.watch(lookaheadBufferProvider).bufferSeconds;
});

/// Exposes the current lookahead buffer duration as a [Duration].
final lookaheadBufferDurationProvider = Provider<Duration>((ref) {
  return ref.watch(lookaheadBufferProvider).bufferDuration;
});

/// Exposes whether subway / tunnel mode is actively overriding buffer to 60s.
final isSubwayModeEnabledProvider = Provider<bool>((ref) {
  return ref.watch(lookaheadBufferProvider).isSubwayMode;
});

/// Computes lookahead buffer coverage ratio [0.0..1.0] for active playback.
final lookaheadCoverageProvider = Provider.family<double,
    ({Duration current, Duration buffered})>((ref, positions) {
  final targetDuration = ref.watch(lookaheadBufferDurationProvider);
  return LookaheadBufferCalculator.calculateCoverageRatio(
    currentPosition: positions.current,
    bufferedPosition: positions.buffered,
    targetBuffer: targetDuration,
  );
});

// ============================================================================
// Widget: LookaheadBufferSlider
// ============================================================================

/// Fine-tuning slider component for configuring audio lookahead buffer.
///
/// Features:
/// - Smooth Material 3 Expressive styling following Softify tokens.
/// - 10s to 60s range with discrete 5-second step increments.
/// - Live duration indicator badge with dynamic accent highlighting.
/// - Preset quick-selection chips (10s, 30s, 45s, 60s).
/// - Haptic selection feedback on discrete value adjustments.
class LookaheadBufferSlider extends ConsumerStatefulWidget {
  /// Optional callback invoked when slider changes.
  final ValueChanged<int>? onChanged;

  /// Whether to display top header row with title and live duration badge.
  final bool showHeader;

  /// Whether to display preset chips (10s, 30s, 45s, 60s) below the slider.
  final bool showPresets;

  /// Whether to display interval second markers (10s, 30s, 60s) below slider track.
  final bool showSecondIndicators;

  /// Custom active slider color override (defaults to [AppTokens.accent]).
  final Color? activeColor;

  const LookaheadBufferSlider({
    super.key,
    this.onChanged,
    this.showHeader = true,
    this.showPresets = true,
    this.showSecondIndicators = true,
    this.activeColor,
  });

  @override
  ConsumerState<LookaheadBufferSlider> createState() =>
      _LookaheadBufferSliderState();
}

class _LookaheadBufferSliderState
    extends ConsumerState<LookaheadBufferSlider> {
  int? _dragValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bufferState = ref.watch(lookaheadBufferProvider);
    final displayedSeconds = _dragValue ?? bufferState.bufferSeconds;
    final activeColor = widget.activeColor ?? tokens.accent;
    final isSubway = bufferState.isSubwayMode && displayedSeconds == kSubwayModeBufferSeconds;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isSubway ? Icons.subway_rounded : Icons.timelapse_rounded,
                    size: 18,
                    color: isSubway ? activeColor : tokens.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lookahead Duration',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontUi,
                    ),
                  ),
                ],
              ),
              _buildDurationBadge(tokens, displayedSeconds, activeColor, isSubway),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Material 3 Styled Slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4.5,
            activeTrackColor: activeColor,
            inactiveTrackColor: tokens.surfaceHighlight,
            thumbColor: Colors.white,
            overlayColor: activeColor.withValues(alpha: 0.16),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7.5,
              elevation: 3.0,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.0),
            activeTickMarkColor: Colors.white.withValues(alpha: 0.7),
            inactiveTickMarkColor: Colors.white.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: displayedSeconds.toDouble(),
            min: kMinLookaheadBufferSeconds.toDouble(),
            max: kMaxLookaheadBufferSeconds.toDouble(),
            divisions: (kMaxLookaheadBufferSeconds - kMinLookaheadBufferSeconds) ~/
                kLookaheadSliderStep,
            onChanged: (val) {
              final newSec = val.round();
              if (newSec != displayedSeconds) {
                HapticFeedback.selectionClick();
              }
              setState(() {
                _dragValue = newSec;
              });
              ref.read(lookaheadBufferProvider.notifier).setBufferSeconds(newSec);
              widget.onChanged?.call(newSec);
            },
            onChangeEnd: (val) {
              final finalSec = val.round();
              setState(() {
                _dragValue = null;
              });
              ref.read(lookaheadBufferProvider.notifier).setBufferSeconds(finalSec);
              widget.onChanged?.call(finalSec);
            },
          ),
        ),

        // Interval Second Indicators
        if (widget.showSecondIndicators) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTrackMarker('10s (Min)', displayedSeconds == 10, tokens, activeColor),
                _buildTrackMarker('30s (Default)', displayedSeconds == 30, tokens, activeColor),
                _buildTrackMarker('60s (Subway)', displayedSeconds == 60, tokens, activeColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Preset Chips Row
        if (widget.showPresets) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LookaheadPreset.values.map((preset) {
              final isSelected = displayedSeconds == preset.seconds;
              return _buildPresetChip(
                preset: preset,
                isSelected: isSelected,
                tokens: tokens,
                activeColor: activeColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(lookaheadBufferProvider.notifier).applyPreset(preset);
                  widget.onChanged?.call(preset.seconds);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDurationBadge(
    AppTokens tokens,
    int seconds,
    Color activeColor,
    bool isSubway,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSubway
            ? activeColor.withValues(alpha: 0.22)
            : tokens.surfaceHighlight,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: isSubway
              ? activeColor.withValues(alpha: 0.6)
              : tokens.divider.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSubway) ...[
            Icon(Icons.subway_rounded, size: 13, color: activeColor),
            const SizedBox(width: 4),
          ],
          Text(
            isSubway ? '${seconds}s SUBWAY' : '${seconds}s',
            style: TextStyle(
              color: isSubway ? activeColor : tokens.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFamily: AppTheme.fontUi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackMarker(
    String label,
    bool isCurrent,
    AppTokens tokens,
    Color activeColor,
  ) {
    return Text(
      label,
      style: TextStyle(
        color: isCurrent ? activeColor : tokens.textMuted,
        fontSize: 11,
        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
        fontFamily: AppTheme.fontUi,
      ),
    );
  }

  Widget _buildPresetChip({
    required LookaheadPreset preset,
    required bool isSelected,
    required AppTokens tokens,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : tokens.surfaceHighlight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: isSelected
                ? activeColor
                : tokens.divider.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              preset.icon,
              size: 14,
              color: isSelected ? activeColor : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              preset.label,
              style: TextStyle(
                color: isSelected ? activeColor : tokens.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: AppTheme.fontUi,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Widget: LookaheadBufferSliderCard
// ============================================================================

/// Full-featured Material 3 settings card for configuring Audio Lookahead Buffer.
///
/// Designed for clean integration into Softify's Network/Playback Settings screen.
///
/// Includes:
/// - Visual subway/network leading avatar icon.
/// - One-tap Subway & Tunnel Mode toggle switch for instant 60s preloading.
/// - Embedded [LookaheadBufferSlider] with fine-tuning steppers and preset chips.
/// - Live RAM footprint indicator and contextual recommendation summary.
/// - One-tap reset to default (30s) action.
class LookaheadBufferSliderCard extends ConsumerWidget {
  /// Optional title override (defaults to "Audio Lookahead Buffer").
  final String? title;

  /// Optional subtitle override.
  final String? subtitle;

  /// Optional card outer padding.
  final EdgeInsetsGeometry? padding;

  /// Whether to display the quick Subway & Tunnel Mode toggle switch.
  final bool showSubwayToggle;

  /// Whether to display memory footprint telemetry (~MB at 320 kbps).
  final bool showMemoryFootprint;

  /// Whether to display the "Reset to Default" button when buffer is customized.
  final bool showResetButton;

  const LookaheadBufferSliderCard({
    super.key,
    this.title,
    this.subtitle,
    this.padding,
    this.showSubwayToggle = true,
    this.showMemoryFootprint = true,
    this.showResetButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final bufferState = ref.watch(lookaheadBufferProvider);
    final isSubway = bufferState.isSubwayMode;
    final activeColor = tokens.accent;

    return AppSurface(
      withBlur: true,
      padding: padding ?? const EdgeInsets.all(16.0),
      borderRadius: BorderRadius.circular(tokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Leading Icon, Titles, and Live Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isSubway ? activeColor : tokens.accent)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSubway ? Icons.subway_rounded : Icons.wifi_tethering_rounded,
                  color: isSubway ? activeColor : tokens.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? 'Audio Lookahead Buffer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTheme.fontUi,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle ??
                          'Pre-buffer audio stream to prevent stuttering in low-connectivity areas & subways',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                        fontFamily: AppTheme.fontUi,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Subway & Tunnel Mode Quick Toggle Switch Tile
          if (showSubwayToggle) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: isSubway
                    ? activeColor.withValues(alpha: 0.12)
                    : tokens.surfaceHighlight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: isSubway
                      ? activeColor.withValues(alpha: 0.4)
                      : tokens.divider.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                dense: true,
                activeColor: activeColor,
                secondary: Icon(
                  Icons.subway_rounded,
                  color: isSubway ? activeColor : tokens.textSecondary,
                  size: 20,
                ),
                title: Text(
                  'Subway & Tunnel Mode (60s Max)',
                  style: TextStyle(
                    color: isSubway ? activeColor : tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTheme.fontUi,
                  ),
                ),
                subtitle: Text(
                  'Aggressively preloads audio ahead of playback to survive underground transit dead zones',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11.5,
                    fontFamily: AppTheme.fontUi,
                  ),
                ),
                value: isSubway,
                onChanged: (_) {
                  HapticFeedback.selectionClick();
                  ref.read(lookaheadBufferProvider.notifier).toggleSubwayMode();
                },
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.black26, height: 1),
          const SizedBox(height: 16),

          // Embedded Lookahead Buffer Slider
          const LookaheadBufferSlider(
            showHeader: true,
            showPresets: true,
            showSecondIndicators: true,
          ),

          const SizedBox(height: 16),

          // Informational Status & Recommendation Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: tokens.divider.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: tokens.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Buffer Telemetry & Advice',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTheme.fontUi,
                      ),
                    ),
                    const Spacer(),
                    if (showMemoryFootprint)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.surfaceHighlight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${bufferState.formattedMemoryEstimate} RAM @ 320k',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            fontFamily: AppTheme.fontUi,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  bufferState.recommendationText,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11.5,
                    fontFamily: AppTheme.fontUi,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          // Reset to Default Button
          if (showResetButton && !bufferState.isDefault) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(lookaheadBufferProvider.notifier).resetToDefault();
                },
                style: TextButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text(
                  'Reset to default (30s)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: AppTheme.fontUi,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Bonus Widget: LookaheadBufferCoverageBar
// ============================================================================

/// Visual progress indicator displaying live lookahead buffer cushion
/// ahead of active playback head.
class LookaheadBufferCoverageBar extends StatelessWidget {
  final Duration currentPosition;
  final Duration bufferedPosition;
  final Duration targetBuffer;
  final Color? barColor;
  final double height;

  const LookaheadBufferCoverageBar({
    super.key,
    required this.currentPosition,
    required this.bufferedPosition,
    required this.targetBuffer,
    this.barColor,
    this.height = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ratio = LookaheadBufferCalculator.calculateCoverageRatio(
      currentPosition: currentPosition,
      bufferedPosition: bufferedPosition,
      targetBuffer: targetBuffer,
    );
    final cushion = LookaheadBufferCalculator.calculateCushion(
      currentPosition: currentPosition,
      bufferedPosition: bufferedPosition,
    );
    final isSufficient = LookaheadBufferCalculator.isBufferSufficient(
      currentPosition: currentPosition,
      bufferedPosition: bufferedPosition,
      targetBuffer: targetBuffer,
    );
    final activeColor = barColor ?? (isSufficient ? tokens.accent : Colors.amber);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Buffered Cushion: ${cushion.inSeconds}s / ${targetBuffer.inSeconds}s',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontFamily: AppTheme.fontUi,
              ),
            ),
            Text(
              '${(ratio * 100).toInt()}%',
              style: TextStyle(
                color: activeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontUi,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: tokens.surfaceHighlight,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(color: activeColor),
            ),
          ),
        ),
      ],
    );
  }
}
