import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// SharedPreferences Persistence Layer (Zero-Dependency & Self-Contained)
// ============================================================================

/// SharedPreferences storage key for lyrics font style.
const String kLyricsFontStylePrefKey = 'lyrics_font_style_id';

/// Self-contained, durable SharedPreferences engine matching standard
/// SharedPreferences semantics without requiring external native plugins.
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

  String? getString(String key) {
    final val = _store[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
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
// Enums & Models: LyricsFontStyle
// ============================================================================

/// Represents the available typography and font styling choices for synced lyrics.
///
/// Supports 4 curated styles:
/// 1. [LyricsFontStyle.modernSans] - Clean, modern geometric sans-serif (Manrope).
/// 2. [LyricsFontStyle.elegantSerif] - Poetic, editorial serif with graceful curves (InstrumentSerif).
/// 3. [LyricsFontStyle.monospacedLyricist] - Fixed-width typewriter cadence for chord charts & rhyme meter.
/// 4. [LyricsFontStyle.displayBold] - Punchy, high-energy grotesque display typography (BricolageGrotesque).
enum LyricsFontStyle {
  modernSans(
    id: 'modern_sans',
    displayName: 'Modern Sans',
    fontFamily: AppTheme.fontUi, // 'Manrope'
    fallbackFamily: 'sans-serif',
    description: 'Clean, contemporary geometric clarity for effortless reading',
    previewBadge: 'Aa',
    defaultWeight: FontWeight.w600,
    activeWeight: FontWeight.w800,
    letterSpacing: -0.2,
    icon: Icons.font_download_outlined,
  ),
  elegantSerif(
    id: 'elegant_serif',
    displayName: 'Elegant Serif',
    fontFamily: AppTheme.fontEditorial, // 'InstrumentSerif'
    fallbackFamily: 'serif',
    description: 'Poetic, expressive editorial aesthetic with graceful curves',
    previewBadge: '𝒬𝒶',
    defaultWeight: FontWeight.w500,
    activeWeight: FontWeight.w700,
    letterSpacing: 0.1,
    icon: Icons.auto_stories_outlined,
  ),
  monospacedLyricist(
    id: 'monospaced_lyricist',
    displayName: 'Monospaced Lyricist',
    fontFamily: 'monospace',
    fallbackFamily: 'Courier',
    description: 'Fixed-width typewriter cadence for rhyme meters & studio chords',
    previewBadge: '>_',
    defaultWeight: FontWeight.w600,
    activeWeight: FontWeight.w800,
    letterSpacing: -0.5,
    icon: Icons.terminal_rounded,
  ),
  displayBold(
    id: 'display_bold',
    displayName: 'Display Bold',
    fontFamily: AppTheme.fontDisplay, // 'BricolageGrotesque'
    fallbackFamily: 'sans-serif',
    description: 'High-energy, punchy grotesque typography for anthems & impact',
    previewBadge: 'AA',
    defaultWeight: FontWeight.w700,
    activeWeight: FontWeight.w900,
    letterSpacing: -0.4,
    icon: Icons.format_bold_rounded,
  );

  final String id;
  final String displayName;
  final String fontFamily;
  final String fallbackFamily;
  final String description;
  final String previewBadge;
  final FontWeight defaultWeight;
  final FontWeight activeWeight;
  final double letterSpacing;
  final IconData icon;

  const LyricsFontStyle({
    required this.id,
    required this.displayName,
    required this.fontFamily,
    required this.fallbackFamily,
    required this.description,
    required this.previewBadge,
    required this.defaultWeight,
    required this.activeWeight,
    required this.letterSpacing,
    required this.icon,
  });

  /// Resolves a [LyricsFontStyle] from its unique string [id].
  ///
  /// Falls back to [LyricsFontStyle.modernSans] if not found or null.
  static LyricsFontStyle fromId(String? id) {
    if (id == null) return LyricsFontStyle.modernSans;
    final normalized = id.trim().toLowerCase();
    return LyricsFontStyle.values.firstWhere(
      (style) => style.id.toLowerCase() == normalized,
      orElse: () => LyricsFontStyle.modernSans,
    );
  }

  /// Resolves a [LyricsFontStyle] from an integer index safely.
  static LyricsFontStyle fromIndex(int? index) {
    if (index == null || index < 0 || index >= LyricsFontStyle.values.length) {
      return LyricsFontStyle.modernSans;
    }
    return LyricsFontStyle.values[index];
  }

  /// Produces a configured [TextStyle] matching this font style.
  TextStyle toTextStyle({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? height,
    double? letterSpacing,
    bool isActive = false,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: [fallbackFamily],
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight ?? (isActive ? activeWeight : defaultWeight),
      fontStyle: fontStyle ?? FontStyle.normal,
      height: height,
      letterSpacing: letterSpacing ?? this.letterSpacing,
    );
  }
}

// ============================================================================
// State Notifier & Providers
// ============================================================================

/// StateNotifier responsible for managing and persisting the active lyrics font style.
class LyricsFontStyleNotifier extends StateNotifier<LyricsFontStyle> {
  static const LyricsFontStyle defaultStyle = LyricsFontStyle.modernSans;

  SharedPreferences? _prefs;

  LyricsFontStyleNotifier({
    LyricsFontStyle initialStyle = defaultStyle,
    SharedPreferences? prefs,
  })  : _prefs = prefs,
        super(initialStyle) {
    _initPersistence();
  }

  Future<void> _initPersistence() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedId = _prefs?.getString(kLyricsFontStylePrefKey);
      if (savedId != null && savedId.isNotEmpty) {
        state = LyricsFontStyle.fromId(savedId);
      }
    } catch (_) {
      // In-memory fallback if storage is inaccessible
    }
  }

  /// Changes the active lyrics font style and persists to local storage.
  Future<void> setStyle(LyricsFontStyle style) async {
    if (state == style) return;
    state = style;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(kLyricsFontStylePrefKey, style.id);
    } catch (_) {}
  }

  /// Selects a font style by string ID.
  Future<void> selectById(String id) async {
    final style = LyricsFontStyle.fromId(id);
    await setStyle(style);
  }

  /// Cycles to the next available font style in circular order.
  Future<void> cycleNext() async {
    final nextIndex = (state.index + 1) % LyricsFontStyle.values.length;
    await setStyle(LyricsFontStyle.values[nextIndex]);
  }

  /// Resets font style to default [LyricsFontStyle.modernSans].
  Future<void> reset() async {
    await setStyle(defaultStyle);
  }

  /// Whether current active style is the system default.
  bool get isDefault => state == defaultStyle;
}

