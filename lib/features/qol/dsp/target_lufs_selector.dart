// ============================================================================
// Softify Quality of Life (QoL): Target LUFS Loudness Normalization Selector
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

import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Minimum supported target LUFS value (quiet / ultra-high dynamic range).
const double kLufsMin = -24.0;

/// Maximum supported target LUFS value (loud / broadcast compressed).
const double kLufsMax = -10.0;

/// Default target LUFS (Spotify Standard: -14.0 LUFS).
const double kLufsDefaultTarget = -14.0;

/// SharedPreferences persistence keys.
const String kTargetLufsValueKey = 'softify_target_lufs_value';
const String kTargetLufsPresetKey = 'softify_target_lufs_preset';
const String kTargetLufsEnabledKey = 'softify_target_lufs_enabled';
const String kTargetLufsPreventClippingKey = 'softify_target_lufs_prevent_clipping';
const String kTargetLufsPeakCeilingKey = 'softify_target_lufs_peak_ceiling_db';

// ============================================================================
// Standard LUFS Presets
// ============================================================================

/// Standard loudness presets for music streaming and broadcast reference standards.
enum LufsPreset {
  /// Spotify Standard reference target: -14.0 LUFS.
  spotify(
    -14.0,
    'Spotify Standard',
    'Standard streaming target (-14 LUFS). Balanced punch and dynamic range.',
    'Spotify',
  ),

  /// Apple Music / AES TD1004 reference target: -16.0 LUFS.
  apple(
    -16.0,
    'Apple Music',
    'AES TD1004 & Apple Sound Check (-16 LUFS). Preserves wide transient dynamics.',
    'Apple Music',
  ),

  /// European Broadcasting Union R128 standard: -23.0 LUFS.
  ebuR128(
    -23.0,
    'EBU R128',
    'EBU R128 broadcast standard (-23 LUFS). Maximum dynamic range with zero compression.',
    'EBU R128',
  ),

  /// User-defined target between -24.0 and -10.0 LUFS.
  custom(
    null,
    'Custom',
    'User-defined normalization reference target (-24 to -10 LUFS).',
    'Custom',
  );

  final double? targetLufs;
  final String label;
  final String description;
  final String shortLabel;

  const LufsPreset(
    this.targetLufs,
    this.label,
    this.description,
    this.shortLabel,
  );

  /// Identifies standard preset from an exact or near-match LUFS value.
  static LufsPreset fromLufs(double lufs) {
    if ((lufs - (-14.0)).abs() < 0.05) return LufsPreset.spotify;
    if ((lufs - (-16.0)).abs() < 0.05) return LufsPreset.apple;
    if ((lufs - (-23.0)).abs() < 0.05) return LufsPreset.ebuR128;
    return LufsPreset.custom;
  }
}

// ============================================================================
// State Model
// ============================================================================

/// Immutable state representing target LUFS loudness normalization settings.
@immutable
class TargetLufsState {
  /// Whether loudness normalization is active.
  final bool isEnabled;

  /// Active reference target in LUFS (-24.0 to -10.0).
  final double targetLufs;

  /// Active preset configuration.
  final LufsPreset preset;

  /// Whether true-peak anti-clipping limiting is enabled.
  final bool preventClipping;

  /// True-peak ceiling in dBFS (default -1.0 dBTP).
  final double peakCeilingDb;

  const TargetLufsState({
    this.isEnabled = true,
    this.targetLufs = kLufsDefaultTarget,
    this.preset = LufsPreset.spotify,
    this.preventClipping = true,
    this.peakCeilingDb = -1.0,
  });

  /// Calculates the volume adjustment gain in decibels (dB) required to normalize
  /// a track with [sourceLufs] to [targetLufs].
  ///
  /// Formula: `gainDb = targetLufs - sourceLufs`
  ///
  /// Positive gain boosts quiet tracks; negative gain attenuates loud tracks.
  /// If normalization is disabled, returns 0.0 dB (unity gain).
  double calculateGainDb(
    double sourceLufs, {
    double maxBoostDb = 12.0,
    double maxCutDb = 30.0,
  }) {
    if (!isEnabled) return 0.0;
    final rawGain = targetLufs - sourceLufs;
    return rawGain.clamp(-maxCutDb, maxBoostDb);
  }

