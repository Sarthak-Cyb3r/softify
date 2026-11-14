// ============================================================================
// Softify Quality of Life (QoL): Feature 44 - Dynamic Palette from Cover Art
// ============================================================================
//
// Advanced Material 3 dynamic color scheme and palette extraction engine
// optimized for lyrics display, album art ambient glow, and immersive
// playback backgrounds.
//
// Extracts dominant, vibrant, light vibrant, muted, and specialized
// low-luminance dark surface colors from album cover image providers.
// Dynamically constructs WCAG-compliant Material 3 ColorSchemes and provides
// customizable surface darkness, saturation tuning, and OLED pure black mode.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Storage & Persistence Contracts (SharedPreferences Compatible)
// ============================================================================

/// SharedPreferences persistent storage keys for Dynamic Cover Color Palette.
const String kDynamicPaletteEnabledPrefKey = 'softify_dynamic_palette_enabled';
const String kDynamicPaletteModePrefKey = 'softify_dynamic_palette_mode';
const String kDynamicPaletteSurfaceDarknessPrefKey =
    'softify_dynamic_palette_surface_darkness';
const String kDynamicPaletteSaturationPrefKey =
    'softify_dynamic_palette_saturation_mult';
const String kDynamicPaletteOledPrefKey = 'softify_dynamic_palette_oled_mode';

/// Contract for persistent storage compatible with SharedPreferences semantics.
abstract class DynamicPalettePrefsStorage {
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<double?> getDouble(String key);
  Future<bool> setDouble(String key, double value);
}