/// Riverpod provider for active lyrics font style.
final lyricsFontStyleProvider =
    StateNotifierProvider<LyricsFontStyleNotifier, LyricsFontStyle>((ref) {
  return LyricsFontStyleNotifier();
});

/// Riverpod provider returning the current active font family string.
final lyricsFontFamilyProvider = Provider<String>((ref) {
  return ref.watch(lyricsFontStyleProvider).fontFamily;
});

// ============================================================================
// Pure Helper: LyricsTypographyHelper
// ============================================================================

/// Pure helper providing typography builders for lyrics rendering widgets.
class LyricsTypographyHelper {
  const LyricsTypographyHelper._();

  /// Resolves the configured [TextStyle] for a lyrics line.
  static TextStyle getLyricsStyle(
    LyricsFontStyle style, {
    required bool isActive,
    double? fontSize,
    Color? activeColor,
    Color? inactiveColor,
    double? height,
  }) {
    return style.toTextStyle(
      fontSize: fontSize,
      isActive: isActive,
      color: isActive
          ? (activeColor ?? AppTheme.textPrimary)
          : (inactiveColor ?? AppTheme.textMuted),
      height: height,
    );
  }
}

// ============================================================================
// UI Component: LyricsFontSwitcherButton
// ============================================================================

/// Quick font switcher icon button designed for lyrics screens and playback toolbars.
///
/// Tapping opens [LyricsFontPickerSheet] to switch typeface with real-time preview.
/// If user has a non-default font style selected, shows an accent indicator dot.
class LyricsFontSwitcherButton extends ConsumerWidget {
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final bool showBadge;
  final VoidCallback? onTap;
  final String? tooltip;

