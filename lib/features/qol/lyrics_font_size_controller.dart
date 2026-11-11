import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// SharedPreferences Persistence Layer (Zero-Dependency & Self-Contained)
// ============================================================================

/// SharedPreferences storage keys for lyrics font and spacing scaler.
const String kLyricsFontSizeScalePrefKey = 'lyrics_font_size_scale';
const String kLyricsLineHeightScalePrefKey = 'lyrics_line_height_scale';

/// Self-contained, durable SharedPreferences engine matching the standard
/// `package:shared_preferences` API interface without requiring external native
/// compilation plugins.
///
/// Persists values to `shared_preferences.json` in the application support
/// directory, with fast in-memory caching and synchronous read capabilities.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible cached singleton instance if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock values for testing environments.
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

  String? getString(String key) {
    final val = _store[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  List<String>? getStringList(String key) {
    final val = _store[key];
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    _store[key] = List<String>.from(value);
    await _persist();
    return true;
  }

  Object? get(String key) => _store[key];

  bool containsKey(String key) => _store.containsKey(key);

  Set<String> getKeys() => _store.keys.toSet();

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
// State Notifiers & Providers
// ============================================================================

/// StateNotifier managing lyrics font size scale factor from 0.8x to 1.6x (default 1.0x).
class LyricsFontSizeScaleNotifier extends StateNotifier<double> {
  static const double minScale = 0.8;
  static const double maxScale = 1.6;
  static const double defaultScale = 1.0;
  static const double step = 0.05;

  SharedPreferences? _prefs;

  LyricsFontSizeScaleNotifier({SharedPreferences? prefs, double? initialScale})
      : _prefs = prefs,
        super(
          (initialScale ??
                  prefs?.getDouble(kLyricsFontSizeScalePrefKey) ??
                  SharedPreferences.instance?.getDouble(kLyricsFontSizeScalePrefKey) ??
                  defaultScale)
              .clamp(minScale, maxScale),
        ) {
    if (initialScale == null) {
      _loadFromPrefs();
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final saved = _prefs!.getDouble(kLyricsFontSizeScalePrefKey);
      if (saved != null && mounted) {
        state = double.parse(
          saved.clamp(minScale, maxScale).toStringAsFixed(2),
        );
      }
    } catch (_) {}
  }

  /// Sets the font size scale factor, clamped to [0.8, 1.6] and persisted.
  Future<void> setScale(double newScale) async {
    final clamped = double.parse(
      newScale.clamp(minScale, maxScale).toStringAsFixed(2),
    );
    if ((state - clamped).abs() < 0.001) return;
    state = clamped;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setDouble(kLyricsFontSizeScalePrefKey, clamped);
    } catch (_) {}
  }

  /// Increases font size by [delta] (defaults to 0.05).
  Future<void> increase([double delta = step]) => setScale(state + delta);

  /// Decreases font size by [delta] (defaults to 0.05).
  Future<void> decrease([double delta = step]) => setScale(state - delta);

  /// Resets font size scale to the canonical 1.0x default.
  Future<void> reset() => setScale(defaultScale);

  /// Returns true if font scale is at default 1.0x.
  bool get isDefault => (state - defaultScale).abs() < 0.001;

  /// Human-readable percentage representation (e.g. "100%", "120%").
  String get percentageText => '${(state * 100).round()}%';
}

/// Riverpod provider for lyrics font size scale factor (0.8x to 1.6x, default 1.0x).
final lyricsFontSizeScaleProvider =
    StateNotifierProvider<LyricsFontSizeScaleNotifier, double>((ref) {
  return LyricsFontSizeScaleNotifier();
});

/// StateNotifier managing lyrics line height (spacing) scale factor.
/// Range: 0.8x to 2.0x (default 1.0x).
class LyricsLineHeightScaleNotifier extends StateNotifier<double> {
  static const double minScale = 0.8;
  static const double maxScale = 2.0;
  static const double defaultScale = 1.0;
  static const double step = 0.05;

  SharedPreferences? _prefs;

  LyricsLineHeightScaleNotifier({SharedPreferences? prefs, double? initialScale})
      : _prefs = prefs,
        super(
          (initialScale ??
                  prefs?.getDouble(kLyricsLineHeightScalePrefKey) ??
                  SharedPreferences.instance?.getDouble(kLyricsLineHeightScalePrefKey) ??
                  defaultScale)
              .clamp(minScale, maxScale),
        ) {
    if (initialScale == null) {
      _loadFromPrefs();
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final saved = _prefs!.getDouble(kLyricsLineHeightScalePrefKey);
      if (saved != null && mounted) {
        state = double.parse(
          saved.clamp(minScale, maxScale).toStringAsFixed(2),
        );
      }
    } catch (_) {}
  }

  /// Sets the line spacing scale factor, clamped to [0.8, 2.0] and persisted.
  Future<void> setScale(double newScale) async {
    final clamped = double.parse(
      newScale.clamp(minScale, maxScale).toStringAsFixed(2),
    );
    if ((state - clamped).abs() < 0.001) return;
    state = clamped;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setDouble(kLyricsLineHeightScalePrefKey, clamped);
    } catch (_) {}
  }

  /// Increases line spacing by [delta] (defaults to 0.05).
  Future<void> increase([double delta = step]) => setScale(state + delta);

  /// Decreases line spacing by [delta] (defaults to 0.05).
  Future<void> decrease([double delta = step]) => setScale(state - delta);

  /// Resets line spacing scale to 1.0x.
  Future<void> reset() => setScale(defaultScale);

  /// Returns true if line height is at default 1.0x.
  bool get isDefault => (state - defaultScale).abs() < 0.001;

  /// Human-readable percentage representation.
  String get percentageText => '${(state * 100).round()}%';
}

