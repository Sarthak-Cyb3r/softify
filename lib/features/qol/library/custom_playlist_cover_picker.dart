// ============================================================================
// Softify QoL Feature 18: Custom Playlist Cover Art Picker
// ============================================================================
// Allows users to customize playlist artwork with:
// - Local image files (.jpg, .png, .webp, .gif, .bmp)
// - Remote web image URLs (http/https)
// - Curated aesthetic gradient & genre presets
// - Spotify-style 2x2 track mosaic fallback
// - SharedPreferences and Drift database persistence
// - Real-time preview & PlaylistCoverEditorSheet Material 3 modal
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../domain/ports/i_library_repository.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';
import '../../../presentation/widgets/shared/app_pill_button.dart';
import '../../../presentation/widgets/shared/app_toast.dart';

// ============================================================================
// Storage Engine (Lightweight SharedPreferences Implementation)
// ============================================================================

/// Self-contained SharedPreferences implementation matching the official
/// package API, backed by local JSON file storage with in-memory caching.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _storageFile;

  SharedPreferences._(this._store, this._storageFile);

  /// Sets mock values for unit tests and headless environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Loads or initializes shared preferences storage.
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
      // In-memory fallback
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
        return File('${dir.path}/playlist_covers_prefs.json');
      }
      return File('.softify_playlist_covers_prefs.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final file = _storageFile;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_store);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  String? getString(String key) => _store[key]?.toString();

  Future<bool> setString(String key, String value) async {
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

  Set<String> getKeys() => _store.keys.toSet();
}

// ============================================================================
// Enums & Models
// ============================================================================

/// Origin source type for a playlist cover.
enum PlaylistCoverSource {
  defaultMosaic('Default Mosaic', Icons.grid_view_rounded),
  localFile('Local File', Icons.photo_library_rounded),
  networkUrl('Web Image URL', Icons.link_rounded),
  preset('Preset Theme', Icons.palette_rounded);

  final String label;
  final IconData icon;
  const PlaylistCoverSource(this.label, this.icon);

  static PlaylistCoverSource fromString(String? value) {
    if (value == null) return PlaylistCoverSource.defaultMosaic;
    for (final src in PlaylistCoverSource.values) {
      if (src.name == value) return src;
    }
    return PlaylistCoverSource.defaultMosaic;
  }
}

/// Metadata model encapsulating customized playlist artwork settings.
@immutable
class PlaylistCoverMetadata {
  final String playlistId;
  final PlaylistCoverSource sourceType;
  final String? uri;
  final DateTime updatedAt;
  final String? customTitle;

  const PlaylistCoverMetadata({
    required this.playlistId,
    required this.sourceType,
    this.uri,
    required this.updatedAt,
    this.customTitle,
  });

  /// Factory for a standard default mosaic (no custom artwork set).
  factory PlaylistCoverMetadata.defaultMosaic(String playlistId) {
    return PlaylistCoverMetadata(
      playlistId: playlistId,
      sourceType: PlaylistCoverSource.defaultMosaic,
      uri: null,
      updatedAt: DateTime.now(),
    );
  }

  bool get isCustom =>
      sourceType != PlaylistCoverSource.defaultMosaic &&
      uri != null &&
      uri!.trim().isNotEmpty;

  bool get isLocal => sourceType == PlaylistCoverSource.localFile;
  bool get isNetwork => sourceType == PlaylistCoverSource.networkUrl;
  bool get isPreset => sourceType == PlaylistCoverSource.preset;
  bool get isMosaic => sourceType == PlaylistCoverSource.defaultMosaic;

  Map<String, dynamic> toMap() {
    return {
      'playlist_id': playlistId,
      'source_type': sourceType.name,
      'uri': uri,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'custom_title': customTitle,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory PlaylistCoverMetadata.fromMap(Map<String, dynamic> map) {
    return PlaylistCoverMetadata(
      playlistId: (map['playlist_id'] as String?) ?? '',
      sourceType: PlaylistCoverSource.fromString(map['source_type'] as String?),
      uri: map['uri'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : DateTime.now(),
      customTitle: map['custom_title'] as String?,
    );
  }

  factory PlaylistCoverMetadata.fromJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return PlaylistCoverMetadata.fromMap(decoded);
      }
      if (decoded is Map) {
        return PlaylistCoverMetadata.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return PlaylistCoverMetadata.defaultMosaic('');
  }

  PlaylistCoverMetadata copyWith({
    String? playlistId,
    PlaylistCoverSource? sourceType,
    String? uri,
    DateTime? updatedAt,
    String? customTitle,
  }) {
    return PlaylistCoverMetadata(
      playlistId: playlistId ?? this.playlistId,
      sourceType: sourceType ?? this.sourceType,
      uri: uri ?? this.uri,
      updatedAt: updatedAt ?? this.updatedAt,
      customTitle: customTitle ?? this.customTitle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistCoverMetadata &&
          runtimeType == other.runtimeType &&
          playlistId == other.playlistId &&
          sourceType == other.sourceType &&
          uri == other.uri;

  @override
  int get hashCode => Object.hash(playlistId, sourceType, uri);

  @override
  String toString() =>
      'PlaylistCoverMetadata(id: $playlistId, source: ${sourceType.name}, uri: $uri)';
}

/// Curated preset design style for fast one-tap playlist branding.
@immutable
class PlaylistCoverPreset {
  final String id;
  final String name;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;

  const PlaylistCoverPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
  });

  static const List<PlaylistCoverPreset> presets = [
    PlaylistCoverPreset(
      id: 'synthwave',
      name: 'Synthwave',
      subtitle: 'Retro 80s Neon Pulse',
      gradientColors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
      accentColor: Color(0xFF00F5D4),
      icon: Icons.album_rounded,
    ),
    PlaylistCoverPreset(
      id: 'lofi',
      name: 'Lo-Fi Chill',
      subtitle: 'Cozy Study Beats',
      gradientColors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
      accentColor: Color(0xFFFFD166),
      icon: Icons.coffee_rounded,
    ),
    PlaylistCoverPreset(
      id: 'midnight',
      name: 'Midnight Jazz',
      subtitle: 'Smooth Velvet Night',
      gradientColors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      accentColor: Color(0xFF64DFDF),
      icon: Icons.nightlight_round,
    ),
    PlaylistCoverPreset(
      id: 'acoustic',
      name: 'Acoustic Sunset',
      subtitle: 'Golden Hour Folk',
      gradientColors: [Color(0xFFF12711), Color(0xFFF5AF19)],
      accentColor: Color(0xFFFFF3B0),
      icon: Icons.music_note_rounded,
    ),
    PlaylistCoverPreset(
      id: 'electric',
      name: 'Electric Neon',
      subtitle: 'Club & Cyber Bass',
      gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
      accentColor: Color(0xFF06D6A0),
      icon: Icons.bolt_rounded,
    ),
    PlaylistCoverPreset(
      id: 'deepfocus',
      name: 'Deep Focus',
      subtitle: 'Ambient Concentration',
      gradientColors: [Color(0xFF141E30), Color(0xFF243B55)],
      accentColor: Color(0xFF48CAE4),
      icon: Icons.spa_rounded,
    ),
    PlaylistCoverPreset(
      id: 'workout',
      name: 'Peak Workout',
      subtitle: 'Cardio & Heavy Lifts',
      gradientColors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      accentColor: Color(0xFFFFBE0B),
      icon: Icons.fitness_center_rounded,
    ),
    PlaylistCoverPreset(
      id: 'vaporwave',
      name: 'Vapor Dream',
      subtitle: 'Pastel Nostalgia',
      gradientColors: [Color(0xFFC33764), Color(0xFF1D2671)],
      accentColor: Color(0xFFFF99C8),
      icon: Icons.waves_rounded,
    ),
  ];

  static PlaylistCoverPreset findById(String? id) {
    if (id == null) return presets.first;
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return presets.first;
  }
}

// ============================================================================
// Service Layer
// ============================================================================

/// Service managing custom playlist covers: validation, loading, saving,
/// and synchronizing between in-memory cache, SharedPreferences, and Drift DB.
class CustomPlaylistCoverService {
  final AppDatabase? _db;
  final SharedPreferences? _prefs;
  final StreamController<PlaylistCoverMetadata> _coverChangeController =
      StreamController<PlaylistCoverMetadata>.broadcast();

  static final Map<String, PlaylistCoverMetadata> _inMemoryCovers = {};

  CustomPlaylistCoverService({AppDatabase? db, SharedPreferences? prefs})
      : _db = db,
        _prefs = prefs;

  Stream<PlaylistCoverMetadata> get onCoverChanged =>
      _coverChangeController.stream;

  Stream<PlaylistCoverMetadata> watchCover(String playlistId) {
    return onCoverChanged.where((meta) => meta.playlistId == playlistId);
  }

  static String storageKey(String playlistId) =>
      'playlist_custom_cover_$playlistId';

  /// Synchronous retrieval from in-memory cache, falls back to default mosaic.
  PlaylistCoverMetadata getCoverMetadataSync(String playlistId) {
    return _inMemoryCovers[playlistId] ??
        PlaylistCoverMetadata.defaultMosaic(playlistId);
  }

  /// Asynchronous retrieval checking memory cache, SharedPreferences, and DB.
  Future<PlaylistCoverMetadata> getCoverMetadata(String playlistId) async {
    if (_inMemoryCovers.containsKey(playlistId)) {
      return _inMemoryCovers[playlistId]!;
    }

    final key = storageKey(playlistId);

    // 1. SharedPreferences lookup
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final savedJson = prefs.getString(key);
      if (savedJson != null && savedJson.trim().isNotEmpty) {
        final meta = PlaylistCoverMetadata.fromJson(savedJson);
        if (meta.playlistId.isNotEmpty) {
          _inMemoryCovers[playlistId] = meta;
          return meta;
        }
      }
    } catch (_) {}

    // 2. Drift AppDatabase settings table lookup
    if (_db != null) {
      try {
        final row = await (_db.select(_db.settings)
              ..where((s) => s.key.equals(key)))
            .getSingleOrNull();
        if (row != null && row.value.trim().isNotEmpty) {
          final meta = PlaylistCoverMetadata.fromJson(row.value);
          if (meta.playlistId.isNotEmpty) {
            _inMemoryCovers[playlistId] = meta;
            return meta;
          }
        }
      } catch (_) {}
    }

    final defaultMeta = PlaylistCoverMetadata.defaultMosaic(playlistId);
    _inMemoryCovers[playlistId] = defaultMeta;
    return defaultMeta;
  }

  /// Sets a local image file as the playlist cover art.
  Future<PlaylistCoverMetadata> setLocalCover(
    String playlistId,
    String filePath,
  ) async {
    final cleanPath = filePath.trim();
    if (cleanPath.isEmpty) {
      throw ArgumentError('Local file path cannot be empty');
    }
    if (!isValidImageFile(cleanPath)) {
      throw ArgumentError(
        'File path must end with a valid image extension (.jpg, .png, .webp, .gif, .bmp)',
      );
    }

    final metadata = PlaylistCoverMetadata(
      playlistId: playlistId,
      sourceType: PlaylistCoverSource.localFile,
      uri: cleanPath,
      updatedAt: DateTime.now(),
    );

    await _persistMetadata(metadata);
    return metadata;
  }

  /// Sets a remote web image URL as the playlist cover art.
  Future<PlaylistCoverMetadata> setNetworkCover(
    String playlistId,
    String url,
  ) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      throw ArgumentError('Network image URL cannot be empty');
    }
    if (!isValidNetworkUrl(cleanUrl)) {
      throw ArgumentError(
        'URL must be a valid http or https image address',
      );
    }

    final normalized =
        cleanUrl.startsWith('//') ? 'https:$cleanUrl' : cleanUrl;
    final metadata = PlaylistCoverMetadata(
      playlistId: playlistId,
      sourceType: PlaylistCoverSource.networkUrl,
      uri: normalized,
      updatedAt: DateTime.now(),
    );

    await _persistMetadata(metadata);
    return metadata;
  }

  /// Sets a curated preset style as the playlist cover art.
  Future<PlaylistCoverMetadata> setPresetCover(
    String playlistId,
    String presetId,
  ) async {
    final preset = PlaylistCoverPreset.findById(presetId);
    final metadata = PlaylistCoverMetadata(
      playlistId: playlistId,
      sourceType: PlaylistCoverSource.preset,
      uri: preset.id,
      updatedAt: DateTime.now(),
    );

    await _persistMetadata(metadata);
    return metadata;
  }

  /// Resets the cover art to the default mosaic, deleting custom settings.
  Future<PlaylistCoverMetadata> resetToDefaultMosaic(String playlistId) async {
    final key = storageKey(playlistId);

    // 1. Remove from SharedPreferences
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}

    // 2. Remove from AppDatabase
    if (_db != null) {
      try {
        await (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();
      } catch (_) {}
    }

    final defaultMeta = PlaylistCoverMetadata.defaultMosaic(playlistId);
    _inMemoryCovers[playlistId] = defaultMeta;
    _coverChangeController.add(defaultMeta);
    return defaultMeta;
  }

  Future<void> _persistMetadata(PlaylistCoverMetadata metadata) async {
    final key = storageKey(metadata.playlistId);
    final jsonStr = metadata.toJson();

    _inMemoryCovers[metadata.playlistId] = metadata;

    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(key, jsonStr);
    } catch (_) {}

    if (_db != null) {
      try {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(key: key, value: jsonStr),
            );
      } catch (_) {}
    }

    _coverChangeController.add(metadata);
  }

  /// Validates whether a file path points to a supported image file.
  static bool isValidImageFile(String path) {
    final clean = path.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final normalized = clean.startsWith('file://') ? clean.substring(7) : clean;
    return normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp') ||
        normalized.endsWith('.bmp') ||
        normalized.endsWith('.gif');
  }

  /// Validates whether a URL is a syntactically valid http/https address.
  static bool isValidNetworkUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return false;
    final normalized = clean.startsWith('//') ? 'https:$clean' : clean;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Clears in-memory caches (primarily for unit tests).
  static void clearMemoryCache() {
    _inMemoryCovers.clear();
  }

  void dispose() {
    _coverChangeController.close();
  }
}