  const LyricsFontSwitcherButton({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.showBadge = true,
    this.onTap,
    this.tooltip = 'Lyrics Typography & Font',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStyle = ref.watch(lyricsFontStyleProvider);
    final isCustomized = currentStyle != LyricsFontStyle.modernSans;

    final effectiveIconColor = iconColor ??
        (isCustomized ? AppTheme.accent : AppTheme.textPrimary);

    final button = BouncingScaleButton(
      scaleDown: 0.92,
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          LyricsFontPickerSheet.show(context);
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
              Icons.font_download_outlined,
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
// UI Component: LyricsFontSelectorBar (Horizontal Segmented Control)
// ============================================================================

/// Compact horizontal segmented bar allowing instant one-tap switching between
/// all 4 lyrics font styles. Ideal for embedding in settings, sidebars, or toolbars.
class LyricsFontSelectorBar extends ConsumerWidget {
  final EdgeInsetsGeometry padding;

  const LyricsFontSelectorBar({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStyle = ref.watch(lyricsFontStyleProvider);
    final notifier = ref.read(lyricsFontStyleProvider.notifier);

    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: LyricsFontStyle.values.map((style) {
            final isSelected = style == currentStyle;
            return Expanded(
              child: BouncingScaleButton(
                scaleDown: 0.95,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setStyle(style);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      style.displayName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: style.fontFamily,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ============================================================================
// UI Component: LyricsFontPickerSheet with Live Text Preview
// ============================================================================

/// Bottom sheet modal allowing users to select their preferred lyrics font style
/// with real-time interactive preview of synchronized lyric lines.
class LyricsFontPickerSheet extends ConsumerStatefulWidget {
  const LyricsFontPickerSheet({super.key});

  /// Presents the [LyricsFontPickerSheet] in a standard modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.68),
      builder: (context) => const LyricsFontPickerSheet(),
    );
  }

  @override
  ConsumerState<LyricsFontPickerSheet> createState() =>
      _LyricsFontPickerSheetState();
}

class _LyricsFontPickerSheetState extends ConsumerState<LyricsFontPickerSheet> {
  int _activePreviewLineIndex = 1;

  static const List<String> _sampleLyrics = [
    'I found a love to carry more than just my secrets',
    'Dancing in the shadows of the fading twilight',
    'Watching the stars illuminate our silhouette',
  ];

  @override
  Widget build(BuildContext context) {
    final currentStyle = ref.watch(lyricsFontStyleProvider);
    final notifier = ref.read(lyricsFontStyleProvider.notifier);
    final isDefault = currentStyle == LyricsFontStyle.modernSans;

    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
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

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
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
                            'Choose typeface for synchronized lyrics display',
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
                              notifier.reset();
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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

              // ================================================================
              // Live Text Preview Card
              // ================================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.24),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.08),
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview Badge & Active Font Tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
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
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: AppTheme.accent.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentStyle.displayName,
                              style: TextStyle(
                                fontFamily: currentStyle.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Synchronized Preview Lines
                      ...List.generate(_sampleLyrics.length, (index) {
                        final isLineActive = index == _activePreviewLineIndex;
                        final text = _sampleLyrics[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activePreviewLineIndex = index);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isLineActive
                                    ? AppTheme.accent.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left active pill indicator
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    width: 3.5,
                                    height: isLineActive ? 22 : 0,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  SizedBox(width: isLineActive ? 8 : 0),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: TextStyle(
                                        fontFamily: currentStyle.fontFamily,
                                        fontFamilyFallback: [currentStyle.fallbackFamily],
                                        fontSize: isLineActive ? 15 : 13.5,
                                        fontWeight: isLineActive
                                            ? currentStyle.activeWeight
                                            : currentStyle.defaultWeight,
                                        letterSpacing: currentStyle.letterSpacing,
                                        color: isLineActive
                                            ? AppTheme.textPrimary
                                            : AppTheme.textMuted.withOpacity(0.7),
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ================================================================
              // Font Style Selector Section
              // ================================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT TYPEFACE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppTheme.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 4 Font Style Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: LyricsFontStyle.values.map((style) {
                    final isSelected = style == currentStyle;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BouncingScaleButton(
                        scaleDown: 0.98,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          notifier.setStyle(style);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent.withOpacity(0.12)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accent
                                  : Colors.white.withOpacity(0.08),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Visual badge in style font
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accent.withOpacity(0.20)
                                      : Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accent.withOpacity(0.4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    style.previewBadge,
                                    style: TextStyle(
                                      fontFamily: style.fontFamily,
                                      fontSize: 17,
                                      fontWeight: style.activeWeight,
                                      color: isSelected
                                          ? AppTheme.accent
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Title and Description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      style.displayName,
                                      style: TextStyle(
                                        fontFamily: style.fontFamily,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppTheme.accent
                                            : AppTheme.textPrimary,
                                        letterSpacing: style.letterSpacing,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      style.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppTheme.textSecondary
                                            .withOpacity(0.85),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Selection Indicator (Radio / Checkmark)
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? AppTheme.accent
                                    : AppTheme.textMuted.withOpacity(0.6),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Done Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: BouncingScaleButton(
                    scaleDown: 0.97,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: bottomPadding + 16),
            ],
          ),
        ),
      ),
    );
  }
}
