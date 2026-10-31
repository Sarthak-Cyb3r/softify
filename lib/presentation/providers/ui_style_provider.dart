import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/track.dart';
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

/// StateNotifier managing whether Liquid Glass effect is enabled.
class LiquidGlassNotifier extends StateNotifier<bool> {
  final AppDatabase? _db;
  static const String _key = 'liquid_glass_enabled';

  LiquidGlassNotifier(this._db) : super(true) {
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
        state = row.value == 'true';
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    final db = _db;
    if (db == null) return;
    try {
      await db.into(db.settings).insertOnConflictUpdate(
            SettingRow(
              key: _key,
              value: enabled.toString(),
            ),
          );
    } catch (_) {}
  }
}

/// Provides whether the Liquid Glass effect is enabled by user preference.
final liquidGlassEnabledProvider =
    StateNotifierProvider<LiquidGlassNotifier, bool>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return LiquidGlassNotifier(db);
});

/// Computes whether Liquid Glass rendering pipeline is currently active.
/// Active when the UI style is Aurora Glass, user has Liquid Glass enabled,
/// and effects are not reduced.
final isLiquidGlassActiveProvider = Provider<bool>((ref) {
  final isGlassStyle = ref.watch(uiStyleProvider) == UiStyle.auroraGlass;
  final isLiquidEnabled = ref.watch(liquidGlassEnabledProvider);
  final reduceEffects = ref.watch(shouldReduceEffectsProvider);
  return isGlassStyle && isLiquidEnabled && !reduceEffects;
});

/// Now Playing Presentation Style (Classic Spotify vs. Apple Music)
enum NowPlayingStyle {
  classic,
  appleMusic;

  String get displayName {
    switch (this) {
      case NowPlayingStyle.classic:
        return 'Classic';
      case NowPlayingStyle.appleMusic:
        return 'Apple Music';
    }
  }

  String get description {
    switch (this) {
      case NowPlayingStyle.classic:
        return 'Spotify-style vertical column with swipable canvas & mini cards';
      case NowPlayingStyle.appleMusic:
        return 'Apple Music dock with full-screen view swapping & volume bar';
    }
  }
}

class NowPlayingStyleNotifier extends StateNotifier<NowPlayingStyle> {
  final AppDatabase? _db;
  static const String _key = 'now_playing_style';

  NowPlayingStyleNotifier(this._db) : super(NowPlayingStyle.classic) {
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
        if (row.value == NowPlayingStyle.appleMusic.name) {
          state = NowPlayingStyle.appleMusic;
        } else {
          state = NowPlayingStyle.classic;
        }
      }
    } catch (_) {}
  }

  Future<void> setStyle(NowPlayingStyle style) async {
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

final nowPlayingStyleProvider =
    StateNotifierProvider<NowPlayingStyleNotifier, NowPlayingStyle>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return NowPlayingStyleNotifier(db);
});

/// Synchronized Lyrics Presentation Style (Classic vs. Apple Music Depth of Field)
enum LyricsStyle {
  classic,
  appleMusic;

  String get displayName {
    switch (this) {
      case LyricsStyle.classic:
        return 'Classic';
      case LyricsStyle.appleMusic:
        return 'Apple Music';
    }
  }

  String get description {
    switch (this) {
      case LyricsStyle.classic:
        return 'Center-anchored with active line size scaling';
      case LyricsStyle.appleMusic:
        return 'Optical depth of field blur, uniform typography & top anchor';
    }
  }
}

class LyricsStyleNotifier extends StateNotifier<LyricsStyle> {
  final AppDatabase? _db;
  static const String _key = 'lyrics_style';