  /// Calculates linear scalar multiplication factor for audio buffer processing:
  /// `gainLinear = 10^(gainDb / 20)`.
  double calculateLinearGain(
    double sourceLufs, {
    double maxBoostDb = 12.0,
    double maxCutDb = 30.0,
  }) {
    if (!isEnabled) return 1.0;
    final gainDb = calculateGainDb(
      sourceLufs,
      maxBoostDb: maxBoostDb,
      maxCutDb: maxCutDb,
    );
    return math.pow(10.0, gainDb / 20.0).toDouble();
  }

  /// Formatted target string with unit (e.g. "-14.0 LUFS").
  String get formattedTarget => '${targetLufs.toStringAsFixed(1)} LUFS';

  /// Formatted target string in decibels (e.g. "-14.0 dB").
  String get formattedTargetDb => '${targetLufs.toStringAsFixed(1)} dB';

  TargetLufsState copyWith({
    bool? isEnabled,
    double? targetLufs,
    LufsPreset? preset,
    bool? preventClipping,
    double? peakCeilingDb,
  }) {
    return TargetLufsState(
      isEnabled: isEnabled ?? this.isEnabled,
      targetLufs: targetLufs ?? this.targetLufs,
      preset: preset ?? this.preset,
      preventClipping: preventClipping ?? this.preventClipping,
      peakCeilingDb: peakCeilingDb ?? this.peakCeilingDb,
    );
  }

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'targetLufs': targetLufs,
        'preset': preset.name,
        'preventClipping': preventClipping,
        'peakCeilingDb': peakCeilingDb,
      };

  factory TargetLufsState.fromJson(Map<String, dynamic> json) {
    final presetName = json['preset'] as String?;
    final preset = LufsPreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => LufsPreset.spotify,
    );
    return TargetLufsState(
      isEnabled: json['isEnabled'] as bool? ?? true,
      targetLufs: (json['targetLufs'] as num?)?.toDouble() ?? kLufsDefaultTarget,
      preset: preset,
      preventClipping: json['preventClipping'] as bool? ?? true,
      peakCeilingDb: (json['peakCeilingDb'] as num?)?.toDouble() ?? -1.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetLufsState &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          (targetLufs - other.targetLufs).abs() < 0.001 &&
          preset == other.preset &&
          preventClipping == other.preventClipping &&
          (peakCeilingDb - other.peakCeilingDb).abs() < 0.001;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        targetLufs.toStringAsFixed(2),
        preset,
        preventClipping,
        peakCeilingDb.toStringAsFixed(2),
      );

  @override
  String toString() =>
      'TargetLufsState(enabled: $isEnabled, target: $formattedTarget, preset: ${preset.label})';
}

// ============================================================================
// DSP Audio Gain & Loudness Calculation Utilities
// ============================================================================

/// Pure Dart DSP helper class for calculating and applying loudness normalization gains.
class LufsGainCalculator {
  /// Computes target normalization gain in decibels.
  static double computeGainDb({
    required double sourceTrackLufs,
    required double targetLufs,
    double maxBoostDb = 12.0,
    double maxCutDb = 30.0,
  }) {
    final diff = targetLufs - sourceTrackLufs;
    return diff.clamp(-maxCutDb, maxBoostDb);
  }

  /// Converts gain in decibels to linear scalar multiplier: $10^{\text{gainDb}/20}$.
  static double dbToLinear(double gainDb) {
    return math.pow(10.0, gainDb / 20.0).toDouble();
  }

  /// Converts linear scalar multiplier to decibels: $20 \log_{10}(\text{linear})$.
  static double linearToDb(double linearGain) {
    if (linearGain <= 0.000001) return -120.0;
    return 20.0 * (math.log(linearGain) / math.ln10);
  }

  /// Finds peak absolute sample amplitude in a Float32List buffer.
  static double computePeak(Float32List buffer) {
    if (buffer.isEmpty) return 0.0;
    double max = 0.0;
    for (int i = 0; i < buffer.length; i++) {
      final abs = buffer[i].abs();
      if (abs > max) max = abs;
    }
    return max;
  }

  /// Applies linear gain to a Float32 audio sample buffer in-place.
  /// If [preventClipping] is true and gain would push samples above [peakLimit],
  /// the gain scalar is automatically attenuated to avoid hard digital clipping.
  ///
  /// Returns the actual effective linear gain applied.
  static double applyGainToBuffer(
    Float32List buffer,
    double gainLinear, {
    bool preventClipping = true,
    double peakLimit = 0.99,
  }) {
    if (buffer.isEmpty || (gainLinear - 1.0).abs() < 0.00001) {
      return 1.0;
    }

    double effectiveGain = gainLinear;
    if (preventClipping) {
      final currentPeak = computePeak(buffer);
      if (currentPeak > 0 && (currentPeak * effectiveGain) > peakLimit) {
        effectiveGain = peakLimit / currentPeak;
      }
    }

    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = (buffer[i] * effectiveGain).clamp(-1.0, 1.0);
    }

