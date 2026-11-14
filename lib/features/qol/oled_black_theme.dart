import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/theme/app_theme.dart';

/// Lightweight, self-contained SharedPreferences persistence engine
/// matching the exact `package:shared_preferences` API interface.
///
/// Persists key-value settings to disk safely across app launches
/// while supporting mock environments for testing.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Injects initial values for test suites and harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Asynchronously loads or initializes the shared preferences storage.
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

  List<String>? getStringList(String key) {
    final val = _preferenceStore[key];
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    _preferenceStore[key] = List<String>.from(value);
    await _persist();
    return true;
  }

  Object? get(String key) => _preferenceStore[key];

  bool containsKey(String key) => _preferenceStore.containsKey(key);

  Set<String> getKeys() => Set<String>.from(_preferenceStore.keys);

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

  Future<void> reload() async {
    final file = _storageFile;
    if (file != null && await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            _preferenceStore.clear();
            decoded.forEach((key, value) {
              if (value != null) {
                _preferenceStore[key.toString()] = value as Object;
              }
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<bool> commit() async {
    await _persist();
    return true;
  }
}

/// State notifier managing Pure OLED Black (#000000) Theme Mode.
///
/// Features:
/// - True `#000000` AMOLED surfaces for zero-pixel power emission.
/// - Subtle border contrast (~14% luminance) ensuring crisp visual separation
///   between surfaces, cards, and dialogue sheets on OLED hardware.
/// - Seamless persistence to [SharedPreferences].
class OledBlackThemeManager extends StateNotifier<bool> {
  static const String prefKey = 'oled_black_theme_enabled';

  // AMOLED & High-Contrast Design Palette
  static const Color pureBlack = Color(0xFF000000);
  static const Color oledBorder = Color(0xFF242424);
  static const Color oledBorderSubtle = Color(0xFF1B1B1B);
  static const Color oledBorderHighContrast = Color(0xFF333333);
  static const Color oledCardBackground = Color(0xFF000000);
  static const Color oledCardElevated = Color(0xFF080808);
  static const Color oledDivider = Color(0xFF1F1F1F);

  Ref? _ref;
  SharedPreferences? _prefs;

  OledBlackThemeManager([dynamic arg1, dynamic arg2]) : super(false) {
    if (arg1 is SharedPreferences) {
      _prefs = arg1;
    } else if (arg1 is Ref) {
      _ref = arg1;
    } else if (arg1 is bool) {
      state = arg1;
    }

    if (arg2 is SharedPreferences) {
      _prefs = arg2;
    } else if (arg2 is Ref) {
      _ref = arg2;
    }

    _loadFromPreferences();
  }

  /// Active Riverpod [Ref] handle if provided.
  Ref? get ref => _ref;

  /// Whether Pure OLED Black mode is currently active.
  bool get isEnabled => state;

  /// Loads the persisted state from SharedPreferences.
  Future<void> _loadFromPreferences() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final persisted = _prefs?.getBool(prefKey);
      if (persisted != null && mounted) {
        state = persisted;
      }
    } catch (_) {}
  }

  /// Updates OLED Black mode state and persists the change to SharedPreferences.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(prefKey, enabled);
    } catch (_) {}
  }

  /// Toggles OLED Black mode.
  Future<void> toggle() => setEnabled(!state);

  /// Enables OLED Black mode.
  Future<void> enable() => setEnabled(true);

  /// Disables OLED Black mode.
  Future<void> disable() => setEnabled(false);

  /// Applies Pure OLED Black overrides and subtle border contrasts to [ThemeData].
  static ThemeData applyOledBlack(ThemeData baseTheme, {bool enabled = true}) {
    if (!enabled) return baseTheme;

    final colorScheme = baseTheme.colorScheme.copyWith(
      surface: pureBlack,
      surfaceContainerLowest: pureBlack,
      surfaceContainerLow: pureBlack,
      surfaceContainer: pureBlack,
      surfaceContainerHigh: oledCardElevated,
      surfaceContainerHighest: const Color(0xFF141414),
      outline: oledBorderHighContrast,
      outlineVariant: oledBorder,
    );

    final existingTokens = baseTheme.extension<AppTokens>();
    final updatedTokens = existingTokens != null
        ? applyOledTokens(existingTokens, enabled: true)
        : null;

    return baseTheme.copyWith(
      scaffoldBackgroundColor: pureBlack,
      canvasColor: pureBlack,
      cardColor: pureBlack,
      dialogBackgroundColor: pureBlack,
      colorScheme: colorScheme,
      dividerColor: oledDivider,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: pureBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: baseTheme.navigationBarTheme.copyWith(
        backgroundColor: pureBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: baseTheme.bottomNavigationBarTheme.copyWith(
        backgroundColor: pureBlack,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: pureBlack,
        elevation: 0,
        margin: baseTheme.cardTheme.margin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(updatedTokens?.radiusCard ?? 12.0),
          side: const BorderSide(color: oledBorder, width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pureBlack,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: const BorderSide(color: oledBorderHighContrast, width: 1.0),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pureBlack,
        modalBackgroundColor: pureBlack,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          side: BorderSide(color: oledBorder, width: 1.0),
        ),
      ),
      extensions: [
        if (updatedTokens != null) updatedTokens,
        ...baseTheme.extensions.values.where((e) => e is! AppTokens),
      ],
    );
  }

  /// Transforms design tokens to Pure OLED Black with AMOLED border styling.
  static AppTokens applyOledTokens(AppTokens baseTokens, {bool enabled = true}) {
    if (!enabled) return baseTokens;

    return baseTokens.copyWith(
      background: pureBlack,
      sidebar: pureBlack,
      surface: pureBlack,
      card: pureBlack,
      cardHover: const Color(0xFF0F0F0F),
      surfaceElevated: oledCardElevated,
      surfaceHighlight: const Color(0xFF141414),
      glass: const Color(0xF5000000),
      glassSurface: const Color(0x33000000),
      glassBorder: oledBorder,
      divider: oledDivider,
      cardShadow: const [],
    );
  }

  /// Reusable [BoxDecoration] for AMOLED card surfaces with subtle border contrast.
  static BoxDecoration oledCardDecoration({
    double radius = 12.0,
    Color borderColor = oledBorder,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: pureBlack,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }
}

/// Riverpod StateNotifierProvider managing Pure OLED Black theme mode.
final isOledBlackEnabledProvider =
    StateNotifierProvider<OledBlackThemeManager, bool>((ref) {
  return OledBlackThemeManager(ref);
});

/// Riverpod provider delivering an OLED-adapted [ThemeData].
final oledThemeDataProvider = Provider<ThemeData>((ref) {
  final isOled = ref.watch(isOledBlackEnabledProvider);
  final baseTheme = AppTheme.buildMetrolistTheme(
    pureBlack: isOled,
  );
  return OledBlackThemeManager.applyOledBlack(baseTheme, enabled: isOled);
});

/// Settings toggle tile for Pure OLED Black theme mode.
///
/// Designed for clean integration into the Settings screen.
class OledBlackSettingTile extends ConsumerWidget {
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;
  final ValueChanged<bool>? onChanged;

  const OledBlackSettingTile({
    super.key,
    this.contentPadding,
    this.showDivider = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(isOledBlackEnabledProvider);
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>() ?? AppTokens.standardTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: contentPadding,
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEnabled
                  ? tokens.accent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: isEnabled
                    ? tokens.accent.withValues(alpha: 0.3)
                    : tokens.divider,
                width: 1.0,
              ),
            ),
            child: Icon(
              Icons.dark_mode_rounded,
              color: isEnabled ? tokens.accent : tokens.textSecondary,
              size: 20,
            ),
          ),
          title: const Text(
            'Pure OLED Black',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'Deep #000000 black surfaces for maximum battery saving on AMOLED displays and enhanced contrast',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
            ),
          ),
          value: isEnabled,
          activeColor: tokens.accent,
          onChanged: (val) {
            ref.read(isOledBlackEnabledProvider.notifier).setEnabled(val);
            onChanged?.call(val);
          },
        ),
        if (showDivider)
          Divider(
            color: tokens.divider,
            height: 1,
            indent: contentPadding != null ? 16 : 0,
            endIndent: contentPadding != null ? 16 : 0,
          ),
      ],
    );
  }
}