  LyricsStyleNotifier(this._db) : super(LyricsStyle.appleMusic) {
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
        if (row.value == LyricsStyle.classic.name) {
          state = LyricsStyle.classic;
        } else {
          state = LyricsStyle.appleMusic;
        }
      }
    } catch (_) {}
  }

  Future<void> setStyle(LyricsStyle style) async {
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

final lyricsStyleProvider =
    StateNotifierProvider<LyricsStyleNotifier, LyricsStyle>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return LyricsStyleNotifier(db);
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

/// Global LRU-bounded cache of extracted artwork seed colors for dynamic theming.
final Map<String, Color> _artworkSeedCache = {};

/// Dynamic theme seed color notifier driven by currently playing song artwork.
class DynamicThemeNotifier extends StateNotifier<Color> {
  final Ref ref;
  String? _lastCoverUrl;

  DynamicThemeNotifier(this.ref) : super(const Color(0xFFED5564)) {
    // 1. Initial track extraction on startup / instantiation
    try {
      final initialTrack = ref.read(currentTrackProvider).value ??
          ref.read(audioHandlerProvider).currentTrack;
      if (initialTrack != null &&
          initialTrack.coverUrl != null &&
          initialTrack.coverUrl!.isNotEmpty) {
        extractFromArtwork(initialTrack.coverUrl!);
      }
    } catch (_) {}

    // 2. React to active track stream updates
    ref.listen<AsyncValue<Track?>>(currentTrackProvider, (prev, next) {
      final isDynamicEnabled = ref.read(dynamicArtworkThemingEnabledProvider);
      if (!isDynamicEnabled) return;
      final track = next.value;
      if (track != null && track.coverUrl != null && track.coverUrl!.isNotEmpty) {
        extractFromArtwork(track.coverUrl!);
      }
    });

    // 3. React to system mediaItem updates (covers background, lockscreen, local audio)
    ref.listen<AsyncValue<MediaItem?>>(mediaItemStreamProvider, (prev, next) {
      final isDynamicEnabled = ref.read(dynamicArtworkThemingEnabledProvider);
      if (!isDynamicEnabled) return;
      final item = next.value;
      final artUri = item?.artUri?.toString();
      if (artUri != null && artUri.isNotEmpty) {
        extractFromArtwork(artUri);
      }
    });
  }

  Future<void> extractFromArtwork(String coverUrl) async {
    final raw = coverUrl.trim();
    if (raw.isEmpty || raw == _lastCoverUrl) return;
    _lastCoverUrl = raw;

    if (_artworkSeedCache.containsKey(raw)) {
      state = _artworkSeedCache[raw]!;
      return;
    }

    // Auto-upgrade cleartext http:// to https:// to prevent Android cleartext blocking
    String primaryUrl = raw;
    if (primaryUrl.startsWith('http://')) {
      primaryUrl = 'https://${primaryUrl.substring(7)}';
    }

    ImageProvider? imageProvider;
    if (primaryUrl.startsWith('file://')) {
      imageProvider = FileImage(File(Uri.parse(primaryUrl).toFilePath()));
    } else if (primaryUrl.startsWith('/')) {
      imageProvider = FileImage(File(primaryUrl));
    } else if (primaryUrl.startsWith('https://')) {
      imageProvider = NetworkImage(primaryUrl);
    }

    if (imageProvider == null) {
      final fallbackColor = _generateConsistentHashColor(raw);
      state = fallbackColor;
      return;
    }

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(64, 64),
        maximumColorCount: 8,
      ).timeout(const Duration(seconds: 4));

      final color = generator.vibrantColor?.color ??
          generator.dominantColor?.color ??
          generator.lightVibrantColor?.color ??
          generator.mutedColor?.color ??
          _generateConsistentHashColor(raw);

      if (_artworkSeedCache.length >= 100) {
        _artworkSeedCache.remove(_artworkSeedCache.keys.first);
      }
      _artworkSeedCache[raw] = color;
      state = color;
    } catch (_) {
      // YouTube fallback: maxresdefault -> hqdefault
      if (primaryUrl.contains('maxresdefault.jpg')) {
        final fallbackUrl = primaryUrl.replaceAll('maxresdefault.jpg', 'hqdefault.jpg');
        try {
          final fallbackGen = await PaletteGenerator.fromImageProvider(
            NetworkImage(fallbackUrl),
            size: const Size(64, 64),
            maximumColorCount: 8,
          ).timeout(const Duration(seconds: 3));

          final color = fallbackGen.vibrantColor?.color ??
              fallbackGen.dominantColor?.color ??
              fallbackGen.lightVibrantColor?.color ??
              _generateConsistentHashColor(raw);

          _artworkSeedCache[raw] = color;
          state = color;
          return;
        } catch (_) {}
      }

      // Guaranteed deterministic harmonious seed from artwork hash so theme ALWAYS adapts
      final fallbackColor = _generateConsistentHashColor(raw);
      _artworkSeedCache[raw] = fallbackColor;
      state = fallbackColor;
    }
  }

  static Color generateConsistentHashColor(String seed) => _generateConsistentHashColor(seed);

  static Color _generateConsistentHashColor(String seed) {
    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = (31 * hash + seed.codeUnitAt(i)) & 0xFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.65, 0.75).toColor();
  }

  void setManualSeed(Color color) {
    state = color;
  }
}