    return effectiveGain;
  }

  /// Computes approximate unweighted RMS level in equivalent dBFS reference.
  static double estimateBufferRmsLufs(Float32List buffer) {
    if (buffer.isEmpty) return -120.0;
    double sumSquares = 0.0;
    for (int i = 0; i < buffer.length; i++) {
      sumSquares += buffer[i] * buffer[i];
    }
    final meanSquare = sumSquares / buffer.length;
    if (meanSquare <= 0.0000000001) return -120.0;
    return 10.0 * (math.log(meanSquare) / math.ln10);
  }
}

// ============================================================================
// SharedPreferences Persistence Engine (Self-Contained & Test-Friendly)
// ============================================================================

/// Self-contained SharedPreferences persistence store compatible with standard API.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible cached singleton instance if resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock initial values for testing environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets singleton instance.
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
          if (decoded is Map<String, dynamic>) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key] = value as Object;
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
    final file = _file;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_store);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  double? getDouble(String key) {
    final val = _store[key];
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Future<bool> setDouble(String key, double value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _store[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final val = _store[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
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

  bool containsKey(String key) => _store.containsKey(key);

  Future<bool> remove(String key) async {
    _store.remove(key);
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    await _persist();
    return true;
  }
}

// ============================================================================
// Riverpod StateNotifier
// ============================================================================

/// Riverpod StateNotifier managing the target LUFS loudness normalization reference.
class TargetLufsNotifier extends StateNotifier<TargetLufsState> {
  final SharedPreferences? _prefs;

  TargetLufsNotifier({
    TargetLufsState? initialState,
    SharedPreferences? prefs,
  })  : _prefs = prefs,
        super(initialState ?? const TargetLufsState()) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final hasStored = prefs.containsKey(kTargetLufsValueKey);
      if (!hasStored) return;

      final storedLufs = prefs.getDouble(kTargetLufsValueKey);
      final storedPresetName = prefs.getString(kTargetLufsPresetKey);
      final storedEnabled = prefs.getBool(kTargetLufsEnabledKey);
      final storedPreventClip = prefs.getBool(kTargetLufsPreventClippingKey);
      final storedCeiling = prefs.getDouble(kTargetLufsPeakCeilingKey);

      LufsPreset preset = state.preset;
      if (storedPresetName != null) {
        preset = LufsPreset.values.firstWhere(
          (p) => p.name == storedPresetName,
          orElse: () => LufsPreset.custom,
        );
      } else if (storedLufs != null) {
        preset = LufsPreset.fromLufs(storedLufs);
      }

      state = state.copyWith(
        targetLufs: storedLufs?.clamp(kLufsMin, kLufsMax) ?? state.targetLufs,
        preset: preset,
        isEnabled: storedEnabled ?? state.isEnabled,
        preventClipping: storedPreventClip ?? state.preventClipping,
        peakCeilingDb: storedCeiling ?? state.peakCeilingDb,
      );
    } catch (_) {}
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setDouble(kTargetLufsValueKey, state.targetLufs);
      await prefs.setString(kTargetLufsPresetKey, state.preset.name);
      await prefs.setBool(kTargetLufsEnabledKey, state.isEnabled);
      await prefs.setBool(kTargetLufsPreventClippingKey, state.preventClipping);
      await prefs.setDouble(kTargetLufsPeakCeilingKey, state.peakCeilingDb);
    } catch (_) {}
  }

  /// Sets one of the standard presets.
  Future<void> setPreset(LufsPreset preset) async {
    final double newTarget = preset.targetLufs ?? state.targetLufs;
    state = state.copyWith(
      preset: preset,
      targetLufs: newTarget.clamp(kLufsMin, kLufsMax),
    );
    await _saveToPreferences();
  }

  /// Sets custom target LUFS value (clamped between -24.0 and -10.0 LUFS).
  /// Automatically matches known standard presets or classifies as Custom.
  Future<void> setTargetLufs(double target) async {
    final rounded = (target * 10).round() / 10.0;
    final clamped = rounded.clamp(kLufsMin, kLufsMax);
    final preset = LufsPreset.fromLufs(clamped);
    state = state.copyWith(
      targetLufs: clamped,
      preset: preset,
    );
    await _saveToPreferences();
  }

  /// Enables or disables loudness normalization.
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(isEnabled: enabled);
    await _saveToPreferences();
  }

  /// Toggles enabled state.
  Future<void> toggleEnabled() async {
    await setEnabled(!state.isEnabled);
  }

  /// Enables or disables true-peak anti-clipping limiter.
  Future<void> setPreventClipping(bool preventClipping) async {
    state = state.copyWith(preventClipping: preventClipping);
    await _saveToPreferences();
  }

  /// Sets true-peak ceiling in dB (e.g. -1.0 dBTP).
  Future<void> setPeakCeilingDb(double ceilingDb) async {
    state = state.copyWith(peakCeilingDb: ceilingDb.clamp(-3.0, 0.0));
    await _saveToPreferences();
  }

  /// Resets target LUFS settings to defaults (Spotify Standard: -14.0 LUFS).
  Future<void> resetToDefault() async {
    state = const TargetLufsState(
      isEnabled: true,
      targetLufs: kLufsDefaultTarget,
      preset: LufsPreset.spotify,
      preventClipping: true,
      peakCeilingDb: -1.0,
    );
    await _saveToPreferences();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Riverpod StateNotifierProvider managing active target LUFS normalization settings.
final targetLufsProvider =
    StateNotifierProvider<TargetLufsNotifier, TargetLufsState>((ref) {
  return TargetLufsNotifier();
});

/// Riverpod Provider exposing the current target LUFS double value.
final targetLufsValueProvider = Provider<double>((ref) {
  return ref.watch(targetLufsProvider).targetLufs;
});

/// Riverpod Provider exposing whether loudness normalization is currently enabled.
final targetLufsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(targetLufsProvider).isEnabled;
});