/// Durable, self-contained key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class DynamicPaletteSharedPreferencesStore
    implements DynamicPalettePrefsStorage {
  static final DynamicPaletteSharedPreferencesStore _instance =
      DynamicPaletteSharedPreferencesStore._internal();
  factory DynamicPaletteSharedPreferencesStore() => _instance;
  DynamicPaletteSharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;
  static Map<String, dynamic>? _mockInitialValues;

  /// Injects mock initial values for isolated testing environments.
  static void setMockInitialValues(Map<String, dynamic> values) {
    _mockInitialValues = Map<String, dynamic>.from(values);
    _instance._memoryCache = Map<String, dynamic>.from(values);
    _instance._isLoaded = true;
    _instance._cacheFile = null;
  }

  /// Resets test overrides and memory caches.
  static void resetForTesting() {
    _mockInitialValues = null;
    _instance._memoryCache.clear();
    _instance._isLoaded = false;
    _instance._cacheFile = null;
  }

  /// Asynchronously initializes storage file and loads cached settings.
  Future<void> init() async {
    if (_isLoaded) return;
    if (_mockInitialValues != null) {
      _memoryCache = Map<String, dynamic>.from(_mockInitialValues!);
      _isLoaded = true;
      return;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      final targetDir = Directory(dir.path);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
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
    } finally {
      _isLoaded = true;
    }
  }

  Future<void> _persist() async {
    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
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
  Future<String?> getString(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    return value?.toString();
  }

  @override
  Future<bool> setString(String key, String value) async {
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
}

// ============================================================================
// Palette Extraction Modes
// ============================================================================

/// Aesthetic modes for applying dynamic cover art color palettes.
enum DynamicPaletteMode {
  /// Focuses on high-energy, saturated tones from the artwork for primary accents.
  vibrant('Vibrant Accent', 'High-energy saturated hues from cover art',
      Icons.flash_on_rounded),

  /// Uses the most prominent, voluminous color tone in the artwork.
  dominant('Dominant Harmony', 'Color schemes grounded in cover art volume',
      Icons.pie_chart_rounded),

  /// Subtle, pastel-like, calmer tone for a relaxed reading atmosphere.
  muted('Muted Atmosphere', 'Subtle, soft pastels for relaxed listening',
      Icons.spa_rounded),

  /// Pure pitch-black OLED background with vivid neon highlights.
  oledContrast('OLED High-Contrast',
      'Pitch black background with neon highlights', Icons.contrast_rounded);

  final String label;
  final String description;
  final IconData icon;

  const DynamicPaletteMode(this.label, this.description, this.icon);

  static DynamicPaletteMode fromString(String? raw) {
    if (raw == null) return DynamicPaletteMode.vibrant;
    for (final mode in DynamicPaletteMode.values) {
      if (mode.name == raw || mode.toString() == raw) {
        return mode;
      }
    }
    return DynamicPaletteMode.vibrant;
  }
}

// ============================================================================
// Extracted Cover Colors Model
// ============================================================================

/// Extracted color set containing dominant, vibrant, light vibrant, muted,
/// dark muted, and specialized dark surface colors derived from album art.
@immutable
class ExtractedCoverColors {
  /// The most frequent / prominent color in the artwork.
  final Color dominantColor;

  /// High-energy, saturated color ideal for primary highlights.
  final Color vibrantColor;

  /// Light, bright vibrant tint useful for glow highlights or glow gradients.
  final Color lightVibrantColor;

  /// Subtle, desaturated color for secondary UI elements.
  final Color mutedColor;

  /// Deep muted tone for borders and dividers.
  final Color darkMutedColor;

  /// Custom low-luminance dark surface color tuned for dark-mode lyrics reading.
  final Color darkSurfaceColor;

  /// The root seed color used to derive the harmony.
  final Color seedColor;

  const ExtractedCoverColors({
    required this.dominantColor,
    required this.vibrantColor,
    required this.lightVibrantColor,
    required this.mutedColor,
    required this.darkMutedColor,
    required this.darkSurfaceColor,
    required this.seedColor,
  });

  /// Default baseline palette matching Softify Metrolist Signature Coral Red.
  factory ExtractedCoverColors.defaultPalette({
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) {
    const seed = Color(0xFFED5564); // Metrolist Coral Red
    return ExtractedCoverColors.fromSeed(
      seed,
      surfaceDarkness: surfaceDarkness,
      saturationMultiplier: saturationMultiplier,
      isOled: isOled,
    );
  }

  /// Derives a full harmonic set of colors from a single seed color.
  factory ExtractedCoverColors.fromSeed(
    Color seed, {
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) {
    final hsv = HSVColor.fromColor(seed);

    final vibrant = hsv
        .withSaturation(
            (hsv.saturation * 1.2 * saturationMultiplier).clamp(0.4, 1.0))
        .withValue((hsv.value * 1.05).clamp(0.65, 0.95))
        .toColor();

    final lightVibrant = hsv
        .withSaturation(
            (hsv.saturation * 0.7 * saturationMultiplier).clamp(0.2, 0.7))
        .withValue(0.92)
        .toColor();

    final muted = hsv
        .withSaturation(
            (hsv.saturation * 0.45 * saturationMultiplier).clamp(0.15, 0.5))
        .withValue(0.60)
        .toColor();

    final darkMuted = hsv
        .withSaturation(
            (hsv.saturation * 0.3 * saturationMultiplier).clamp(0.1, 0.35))
        .withValue(0.25)
        .toColor();

    final darkSurface =
        DynamicMaterial3ColorSchemeGenerator.deriveDarkSurfaceColor(
      seed,
      darkness: surfaceDarkness,
      saturationScale: saturationMultiplier,
      oledBlack: isOled,
    );

    return ExtractedCoverColors(
      dominantColor: seed,
      vibrantColor: vibrant,
      lightVibrantColor: lightVibrant,
      mutedColor: muted,
      darkMutedColor: darkMuted,
      darkSurfaceColor: darkSurface,
      seedColor: seed,
    );
  }

  ExtractedCoverColors copyWith({
    Color? dominantColor,
    Color? vibrantColor,
    Color? lightVibrantColor,
    Color? mutedColor,
    Color? darkMutedColor,
    Color? darkSurfaceColor,
    Color? seedColor,
  }) {
    return ExtractedCoverColors(
      dominantColor: dominantColor ?? this.dominantColor,
      vibrantColor: vibrantColor ?? this.vibrantColor,
      lightVibrantColor: lightVibrantColor ?? this.lightVibrantColor,
      mutedColor: mutedColor ?? this.mutedColor,
      darkMutedColor: darkMutedColor ?? this.darkMutedColor,
      darkSurfaceColor: darkSurfaceColor ?? this.darkSurfaceColor,
      seedColor: seedColor ?? this.seedColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedCoverColors &&
          runtimeType == other.runtimeType &&
          dominantColor == other.dominantColor &&
          vibrantColor == other.vibrantColor &&
          lightVibrantColor == other.lightVibrantColor &&
          mutedColor == other.mutedColor &&
          darkMutedColor == other.darkMutedColor &&
          darkSurfaceColor == other.darkSurfaceColor &&
          seedColor == other.seedColor;

  @override
  int get hashCode => Object.hash(
        dominantColor,
        vibrantColor,
        lightVibrantColor,
        mutedColor,
        darkMutedColor,
        darkSurfaceColor,
        seedColor,
      );
}

// ============================================================================
// Material 3 Dynamic ColorScheme Generator
// ============================================================================

/// Dynamic Material 3 ColorScheme generator creating customized light and dark
/// color schemes derived from album artwork with guaranteed WCAG contrast.
class DynamicMaterial3ColorSchemeGenerator {
  DynamicMaterial3ColorSchemeGenerator._();

  /// Calculates the W3C relative luminance of a color (0.0 = black, 1.0 = white).
  static double computeLuminance(Color color) {
    return color.computeLuminance();
  }

  /// Calculates the WCAG contrast ratio between [foreground] and [background].
  /// Returns a value between 1.0 (identical) and 21.0 (black on white).
  static double computeContrastRatio(Color foreground, Color background) {
    final double l1 = foreground.computeLuminance();
    final double l2 = background.computeLuminance();
    final double lighter = math.max(l1, l2);
    final double darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Derives an atmospheric, low-luminance dark surface color from a source color.
  ///
  /// Preserves the musical hue while reducing saturation and value to ensure
  /// OLED-friendly darkness and zero eye fatigue during lyrics reading.
  static Color deriveDarkSurfaceColor(
    Color sourceColor, {
    double darkness = 0.85,
    double saturationScale = 1.0,
    bool oledBlack = false,
  }) {
    if (oledBlack) {
      return const Color(0xFF000000);
    }

    final hsv = HSVColor.fromColor(sourceColor);
    final effectiveSaturation =
        (hsv.saturation * 0.35 * saturationScale).clamp(0.04, 0.40);

    // Darkness slider from 0.0 to 1.0: 1.0 is deepest (value ~ 0.03), 0.0 is lighter (value ~ 0.16)
    final clampedDarkness = darkness.clamp(0.0, 1.0);
    final effectiveValue =
        ((1.0 - clampedDarkness) * 0.13 + 0.035).clamp(0.02, 0.18);

    return hsv
        .withSaturation(effectiveSaturation)
        .withValue(effectiveValue)
        .toColor();
  }

  /// Ensures a foreground text color maintains at least [minRatio] contrast against [background].
  static Color ensureMinimumContrast(
    Color foreground,
    Color background, {
    double minRatio = 4.5,
  }) {
    final currentRatio = computeContrastRatio(foreground, background);
    if (currentRatio >= minRatio) {
      return foreground;
    }

    final bgLuminance = background.computeLuminance();
    final hsv = HSVColor.fromColor(foreground);

    if (bgLuminance < 0.5) {
      // Lighten foreground
      for (double v = hsv.value; v <= 1.0; v += 0.05) {
        final candidate = hsv.withValue(v).toColor();
        if (computeContrastRatio(candidate, background) >= minRatio) {
          return candidate;
        }
      }
      return const Color(0xFFFFFFFF);
    } else {
      // Darken foreground
      for (double v = hsv.value; v >= 0.0; v -= 0.05) {
        final candidate = hsv.withValue(v).toColor();
        if (computeContrastRatio(candidate, background) >= minRatio) {
          return candidate;
        }
      }
      return const Color(0xFF000000);
    }
  }

  /// Generates a comprehensive Material 3 Dark [ColorScheme] customized for Softify.
  static ColorScheme generateDarkColorScheme({
    required Color seedColor,
    Color? vibrantAccent,
    Color? dominantColor,
    Color? darkSurface,
    DynamicPaletteMode mode = DynamicPaletteMode.vibrant,
    bool pureBlackSurface = false,
  }) {
    Color effectivePrimary;
    switch (mode) {
      case DynamicPaletteMode.vibrant:
        effectivePrimary = vibrantAccent ?? seedColor;
        break;
      case DynamicPaletteMode.dominant:
        effectivePrimary = dominantColor ?? seedColor;
        break;
      case DynamicPaletteMode.muted:
        final hsv = HSVColor.fromColor(vibrantAccent ?? seedColor);
        effectivePrimary =
            hsv.withSaturation((hsv.saturation * 0.55).clamp(0.2, 0.6)).toColor();
        break;
      case DynamicPaletteMode.oledContrast:
        final hsv = HSVColor.fromColor(vibrantAccent ?? seedColor);
        effectivePrimary =
            hsv.withSaturation(1.0).withValue(0.95).toColor();
        break;
    }

    // Ensure primary has adequate brightness on dark backgrounds
    final primaryHsv = HSVColor.fromColor(effectivePrimary);
    if (primaryHsv.value < 0.70) {
      effectivePrimary = primaryHsv.withValue(0.85).toColor();
    }

    final baseScheme = ColorScheme.fromSeed(
      seedColor: effectivePrimary,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    final effectiveSurface = pureBlackSurface || mode == DynamicPaletteMode.oledContrast
        ? const Color(0xFF000000)
        : (darkSurface ??
            deriveDarkSurfaceColor(dominantColor ?? seedColor, darkness: 0.85));

    final hsvSurface = HSVColor.fromColor(effectiveSurface);

    final surfaceContainerLowest = pureBlackSurface || mode == DynamicPaletteMode.oledContrast
        ? const Color(0xFF000000)
        : hsvSurface
            .withValue((hsvSurface.value * 0.8).clamp(0.01, 1.0))
            .toColor();

    final surfaceContainerLow = pureBlackSurface || mode == DynamicPaletteMode.oledContrast
        ? const Color(0xFF080808)
        : hsvSurface
            .withValue((hsvSurface.value + 0.02).clamp(0.0, 1.0))
            .toColor();

    final surfaceContainer = pureBlackSurface || mode == DynamicPaletteMode.oledContrast
        ? const Color(0xFF121212)
        : hsvSurface
            .withValue((hsvSurface.value + 0.045).clamp(0.0, 1.0))
            .toColor();

    final surfaceContainerHigh = pureBlackSurface || mode == DynamicPaletteMode.oledContrast
        ? const Color(0xFF1B1B1B)
        : hsvSurface
            .withValue((hsvSurface.value + 0.075).clamp(0.0, 1.0))
            .toColor();

    final surfaceContainerHighest = pureBlackSurface || mode == DynamicPaletteMode.oledContrast
        ? const Color(0xFF262626)
        : hsvSurface
            .withValue((hsvSurface.value + 0.11).clamp(0.0, 1.0))
            .toColor();

    final onPrimary = effectivePrimary.computeLuminance() > 0.45
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);

    const onSurface = Color(0xFFE6E1E5);

    return baseScheme.copyWith(
      primary: effectivePrimary,
      onPrimary: onPrimary,
      surface: effectiveSurface,
      onSurface: onSurface,
      surfaceDim: surfaceContainerLowest,
      surfaceBright: surfaceContainerHighest,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceTint: effectivePrimary,
    );
  }

  /// Generates a Material 3 Light [ColorScheme].
  static ColorScheme generateLightColorScheme({
    required Color seedColor,
    Color? vibrantAccent,
    Color? dominantColor,
    DynamicPaletteMode mode = DynamicPaletteMode.vibrant,
  }) {
    final effectivePrimary = vibrantAccent ?? seedColor;
    return ColorScheme.fromSeed(
      seedColor: effectivePrimary,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
  }
}

// ============================================================================
// Palette LRU Cache
// ============================================================================

/// In-memory LRU cache storing extracted palettes by key to avoid
/// re-analyzing image buffers on repeated tracks.
class DynamicCoverPaletteCache {
  final int maxCapacity;
  final Map<String, ExtractedCoverColors> _cache = {};

  DynamicCoverPaletteCache({this.maxCapacity = 100});

  int get size => _cache.length;

  ExtractedCoverColors? get(String key) {
    final item = _cache.remove(key);
    if (item != null) {
      _cache[key] = item; // Move to most recent
      return item;
    }
    return null;
  }

  void put(String key, ExtractedCoverColors palette) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = palette;
  }

  void clear() {
    _cache.clear();
  }
}

// ============================================================================
// Dynamic Cover Palette Extraction Service
// ============================================================================

/// Service for extracting dominant, vibrant, and dark surface colors
/// from album art [ImageProvider]s or color lists, generating dynamic schemes.
class DynamicCoverPaletteService {
  final DynamicCoverPaletteCache cache;

  DynamicCoverPaletteService({DynamicCoverPaletteCache? cache})
      : cache = cache ?? DynamicCoverPaletteCache();

  /// Extracts colors asynchronously from an [ImageProvider] via [PaletteGenerator].
  ///
  /// Falls back smoothly to [fallbackSeed] or hash generation if decoding
  /// fails, times out, or runs in a headless test environment.
  Future<ExtractedCoverColors> extractFromImageProvider(
    ImageProvider provider, {
    Size? targetSize,
    int maximumColorCount = 16,
    Color? fallbackSeed,
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) async {
    final defaultSeed = fallbackSeed ?? AppTheme.accent;

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        provider,
        size: targetSize ?? const Size(64, 64),
        maximumColorCount: maximumColorCount,
      ).timeout(const Duration(seconds: 4));

      return extractFromPaletteGenerator(
        generator,
        fallbackSeed: defaultSeed,
        surfaceDarkness: surfaceDarkness,
        saturationMultiplier: saturationMultiplier,
        isOled: isOled,
      );
    } catch (_) {
      // Graceful fallback for test runners or network errors
      return extractFromSeed(
        defaultSeed,
        surfaceDarkness: surfaceDarkness,
        saturationMultiplier: saturationMultiplier,
        isOled: isOled,
      );
    }
  }

  /// Extracts colors directly from an existing [PaletteGenerator] instance.
  ExtractedCoverColors extractFromPaletteGenerator(
    PaletteGenerator generator, {
    Color? fallbackSeed,
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) {
    final defaultSeed = fallbackSeed ?? AppTheme.accent;

    final dominant = generator.dominantColor?.color ??
        (generator.colors.isNotEmpty ? generator.colors.first : defaultSeed);

    final vibrant = generator.vibrantColor?.color ??
        generator.lightVibrantColor?.color ??
        generator.darkVibrantColor?.color ??
        dominant;

    final lightVibrant = generator.lightVibrantColor?.color ??
        HSVColor.fromColor(vibrant)
            .withValue(0.92)
            .withSaturation((HSVColor.fromColor(vibrant).saturation * 0.7).clamp(0.2, 0.7))
            .toColor();

    final muted = generator.mutedColor?.color ??
        generator.darkMutedColor?.color ??
        HSVColor.fromColor(dominant)
            .withSaturation((HSVColor.fromColor(dominant).saturation * 0.4).clamp(0.15, 0.5))
            .toColor();

    final darkMuted = generator.darkMutedColor?.color ??
        HSVColor.fromColor(muted).withValue(0.22).toColor();

    final darkSurface =
        DynamicMaterial3ColorSchemeGenerator.deriveDarkSurfaceColor(
      dominant,
      darkness: surfaceDarkness,
      saturationScale: saturationMultiplier,
      oledBlack: isOled,
    );

    return ExtractedCoverColors(
      dominantColor: dominant,
      vibrantColor: vibrant,
      lightVibrantColor: lightVibrant,
      mutedColor: muted,
      darkMutedColor: darkMuted,
      darkSurfaceColor: darkSurface,
      seedColor: vibrant,
    );
  }

  /// Pure Dart color extraction from a list of colors (e.g. mock pixels or swatches).
  ExtractedCoverColors extractFromColors(
    List<Color> colors, {
    Color? fallbackSeed,
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) {
    final defaultSeed = fallbackSeed ?? AppTheme.accent;
    if (colors.isEmpty) {
      return extractFromSeed(
        defaultSeed,
        surfaceDarkness: surfaceDarkness,
        saturationMultiplier: saturationMultiplier,
        isOled: isOled,
      );
    }

    // 1. Dominant: Color with the highest frequency
    final Map<int, int> counts = {};
    for (final c in colors) {
      counts[c.value] = (counts[c.value] ?? 0) + 1;
    }
    int maxCount = -1;
    int dominantValue = colors.first.value;
    counts.forEach((val, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantValue = val;
      }
    });
    final dominant = Color(dominantValue);

    // 2. Vibrant: Color with highest vibrancy score (high saturation + balanced value)
    Color vibrant = dominant;
    double maxVibrancyScore = -1.0;
    for (final c in colors) {
      final hsv = HSVColor.fromColor(c);
      final valuePenalty = (1.0 - (hsv.value - 0.75).abs() * 2.0).clamp(0.0, 1.0);
      final score = (hsv.saturation * 1.5) + valuePenalty;
      if (score > maxVibrancyScore) {
        maxVibrancyScore = score;
        vibrant = c;
      }
    }

    // 3. Light vibrant: High value + moderate saturation
    Color lightVibrant = vibrant;
    double maxLightVibrantScore = -1.0;
    for (final c in colors) {
      final hsv = HSVColor.fromColor(c);
      if (hsv.value >= 0.70) {
        final score = hsv.saturation * 0.8 + hsv.value * 0.5;
        if (score > maxLightVibrantScore) {
          maxLightVibrantScore = score;
          lightVibrant = c;
        }
      }
    }

    // 4. Muted: Moderate luminance and lower saturation
    Color muted = dominant;
    double bestMutedDiff = 999.0;
    for (final c in colors) {
      final hsv = HSVColor.fromColor(c);
      final diff = (hsv.saturation - 0.35).abs() + (hsv.value - 0.55).abs();
      if (diff < bestMutedDiff) {
        bestMutedDiff = diff;
        muted = c;
      }
    }

    final darkMuted = HSVColor.fromColor(muted).withValue(0.24).toColor();

    final darkSurface =
        DynamicMaterial3ColorSchemeGenerator.deriveDarkSurfaceColor(
      dominant,
      darkness: surfaceDarkness,
      saturationScale: saturationMultiplier,
      oledBlack: isOled,
    );

    return ExtractedCoverColors(
      dominantColor: dominant,
      vibrantColor: vibrant,
      lightVibrantColor: lightVibrant,
      mutedColor: muted,
      darkMutedColor: darkMuted,
      darkSurfaceColor: darkSurface,
      seedColor: vibrant,
    );
  }

  /// Extracts a palette derived deterministically from a single seed color.
  ExtractedCoverColors extractFromSeed(
    Color seed, {
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) {
    return ExtractedCoverColors.fromSeed(
      seed,
      surfaceDarkness: surfaceDarkness,
      saturationMultiplier: saturationMultiplier,
      isOled: isOled,
    );
  }

  /// Deterministic hash-based color generator for tracks with missing cover art.
  Color generateConsistentHashColor(String seed) {
    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = (31 * hash + seed.codeUnitAt(i)) & 0xFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.65, 0.78).toColor();
  }

  /// Extracts a complete palette from a string hash (e.g. title or artist).
  ExtractedCoverColors extractFromHash(
    String seedText, {
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) {
    final seed = generateConsistentHashColor(seedText);
    return extractFromSeed(
      seed,
      surfaceDarkness: surfaceDarkness,
      saturationMultiplier: saturationMultiplier,
      isOled: isOled,
    );
  }
}

// ============================================================================
// State Model: DynamicCoverPaletteState
// ============================================================================

/// Immutable Riverpod state holding the current dynamic palette,
/// generated Material 3 ColorSchemes, and user configuration.
@immutable
class DynamicCoverPaletteState {
  final ExtractedCoverColors colors;
  final ColorScheme darkColorScheme;
  final ColorScheme lightColorScheme;
  final DynamicPaletteMode paletteMode;
  final bool isEnabled;
  final double surfaceDarkness;
  final double saturationMultiplier;
  final bool isOledBlack;
  final bool isLoading;
  final String? error;
  final String? sourceKey;

  const DynamicCoverPaletteState({
    required this.colors,
    required this.darkColorScheme,
    required this.lightColorScheme,
    this.paletteMode = DynamicPaletteMode.vibrant,
    this.isEnabled = true,
    this.surfaceDarkness = 0.85,
    this.saturationMultiplier = 1.0,
    this.isOledBlack = false,
    this.isLoading = false,
    this.error,
    this.sourceKey,
  });

  /// Initial default state matching Softify design tokens.
  factory DynamicCoverPaletteState.initial({
    bool isEnabled = true,
    DynamicPaletteMode mode = DynamicPaletteMode.vibrant,
    double surfaceDarkness = 0.85,
    double saturationMultiplier = 1.0,
    bool isOled = false,
  }) {
    final colors = ExtractedCoverColors.defaultPalette(
      surfaceDarkness: surfaceDarkness,
      saturationMultiplier: saturationMultiplier,
      isOled: isOled,
    );

    final darkScheme =
        DynamicMaterial3ColorSchemeGenerator.generateDarkColorScheme(
      seedColor: colors.seedColor,
      vibrantAccent: colors.vibrantColor,
      dominantColor: colors.dominantColor,
      darkSurface: colors.darkSurfaceColor,
      mode: mode,
      pureBlackSurface: isOled,
    );

    final lightScheme =
        DynamicMaterial3ColorSchemeGenerator.generateLightColorScheme(
      seedColor: colors.seedColor,
      vibrantAccent: colors.vibrantColor,
      dominantColor: colors.dominantColor,
      mode: mode,
    );

    return DynamicCoverPaletteState(
      colors: colors,
      darkColorScheme: darkScheme,
      lightColorScheme: lightScheme,
      paletteMode: mode,
      isEnabled: isEnabled,
      surfaceDarkness: surfaceDarkness,
      saturationMultiplier: saturationMultiplier,
      isOledBlack: isOled,
    );
  }

  // Convenience Color Accessors
  Color get dominantColor => colors.dominantColor;
  Color get vibrantColor => colors.vibrantColor;
  Color get darkSurfaceColor => colors.darkSurfaceColor;
  Color get lightVibrantColor => colors.lightVibrantColor;
  Color get mutedColor => colors.mutedColor;
  Color get darkMutedColor => colors.darkMutedColor;
  Color get seedColor => colors.seedColor;

  /// The primary accent color chosen based on the active [DynamicPaletteMode].
  Color get primaryAccent {
    if (!isEnabled) return AppTheme.accent;
    switch (paletteMode) {
      case DynamicPaletteMode.vibrant:
        return vibrantColor;
      case DynamicPaletteMode.dominant:
        return dominantColor;
      case DynamicPaletteMode.muted:
        return mutedColor;
      case DynamicPaletteMode.oledContrast:
        return lightVibrantColor;
    }
  }

  /// The surface color for lyrics views (reflecting enable toggle and darkness).
  Color get lyricsBackgroundColor {
    if (!isEnabled) return AppTheme.surface;
    if (isOledBlack || paletteMode == DynamicPaletteMode.oledContrast) {
      return const Color(0xFF000000);
    }
    return darkSurfaceColor;
  }

  /// High-contrast active lyrics text color.
  Color get activeLyricsColor {
    return DynamicMaterial3ColorSchemeGenerator.ensureMinimumContrast(
      const Color(0xFFFFFFFF),
      lyricsBackgroundColor,
      minRatio: 4.5,
    );
  }

  /// Readable inactive lyrics text color (muted secondary).
  Color get inactiveLyricsColor {
    return const Color(0xFFE6E1E5).withOpacity(0.48);
  }

  /// WCAG Contrast ratio between active lyrics line and background surface.
  double get lyricsContrastRatio {
    return DynamicMaterial3ColorSchemeGenerator.computeContrastRatio(
      activeLyricsColor,
      lyricsBackgroundColor,
    );
  }

  /// Whether active lyrics text meets WCAG AA contrast standard (>= 4.5:1).
  bool get isWcagAaCompliant => lyricsContrastRatio >= 4.5;

  /// Whether active lyrics text meets WCAG AAA contrast standard (>= 7.0:1).
  bool get isWcagAaaCompliant => lyricsContrastRatio >= 7.0;

  DynamicCoverPaletteState copyWith({
    ExtractedCoverColors? colors,
    ColorScheme? darkColorScheme,
    ColorScheme? lightColorScheme,
    DynamicPaletteMode? paletteMode,
    bool? isEnabled,
    double? surfaceDarkness,
    double? saturationMultiplier,
    bool? isOledBlack,
    bool? isLoading,
    String? error,
    String? sourceKey,
  }) {
    return DynamicCoverPaletteState(
      colors: colors ?? this.colors,
      darkColorScheme: darkColorScheme ?? this.darkColorScheme,
      lightColorScheme: lightColorScheme ?? this.lightColorScheme,
      paletteMode: paletteMode ?? this.paletteMode,
      isEnabled: isEnabled ?? this.isEnabled,
      surfaceDarkness: surfaceDarkness ?? this.surfaceDarkness,
      saturationMultiplier:
          saturationMultiplier ?? this.saturationMultiplier,
      isOledBlack: isOledBlack ?? this.isOledBlack,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sourceKey: sourceKey ?? this.sourceKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicCoverPaletteState &&
          runtimeType == other.runtimeType &&
          colors == other.colors &&
          darkColorScheme == other.darkColorScheme &&
          lightColorScheme == other.lightColorScheme &&
          paletteMode == other.paletteMode &&
          isEnabled == other.isEnabled &&
          surfaceDarkness == other.surfaceDarkness &&
          saturationMultiplier == other.saturationMultiplier &&
          isOledBlack == other.isOledBlack &&
          isLoading == other.isLoading &&
          error == other.error &&
          sourceKey == other.sourceKey;

  @override
  int get hashCode => Object.hash(
        colors,
        darkColorScheme,
        lightColorScheme,
        paletteMode,
        isEnabled,
        surfaceDarkness,
        saturationMultiplier,
        isOledBlack,
        isLoading,
        error,
        sourceKey,
      );
}

// ============================================================================
// StateNotifier: DynamicCoverColorPaletteNotifier
// ============================================================================

/// Manages dynamic cover art color palette extraction, Material 3 scheme
/// updates, and persistent user customization.
class DynamicCoverColorPaletteNotifier
    extends StateNotifier<DynamicCoverPaletteState> {
  final DynamicCoverPaletteService _service;
  final DynamicPalettePrefsStorage _storage;
  int _activeExtractionId = 0;

  static DynamicPalettePrefsStorage? customStorageForTesting;

  DynamicCoverColorPaletteNotifier({
    DynamicCoverPaletteService? service,
    DynamicPalettePrefsStorage? storage,
  })  : _service = service ?? DynamicCoverPaletteService(),
        _storage = storage ??
            customStorageForTesting ??
            DynamicPaletteSharedPreferencesStore(),
        super(DynamicCoverPaletteState.initial()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final enabled = await _storage.getBool(kDynamicPaletteEnabledPrefKey);
      final modeStr = await _storage.getString(kDynamicPaletteModePrefKey);
      final darkness =
          await _storage.getDouble(kDynamicPaletteSurfaceDarknessPrefKey);
      final saturation =
          await _storage.getDouble(kDynamicPaletteSaturationPrefKey);
      final oled = await _storage.getBool(kDynamicPaletteOledPrefKey);

      final effectiveEnabled = enabled ?? true;
      final effectiveMode = DynamicPaletteMode.fromString(modeStr);
      final effectiveDarkness = darkness ?? 0.85;
      final effectiveSaturation = saturation ?? 1.0;
      final effectiveOled = oled ?? false;

      if (!mounted) return;

      _recalculateState(
        colors: state.colors,
        isEnabled: effectiveEnabled,
        mode: effectiveMode,
        darkness: effectiveDarkness,
        saturation: effectiveSaturation,
        isOled: effectiveOled,
      );
    } catch (_) {}
  }

  /// Recalculates full color schemes and updates state.
  void _recalculateState({
    required ExtractedCoverColors colors,
    bool? isEnabled,
    DynamicPaletteMode? mode,
    double? darkness,
    double? saturation,
    bool? isOled,
    bool isLoading = false,
    String? error,
    String? sourceKey,
  }) {
    final effectiveEnabled = isEnabled ?? state.isEnabled;
    final effectiveMode = mode ?? state.paletteMode;
    final effectiveDarkness = darkness ?? state.surfaceDarkness;
    final effectiveSaturation = saturation ?? state.saturationMultiplier;
    final effectiveOled = isOled ?? state.isOledBlack;

    // Recalculate dark surface based on updated parameters
    final updatedDarkSurface =
        DynamicMaterial3ColorSchemeGenerator.deriveDarkSurfaceColor(
      colors.dominantColor,
      darkness: effectiveDarkness,
      saturationScale: effectiveSaturation,
      oledBlack: effectiveOled,
    );

    final updatedColors = colors.copyWith(
      darkSurfaceColor: updatedDarkSurface,
    );

    final darkScheme =
        DynamicMaterial3ColorSchemeGenerator.generateDarkColorScheme(
      seedColor: updatedColors.seedColor,
      vibrantAccent: updatedColors.vibrantColor,
      dominantColor: updatedColors.dominantColor,
      darkSurface: updatedDarkSurface,
      mode: effectiveMode,
      pureBlackSurface: effectiveOled,
    );

    final lightScheme =
        DynamicMaterial3ColorSchemeGenerator.generateLightColorScheme(
      seedColor: updatedColors.seedColor,
      vibrantAccent: updatedColors.vibrantColor,
      dominantColor: updatedColors.dominantColor,
      mode: effectiveMode,
    );

    state = state.copyWith(
      colors: updatedColors,
      darkColorScheme: darkScheme,
      lightColorScheme: lightScheme,
      isEnabled: effectiveEnabled,
      paletteMode: effectiveMode,
      surfaceDarkness: effectiveDarkness,
      saturationMultiplier: effectiveSaturation,
      isOledBlack: effectiveOled,
      isLoading: isLoading,
      error: error,
      sourceKey: sourceKey ?? state.sourceKey,
    );
  }

  /// Extracts dynamic palette from an [ImageProvider] (NetworkImage, FileImage, etc.).
  Future<void> extractFromImage(
    ImageProvider? provider, {
    String? key,
    Color? fallbackSeed,
  }) async {
    final extractionId = ++_activeExtractionId;

    if (key != null) {
      final cached = _service.cache.get(key);
      if (cached != null) {
        _recalculateState(
          colors: cached,
          sourceKey: key,
          isLoading: false,
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true);

    try {
      ExtractedCoverColors colors;
      if (provider != null) {
        colors = await _service.extractFromImageProvider(
          provider,
          fallbackSeed: fallbackSeed ?? AppTheme.accent,
          surfaceDarkness: state.surfaceDarkness,
          saturationMultiplier: state.saturationMultiplier,
          isOled: state.isOledBlack,
        );
      } else {
        colors = _service.extractFromSeed(
          fallbackSeed ?? AppTheme.accent,
          surfaceDarkness: state.surfaceDarkness,
          saturationMultiplier: state.saturationMultiplier,
          isOled: state.isOledBlack,
        );
      }

      if (extractionId != _activeExtractionId || !mounted) return;

      if (key != null) {
        _service.cache.put(key, colors);
      }

      _recalculateState(
        colors: colors,
        sourceKey: key,
        isLoading: false,
      );
    } catch (e) {
      if (extractionId != _activeExtractionId || !mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Updates palette given a Softify [Track] instance.
  Future<void> updateFromTrack(
    Track? track, {
    ImageProvider? customImageProvider,
  }) async {
    if (track == null) {
      reset();
      return;
    }

    final key = track.id;
    final cached = _service.cache.get(key);
    if (cached != null) {
      _recalculateState(colors: cached, sourceKey: key);
      return;
    }

    ImageProvider? imageProvider = customImageProvider;
    if (imageProvider == null && track.coverUrl != null && track.coverUrl!.isNotEmpty) {
      final url = track.coverUrl!;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        imageProvider = NetworkImage(url);
      } else if (File(url).existsSync()) {
        imageProvider = FileImage(File(url));
      }
    }

    final fallbackColor =
        _service.generateConsistentHashColor('${track.title}_${track.artist}');

    await extractFromImage(
      imageProvider,
      key: key,
      fallbackSeed: fallbackColor,
    );
  }

  /// Updates palette given an artwork URL or fallback text.
  Future<void> updateFromArtworkUrl(String? artworkUrl, {String? seedText}) async {
    if (artworkUrl == null || artworkUrl.isEmpty) {
      if (seedText != null && seedText.isNotEmpty) {
        final colors = _service.extractFromHash(
          seedText,
          surfaceDarkness: state.surfaceDarkness,
          saturationMultiplier: state.saturationMultiplier,
          isOled: state.isOledBlack,
        );
        _recalculateState(colors: colors, sourceKey: seedText);
      } else {
        reset();
      }
      return;
    }

    final key = artworkUrl;
    ImageProvider? imageProvider;
    if (artworkUrl.startsWith('http://') || artworkUrl.startsWith('https://')) {
      imageProvider = NetworkImage(artworkUrl);
    } else if (File(artworkUrl).existsSync()) {
      imageProvider = FileImage(File(artworkUrl));
    }

    final fallback = seedText != null
        ? _service.generateConsistentHashColor(seedText)
        : AppTheme.accent;

    await extractFromImage(
      imageProvider,
      key: key,
      fallbackSeed: fallback,
    );
  }

  /// Manually overrides the palette seed with a custom color.
  void setManualSeed(Color color) {
    final colors = _service.extractFromSeed(
      color,
      surfaceDarkness: state.surfaceDarkness,
      saturationMultiplier: state.saturationMultiplier,
      isOled: state.isOledBlack,
    );
    _recalculateState(colors: colors, sourceKey: 'manual_${color.value}');
  }

  /// Directly applies colors from a test or custom color list.
  void applyColors(List<Color> colors, {String? key}) {
    final extracted = _service.extractFromColors(
      colors,
      surfaceDarkness: state.surfaceDarkness,
      saturationMultiplier: state.saturationMultiplier,
      isOled: state.isOledBlack,
    );
    _recalculateState(colors: extracted, sourceKey: key);
  }

  /// Toggles dynamic cover art palette on or off.
  Future<void> toggleEnabled() async {
    await setEnabled(!state.isEnabled);
  }

  /// Enables or disables dynamic cover art coloring.
  Future<void> setEnabled(bool enabled) async {
    if (state.isEnabled == enabled) return;
    _recalculateState(colors: state.colors, isEnabled: enabled);
    try {
      await _storage.setBool(kDynamicPaletteEnabledPrefKey, enabled);
    } catch (_) {}
  }

  /// Updates aesthetic palette extraction mode.
  Future<void> setPaletteMode(DynamicPaletteMode mode) async {
    if (state.paletteMode == mode) return;
    _recalculateState(colors: state.colors, mode: mode);
    try {
      await _storage.setString(kDynamicPaletteModePrefKey, mode.name);
    } catch (_) {}
  }

  /// Tunes dark surface depth (0.0 to 1.0).
  Future<void> setSurfaceDarkness(double darkness) async {
    final clamped = darkness.clamp(0.0, 1.0);
    if ((state.surfaceDarkness - clamped).abs() < 0.001) return;
    _recalculateState(colors: state.colors, darkness: clamped);
    try {
      await _storage.setDouble(kDynamicPaletteSurfaceDarknessPrefKey, clamped);
    } catch (_) {}
  }

  /// Tunes color saturation multiplier (0.5 to 2.0).
  Future<void> setSaturationMultiplier(double multiplier) async {
    final clamped = multiplier.clamp(0.5, 2.0);
    if ((state.saturationMultiplier - clamped).abs() < 0.001) return;
    _recalculateState(colors: state.colors, saturation: clamped);
    try {
      await _storage.setDouble(kDynamicPaletteSaturationPrefKey, clamped);
    } catch (_) {}
  }

  /// Sets OLED pure black background mode.
  Future<void> setOledBlack(bool isOled) async {
    if (state.isOledBlack == isOled) return;
    _recalculateState(colors: state.colors, isOled: isOled);
    try {
      await _storage.setBool(kDynamicPaletteOledPrefKey, isOled);
    } catch (_) {}
  }

  /// Resets state and parameters to default values.
  Future<void> reset() async {
    final defaultColors = ExtractedCoverColors.defaultPalette();
    _recalculateState(
      colors: defaultColors,
      isEnabled: true,
      mode: DynamicPaletteMode.vibrant,
      darkness: 0.85,
      saturation: 1.0,
      isOled: false,
      sourceKey: null,
    );
    try {
      await _storage.setBool(kDynamicPaletteEnabledPrefKey, true);
      await _storage.setString(
          kDynamicPaletteModePrefKey, DynamicPaletteMode.vibrant.name);
      await _storage.setDouble(kDynamicPaletteSurfaceDarknessPrefKey, 0.85);
      await _storage.setDouble(kDynamicPaletteSaturationPrefKey, 1.0);
      await _storage.setBool(kDynamicPaletteOledPrefKey, false);
    } catch (_) {}
  }

  void resetForTesting() {
    _activeExtractionId = 0;
    _service.cache.clear();
    state = DynamicCoverPaletteState.initial();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Provider for the [DynamicCoverPaletteService] instance.
final dynamicCoverPaletteServiceProvider =
    Provider<DynamicCoverPaletteService>((ref) {
  return DynamicCoverPaletteService();
});

/// Primary state notifier provider managing the dynamic cover palette.
final dynamicCoverPaletteProvider = StateNotifierProvider<
    DynamicCoverColorPaletteNotifier, DynamicCoverPaletteState>((ref) {
  final service = ref.watch(dynamicCoverPaletteServiceProvider);
  return DynamicCoverColorPaletteNotifier(service: service);
});

/// Readable provider exposing whether dynamic palette theming is enabled.
final isDynamicPaletteEnabledProvider = Provider<bool>((ref) {
  return ref.watch(dynamicCoverPaletteProvider.select((s) => s.isEnabled));
});

/// Active ColorScheme: returns artwork-derived dark ColorScheme when enabled,
/// or standard AppTheme dark ColorScheme when disabled.
final dynamicColorSchemeProvider = Provider<ColorScheme>((ref) {
  final state = ref.watch(dynamicCoverPaletteProvider);
  if (!state.isEnabled) {
    return AppTheme.unifiedDarkTheme.colorScheme;
  }
  return state.darkColorScheme;
});

/// Dynamic dark surface color for lyrics background.
final dynamicLyricsSurfaceColorProvider = Provider<Color>((ref) {
  final state = ref.watch(dynamicCoverPaletteProvider);
  return state.lyricsBackgroundColor;
});

/// Dynamic accent color for active lyrics line highlight.
final dynamicLyricsAccentColorProvider = Provider<Color>((ref) {
  final state = ref.watch(dynamicCoverPaletteProvider);
  return state.primaryAccent;
});

/// Calculated WCAG contrast ratio between lyrics text and background.
final dynamicLyricsContrastRatioProvider = Provider<double>((ref) {
  final state = ref.watch(dynamicCoverPaletteProvider);
  return state.lyricsContrastRatio;
});

// ============================================================================
// UI Widgets: Material 3 Cards, Surfaces & Controls
// ============================================================================

/// Material 3 Preview & Configuration Card for Dynamic Cover Art Palette.
class DynamicPalettePreviewCard extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onInspectRequested;

  const DynamicPalettePreviewCard({
    super.key,
    this.margin,
    this.padding,
    this.onInspectRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dynamicCoverPaletteProvider);
    final notifier = ref.read(dynamicCoverPaletteProvider.notifier);
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    final cardColor = tokens?.card ?? theme.cardColor;
    final primaryAccent = state.isEnabled ? state.primaryAccent : (tokens?.accent ?? theme.colorScheme.primary);
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ??
        theme.colorScheme.onSurface.withOpacity(0.7);
    final dividerColor = tokens?.divider ?? theme.dividerColor;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens?.radiusCard ?? 16),
        border: Border.all(
          color: state.isEnabled
              ? primaryAccent.withOpacity(0.25)
              : dividerColor.withOpacity(0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryAccent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: primaryAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dynamic Cover Art Palette',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Adapt player & lyrics colors to current album artwork',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.isEnabled,
                onChanged: (val) => notifier.setEnabled(val),
                activeColor: primaryAccent,
              ),
            ],
          ),

          if (state.isEnabled) ...[
            const SizedBox(height: 16),
            Divider(color: dividerColor.withOpacity(0.2), height: 1),
            const SizedBox(height: 14),

            // Color Swatches Section
            Text(
              'Extracted Swatches',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SwatchBubble(
                    label: 'Dominant',
                    color: state.dominantColor,
                    textColor: textPrimary,
                  ),
                  const SizedBox(width: 12),
                  _SwatchBubble(
                    label: 'Vibrant',
                    color: state.vibrantColor,
                    textColor: textPrimary,
                  ),
                  const SizedBox(width: 12),
                  _SwatchBubble(
                    label: 'Dark Surface',
                    color: state.darkSurfaceColor,
                    textColor: textPrimary,
                    isSurface: true,
                  ),
                  const SizedBox(width: 12),
                  _SwatchBubble(
                    label: 'Light Vibrant',
                    color: state.lightVibrantColor,
                    textColor: textPrimary,
                  ),
                  const SizedBox(width: 12),
                  _SwatchBubble(
                    label: 'Muted',
                    color: state.mutedColor,
                    textColor: textPrimary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Mode Selector Chips
            Text(
              'Aesthetic Tuning Mode',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DynamicPaletteMode.values.map((mode) {
                final isSelected = state.paletteMode == mode;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode.icon,
                        size: 16,
                        color: isSelected ? Colors.white : textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(mode.label),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: primaryAccent,
                  backgroundColor: theme.colorScheme.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (val) {
                    if (val) notifier.setPaletteMode(mode);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Contrast & Readability Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: state.lyricsBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primaryAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.isWcagAaCompliant
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: state.isWcagAaCompliant
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lyrics Contrast: ${state.lyricsContrastRatio.toStringAsFixed(1)}:1 (${state.isWcagAaaCompliant ? "WCAG AAA" : state.isWcagAaCompliant ? "WCAG AA" : "Low Contrast"})',
                      style: TextStyle(
                        color: state.activeLyricsColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'Aa',
                    style: TextStyle(
                      color: state.activeLyricsColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Surface Darkness Slider
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Surface Darkness Depth: ${(state.surfaceDarkness * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(color: textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => notifier.reset(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: primaryAccent,
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: primaryAccent,
                thumbColor: primaryAccent,
                overlayColor: primaryAccent.withOpacity(0.15),
                trackHeight: 3,
              ),
              child: Slider(
                value: state.surfaceDarkness,
                min: 0.50,
                max: 1.0,
                divisions: 25,
                onChanged: (val) => notifier.setSurfaceDarkness(val),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwatchBubble extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool isSurface;

  const _SwatchBubble({
    required this.label,
    required this.color,
    required this.textColor,
    this.isSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final hexCode =
        '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSurface ? Colors.white24 : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          hexCode,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// Dynamic Background Surface container for lyrics view.
///
/// Smoothly transitions multi-stop radial and linear gradients
/// blending the dark surface with vibrant ambient bloom.
class DynamicLyricsBackgroundSurface extends ConsumerWidget {
  final Widget child;
  final Alignment bloomAlignment;
  final double bloomRadius;
  final Duration animationDuration;

  const DynamicLyricsBackgroundSurface({
    super.key,
    required this.child,
    this.bloomAlignment = Alignment.topRight,
    this.bloomRadius = 0.85,
    this.animationDuration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dynamicCoverPaletteProvider);
    final surfaceColor = state.lyricsBackgroundColor;
    final accentBloom = state.primaryAccent;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: surfaceColor, end: surfaceColor),
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedSurface, _) {
        final currentSurface = animatedSurface ?? surfaceColor;

        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: accentBloom, end: accentBloom),
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          builder: (context, animatedBloom, _) {
            final currentBloom = animatedBloom ?? accentBloom;

            return Container(
              decoration: BoxDecoration(
                color: currentSurface,
                gradient: state.isEnabled
                    ? RadialGradient(
                        center: bloomAlignment,
                        radius: bloomRadius,
                        colors: [
                          currentBloom.withOpacity(0.24),
                          currentBloom.withOpacity(0.08),
                          currentSurface,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      )
                    : null,
              ),
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Compact settings tile for easy integration into Settings screen.
class DynamicPaletteTile extends ConsumerWidget {
  final VoidCallback? onTap;

  const DynamicPaletteTile({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(isDynamicPaletteEnabledProvider);
    final notifier = ref.read(dynamicCoverPaletteProvider.notifier);
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    return ListTile(
      leading: Icon(
        Icons.palette_rounded,
        color: isEnabled
            ? (tokens?.accent ?? theme.colorScheme.primary)
            : (tokens?.textSecondary ?? theme.colorScheme.onSurface.withOpacity(0.6)),
      ),
      title: const Text('Dynamic Palette from Cover Art'),
      subtitle: const Text('Extract ambient colors and dark surface from track artwork'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (val) => notifier.setEnabled(val),
      ),
      onTap: onTap ?? () => notifier.toggleEnabled(),
    );
  }
}