/// Riverpod provider for lyrics line height scale factor (0.8x to 2.0x, default 1.0x).
final lyricsLineHeightScaleProvider =
    StateNotifierProvider<LyricsLineHeightScaleNotifier, double>((ref) {
  return LyricsLineHeightScaleNotifier();
});

/// Immutable configuration holding both font size and line height scales.
class LyricsTypographyScale {
  final double fontSizeScale;
  final double lineHeightScale;

  const LyricsTypographyScale({
    this.fontSizeScale = LyricsFontSizeScaleNotifier.defaultScale,
    this.lineHeightScale = LyricsLineHeightScaleNotifier.defaultScale,
  });

  /// Calculates scaled font size given a base size.
  double scaleFontSize(double base) => (base * fontSizeScale).clamp(10.0, 60.0);

  /// Calculates scaled line height given a base line height multiplier.
  double scaleLineHeight(double base) => (base * lineHeightScale).clamp(0.8, 3.0);

  /// Whether typography matches default 1.0x on both axes.
  bool get isDefault =>
      (fontSizeScale - 1.0).abs() < 0.001 &&
      (lineHeightScale - 1.0).abs() < 0.001;
}

/// Combined Riverpod provider for unified lyrics typography scaling.
final lyricsTypographyScaleProvider = Provider<LyricsTypographyScale>((ref) {
  final fontSizeScale = ref.watch(lyricsFontSizeScaleProvider);
  final lineHeightScale = ref.watch(lyricsLineHeightScaleProvider);
  return LyricsTypographyScale(
    fontSizeScale: fontSizeScale,
    lineHeightScale: lineHeightScale,
  );
});

// ============================================================================
// Quick Font Scale Button for Lyrics Screens
// ============================================================================

/// Quick font scale button designed for lyrics screens and player toolbars.
///
/// Tapping opens [LyricsFontScaleSheet] to adjust size and spacing with preview.
/// If user has customized their typography (non-default scale), an accent indicator
/// dot is presented on the button.
class LyricsFontScaleButton extends ConsumerWidget {
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final bool showBadge;
  final VoidCallback? onTap;
  final String? tooltip;