final dynamicThemeColorProvider =
    StateNotifierProvider<DynamicThemeNotifier, Color>((ref) {
  return DynamicThemeNotifier(ref);
});

final pureBlackThemeEnabledProvider = StateProvider<bool>((ref) => false);
final dynamicArtworkThemingEnabledProvider = StateProvider<bool>((ref) => true);

/// Provides the active ThemeData corresponding to the active [UiStyle] and dynamic seed.
final uiThemeDataProvider = Provider<ThemeData>((ref) {
  final dynamicSeed = ref.watch(dynamicThemeColorProvider);
  final pureBlack = ref.watch(pureBlackThemeEnabledProvider);
  return AppTheme.buildMetrolistTheme(
    seedColor: dynamicSeed,
    pureBlack: pureBlack,
  );
});

/// Global LRU-bounded cache of extracted artwork colors for Aurora background gradients.
final Map<String, Color> _auroraPaletteCache = {};

/// Extracts and caches dominant vibrant color from album art for Aurora background.
final auroraPaletteProvider =
    FutureProvider.family<Color, String?>((ref, coverUrl) async {
  if (coverUrl == null || coverUrl.isEmpty) {
    return const Color(0xFF34D399); // Default studio sage mint
  }

  final raw = coverUrl.trim();
  if (_auroraPaletteCache.containsKey(raw)) {
    return _auroraPaletteCache[raw]!;
  }

  String primaryUrl = raw;
  if (primaryUrl.startsWith('http://')) {
    primaryUrl = 'https://${primaryUrl.substring(7)}';
  }

  ImageProvider? imageProvider;
  if (primaryUrl.startsWith('file://')) {
    imageProvider = FileImage(File(Uri.parse(primaryUrl).toFilePath()));
  } else if (primaryUrl.startsWith('/')) {
    imageProvider = FileImage(File(primaryUrl));
  } else if (primaryUrl.startsWith('https://')) {
    imageProvider = NetworkImage(primaryUrl);
  }

  if (imageProvider == null) {
    return DynamicThemeNotifier._generateConsistentHashColor(raw);
  }

  try {
    final generator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const Size(32, 32),
      maximumColorCount: 6,
    ).timeout(const Duration(seconds: 4));

    final color = generator.dominantColor?.color ??
        generator.mutedColor?.color ??
        generator.vibrantColor?.color ??
        DynamicThemeNotifier._generateConsistentHashColor(raw);

    if (_auroraPaletteCache.length >= 100) {
      _auroraPaletteCache.remove(_auroraPaletteCache.keys.first);
    }
    _auroraPaletteCache[raw] = color;
    return color;
  } catch (_) {
    final fallback = DynamicThemeNotifier._generateConsistentHashColor(raw);
    _auroraPaletteCache[raw] = fallback;
    return fallback;
  }
});
