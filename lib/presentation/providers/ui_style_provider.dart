import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../data/database/app_database.dart';
import '../theme/app_theme.dart';
import 'player_providers.dart';

/// StateNotifier managing the user's selected [UiStyle].
class UiStyleNotifier extends StateNotifier<UiStyle> {
  final AppDatabase? _db;
  static const String _key = 'ui_style';

  UiStyleNotifier(this._db) : super(UiStyle.auroraGlass) {
    if (_db != null) {
      _loadFromDb();
    }
  }

  Future<void> _loadFromDb() async {
    final db = _db;
    if (db == null) return;
    try {
      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals(_key)))
          .getSingleOrNull();
      if (row != null) {
        if (row.value == UiStyle.classic.name) {
          state = UiStyle.classic;
        } else {
          state = UiStyle.auroraGlass;
        }
      }
    } catch (_) {}
  }

  Future<void> setStyle(UiStyle style) async {
    if (state == style) return;
    state = style;
    final db = _db;
    if (db == null) return;
    try {
      await db.into(db.settings).insertOnConflictUpdate(
            SettingRow(
              key: _key,
              value: style.name,
            ),
          );
    } catch (_) {}
  }
}

/// Provides the current [UiStyle] (Classic or Aurora Glass).
final uiStyleProvider =
    StateNotifierProvider<UiStyleNotifier, UiStyle>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return UiStyleNotifier(db);
});

/// StateNotifier managing [ReduceEffectsMode] (Auto, On, Off).
class ReduceEffectsNotifier extends StateNotifier<ReduceEffectsMode> {
  final AppDatabase? _db;
  static const String _key = 'reduce_effects';

  ReduceEffectsNotifier(this._db) : super(ReduceEffectsMode.auto) {
    if (_db != null) {
      _loadFromDb();
    }
  }

  Future<void> _loadFromDb() async {
    final db = _db;
    if (db == null) return;
    try {
      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals(_key)))
          .getSingleOrNull();
      if (row != null) {
        if (row.value == ReduceEffectsMode.on.name) {
          state = ReduceEffectsMode.on;
        } else if (row.value == ReduceEffectsMode.off.name) {
          state = ReduceEffectsMode.off;
        } else {
          state = ReduceEffectsMode.auto;
        }
      }
    } catch (_) {}
  }

  Future<void> setMode(ReduceEffectsMode mode) async {
    if (state == mode) return;
    state = mode;
    final db = _db;
    if (db == null) return;
    try {
      await db.into(db.settings).insertOnConflictUpdate(
            SettingRow(
              key: _key,
              value: mode.name,
            ),
          );
    } catch (_) {}
  }
}

/// Provides the configured [ReduceEffectsMode].
final reduceEffectsProvider =
    StateNotifierProvider<ReduceEffectsNotifier, ReduceEffectsMode>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return ReduceEffectsNotifier(db);
});

/// Auto-detects whether the current device is low-spec or constrained.
final isLowEndDeviceProvider = Provider<bool>((ref) {
  try {
    // Desktop Linux & Windows Skia engines suffer from glReadPixels GPU pipeline stalls on BackdropFilter
    if (Platform.isLinux || Platform.isWindows) return true;
    // If device has 2 or fewer processor cores, consider it constrained
    final cores = Platform.numberOfProcessors;
    if (cores <= 2) return true;
  } catch (_) {}
  return false;
});

/// Computes whether heavy effects (BackdropFilter blur, live mesh gradients)
/// should be swapped for lightweight solid translucent fills.
final shouldReduceEffectsProvider = Provider<bool>((ref) {
  final mode = ref.watch(reduceEffectsProvider);
  switch (mode) {
    case ReduceEffectsMode.on:
      return true;
    case ReduceEffectsMode.off:
      return false;
    case ReduceEffectsMode.auto:
      return ref.watch(isLowEndDeviceProvider);
  }
});

/// Provides the active ThemeData corresponding to the active [UiStyle].
final uiThemeDataProvider = Provider<ThemeData>((ref) {
  final style = ref.watch(uiStyleProvider);
  return AppTheme.themeFor(style);
});

/// Global LRU-bounded cache of extracted artwork colors for Aurora background gradients.
final Map<String, Color> _auroraPaletteCache = {};

/// Extracts and caches dominant vibrant color from album art for Aurora background.
final auroraPaletteProvider =
    FutureProvider.family<Color, String?>((ref, coverUrl) async {
  if (coverUrl == null || coverUrl.isEmpty) {
    return const Color(0xFF34D399); // Default studio sage mint
  }

  if (_auroraPaletteCache.containsKey(coverUrl)) {
    return _auroraPaletteCache[coverUrl]!;
  }

  try {
    final generator = await PaletteGenerator.fromImageProvider(
      NetworkImage(coverUrl),
      size: const Size(32, 32), // Fast downsample for minimal CPU/GPU overhead
      maximumColorCount: 6,
    );

    final color = generator.dominantColor?.color ??
        generator.mutedColor?.color ??
        generator.vibrantColor?.color ??
        const Color(0xFF34D399);

    if (_auroraPaletteCache.length >= 100) {
      _auroraPaletteCache.remove(_auroraPaletteCache.keys.first);
    }
    _auroraPaletteCache[coverUrl] = color;
    return color;
  } catch (_) {
    return const Color(0xFF34D399);
  }
});