  const LyricsFontScaleButton({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.showBadge = true,
    this.onTap,
    this.tooltip = 'Lyrics Typography & Spacing',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typo = ref.watch(lyricsTypographyScaleProvider);
    final isCustomized = !typo.isDefault;

    final effectiveIconColor = iconColor ??
        (isCustomized ? AppTheme.accent : AppTheme.textPrimary);

    final button = BouncingScaleButton(
      scaleDown: 0.92,
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          LyricsFontScaleSheet.show(context);
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isCustomized
                  ? AppTheme.accent.withOpacity(0.14)
                  : Colors.white.withOpacity(0.08)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isCustomized
                ? AppTheme.accent.withOpacity(0.35)
                : Colors.white.withOpacity(0.12),
            width: 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.format_size_rounded,
              color: effectiveIconColor,
              size: iconSize,
            ),
            if (showBadge && isCustomized)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

// ============================================================================
// Lyrics Font Scale Sheet with Live Interactive Preview
// ============================================================================

/// Bottom sheet modal allowing users to adjust lyrics font size (0.8x-1.6x)
/// and line height spacing (0.8x-2.0x) with real-time interactive preview text.
class LyricsFontScaleSheet extends ConsumerStatefulWidget {
  const LyricsFontScaleSheet({super.key});

  /// Presents the [LyricsFontScaleSheet] in a standard modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (context) => const LyricsFontScaleSheet(),
    );
  }

  @override
  ConsumerState<LyricsFontScaleSheet> createState() =>
      _LyricsFontScaleSheetState();
}

class _LyricsFontScaleSheetState extends ConsumerState<LyricsFontScaleSheet> {
  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(lyricsFontSizeScaleProvider);
    final lineScale = ref.watch(lyricsLineHeightScaleProvider);
    final fontNotifier = ref.read(lyricsFontSizeScaleProvider.notifier);
    final lineNotifier = ref.read(lyricsLineHeightScaleProvider.notifier);

