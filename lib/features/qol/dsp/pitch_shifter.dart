// ============================================================================
// Softify Quality of Life (QoL): Pitch Transpose DSP (Independent of Tempo)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// SharedPreferences persistent storage key for pitch semitone transposition.
const String kPitchTransposePrefKey = 'softify_pitch_transpose_semitones';

/// Minimum supported semitone transposition (-1 octave).
const int kMinPitchSemitones = -12;

/// Maximum supported semitone transposition (+1 octave).
const int kMaxPitchSemitones = 12;

/// Default pitch transposition semitones (0 = original / unison).
const int kDefaultPitchSemitones = 0;

/// Standard musical semitone preset points for rapid selection chips.
const List<int> kPitchPresetChips = [
  -12, // -1 Octave
  -7,  // Perfect 5th Down
  -5,  // Perfect 4th Down
  -2,  // Major 2nd Down
  -1,  // Minor 2nd Down
  0,   // Normal / Original
  1,   // Minor 2nd Up
  2,   // Major 2nd Up
  5,   // Perfect 4th Up
  7,   // Perfect 5th Up
  12,  // +1 Octave
];

// ============================================================================
// SharedPreferences Persistence Engine
// ============================================================================

/// Lightweight, self-contained SharedPreferences persistence engine
/// matching the exact `package:shared_preferences` API interface.
///
/// Persists key-value settings to disk safely across app launches
/// while supporting mock environments for testing and headless runs.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Injects initial values for test suites and unit harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Returns active singleton instance if already initialized.
  static SharedPreferences? get instance => _instance;

  /// Asynchronously loads or initializes shared preferences storage.
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
      file = _resolveStorageFile();
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

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
    } catch (_) {
      return null;
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

  double? getDouble(String key) {
    final val = _preferenceStore[key];
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Future<bool> setDouble(String key, double value) async {
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
// DSP Mathematical Utilities & Interval Nomenclature
// ============================================================================

/// Mathematical calculations and nomenclature for musical pitch transpositions.
class PitchShifterMath {
  const PitchShifterMath._();

  /// Converts semitone transposition value $s$ into a frequency multiplier ratio:
  ///
  /// $$ratio = 2^{\frac{s}{12}}$$
  ///
  /// A value of 0 yields 1.0 (unison). +12 yields 2.0 (one octave up),
  /// while -12 yields 0.5 (one octave down).
  static double ratioFromSemitones(int semitones) {
    return math.pow(2.0, semitones / 12.0).toDouble();
  }

  /// Converts a pitch ratio into the nearest semitone transposition step.
  static int semitonesFromRatio(double ratio) {
    if (ratio <= 0.0) return kDefaultPitchSemitones;
    final semitones = (12.0 * math.log(ratio) / math.ln2).round();
    return semitones.clamp(kMinPitchSemitones, kMaxPitchSemitones);
  }

  /// Calculates percentage frequency offset from 1.0 (unison).
  static double percentageChange(int semitones) {
    final ratio = ratioFromSemitones(semitones);
    return (ratio - 1.0) * 100.0;
  }

  /// Formats semitone value into a display string (e.g. `+2 st`, `0 st (Normal)`, `-3 st`).
  static String formatSemitones(int semitones) {
    if (semitones > 0) {
      return '+$semitones st';
    } else if (semitones == 0) {
      return '0 st (Normal)';
    } else {
      return '$semitones st';
    }
  }

  /// Formats semitones for compact chip representation (e.g. `+2`, `0`, `-3`).
  static String formatChipLabel(int semitones) {
    if (semitones > 0) {
      return '+$semitones';
    } else {
      return '$semitones';
    }
  }

  /// Resolves the traditional musical interval name for a given semitone offset.
  static String intervalName(int semitones) {
    switch (semitones) {
      case -12:
        return 'Octave Down (-12)';
      case -11:
        return 'Major 7th Down (-11)';
      case -10:
        return 'Minor 7th Down (-10)';
      case -9:
        return 'Major 6th Down (-9)';
      case -8:
        return 'Minor 6th Down (-8)';
      case -7:
        return 'Perfect 5th Down (-7)';
      case -6:
        return 'Tritone Down (-6)';
      case -5:
        return 'Perfect 4th Down (-5)';
      case -4:
        return 'Major 3rd Down (-4)';
      case -3:
        return 'Minor 3rd Down (-3)';
      case -2:
        return 'Major 2nd Down (-2)';
      case -1:
        return 'Minor 2nd Down (-1)';
      case 0:
        return 'Original / Unison (0)';
      case 1:
        return 'Minor 2nd Up (+1)';
      case 2:
        return 'Major 2nd Up (+2)';
      case 3:
        return 'Minor 3rd Up (+3)';
      case 4:
        return 'Major 3rd Up (+4)';
      case 5:
        return 'Perfect 4th Up (+5)';
      case 6:
        return 'Tritone Up (+6)';
      case 7:
        return 'Perfect 5th Up (+7)';
      case 8:
        return 'Minor 6th Up (+8)';
      case 9:
        return 'Major 6th Up (+9)';
      case 10:
        return 'Minor 7th Up (+10)';
      case 11:
        return 'Major 7th Up (+11)';
      case 12:
        return 'Octave Up (+12)';
      default:
        return semitones > 0 ? '+$semitones st' : '$semitones st';
    }
  }
}

// ============================================================================
// Riverpod StateNotifier
// ============================================================================

/// Riverpod StateNotifier managing semitone transposition (-12 to +12 semitones).
///
/// Features:
/// - Bounds clamping strictly within [-12, +12].
/// - Instant `reset()` back to normal unison (0 semitones).
/// - Asynchronous persistence to [SharedPreferences].
/// - Audio player engine synchronization independent of tempo.
class PitchShifterNotifier extends StateNotifier<int> {
  final SharedPreferences? _injectedPrefs;
  SharedPreferences? _prefs;
  final Ref? _ref;

  PitchShifterNotifier({
    SharedPreferences? prefs,
    int? initialSemitones,
    Ref? ref,
  })  : _injectedPrefs = prefs,
        _ref = ref,
        super(_clampSemitones(initialSemitones ?? kDefaultPitchSemitones)) {
    _initPersistence(initialSemitones);
  }

  static int _clampSemitones(int val) {
    if (val < kMinPitchSemitones) return kMinPitchSemitones;
    if (val > kMaxPitchSemitones) return kMaxPitchSemitones;
    return val;
  }

  /// Current semitone transposition count.
  int get semitones => state;

  /// Whether playback is at normal unison (0 semitones).
  bool get isNormal => state == 0;

  /// Whether playback is pitch-shifted away from unison.
  bool get isShifted => state != 0;

  /// The active frequency pitch multiplier (e.g. 1.0 for normal, 2.0 for +12 st).
  double get pitchRatio => PitchShifterMath.ratioFromSemitones(state);

  /// Formatted display label (e.g. `+2 st`, `0 st (Normal)`).
  String get formattedLabel => PitchShifterMath.formatSemitones(state);

  /// Musical interval designation for the current transposition.
  String get intervalName => PitchShifterMath.intervalName(state);

  /// Frequency percentage difference relative to normal pitch.
  double get percentageChange => PitchShifterMath.percentageChange(state);

  /// Initializes persistence and restores persisted preference if no explicit
  /// initial override was supplied.
  Future<void> _initPersistence(int? initialOverride) async {
    try {
      _prefs = _injectedPrefs ?? await SharedPreferences.getInstance();
      if (initialOverride == null) {
        final stored = _prefs?.getInt(kPitchTransposePrefKey);
        if (stored != null && mounted) {
          state = _clampSemitones(stored);
          _syncToAudioPlayer();
        }
      }
    } catch (_) {
      // Graceful fallback for headless or test environments
    }
  }

  /// Sets the semitone transposition, clamping strictly to [-12, 12] and persisting.
  Future<void> setSemitones(int targetSemitones) async {
    final clamped = _clampSemitones(targetSemitones);
    if (state == clamped) return;
    state = clamped;
    _syncToAudioPlayer();
    await _persistState(clamped);
  }

  /// Transposes current pitch by [delta] semitones, clamping to bounds.
  Future<void> transpose(int delta) async {
    await setSemitones(state + delta);
  }

  /// Steps pitch up by 1 semitone (+1 st).
  Future<void> increment() async {
    await transpose(1);
  }

  /// Steps pitch down by 1 semitone (-1 st).
  Future<void> decrement() async {
    await transpose(-1);
  }

  /// Resets transposition back to unison normal (0 semitones).
  Future<void> reset() async {
    await setSemitones(kDefaultPitchSemitones);
  }

  Future<void> _persistState(int val) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(kPitchTransposePrefKey, val);
    } catch (_) {}
  }

  void _syncToAudioPlayer() {
    if (_ref == null) return;
    try {
      final handler = _ref.read(audioHandlerProvider);
      final ratio = pitchRatio;
      (handler as dynamic).setPitch?.call(ratio);
    } catch (_) {
      // Audio handler may be uninitialized in isolated testing environments
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary Riverpod StateNotifierProvider for pitch transposition semitones (-12 to +12).
final pitchShifterProvider =
    StateNotifierProvider<PitchShifterNotifier, int>((ref) {
  return PitchShifterNotifier(ref: ref);
});

/// Readable provider exposing the current frequency pitch ratio multiplier.
final pitchRatioProvider = Provider<double>((ref) {
  final semitones = ref.watch(pitchShifterProvider);
  return PitchShifterMath.ratioFromSemitones(semitones);
});

/// Readable provider indicating whether pitch is transposed away from normal unison.
final isPitchShiftedProvider = Provider<bool>((ref) {
  return ref.watch(pitchShifterProvider) != 0;
});

/// Readable provider exposing the formatted semitone string (e.g. `+2 st`).
final pitchFormattedLabelProvider = Provider<String>((ref) {
  final semitones = ref.watch(pitchShifterProvider);
  return PitchShifterMath.formatSemitones(semitones);
});

/// Readable provider exposing the full musical interval name.
final pitchIntervalNameProvider = Provider<String>((ref) {
  final semitones = ref.watch(pitchShifterProvider);
  return PitchShifterMath.intervalName(semitones);
});

// ============================================================================
// UI Control Widget: PitchShifterControl
// ============================================================================

/// Material 3 Quality-of-Life control widget for Pitch Transposition.
///
/// Provides:
/// - Smooth slider with -12 to +12 semitone range and tactile step buttons.
/// - Quick-tap semitone chip indicators for common musical intervals.
/// - Prominent reset-to-zero action button.
/// - Informative acoustic readouts showing frequency ratio & percentage change.
class PitchShifterControl extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool showHeader;
  final bool showChips;
  final bool showReset;
  final bool showIntervalInfo;
  final ValueChanged<int>? onPitchChanged;
  final VoidCallback? onReset;

  const PitchShifterControl({
    super.key,
    this.margin,
    this.padding,
    this.showHeader = true,
    this.showChips = true,
    this.showReset = true,
    this.showIntervalInfo = true,
    this.onPitchChanged,
    this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semitones = ref.watch(pitchShifterProvider);
    final notifier = ref.read(pitchShifterProvider.notifier);
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    // Design Tokens with safe Material 3 fallbacks
    final cardBg = tokens?.card ?? theme.cardColor;
    final primaryAccent = tokens?.accent ?? theme.colorScheme.primary;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final textMuted = tokens?.textMuted ??
        theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final dividerColor = tokens?.divider ?? theme.dividerColor;
    final surfaceElevated = tokens?.surfaceElevated ?? theme.colorScheme.surface;

    final isShifted = semitones != 0;
    final ratio = PitchShifterMath.ratioFromSemitones(semitones);
    final pct = PitchShifterMath.percentageChange(semitones);
    final pctString =
        '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isShifted
              ? primaryAccent.withValues(alpha: 0.3)
              : dividerColor.withValues(alpha: 0.1),
          width: 1.2,
        ),
        boxShadow: tokens?.cardShadow ?? const [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------------------------------------------------------------------
          // 1. Header (Icon, Title, Transposition Badge, and Reset Button)
          // ------------------------------------------------------------------
          if (showHeader) ...[
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isShifted
                        ? primaryAccent.withValues(alpha: 0.15)
                        : surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: isShifted ? primaryAccent : textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pitch Transpose',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shift musical key independent of tempo',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Current Value Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isShifted
                        ? primaryAccent.withValues(alpha: 0.2)
                        : surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isShifted
                          ? primaryAccent.withValues(alpha: 0.4)
                          : dividerColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    PitchShifterMath.formatSemitones(semitones),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isShifted ? primaryAccent : textSecondary,
                    ),
                  ),
                ),
                if (showReset) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Reset pitch to normal (0 st)',
                    child: IconButton(
                      key: const Key('pitch_reset_button'),
                      icon: const Icon(Icons.restart_alt_rounded),
                      iconSize: 20,
                      color: isShifted ? primaryAccent : textMuted,
                      onPressed: isShifted
                          ? () {
                              notifier.reset();
                              onReset?.call();
                              onPitchChanged?.call(0);
                            }
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ------------------------------------------------------------------
          // 2. Interactive Slider & Step Buttons (-1 / +1)
          // ------------------------------------------------------------------
          Row(
            children: [
              // Nudge -1 Semitone Step Button
              Tooltip(
                message: 'Step down 1 semitone (-1 st)',
                child: IconButton(
                  key: const Key('pitch_step_down_button'),
                  icon: const Icon(Icons.remove_rounded),
                  iconSize: 18,
                  color: semitones > kMinPitchSemitones
                      ? textPrimary
                      : textMuted,
                  onPressed: semitones > kMinPitchSemitones
                      ? () {
                          final newVal = (semitones - 1).clamp(
                              kMinPitchSemitones, kMaxPitchSemitones);
                          notifier.decrement();
                          onPitchChanged?.call(newVal);
                        }
                      : null,
                ),
              ),

              // Transposition Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryAccent,
                    inactiveTrackColor: dividerColor.withValues(alpha: 0.2),
                    thumbColor: primaryAccent,
                    overlayColor: primaryAccent.withValues(alpha: 0.15),
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7.0,
                      pressedElevation: 4.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16.0,
                    ),
                  ),
                  child: Slider(
                    key: const Key('pitch_shifter_slider'),
                    value: semitones.toDouble(),
                    min: kMinPitchSemitones.toDouble(),
                    max: kMaxPitchSemitones.toDouble(),
                    divisions: kMaxPitchSemitones - kMinPitchSemitones,
                    label: PitchShifterMath.formatSemitones(semitones),
                    onChanged: (val) {
                      final target = val.round();
                      notifier.setSemitones(target);
                      onPitchChanged?.call(target);
                    },
                  ),
                ),
              ),

              // Nudge +1 Semitone Step Button
              Tooltip(
                message: 'Step up 1 semitone (+1 st)',
                child: IconButton(
                  key: const Key('pitch_step_up_button'),
                  icon: const Icon(Icons.add_rounded),
                  iconSize: 18,
                  color: semitones < kMaxPitchSemitones
                      ? textPrimary
                      : textMuted,
                  onPressed: semitones < kMaxPitchSemitones
                      ? () {
                          final newVal = (semitones + 1).clamp(
                              kMinPitchSemitones, kMaxPitchSemitones);
                          notifier.increment();
                          onPitchChanged?.call(newVal);
                        }
                      : null,
                ),
              ),
            ],
          ),

          // Axis Range Markers (-12, 0, +12)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '-12 (Octave Down)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
                Text(
                  '0 (Normal)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: semitones == 0
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: semitones == 0 ? primaryAccent : textMuted,
                  ),
                ),
                Text(
                  '+12 (Octave Up)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ------------------------------------------------------------------
          // 3. Semitone Chip Indicators (Quick Selection Chips)
          // ------------------------------------------------------------------
          if (showChips) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: kPitchPresetChips.map((preset) {
                final isSelected = semitones == preset;
                return ChoiceChip(
                  key: Key('pitch_chip_$preset'),
                  label: Text(PitchShifterMath.formatChipLabel(preset)),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                  selected: isSelected,
                  selectedColor: primaryAccent,
                  backgroundColor: surfaceElevated,
                  side: BorderSide(
                    color: isSelected
                        ? primaryAccent
                        : dividerColor.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  onSelected: (_) {
                    notifier.setSemitones(preset);
                    onPitchChanged?.call(preset);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // ------------------------------------------------------------------
          // 4. Acoustic Details & Interval Readout
          // ------------------------------------------------------------------
          if (showIntervalInfo) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: surfaceElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: dividerColor.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 16,
                    color: isShifted ? primaryAccent : textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      PitchShifterMath.intervalName(semitones),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${ratio.toStringAsFixed(3)}x ($pctString)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isShifted ? primaryAccent : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ------------------------------------------------------------------
          // 5. Explicit Text Reset Button (Visible when transposed)
          // ------------------------------------------------------------------
          if (isShifted && showReset) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                key: const Key('pitch_reset_text_button'),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset to Normal (0 st)'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryAccent,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  notifier.reset();
                  onReset?.call();
                  onPitchChanged?.call(0);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Modal Sheet Helper
// ============================================================================

/// Shows [PitchShifterControl] embedded within a responsive modal bottom sheet.
Future<void> showPitchShifterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _PitchShifterModalSheet(),
  );
}

class _PitchShifterModalSheet extends StatelessWidget {
  const _PitchShifterModalSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final surfaceColor = tokens?.surfaceElevated ?? theme.cardColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: (tokens?.divider ?? theme.dividerColor).withValues(alpha: 0.1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const PitchShifterControl(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
