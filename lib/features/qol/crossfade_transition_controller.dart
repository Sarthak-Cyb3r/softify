import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_surface.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Minimum crossfade duration in seconds (0s = pure gapless playback).
const int kCrossfadeMinSeconds = 0;

/// Maximum crossfade duration in seconds.
const int kCrossfadeMaxSeconds = 12;

/// Default crossfade duration in seconds (0s = gapless).
const int kCrossfadeDefaultSeconds = 0;

/// Key used to persist crossfade duration in SharedPreferences.
const String kCrossfadeDurationPrefKey = 'crossfade_duration_seconds';

/// Key used to persist crossfade duration in Drift database settings table.
const String kCrossfadeDurationDbKey = 'crossfade_duration';

/// Preset second options for quick selection in crossfade UI.
const List<int> kCrossfadePresets = [0, 2, 4, 6, 8, 12];

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
// Crossfade Duration Notifier & Controller
// ============================================================================

/// StateNotifier that manages audio crossfade duration between 0s and 12s.
///
/// Setting duration to 0s engages seamless gapless audio playback. Setting
/// duration between 1s and 12s triggers an equal-power audio crossfade
/// curve overlapping the outgoing and incoming song buffers.
///
/// Automatically persists to [SharedPreferences] and syncs with [AppDatabase]
/// and [audioHandlerProvider].
class CrossfadeDurationNotifier extends StateNotifier<int> {
  final Ref? _ref;
  final AppDatabase? _db;
  final SharedPreferences? _prefs;

  int? _lastNonZeroDuration;
  bool _initialized = false;

  CrossfadeDurationNotifier([this._ref, this._db, this._prefs])
      : super(kCrossfadeDefaultSeconds) {
    _init();
  }

  /// Whether the notifier has finished loading stored preferences.
  bool get isInitialized => _initialized;

  /// Whether playback is currently configured for gapless transition (0s).
  bool get isGapless => state == 0;

  /// Human-friendly display label: "Gapless" for 0s, or "${duration}s".
  String get formattedLabel => state == 0 ? 'Gapless' : '${state}s';

  Future<void> _init() async {
    int? loadedSeconds;

    // 1. Try loading from SharedPreferences first
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      loadedSeconds = prefs.getInt(kCrossfadeDurationPrefKey);
    } catch (_) {}

    // 2. Fallback to Drift AppDatabase settings table
    if (loadedSeconds == null && _db != null) {
      try {
        final row = await (_db.select(_db.settings)
              ..where((t) => t.key.equals(kCrossfadeDurationDbKey)))
            .getSingleOrNull();
        if (row != null) {
          loadedSeconds = int.tryParse(row.value);
        }
      } catch (_) {}
    }

    if (!_initialized && loadedSeconds != null) {
      final clamped = loadedSeconds.clamp(kCrossfadeMinSeconds, kCrossfadeMaxSeconds);
      state = clamped;
      if (clamped > 0) {
        _lastNonZeroDuration = clamped;
      }
      _syncToAudioHandler(clamped);
    }

    _initialized = true;
  }

  /// Updates crossfade duration to [seconds] (clamped to 0..12).
  ///
  /// Persists change to [SharedPreferences] and [AppDatabase], and updates
  /// the active audio handler.
  Future<void> setCrossfadeDuration(int seconds) async {
    _initialized = true;
    final clamped = seconds.clamp(kCrossfadeMinSeconds, kCrossfadeMaxSeconds);
    if (clamped > 0) {
      _lastNonZeroDuration = clamped;
    }

    state = clamped;
    _syncToAudioHandler(clamped);

    // 1. Persist to SharedPreferences
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt(kCrossfadeDurationPrefKey, clamped);
    } catch (_) {}

    // 2. Persist to Drift Database
    if (_db != null) {
      try {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(
                key: kCrossfadeDurationDbKey,
                value: clamped.toString(),
              ),
            );
      } catch (_) {}
    }
  }

  /// Alias for [setCrossfadeDuration].
  Future<void> setDuration(int seconds) => setCrossfadeDuration(seconds);

  /// Quick toggle between Gapless (0s) and the last active crossfade duration.
  ///
  /// If crossfade is currently active (> 0s), turns it off to Gapless (0s).
  /// If currently Gapless (0s), restores the previous duration or [defaultWhenEnabling] (default: 4s).
  Future<void> toggleGapless({int defaultWhenEnabling = 4}) async {
    if (state > 0) {
      _lastNonZeroDuration = state;
      await setCrossfadeDuration(0);
    } else {
      final target = _lastNonZeroDuration ?? defaultWhenEnabling;
      await setCrossfadeDuration(target);
    }
  }

  void _syncToAudioHandler(int seconds) {
    if (_ref == null) return;
    try {
      final handler = _ref.read(audioHandlerProvider);
      handler.setCrossfadeSeconds(seconds);
    } catch (_) {
      // AudioHandler may be uninitialized in isolated widget tests
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Riverpod provider managing customizable crossfade duration (0s to 12s, default 0s = gapless).
final crossfadeDurationProvider =
    StateNotifierProvider<CrossfadeDurationNotifier, int>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return CrossfadeDurationNotifier(ref, db);
});