/// Riverpod family provider computing real-time gain adjustment in dB for a track with [trackLufs].
final targetLufsGainProvider =
    Provider.family<double, double>((ref, trackLufs) {
  final state = ref.watch(targetLufsProvider);
  return state.calculateGainDb(trackLufs);
});

// ============================================================================
// UI Widget: TargetLufsSelectorCard
// ============================================================================

/// Descriptive tooltip explaining LUFS loudness normalization and dynamic range.
const String kTargetLufsTooltipDescription =
    'Loudness Units relative to Full Scale (LUFS / ITU-R BS.1770) automatically levels '
    'playback volume so loud modern masters and quiet acoustic or classical tracks '
    'play at consistent perceived loudness without manual volume adjustments.';

/// Material 3 Card Widget providing preset selection buttons and a target dB / LUFS
/// slider for loudness normalization.
class TargetLufsSelectorCard extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool showHeader;
  final bool showPresets;
  final bool showSlider;
  final bool showPreview;
  final bool showTooltip;
  final String? customTooltip;
  final ValueChanged<double>? onTargetChanged;
  final ValueChanged<LufsPreset>? onPresetChanged;
  final ValueChanged<bool>? onToggleChanged;

  const TargetLufsSelectorCard({
    super.key,
    this.margin,
    this.padding,
    this.showHeader = true,
    this.showPresets = true,
    this.showSlider = true,
    this.showPreview = true,
    this.showTooltip = true,
    this.customTooltip,
    this.onTargetChanged,
    this.onPresetChanged,
    this.onToggleChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(targetLufsProvider);
    final notifier = ref.read(targetLufsProvider.notifier);
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    // Design Tokens & Fallbacks
    final cardColor = tokens?.card ?? theme.cardColor;
    final primaryAccent = tokens?.accent ?? theme.colorScheme.primary;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final textMuted = tokens?.textMuted ?? theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final dividerColor = tokens?.divider ?? theme.dividerColor;
    final surfaceElevated = tokens?.surfaceElevated ?? theme.colorScheme.surface;

    final isEnabled = state.isEnabled;
    final tooltipMessage = customTooltip ?? kTargetLufsTooltipDescription;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens?.radiusCard ?? 16),
        border: Border.all(
          color: isEnabled
              ? primaryAccent.withValues(alpha: 0.28)
              : dividerColor.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ------------------------------------------------------------------
          // Header: Icon, Title, Subtitle, Info Tooltip, Toggle Switch
          // ------------------------------------------------------------------
          if (showHeader) ...[
            Row(
              children: [
                // Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? primaryAccent.withValues(alpha: 0.15)
                        : textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: isEnabled ? primaryAccent : textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Target LUFS Loudness Normalization',
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isEnabled
                                  ? primaryAccent.withValues(alpha: 0.18)
                                  : textMuted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              state.formattedTarget,
                              style: TextStyle(
                                color: isEnabled ? primaryAccent : textMuted,
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
                        isEnabled
                            ? 'Normalizes playback loudness to ${state.formattedTarget} (${state.preset.label})'
                            : 'Loudness normalization disabled (tracks play at original mastering level)',
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

                // Info Tooltip Button
                if (showTooltip)
                  Tooltip(
                    message: tooltipMessage,
                    waitDuration: const Duration(milliseconds: 300),
                    showDuration: const Duration(seconds: 5),
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
                      tooltip: 'Loudness information',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {},
                    ),
                  ),

                // Enable / Disable Switch
                Semantics(
                  label: 'Target LUFS Normalization Switch',
                  hint: 'Enables or disables volume leveling across tracks',
                  toggled: isEnabled,
                  child: Switch(
                    value: isEnabled,
                    activeTrackColor: primaryAccent,
                    onChanged: (newValue) {
                      notifier.setEnabled(newValue);
                      onToggleChanged?.call(newValue);
                    },
                  ),
                ),
              ],
            ),
          ],

          // ------------------------------------------------------------------
          // Presets Row
          // ------------------------------------------------------------------
          if (showPresets) ...[
            const SizedBox(height: 16),
            Text(
              'STANDARD PRESETS',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Render 4 responsive preset buttons
                final presets = [
                  LufsPreset.spotify,
                  LufsPreset.apple,
                  LufsPreset.ebuR128,
                  LufsPreset.custom,
                ];

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((preset) {
                    final isSelected = state.preset == preset;
                    final targetLabel = preset.targetLufs != null
                        ? '${preset.targetLufs!.toStringAsFixed(0)} LUFS'
                        : '-24 to -10';

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isEnabled
                            ? () {
                                HapticFeedback.selectionClick();
                                notifier.setPreset(preset);
                                onPresetChanged?.call(preset);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected && isEnabled
                                ? primaryAccent.withValues(alpha: 0.16)
                                : surfaceElevated.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected && isEnabled
                                  ? primaryAccent
                                  : dividerColor.withValues(alpha: 0.15),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected && isEnabled) ...[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 13,
                                      color: primaryAccent,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    preset.label,
                                    style: TextStyle(
                                      color: isEnabled
                                          ? (isSelected ? primaryAccent : textPrimary)
                                          : textMuted,
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                targetLabel,
                                style: TextStyle(
                                  color: isSelected && isEnabled
                                      ? primaryAccent.withValues(alpha: 0.85)
                                      : textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],

          // ------------------------------------------------------------------
          // Target dB / LUFS Slider
          // ------------------------------------------------------------------
          if (showSlider) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NORMALIZATION TARGET',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${state.formattedTarget} (${state.formattedTargetDb})',
                  style: TextStyle(
                    color: isEnabled ? primaryAccent : textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${kLufsMin.toStringAsFixed(0)} LUFS\n(Dynamic)',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: isEnabled ? primaryAccent : textMuted,
                      inactiveTrackColor: dividerColor.withValues(alpha: 0.2),
                      thumbColor: isEnabled ? primaryAccent : textMuted,
                      overlayColor: primaryAccent.withValues(alpha: 0.15),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                        elevation: 2,
                      ),
                    ),
                    child: Slider(
                      value: state.targetLufs.clamp(kLufsMin, kLufsMax),
                      min: kLufsMin,
                      max: kLufsMax,
                      divisions: 28, // 0.5 LUFS increments across 14 LUFS range
                      label: state.formattedTarget,
                      onChanged: isEnabled
                          ? (value) {
                              notifier.setTargetLufs(value);
                              onTargetChanged?.call(value);
                            }
                          : null,
                    ),
                  ),
                ),
                Text(
                  '${kLufsMax.toStringAsFixed(0)} LUFS\n(Loud)',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // ------------------------------------------------------------------
          // Gain Preview / Real-Time Calculation Card
          // ------------------------------------------------------------------
          if (showPreview) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceElevated.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dividerColor.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.multitrack_audio_rounded,
                    size: 16,
                    color: isEnabled ? primaryAccent : textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEnabled
                          ? 'Hot master at -9.0 LUFS attenuated by ${(state.targetLufs - (-9.0)).toStringAsFixed(1)} dB • Quiet track at -18.0 LUFS boosted by +${(state.targetLufs - (-18.0)).toStringAsFixed(1)} dB'
                          : 'Loudness normalization is inactive. Tracks will play at their variable mastering volumes.',
                      style: TextStyle(
                        color: isEnabled ? textSecondary : textMuted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