// ============================================================================
// State & Riverpod Controller
// ============================================================================

/// Reactive UI state for playlist cover editing and preview.
@immutable
class PlaylistCoverState {
  final PlaylistCoverMetadata metadata;
  final bool isLoading;
  final String? errorMessage;
  final PlaylistCoverSource? previewSource;
  final String? previewUri;

  const PlaylistCoverState({
    required this.metadata,
    this.isLoading = false,
    this.errorMessage,
    this.previewSource,
    this.previewUri,
  });

  PlaylistCoverSource get effectiveSource =>
      previewSource ?? metadata.sourceType;

  String? get effectiveUri => previewUri ?? metadata.uri;

  bool get hasPreview => previewSource != null || previewUri != null;

  bool get isCustom =>
      effectiveSource != PlaylistCoverSource.defaultMosaic &&
      effectiveUri != null &&
      effectiveUri!.trim().isNotEmpty;

  PlaylistCoverState copyWith({
    PlaylistCoverMetadata? metadata,
    bool? isLoading,
    String? errorMessage,
    PlaylistCoverSource? previewSource,
    String? previewUri,
    bool clearPreview = false,
    bool clearError = false,
  }) {
    return PlaylistCoverState(
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      previewSource:
          clearPreview ? null : (previewSource ?? this.previewSource),
      previewUri: clearPreview ? null : (previewUri ?? this.previewUri),
    );
  }
}