/// Riverpod provider indicating whether playback is currently gapless (0s crossfade).
final isGaplessCrossfadeProvider = Provider<bool>((ref) {
  return ref.watch(crossfadeDurationProvider) == 0;
});

/// Riverpod provider returning formatted crossfade label ("Gapless" or "${duration}s").
final crossfadeLabelProvider = Provider<String>((ref) {
  final seconds = ref.watch(crossfadeDurationProvider);
  return seconds == 0 ? 'Gapless' : '${seconds}s';
});

// ============================================================================
// Crossfade Duration Slider Widget
// ============================================================================

/// Sleek Material 3 / Metrolist styled slider widget for customizing audio crossfade.
///
/// Features:
/// - Smooth slider thumb and track with Metrolist accent palette.
/// - Prominent "Gapless" label and badge when positioned at 0s.
/// - Interactive second indicators below the track (0s, 2s, 4s, 6s, 8s, 10s, 12s).
/// - Optional quick preset chips for instant 1-tap switching.
/// - Haptic tick feedback on drag adjustments.
class CrossfadeDurationSlider extends ConsumerStatefulWidget {
  /// Optional callback invoked when the slider value changes.
  final ValueChanged<int>? onChanged;

  /// Whether to display the top header row with title and live duration badge.
  final bool showHeader;

  /// Whether to display preset chips (Gapless, 2s, 4s, 6s, 8s, 12s) below the slider.
  final bool showPresets;

  /// Whether to display second indicators along the slider track.
  final bool showSecondIndicators;

  /// Active track & thumb highlight color (defaults to [AppTokens.accent]).
  final Color? activeColor;

  const CrossfadeDurationSlider({
    super.key,
    this.onChanged,
    this.showHeader = true,
    this.showPresets = true,
    this.showSecondIndicators = true,
    this.activeColor,
  });

  @override
  ConsumerState<CrossfadeDurationSlider> createState() =>
      _CrossfadeDurationSliderState();
}