    final isDefault = (fontScale - 1.0).abs() < 0.001 &&
        (lineScale - 1.0).abs() < 0.001;

    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.text_fields_rounded,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lyrics Typography',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                              fontFamily: AppTheme.fontPageTitle,
                            ),
                          ),
                          Text(
                            'Adjust font scale and line spacing',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reset Button
                    BouncingScaleButton(
                      scaleDown: 0.95,
                      onTap: isDefault
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              fontNotifier.reset();
                              lineNotifier.reset();
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDefault
                              ? Colors.white.withOpacity(0.04)
                              : AppTheme.accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDefault
                                ? Colors.transparent
                                : AppTheme.accent.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: 14,
                              color: isDefault
                                  ? AppTheme.textMuted
                                  : AppTheme.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDefault
                                    ? AppTheme.textMuted
                                    : AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Live Lyrics Preview Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildLiveLyricsPreview(fontScale, lineScale),
              ),

              const SizedBox(height: 20),

              // Controls Section (Scrollable if height constrained)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Font Size Scaler
                      _buildControlGroup(
                        title: 'Font Size',
                        currentValueText: '${(fontScale * 100).round()}% (${fontScale.toStringAsFixed(2)}x)',
                        sliderValue: fontScale,
                        min: LyricsFontSizeScaleNotifier.minScale,
                        max: LyricsFontSizeScaleNotifier.maxScale,
                        divisions: 16,
                        onChanged: (val) {
                          fontNotifier.setScale(val);
                        },
                        onStepDown: () {
                          HapticFeedback.selectionClick();
                          fontNotifier.decrease();
                        },
                        onStepUp: () {
                          HapticFeedback.selectionClick();
                          fontNotifier.increase();
                        },
                        presets: const [
                          _ScalePreset(label: 'Compact', scale: 0.8),
                          _ScalePreset(label: 'Normal', scale: 1.0),
                          _ScalePreset(label: 'Large', scale: 1.25),
                          _ScalePreset(label: 'Max', scale: 1.6),
                        ],
                        activeScale: fontScale,
                        onSelectPreset: (presetScale) {
                          HapticFeedback.mediumImpact();
                          fontNotifier.setScale(presetScale);
                        },
                      ),

                      const SizedBox(height: 20),

                      // Line Spacing Scaler
                      _buildControlGroup(
                        title: 'Line Spacing',
                        currentValueText: '${(lineScale * 100).round()}% (${lineScale.toStringAsFixed(2)}x)',
                        sliderValue: lineScale,
                        min: LyricsLineHeightScaleNotifier.minScale,
                        max: LyricsLineHeightScaleNotifier.maxScale,
                        divisions: 24,
                        onChanged: (val) {
                          lineNotifier.setScale(val);
                        },
                        onStepDown: () {
                          HapticFeedback.selectionClick();
                          lineNotifier.decrease();
                        },
                        onStepUp: () {
                          HapticFeedback.selectionClick();
                          lineNotifier.increase();
                        },
                        presets: const [
                          _ScalePreset(label: 'Tight', scale: 0.85),
                          _ScalePreset(label: 'Normal', scale: 1.0),
                          _ScalePreset(label: 'Relaxed', scale: 1.3),
                          _ScalePreset(label: 'Spacious', scale: 1.6),
                        ],
                        activeScale: lineScale,
                        onSelectPreset: (presetScale) {
                          HapticFeedback.mediumImpact();
                          lineNotifier.setScale(presetScale);
                        },
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, math.max(16, bottomPadding + 8)),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BouncingScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Apply & Done',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveLyricsPreview(double fontScale, double lineScale) {
    final activeFontSize = (21.0 * fontScale).clamp(13.0, 36.0);
    final inactiveFontSize = (17.0 * fontScale).clamp(11.0, 29.0);
    final effectiveHeight = (1.35 * lineScale).clamp(0.9, 2.6);
    final lineSpacing = (10.0 * lineScale).clamp(4.0, 26.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live preview badge
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent.withOpacity(0.9),
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                'Text: ${(fontScale * 100).round()}% • Spacing: ${(lineScale * 100).round()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Inactive Lyric Line 1
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: inactiveFontSize,
              height: effectiveHeight,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary.withOpacity(0.55),
              fontFamily: AppTheme.fontUi,
            ),
            child: const Text('I hear the music through the night'),
          ),

          SizedBox(height: lineSpacing),

          // Active Lyric Line (Highlighted)
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: activeFontSize,
              height: effectiveHeight,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: AppTheme.fontUi,
              shadows: [
                Shadow(
                  color: AppTheme.accent.withOpacity(0.55),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3.5,
                  height: activeFontSize * 0.9,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Expanded(
                  child: Text('Every beat is singing your name'),
                ),
              ],
            ),
          ),

          SizedBox(height: lineSpacing),

          // Inactive Lyric Line 2
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: inactiveFontSize,
              height: effectiveHeight,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary.withOpacity(0.55),
              fontFamily: AppTheme.fontUi,
            ),
            child: const Text('Lost in melodies that never fade away'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlGroup({
    required String title,
    required String currentValueText,
    required double sliderValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required VoidCallback onStepDown,
    required VoidCallback onStepUp,
    required List<_ScalePreset> presets,
    required double activeScale,
    required ValueChanged<double> onSelectPreset,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardHover.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Label + Value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  currentValueText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Slider with Steppers
          Row(
            children: [
              // Minus step button
              _buildStepIconButton(
                icon: Icons.remove_rounded,
                onTap: onStepDown,
                enabled: sliderValue > min,
              ),

              // Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: Colors.white.withOpacity(0.12),
                    thumbColor: Colors.white,
                    overlayColor: AppTheme.accent.withOpacity(0.2),
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8.0,
                      elevation: 3.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18.0,
                    ),
                  ),
                  child: Slider(
                    value: sliderValue.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ),

              // Plus step button
              _buildStepIconButton(
                icon: Icons.add_rounded,
                onTap: onStepUp,
                enabled: sliderValue < max,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Presets Row
          Row(
            children: presets.map((p) {
              final isSelected = (activeScale - p.scale).abs() < 0.04;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: BouncingScaleButton(
                    scaleDown: 0.94,
                    onTap: () => onSelectPreset(p.scale),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accent
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accent
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return BouncingScaleButton(
      scaleDown: 0.9,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? Colors.white.withOpacity(0.12)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _ScalePreset {
  final String label;
  final double scale;

  const _ScalePreset({
    required this.label,
    required this.scale,
  });
}