/// State notifier managing active cover artwork and live previews per playlist.
class PlaylistCoverNotifier extends StateNotifier<PlaylistCoverState> {
  final CustomPlaylistCoverService _service;
  final String playlistId;

  PlaylistCoverNotifier(this._service, this.playlistId)
      : super(
          PlaylistCoverState(
            metadata: _service.getCoverMetadataSync(playlistId),
            isLoading: true,
          ),
        ) {
    _init();
  }

  Future<void> _init() async {
    try {
      final meta = await _service.getCoverMetadata(playlistId);
      if (mounted) {
        state = state.copyWith(metadata: meta, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Sets a temporary preview without persisting to disk.
  void setPreview(PlaylistCoverSource source, String? uri) {
    state = state.copyWith(
      previewSource: source,
      previewUri: uri,
      clearError: true,
    );
  }

  /// Clears temporary preview and restores the saved metadata.
  void clearPreview() {
    state = state.copyWith(clearPreview: true, clearError: true);
  }

  /// Persists a local file as the playlist cover.
  Future<bool> setLocalFile(String path) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.setLocalCover(playlistId, path);
      state = state.copyWith(
        metadata: updated,
        isLoading: false,
        clearPreview: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Persists a web URL as the playlist cover.
  Future<bool> setNetworkUrl(String url) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.setNetworkCover(playlistId, url);
      state = state.copyWith(
        metadata: updated,
        isLoading: false,
        clearPreview: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Persists a preset theme as the playlist cover.
  Future<bool> setPreset(String presetId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.setPresetCover(playlistId, presetId);
      state = state.copyWith(
        metadata: updated,
        isLoading: false,
        clearPreview: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Resets artwork to default mosaic and clears custom metadata.
  Future<bool> resetToDefaultMosaic() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.resetToDefaultMosaic(playlistId);
      state = state.copyWith(
        metadata: updated,
        isLoading: false,
        clearPreview: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

// ============================================================================
// Providers
// ============================================================================

/// Provider for the custom playlist cover art service.
final customPlaylistCoverServiceProvider =
    Provider<CustomPlaylistCoverService>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return CustomPlaylistCoverService(db: db);
});

/// Riverpod family provider managing cover state for a specific playlist.
final playlistCoverProvider = StateNotifierProvider.family<
    PlaylistCoverNotifier, PlaylistCoverState, String>(
  (ref, playlistId) {
    final service = ref.watch(customPlaylistCoverServiceProvider);
    return PlaylistCoverNotifier(service, playlistId);
  },
);

/// Helper provider that retrieves distinct track cover URLs for a playlist's mosaic.
final playlistTrackCoversProvider =
    FutureProvider.family<List<String>, String>((ref, playlistId) async {
  try {
    final library = ref.watch(libraryRepositoryProvider);
    final playlistWithTracks =
        await library.getPlaylistWithTracks(playlistId);
    if (playlistWithTracks != null) {
      final covers = <String>[];
      for (final entry in playlistWithTracks.entries) {
        final url = entry.track?.coverUrl;
        if (url != null &&
            url.trim().isNotEmpty &&
            !covers.contains(url.trim())) {
          covers.add(url.trim());
          if (covers.length >= 4) break;
        }
      }
      return covers;
    }
  } catch (_) {}
  return const <String>[];
});

// ============================================================================
// UI Component: PlaylistMosaicCover
// ============================================================================

/// Spotify-style 2x2 artwork mosaic rendering:
/// - 0 tracks: Dark gradient with stylized musical note icon.
/// - 1-3 tracks: Single full-bleed cover from the first track.
/// - 4+ tracks: 4-quadrant 2x2 grid of distinct track album covers.
class PlaylistMosaicCover extends StatelessWidget {
  final List<String> trackCoverUrls;
  final double size;
  final BorderRadius? borderRadius;

  const PlaylistMosaicCover({
    super.key,
    required this.trackCoverUrls,
    this.size = 140.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16.0);
    final validUrls = trackCoverUrls
        .where((u) => u.trim().isNotEmpty)
        .take(4)
        .toList();

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF181818),
        child: _buildContent(validUrls),
      ),
    );
  }

  Widget _buildContent(List<String> urls) {
    if (urls.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF282828), Color(0xFF121212)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            size: size * 0.42,
            color: Colors.white24,
          ),
        ),
      );
    }

    if (urls.length < 4) {
      return AppNetworkImage(
        imageUrl: urls.first,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallbackIcon: Icons.queue_music_rounded,
      );
    }

    // 2x2 Mosaic Grid
    final half = size / 2.0;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AppNetworkImage(
                    imageUrl: urls[0],
                    width: half,
                    height: half,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: AppNetworkImage(
                    imageUrl: urls[1],
                    width: half,
                    height: half,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AppNetworkImage(
                    imageUrl: urls[2],
                    width: half,
                    height: half,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: AppNetworkImage(
                    imageUrl: urls[3],
                    width: half,
                    height: half,
                    fit: BoxFit.cover,
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

// ============================================================================
// UI Component: PlaylistPresetCover
// ============================================================================

/// Renders a curated aesthetic preset cover with vibrant gradients & icons.
class PlaylistPresetCover extends StatelessWidget {
  final PlaylistCoverPreset preset;
  final double size;
  final BorderRadius? borderRadius;

  const PlaylistPresetCover({
    super.key,
    required this.preset,
    this.size = 140.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16.0);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: preset.gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: preset.accentColor.withValues(alpha: 0.3),
              blurRadius: 16.0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Ambient glow orb
            Positioned(
              top: -size * 0.2,
              right: -size * 0.2,
              child: Container(
                width: size * 0.8,
                height: size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Centered icon
            Center(
              child: Icon(
                preset.icon,
                size: size * 0.44,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            // Bottom title pill
            Positioned(
              left: 8.0,
              right: 8.0,
              bottom: 8.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  preset.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UI Component: PlaylistCoverPreview
// ============================================================================

/// High-level unified playlist cover preview widget.
/// Gracefully handles local files, remote web URLs, curated presets,
/// and default track mosaics.
class PlaylistCoverPreview extends StatelessWidget {
  final String playlistId;
  final PlaylistCoverMetadata? metadata;
  final List<String>? trackCoverUrls;
  final double size;
  final BorderRadius? borderRadius;
  final double elevation;
  final bool isEditable;
  final VoidCallback? onEditTap;
  final bool showBadge;

  const PlaylistCoverPreview({
    super.key,
    required this.playlistId,
    this.metadata,
    this.trackCoverUrls,
    this.size = 140.0,
    this.borderRadius,
    this.elevation = 6.0,
    this.isEditable = false,
    this.onEditTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16.0);
    final meta = metadata ??
        CustomPlaylistCoverService._inMemoryCovers[playlistId] ??
        PlaylistCoverMetadata.defaultMosaic(playlistId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation * 0.6),
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Artwork Body
          ClipRRect(
            borderRadius: radius,
            child: _buildArtwork(meta, radius),
          ),

          // 2. Source Type Badge
          if (showBadge)
            Positioned(
              left: 6.0,
              top: 6.0,
              child: _buildBadge(meta),
            ),

          // 3. Edit Overlay
          if (isEditable)
            Positioned(
              right: 6.0,
              bottom: 6.0,
              child: Material(
                color: Colors.black.withValues(alpha: 0.65),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onEditTap,
                  child: Padding(
                    padding: const EdgeInsets.all(7.0),
                    child: Icon(
                      Icons.edit_rounded,
                      size: size * 0.16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtwork(PlaylistCoverMetadata meta, BorderRadius radius) {
    switch (meta.sourceType) {
      case PlaylistCoverSource.preset:
        final preset = PlaylistCoverPreset.findById(meta.uri);
        return PlaylistPresetCover(
          preset: preset,
          size: size,
          borderRadius: radius,
        );

      case PlaylistCoverSource.networkUrl:
        final url = meta.uri ?? '';
        return AppNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          borderRadius: radius,
          fallbackIcon: Icons.broken_image_rounded,
        );

      case PlaylistCoverSource.localFile:
        final path = meta.uri ?? '';
        final file = File(path);
        final exists = file.existsSync();

        if (exists) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildLocalFileFallback(path),
          );
        } else {
          return _buildLocalFileFallback(path);
        }

      case PlaylistCoverSource.defaultMosaic:
        return PlaylistMosaicCover(
          trackCoverUrls: trackCoverUrls ?? const [],
          size: size,
          borderRadius: radius,
        );
    }
  }

  Widget _buildLocalFileFallback(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    return Container(
      color: const Color(0xFF222222),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            size: size * 0.3,
            color: Colors.white54,
          ),
          const SizedBox(height: 4.0),
          Text(
            fileName.isNotEmpty ? fileName : 'Local File',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.0,
              color: Colors.white70,
              fontFamily: AppTheme.fontUi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(PlaylistCoverMetadata meta) {
    final label = switch (meta.sourceType) {
      PlaylistCoverSource.defaultMosaic => 'MOSAIC',
      PlaylistCoverSource.preset => 'PRESET',
      PlaylistCoverSource.networkUrl => 'WEB',
      PlaylistCoverSource.localFile => 'LOCAL',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============================================================================
// UI Component: PlaylistCoverEditorSheet
// ============================================================================

/// Modal Bottom Sheet allowing users to customize their playlist cover artwork.
/// Offers curated presets, direct image URL pasting, local file selection,
/// instant live previewing, and one-tap reset to default track mosaic.
class PlaylistCoverEditorSheet extends ConsumerStatefulWidget {
  final String playlistId;
  final String? playlistName;
  final List<String>? trackCoverUrls;

  const PlaylistCoverEditorSheet({
    super.key,
    required this.playlistId,
    this.playlistName,
    this.trackCoverUrls,
  });

  /// Presents the bottom sheet over the given context.
  static Future<void> show(
    BuildContext context, {
    required String playlistId,
    String? playlistName,
    List<String>? trackCoverUrls,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlaylistCoverEditorSheet(
        playlistId: playlistId,
        playlistName: playlistName,
        trackCoverUrls: trackCoverUrls,
      ),
    );
  }

  @override
  ConsumerState<PlaylistCoverEditorSheet> createState() =>
      _PlaylistCoverEditorSheetState();
}

class _PlaylistCoverEditorSheetState
    extends ConsumerState<PlaylistCoverEditorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _localPathController = TextEditingController();

  PlaylistCoverSource _selectedSource = PlaylistCoverSource.preset;
  String? _previewUri;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Initial populate from current cover
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref
          .read(customPlaylistCoverServiceProvider)
          .getCoverMetadataSync(widget.playlistId);

      setState(() {
        _selectedSource = current.sourceType == PlaylistCoverSource.defaultMosaic
            ? PlaylistCoverSource.preset
            : current.sourceType;
        _previewUri = current.uri;

        if (current.isNetwork && current.uri != null) {
          _urlController.text = current.uri!;
          _tabController.index = 1;
        } else if (current.isLocal && current.uri != null) {
          _localPathController.text = current.uri!;
          _tabController.index = 2;
        } else {
          _tabController.index = 0;
        }
      });
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _validationError = null;
      switch (_tabController.index) {
        case 0:
          _selectedSource = PlaylistCoverSource.preset;
          _previewUri ??= PlaylistCoverPreset.presets.first.id;
          break;
        case 1:
          _selectedSource = PlaylistCoverSource.networkUrl;
          _previewUri = _urlController.text.trim().isNotEmpty
              ? _urlController.text.trim()
              : null;
          break;
        case 2:
          _selectedSource = PlaylistCoverSource.localFile;
          _previewUri = _localPathController.text.trim().isNotEmpty
              ? _localPathController.text.trim()
              : null;
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _urlController.dispose();
    _localPathController.dispose();
    super.dispose();
  }

  void _applyPreview(PlaylistCoverSource source, String? uri) {
    setState(() {
      _selectedSource = source;
      _previewUri = uri;
      _validationError = null;
    });
    ref.read(playlistCoverProvider(widget.playlistId).notifier).setPreview(
          source,
          uri,
        );
  }

  Future<void> _handleSave() async {
    final notifier =
        ref.read(playlistCoverProvider(widget.playlistId).notifier);
    bool success = false;

    setState(() => _validationError = null);

    switch (_selectedSource) {
      case PlaylistCoverSource.preset:
        final id = _previewUri ?? PlaylistCoverPreset.presets.first.id;
        success = await notifier.setPreset(id);
        break;

      case PlaylistCoverSource.networkUrl:
        final url = _urlController.text.trim();
        if (url.isEmpty) {
          setState(() => _validationError = 'Please enter an image URL');
          return;
        }
        if (!CustomPlaylistCoverService.isValidNetworkUrl(url)) {
          setState(() => _validationError = 'Please enter a valid http/https URL');
          return;
        }
        success = await notifier.setNetworkUrl(url);
        break;

      case PlaylistCoverSource.localFile:
        final path = _localPathController.text.trim();
        if (path.isEmpty) {
          setState(() => _validationError = 'Please enter a local file path');
          return;
        }
        if (!CustomPlaylistCoverService.isValidImageFile(path)) {
          setState(
            () => _validationError =
                'Image must end with .jpg, .png, .webp, .gif, or .bmp',
          );
          return;
        }
        success = await notifier.setLocalFile(path);
        break;

      case PlaylistCoverSource.defaultMosaic:
        success = await notifier.resetToDefaultMosaic();
        break;
    }

    if (mounted) {
      if (success) {
        AppToast.show(
          context,
          message: 'Playlist cover updated successfully',
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF1DB954),
            size: 18,
          ),
        );
        Navigator.of(context).pop();
      } else {
        final err = ref.read(playlistCoverProvider(widget.playlistId)).errorMessage;
        setState(() => _validationError = err ?? 'Failed to update playlist cover');
      }
    }
  }

  Future<void> _handleResetMosaic() async {
    final notifier =
        ref.read(playlistCoverProvider(widget.playlistId).notifier);
    final success = await notifier.resetToDefaultMosaic();

    if (mounted) {
      if (success) {
        AppToast.show(
          context,
          message: 'Restored default playlist mosaic',
          icon: const Icon(
            Icons.restore_rounded,
            color: Color(0xFF1DB954),
            size: 18,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(playlistCoverProvider(widget.playlistId));
    final mediaQuery = MediaQuery.of(context);

    // Active metadata for preview display
    final previewMeta = PlaylistCoverMetadata(
      playlistId: widget.playlistId,
      sourceType: _selectedSource,
      uri: _previewUri,
      updatedAt: DateTime.now(),
    );

    return Material(
      color: tokens.surfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: mediaQuery.viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  width: 44.0,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // 2. Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 4.0, 16.0, 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Playlist Cover',
                            style: TextStyle(
                              fontFamily: AppTheme.fontDisplay,
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.playlistName != null) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              widget.playlistName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 13.0,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () {
                        ref
                            .read(playlistCoverProvider(widget.playlistId).notifier)
                            .clearPreview();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),

              // 3. Central Live Preview
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: PlaylistCoverPreview(
                    playlistId: widget.playlistId,
                    metadata: previewMeta,
                    trackCoverUrls: widget.trackCoverUrls,
                    size: 148.0,
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    elevation: 10.0,
                    showBadge: true,
                  ),
                ),
              ),

              // Error feedback if any
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: tokens.error.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 16.0, color: tokens.error),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12.0,
                              color: tokens.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Tab Bar (Presets | Web URL | Local File)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: tokens.accent,
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: tokens.textSecondary,
                    labelStyle: const TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Presets'),
                      Tab(text: 'Web URL'),
                      Tab(text: 'Local File'),
                    ],
                  ),
                ),
              ),

              // 5. Tab Content Views
              SizedBox(
                height: 140.0,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Curated Presets
                    _buildPresetsTab(tokens),

                    // Tab 2: Web URL
                    _buildWebUrlTab(tokens),

                    // Tab 3: Local File
                    _buildLocalFileTab(tokens),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1.0),

              // 6. Action Buttons Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 16.0),
                child: Row(
                  children: [
                    // Reset to Mosaic button
                    TextButton.icon(
                      onPressed: state.isLoading ? null : _handleResetMosaic,
                      icon: const Icon(
                        Icons.restore_rounded,
                        size: 18.0,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        'Reset Mosaic',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.0,
                          fontFamily: AppTheme.fontUi,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Cancel
                    TextButton(
                      onPressed: () {
                        ref
                            .read(playlistCoverProvider(widget.playlistId).notifier)
                            .clearPreview();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13.0,
                          fontFamily: AppTheme.fontUi,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Save Button
                    AppPillButton(
                      label: 'Save Artwork',
                      isLoading: state.isLoading,
                      icon: const Icon(Icons.check_rounded, size: 18.0),
                      onPressed: _handleSave,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsTab(AppTokens tokens) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      scrollDirection: Axis.horizontal,
      itemCount: PlaylistCoverPreset.presets.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12.0),
      itemBuilder: (context, index) {
        final preset = PlaylistCoverPreset.presets[index];
        final isSelected =
            _selectedSource == PlaylistCoverSource.preset &&
            _previewUri == preset.id;

        return GestureDetector(
          onTap: () => _applyPreview(PlaylistCoverSource.preset, preset.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 96.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isSelected ? tokens.accent : Colors.white12,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.35),
                        blurRadius: 8.0,
                      ),
                    ]
                  : null,
            ),
            child: PlaylistPresetCover(
              preset: preset,
              size: 96.0,
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebUrlTab(AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.white,
              fontFamily: AppTheme.fontUi,
            ),
            decoration: InputDecoration(
              hintText: 'https://images.example.com/cover.jpg',
              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13.0),
              filled: true,
              fillColor: tokens.card,
              isDense: true,
              prefixIcon: const Icon(Icons.link_rounded, size: 18.0),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_urlController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16.0),
                      onPressed: () {
                        _urlController.clear();
                        _applyPreview(PlaylistCoverSource.networkUrl, null);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.paste_rounded, size: 16.0),
                    tooltip: 'Paste from Clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _urlController.text = data!.text!.trim();
                        _applyPreview(
                          PlaylistCoverSource.networkUrl,
                          _urlController.text,
                        );
                      }
                    },
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.accent, width: 1.5),
              ),
            ),
            onChanged: (val) {
              _applyPreview(
                PlaylistCoverSource.networkUrl,
                val.trim().isNotEmpty ? val.trim() : null,
              );
            },
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Text(
                'Supports Direct JPEG, PNG, and WebP image URLs',
                style: TextStyle(fontSize: 11.0, color: tokens.textMuted),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  final text = _urlController.text.trim();
                  if (text.isNotEmpty) {
                    _applyPreview(PlaylistCoverSource.networkUrl, text);
                  }
                },
                child: const Text('Preview URL', style: TextStyle(fontSize: 12.0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalFileTab(AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _localPathController,
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.white,
              fontFamily: AppTheme.fontUi,
            ),
            decoration: InputDecoration(
              hintText: '/home/user/Pictures/album_cover.png',
              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13.0),
              filled: true,
              fillColor: tokens.card,
              isDense: true,
              prefixIcon: const Icon(Icons.folder_open_rounded, size: 18.0),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_localPathController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16.0),
                      onPressed: () {
                        _localPathController.clear();
                        _applyPreview(PlaylistCoverSource.localFile, null);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.paste_rounded, size: 16.0),
                    tooltip: 'Paste Path',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _localPathController.text = data!.text!.trim();
                        _applyPreview(
                          PlaylistCoverSource.localFile,
                          _localPathController.text,
                        );
                      }
                    },
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.accent, width: 1.5),
              ),
            ),
            onChanged: (val) {
              _applyPreview(
                PlaylistCoverSource.localFile,
                val.trim().isNotEmpty ? val.trim() : null,
              );
            },
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Text(
                'Enter absolute path to .jpg, .png, .webp, or .gif',
                style: TextStyle(fontSize: 11.0, color: tokens.textMuted),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  final text = _localPathController.text.trim();
                  if (text.isNotEmpty) {
                    _applyPreview(PlaylistCoverSource.localFile, text);
                  }
                },
                child: const Text('Test Path', style: TextStyle(fontSize: 12.0)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