class _CrossfadeDurationSliderState
    extends ConsumerState<CrossfadeDurationSlider> {
  int? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentDuration = ref.watch(crossfadeDurationProvider);
    final displayedDuration = _draggingValue ?? currentDuration;
    final activeColor = widget.activeColor ?? tokens.accent;
    final isGapless = displayedDuration == 0;

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
                    Icons.timelapse_rounded,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Crossfade Duration',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontUi,
                    ),
                  ),
                ],
              ),
              _buildDurationBadge(tokens, displayedDuration, activeColor, isGapless),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Sleek Slider Control
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
            value: displayedDuration.toDouble(),
            min: kCrossfadeMinSeconds.toDouble(),
            max: kCrossfadeMaxSeconds.toDouble(),
            divisions: kCrossfadeMaxSeconds - kCrossfadeMinSeconds,
            onChanged: (val) {
              final newSec = val.round();
              if (newSec != displayedDuration) {
                HapticFeedback.selectionClick();
              }
              setState(() {
                _draggingValue = newSec;
              });
              ref.read(crossfadeDurationProvider.notifier).setCrossfadeDuration(newSec);
              widget.onChanged?.call(newSec);
            },
            onChangeEnd: (val) {
              final finalSec = val.round();
              setState(() {
                _draggingValue = null;
              });
              ref.read(crossfadeDurationProvider.notifier).setCrossfadeDuration(finalSec);
              widget.onChanged?.call(finalSec);
            },
          ),
        ),

        // Second Indicators (Ticks with Gapless label at 0s)
        if (widget.showSecondIndicators) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIndicatorLabel('Gapless', 0, displayedDuration, activeColor, tokens),
                _buildIndicatorLabel('3s', 3, displayedDuration, activeColor, tokens),
                _buildIndicatorLabel('6s', 6, displayedDuration, activeColor, tokens),
                _buildIndicatorLabel('9s', 9, displayedDuration, activeColor, tokens),
                _buildIndicatorLabel('12s', 12, displayedDuration, activeColor, tokens),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Quick Preset Chips
        if (widget.showPresets) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.start,
            children: kCrossfadePresets.map((preset) {
              final isSelected = displayedDuration == preset;
              final isGaplessChip = preset == 0;
              final label = isGaplessChip ? 'Gapless (0s)' : '${preset}s';

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(crossfadeDurationProvider.notifier).setCrossfadeDuration(preset);
                  widget.onChanged?.call(preset);
                },
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.18)
                        : tokens.surfaceHighlight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(
                      color: isSelected
                          ? activeColor
                          : tokens.surfaceHighlight.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isGaplessChip) ...[
                        Icon(
                          Icons.all_inclusive_rounded,
                          size: 13,
                          color: isSelected ? activeColor : tokens.textMuted,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : tokens.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontFamily: AppTheme.fontUi,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDurationBadge(
    AppTokens tokens,
    int duration,
    Color activeColor,
    bool isGapless,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isGapless
            ? const Color(0x1F22C55E) // Subtle emerald tint for gapless
            : activeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: isGapless
              ? const Color(0xFF22C55E).withValues(alpha: 0.5)
              : activeColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGapless ? Icons.all_inclusive_rounded : Icons.compare_arrows_rounded,
            size: 13,
            color: isGapless ? const Color(0xFF4ADE80) : activeColor,
          ),
          const SizedBox(width: 5),
          Text(
            isGapless ? 'Gapless' : '${duration}s',
            style: TextStyle(
              color: isGapless ? const Color(0xFF4ADE80) : activeColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: AppTheme.fontUi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorLabel(
    String label,
    int seconds,
    int activeSeconds,
    Color activeColor,
    AppTokens tokens,
  ) {
    final isSelected = activeSeconds == seconds;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(crossfadeDurationProvider.notifier).setCrossfadeDuration(seconds);
        widget.onChanged?.call(seconds);
      },
      borderRadius: BorderRadius.circular(4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : tokens.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontFamily: AppTheme.fontUi,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Crossfade Settings Card Widget
// ============================================================================

/// Full-featured playback settings card for configuring Audio Crossfade.
///
/// Designed for clean integration into Softify's Settings screen.
///
/// Includes:
/// - Visual icon avatar and title.
/// - Switch to enable/disable (gapless vs active crossfade).
/// - Seamless [CrossfadeDurationSlider] with second markers.
/// - Informational explanation footer detailing audio buffer pre-mixing.
class CrossfadeSettingsCard extends ConsumerWidget {
  /// Optional title override (defaults to "Audio Crossfade").
  final String? title;

  /// Optional subtitle override.
  final String? subtitle;

  /// Optional outer padding.
  final EdgeInsetsGeometry? padding;

  const CrossfadeSettingsCard({
    super.key,
    this.title,
    this.subtitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final crossfadeSeconds = ref.watch(crossfadeDurationProvider);
    final isGapless = crossfadeSeconds == 0;
    final isEnabled = !isGapless;

    return AppSurface(
      withBlur: true,
      padding: padding ?? const EdgeInsets.all(16.0),
      borderRadius: BorderRadius.circular(tokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Leading Icon, Titles, and Quick Switch
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: tokens.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? 'Audio Crossfade',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTheme.fontUi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle ??
                          (isGapless
                              ? 'Gapless playback (no volume dip or overlap)'
                              : 'Crossfading $crossfadeSeconds seconds between songs'),
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                        fontFamily: AppTheme.fontUi,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                activeColor: tokens.accent,
                onChanged: (_) {
                  ref.read(crossfadeDurationProvider.notifier).toggleGapless();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.black26, height: 1),
          const SizedBox(height: 16),

          // Embedded Crossfade Duration Slider
          const CrossfadeDurationSlider(
            showHeader: true,
            showPresets: true,
            showSecondIndicators: true,
          ),

          const SizedBox(height: 14),

          // Informational Note
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(tokens.radiusCard),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'When set between 1s and 12s, Softify smoothly pre-buffers and blends the outgoing and incoming audio. At 0s, songs switch instantaneously with pure gapless playback.',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                      fontFamily: AppTheme.fontUi,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
