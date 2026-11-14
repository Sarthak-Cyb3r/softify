// ============================================================================
// Softify Quality of Life (QoL) - Feature 21: Smart Playlist - Recently Added (Top 100)
// ============================================================================
//
// Dynamic smart playlist providing the last 100 library additions chronologically.
// Auto-refreshes whenever new songs or albums are saved to the user's library.
//
// Features:
// 1. Dynamic Top 100 Playlist: Pure Dart algorithmic generator sorting library
//    additions in reverse chronological order (newest first).
// 2. Real-Time Auto-Refresh: Drift reactive streams trigger immediate updates
//    whenever songs or albums are inserted, liked, or modified.
// 3. RecentlyAddedPlaylistTile: Material 3 visual tile with multi-artwork
//    collage thumbnail, dynamic duration badge, and instant 1-tap playback.
// 4. Detailed Track Inspector: Formatted relative timestamps ("Just added",
//    "15m ago", "Yesterday"), album badges, and track-level controls.
// 5. Riverpod State Management: Reactive stream providers, config notifiers,
//    and dedicated play/pause controller.
// 6. Self-Contained SharedPreferences Persistence: Preserves user filters,
//    custom limits, and sort preferences with zero native plugin dependencies.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/ports/i_library_repository.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/animated_music_wave_indicator.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';

// ============================================================================
// Configuration Constants & SharedPreferences Keys
// ============================================================================

/// Canonical unique identifier for the Recently Added smart playlist.
const String kRecentlyAddedSmartPlaylistId = 'smart_playlist_recently_added_top_100';

/// Default chronological limit for the Recently Added smart playlist.
const int kRecentlyAddedDefaultMax = 100;

/// Persistent SharedPreferences key for maximum track count.
const String kRecentlyAddedPrefMaxTracks = 'softify_recently_added_max_tracks';

/// Persistent SharedPreferences key for active library filter mode.
const String kRecentlyAddedPrefFilter = 'softify_recently_added_filter';

/// Persistent SharedPreferences key for sorting direction.
const String kRecentlyAddedPrefSortOrder = 'softify_recently_added_sort_order';

/// Persistent SharedPreferences key for deduplication flag.
const String kRecentlyAddedPrefDeduplicate = 'softify_recently_added_deduplicate';

/// Persistent SharedPreferences key for play count metrics.
const String kRecentlyAddedPrefPlayCount = 'softify_recently_added_play_count';

// ============================================================================
// Enums & Filter Modes
// ============================================================================

/// Filtering scope for library additions in the Recently Added playlist.
enum RecentlyAddedSourceFilter {
  all('All Additions', 'All songs and albums added to your library', Icons.all_inclusive_rounded),
  songs('Liked Songs', 'Tracks explicitly saved or liked by the user', Icons.favorite_rounded),
  albums('Album Tracks', 'Tracks belonging to saved full albums', Icons.album_rounded);

  final String label;
  final String description;
  final IconData icon;

  const RecentlyAddedSourceFilter(this.label, this.description, this.icon);

  static RecentlyAddedSourceFilter fromString(String? val) {
    if (val == null) return RecentlyAddedSourceFilter.all;
    for (final filter in RecentlyAddedSourceFilter.values) {
      if (filter.name == val) return filter;
    }
    return RecentlyAddedSourceFilter.all;
  }
}

/// Chronological ordering direction for recent additions.
enum RecentlyAddedSortOrder {
  newestFirst('Newest First', Icons.arrow_downward_rounded),
  oldestFirst('Oldest First', Icons.arrow_upward_rounded);

  final String label;
  final IconData icon;

  const RecentlyAddedSortOrder(this.label, this.icon);

  static RecentlyAddedSortOrder fromString(String? val) {
    if (val == null) return RecentlyAddedSortOrder.newestFirst;
    for (final order in RecentlyAddedSortOrder.values) {
      if (order.name == val) return order;
    }
    return RecentlyAddedSortOrder.newestFirst;
  }
}

// ============================================================================
// Data Models
// ============================================================================

/// Represents a track item within the Recently Added smart playlist,
/// enriched with chronological metadata and relative addition timestamps.
@immutable
class RecentlyAddedTrackItem {
  /// The underlying domain track entity.
  final Track track;

  /// The exact timestamp when this track was added to the library.
  final DateTime addedAt;

  /// 1-based chronological index in the top 100 list.
  final int orderIndex;

  /// Optional name of the album this addition belongs to.
  final String? albumTitle;

  /// Whether this track was saved as part of an album collection.
  final bool isAlbumTrack;

  const RecentlyAddedTrackItem({
    required this.track,
    required this.addedAt,
    required this.orderIndex,
    this.albumTitle,
    this.isAlbumTrack = false,
  });

  /// Human-friendly relative addition label (e.g., "Just added", "12m ago", "Yesterday").
  String get formattedRelativeTime {
    final now = DateTime.now();
    final difference = now.difference(addedAt);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just added';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hr' : 'hrs'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[addedAt.month - 1];
      if (addedAt.year == now.year) {
        return '$month ${addedAt.day}';
      }
      return '$month ${addedAt.day}, ${addedAt.year}';
    }
  }

  RecentlyAddedTrackItem copyWith({
    Track? track,
    DateTime? addedAt,
    int? orderIndex,
    String? albumTitle,
    bool? isAlbumTrack,
  }) {
    return RecentlyAddedTrackItem(
      track: track ?? this.track,
      addedAt: addedAt ?? this.addedAt,
      orderIndex: orderIndex ?? this.orderIndex,
      albumTitle: albumTitle ?? this.albumTitle,
      isAlbumTrack: isAlbumTrack ?? this.isAlbumTrack,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'track_id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'duration_ms': track.duration.inMilliseconds,
      'cover_url': track.coverUrl,
      'added_at_ms': addedAt.millisecondsSinceEpoch,
      'order_index': orderIndex,
      'album_title': albumTitle,
      'is_album_track': isAlbumTrack,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentlyAddedTrackItem &&
          runtimeType == other.runtimeType &&
          track.id == other.track.id &&
          addedAt.millisecondsSinceEpoch == other.addedAt.millisecondsSinceEpoch &&
          orderIndex == other.orderIndex;

  @override
  int get hashCode => Object.hash(track.id, addedAt.millisecondsSinceEpoch, orderIndex);
}

/// User configuration settings for the Recently Added smart playlist.
@immutable
class RecentlyAddedConfig {
  /// Maximum number of tracks in the smart playlist (default: 100).
  final int maxTracks;

  /// Source filtering mode (all, liked songs only, or album tracks only).
  final RecentlyAddedSourceFilter filter;

  /// Sort ordering direction (newest additions first vs oldest).
  final RecentlyAddedSortOrder sortOrder;

  /// Whether automatic reactive refreshing is enabled.
  final bool autoRefresh;

  /// Whether duplicate songs are collapsed to their latest addition date.
  final bool deduplicate;

  const RecentlyAddedConfig({
    this.maxTracks = kRecentlyAddedDefaultMax,
    this.filter = RecentlyAddedSourceFilter.all,
    this.sortOrder = RecentlyAddedSortOrder.newestFirst,
    this.autoRefresh = true,
    this.deduplicate = true,
  });

  RecentlyAddedConfig copyWith({
    int? maxTracks,
    RecentlyAddedSourceFilter? filter,
    RecentlyAddedSortOrder? sortOrder,
    bool? autoRefresh,
    bool? deduplicate,
  }) {
    return RecentlyAddedConfig(
      maxTracks: maxTracks ?? this.maxTracks,
      filter: filter ?? this.filter,
      sortOrder: sortOrder ?? this.sortOrder,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      deduplicate: deduplicate ?? this.deduplicate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'max_tracks': maxTracks,
      'filter': filter.name,
      'sort_order': sortOrder.name,
      'auto_refresh': autoRefresh,
      'deduplicate': deduplicate,
    };
  }

  factory RecentlyAddedConfig.fromMap(Map<String, dynamic> map) {
    return RecentlyAddedConfig(
      maxTracks: (map['max_tracks'] as int?) ?? kRecentlyAddedDefaultMax,
      filter: RecentlyAddedSourceFilter.fromString(map['filter'] as String?),
      sortOrder: RecentlyAddedSortOrder.fromString(map['sort_order'] as String?),
      autoRefresh: (map['auto_refresh'] as bool?) ?? true,
      deduplicate: (map['deduplicate'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentlyAddedConfig &&
          runtimeType == other.runtimeType &&
          maxTracks == other.maxTracks &&
          filter == other.filter &&
          sortOrder == other.sortOrder &&
          autoRefresh == other.autoRefresh &&
          deduplicate == other.deduplicate;

  @override
  int get hashCode => Object.hash(maxTracks, filter, sortOrder, autoRefresh, deduplicate);
}

/// Complete generated state for the Recently Added (Top 100) smart playlist.
@immutable
class RecentlyAddedSmartPlaylist {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final DateTime generatedAt;
  final List<RecentlyAddedTrackItem> items;
  final RecentlyAddedConfig config;

  const RecentlyAddedSmartPlaylist({
    this.id = kRecentlyAddedSmartPlaylistId,
    this.title = 'Recently Added',
    this.subtitle = 'Top 100 • Library Additions',
    this.description =
        'Your last 100 library additions chronologically ordered, auto-updating in real-time when new songs or albums are saved.',
    required this.generatedAt,
    required this.items,
    this.config = const RecentlyAddedConfig(),
  });

  /// List of underlying tracks for playback queue construction.
  List<Track> get tracks => items.map((i) => i.track).toList();

  /// Total count of tracks in this playlist.
  int get length => items.length;

  /// Whether the playlist is empty.
  bool get isEmpty => items.isEmpty;

  /// Whether the playlist has one or more tracks.
  bool get isNotEmpty => items.isNotEmpty;

  /// Combined total duration across all tracks.
  Duration get totalDuration {
    return items.fold<Duration>(
      Duration.zero,
      (acc, item) => acc + item.track.duration,
    );
  }

  /// Formatted duration string (e.g. "1 hr 45 min" or "38 min").
  String get formattedTotalDuration {
    final minutes = totalDuration.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '$hours hr $remainingMinutes min' : '$hours hr';
  }

  /// Up to 4 unique artwork URLs for high-resolution collage rendering.
  List<String> get previewCovers {
    final covers = <String>[];
    for (final item in items) {
      final url = item.track.coverUrl;
      if (url != null && url.trim().isNotEmpty && !covers.contains(url)) {
        covers.add(url);
        if (covers.length >= 4) break;
      }
    }
    return covers;
  }

  /// Number of distinct albums represented in the playlist.
  int get uniqueAlbumsCount {
    final albums = <String>{};
    for (final item in items) {
      if (item.track.album != null && item.track.album!.trim().isNotEmpty) {
        albums.add(item.track.album!.trim().toLowerCase());
      }
    }
    return albums.length;
  }

  /// Number of distinct artists represented in the playlist.
  int get uniqueArtistsCount {
    final artists = <String>{};
    for (final item in items) {
      if (item.track.artist.trim().isNotEmpty) {
        artists.add(item.track.artist.trim().toLowerCase());
      }
    }
    return artists.length;
  }

  /// Total tracks added within the last 24 hours.
  int get additionsTodayCount {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return items.where((i) => i.addedAt.isAfter(cutoff)).length;
  }

  /// Total tracks added within the last 7 days.
  int get additionsThisWeekCount {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return items.where((i) => i.addedAt.isAfter(cutoff)).length;
  }

  /// Converts this smart playlist to standard Softify domain [Playlist].
  Playlist toDomainPlaylist() {
    return Playlist(
      id: id,
      name: title,
      description: description,
      trackCount: items.length,
      isImported: false,
      sourceUrl: null,
      createdAt: items.isNotEmpty ? items.first.addedAt : generatedAt,
    );
  }

  RecentlyAddedSmartPlaylist copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    DateTime? generatedAt,
    List<RecentlyAddedTrackItem>? items,
    RecentlyAddedConfig? config,
  }) {
    return RecentlyAddedSmartPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      generatedAt: generatedAt ?? this.generatedAt,
      items: items ?? this.items,
      config: config ?? this.config,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentlyAddedSmartPlaylist &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          items.length == other.items.length &&
          config == other.config;

  @override
  int get hashCode => Object.hash(id, items.length, config);
}

// ============================================================================
// SharedPreferences Persistence Engine (Self-Contained)
// ============================================================================

/// Storage contract for saving user Recently Added preferences.
abstract class RecentlyAddedPrefsStorage {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);
  Future<bool> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<bool> remove(String key);
  Future<bool> clear();
}

/// Durable disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class RecentlyAddedSharedPreferencesStore implements RecentlyAddedPrefsStorage {
  static final RecentlyAddedSharedPreferencesStore _instance =
      RecentlyAddedSharedPreferencesStore._internal();
  factory RecentlyAddedSharedPreferencesStore() => _instance;
  RecentlyAddedSharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  static Map<String, dynamic>? _mockStore;

  /// Injects in-memory mock values for testing.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockStore = Map<String, dynamic>.from(values);
    _instance._memoryCache = Map<String, dynamic>.from(values);
    _instance._isLoaded = true;
  }

  /// Resets memory state and mocks.
  static void reset() {
    _mockStore = null;
    _instance._memoryCache.clear();
    _instance._isLoaded = false;
  }

  Future<void> _ensureLoaded() async {
    if (_mockStore != null) {
      _memoryCache = _mockStore!;
      _isLoaded = true;
      return;
    }
    if (_isLoaded) return;

    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (home != null && home.isNotEmpty) {
        final dir = Directory('$home/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _cacheFile = File('${dir.path}/recently_added_preferences.json');
        if (await _cacheFile!.exists()) {
          final raw = await _cacheFile!.readAsString();
          if (raw.trim().isNotEmpty) {
            final parsed = jsonDecode(raw);
            if (parsed is Map) {
              _memoryCache = Map<String, dynamic>.from(parsed);
            }
          }
        }
      }
    } catch (_) {
      // Fall back safely to in-memory store
    }
    _isLoaded = true;
  }

  Future<void> _persist() async {
    if (_mockStore != null) return;
    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache));
      }
    } catch (_) {}
  }

  @override
  Future<String?> getString(String key) async {
    await _ensureLoaded();
    final val = _memoryCache[key];
    return val is String ? val : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    await _persist();
    return true;
  }

  @override
  Future<int?> getInt(String key) async {
    await _ensureLoaded();
    final val = _memoryCache[key];
    return val is int ? val : null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    await _persist();
    return true;
  }

  @override
  Future<bool> getBool(String key) async {
    await _ensureLoaded();
    final val = _memoryCache[key];
    return val is bool ? val : false;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    await _persist();
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    await _ensureLoaded();
    _memoryCache.remove(key);
    await _persist();
    return true;
  }

  @override
  Future<bool> clear() async {
    await _ensureLoaded();
    _memoryCache.clear();
    await _persist();
    return true;
  }
}

// ============================================================================
// Pure Dart Algorithmic Generator & Database Watchers
// ============================================================================

/// High-performance algorithmic engine for sorting and compiling the
/// Recently Added (Top 100) dynamic playlist.
class RecentlyAddedPlaylistEngine {
  const RecentlyAddedPlaylistEngine._();

  /// Converts a database [TrackRow] into a domain [Track].
  static Track trackFromRow(TrackRow r) {
    return Track(
      id: r.id,
      sourceId: r.sourceId,
      title: r.title,
      artist: r.artist,
      album: r.album,
      duration: Duration(milliseconds: r.durationMs),
      coverUrl: r.coverUrl,
      matchConfidence: r.matchConfidence,
      isLiked: r.isLiked,
      isUnavailable: r.isUnavailable,
    );
  }

  /// Pure Dart generator producing a [RecentlyAddedSmartPlaylist] from an in-memory
  /// list of track entries with explicit addition timestamps.
  static RecentlyAddedSmartPlaylist generateFromTracks({
    required List<({Track track, DateTime addedAt})> entries,
    RecentlyAddedConfig config = const RecentlyAddedConfig(),
    DateTime? referenceTime,
  }) {
    if (entries.isEmpty) {
      return RecentlyAddedSmartPlaylist(
        generatedAt: referenceTime ?? DateTime.now(),
        items: const [],
        config: config,
      );
    }

    // 1. Optional deduplication: retain the most recent addition date per track ID
    List<({Track track, DateTime addedAt})> processedEntries;
    if (config.deduplicate) {
      final seen = <String, ({Track track, DateTime addedAt})>{};
      for (final entry in entries) {
        final existing = seen[entry.track.id];
        if (existing == null || entry.addedAt.isAfter(existing.addedAt)) {
          seen[entry.track.id] = entry;
        }
      }
      processedEntries = seen.values.toList();
    } else {
      processedEntries = List.of(entries);
    }

    // 2. Filter application
    if (config.filter == RecentlyAddedSourceFilter.songs) {
      processedEntries = processedEntries.where((e) => e.track.isLiked).toList();
    } else if (config.filter == RecentlyAddedSourceFilter.albums) {
      processedEntries = processedEntries.where((e) {
        final alb = e.track.album;
        return alb != null && alb.trim().isNotEmpty;
      }).toList();
    }

    // 3. Chronological sorting
    processedEntries.sort((a, b) {
      if (config.sortOrder == RecentlyAddedSortOrder.newestFirst) {
        return b.addedAt.compareTo(a.addedAt);
      } else {
        return a.addedAt.compareTo(b.addedAt);
      }
    });

    // 4. Limit to maxTracks (default 100)
    final capped = processedEntries.take(config.maxTracks).toList();

    // 5. Build enriched items with 1-based order index
    final items = <RecentlyAddedTrackItem>[];
    for (int i = 0; i < capped.length; i++) {
      final entry = capped[i];
      final isAlbum = entry.track.album != null && entry.track.album!.trim().isNotEmpty;
      items.add(RecentlyAddedTrackItem(
        track: entry.track,
        addedAt: entry.addedAt,
        orderIndex: i + 1,
        albumTitle: entry.track.album,
        isAlbumTrack: isAlbum,
      ));
    }

    return RecentlyAddedSmartPlaylist(
      generatedAt: referenceTime ?? DateTime.now(),
      items: items,
      config: config,
    );
  }

  /// Generates the playlist snapshot directly from SQLite database records.
  static Future<RecentlyAddedSmartPlaylist> generateFromDatabase(
    AppDatabase db, {
    RecentlyAddedConfig config = const RecentlyAddedConfig(),
    DateTime? referenceTime,
  }) async {
    final query = db.select(db.tracks);

    // Apply database-level filters where applicable
    if (config.filter == RecentlyAddedSourceFilter.songs) {
      query.where((t) => t.isLiked.equals(true));
    } else if (config.filter == RecentlyAddedSourceFilter.albums) {
      query.where((t) => t.album.isNotNull() & t.album.isBiggerThanValue(''));
    }

    // Chronological order
    if (config.sortOrder == RecentlyAddedSortOrder.newestFirst) {
      query.orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]);
    } else {
      query.orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]);
    }

    // Overfetch slightly if deduplication is required
    final fetchLimit = config.deduplicate ? config.maxTracks * 2 : config.maxTracks;
    query.limit(fetchLimit);

    final rows = await query.get();
    final entries = rows.map((r) {
      final track = trackFromRow(r);
      final addedAt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
      return (track: track, addedAt: addedAt);
    }).toList();

    return generateFromTracks(
      entries: entries,
      config: config,
      referenceTime: referenceTime,
    );
  }

  /// Reactive Stream watcher on SQLite database tracks table.
  /// Automatically fires a fresh playlist whenever any track or album is saved, liked, or removed.
  static Stream<RecentlyAddedSmartPlaylist> watchFromDatabase(
    AppDatabase db, {
    RecentlyAddedConfig config = const RecentlyAddedConfig(),
  }) {
    final query = db.select(db.tracks);

    if (config.filter == RecentlyAddedSourceFilter.songs) {
      query.where((t) => t.isLiked.equals(true));
    } else if (config.filter == RecentlyAddedSourceFilter.albums) {
      query.where((t) => t.album.isNotNull() & t.album.isBiggerThanValue(''));
    }

    if (config.sortOrder == RecentlyAddedSortOrder.newestFirst) {
      query.orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]);
    } else {
      query.orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]);
    }

    final fetchLimit = config.deduplicate ? config.maxTracks * 2 : config.maxTracks;
    query.limit(fetchLimit);

    return query.watch().map((rows) {
      final entries = rows.map((r) {
        final track = trackFromRow(r);
        final addedAt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
        return (track: track, addedAt: addedAt);
      }).toList();

      return generateFromTracks(
        entries: entries,
        config: config,
      );
    });
  }

  /// Fallback reactive Stream watcher using [ILibraryRepository] liked tracks.
  static Stream<RecentlyAddedSmartPlaylist> watchFromRepository(
    ILibraryRepository repo, {
    RecentlyAddedConfig config = const RecentlyAddedConfig(),
  }) {
    return repo.watchLikedTracks().map((tracks) {
      final now = DateTime.now();
      final entries = <({Track track, DateTime addedAt})>[];
      for (int i = 0; i < tracks.length; i++) {
        // Approximate chronological spacing if created timestamp is encapsulated
        entries.add((
          track: tracks[i],
          addedAt: now.subtract(Duration(minutes: i * 5)),
        ));
      }
      return generateFromTracks(
        entries: entries,
        config: config,
      );
    });
  }
}

// ============================================================================
// Riverpod State Notifiers & Providers
// ============================================================================

/// Notifier managing persistent configuration for the Recently Added smart playlist.
class RecentlyAddedConfigNotifier extends StateNotifier<RecentlyAddedConfig> {
  final RecentlyAddedPrefsStorage _storage;

  RecentlyAddedConfigNotifier([RecentlyAddedPrefsStorage? storage])
      : _storage = storage ?? RecentlyAddedSharedPreferencesStore(),
        super(const RecentlyAddedConfig()) {
    _loadPersistedConfig();
  }

  Future<void> _loadPersistedConfig() async {
    try {
      final maxTracks = await _storage.getInt(kRecentlyAddedPrefMaxTracks);
      final filterStr = await _storage.getString(kRecentlyAddedPrefFilter);
      final sortStr = await _storage.getString(kRecentlyAddedPrefSortOrder);
      final deduplicate = await _storage.getBool(kRecentlyAddedPrefDeduplicate);

      state = state.copyWith(
        maxTracks: maxTracks ?? kRecentlyAddedDefaultMax,
        filter: RecentlyAddedSourceFilter.fromString(filterStr),
        sortOrder: RecentlyAddedSortOrder.fromString(sortStr),
        deduplicate: deduplicate,
      );
    } catch (_) {}
  }

  Future<void> setMaxTracks(int count) async {
    final clamped = count.clamp(10, 500);
    state = state.copyWith(maxTracks: clamped);
    await _storage.setInt(kRecentlyAddedPrefMaxTracks, clamped);
  }

  Future<void> setFilter(RecentlyAddedSourceFilter filter) async {
    state = state.copyWith(filter: filter);
    await _storage.setString(kRecentlyAddedPrefFilter, filter.name);
  }

  Future<void> setSortOrder(RecentlyAddedSortOrder order) async {
    state = state.copyWith(sortOrder: order);
    await _storage.setString(kRecentlyAddedPrefSortOrder, order.name);
  }

  Future<void> setDeduplicate(bool deduplicate) async {
    state = state.copyWith(deduplicate: deduplicate);
    await _storage.setBool(kRecentlyAddedPrefDeduplicate, deduplicate);
  }
}

/// Provider for user-defined playlist configuration.
final recentlyAddedConfigProvider =
    StateNotifierProvider<RecentlyAddedConfigNotifier, RecentlyAddedConfig>((ref) {
  return RecentlyAddedConfigNotifier();
});

/// Manual refresh trigger tick.
final recentlyAddedRefreshTickProvider = StateProvider<int>((ref) => 0);

/// Stream provider delivering real-time, auto-refreshing updates to the
/// Recently Added (Top 100) playlist whenever songs or albums are saved.
final recentlyAddedPlaylistStreamProvider =
    StreamProvider<RecentlyAddedSmartPlaylist>((ref) {
  final config = ref.watch(recentlyAddedConfigProvider);
  ref.watch(recentlyAddedRefreshTickProvider);

  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}

  if (db != null) {
    return RecentlyAddedPlaylistEngine.watchFromDatabase(db, config: config);
  }

  // Graceful fallback to library repository
  ILibraryRepository? repo;
  try {
    repo = ref.watch(libraryRepositoryProvider);
  } catch (_) {}

  if (repo != null) {
    return RecentlyAddedPlaylistEngine.watchFromRepository(repo, config: config);
  }

  // Pure in-memory fallback stream
  return Stream.value(
    RecentlyAddedSmartPlaylist(
      generatedAt: DateTime.now(),
      items: const [],
      config: config,
    ),
  );
});

/// Convenience provider returning the active track list.
final recentlyAddedTracksProvider = Provider<List<Track>>((ref) {
  final playlistAsync = ref.watch(recentlyAddedPlaylistStreamProvider);
  return playlistAsync.maybeWhen(
    data: (playlist) => playlist.tracks,
    orElse: () => const [],
  );
});

/// Indicates whether the currently playing song belongs to the Recently Added playlist.
final isRecentlyAddedActiveProvider = Provider<bool>((ref) {
  final currentTrack = ref.watch(currentTrackProvider).value;
  if (currentTrack == null) return false;

  final tracks = ref.watch(recentlyAddedTracksProvider);
  return tracks.any((t) => t.id == currentTrack.id);
});

/// Indicates whether the Recently Added playlist is actively playing.
final isRecentlyAddedPlayingProvider = Provider<bool>((ref) {
  final isActive = ref.watch(isRecentlyAddedActiveProvider);
  final isPlaying = ref.watch(isPlayingProvider);
  return isActive && isPlaying;
});

/// Coordinating controller for 1-tap playback and queue management of Recently Added.
class RecentlyAddedPlayController extends ChangeNotifier {
  final Ref _ref;
  bool _isLoading = false;

  RecentlyAddedPlayController(this._ref);

  bool get isLoading => _isLoading;

  /// Starts or toggles play/pause for the Recently Added playlist.
  Future<void> playOrPause({int startIndex = 0}) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      SoftifyAudioHandler? handler;
      try {
        handler = _ref.read(audioHandlerProvider);
      } catch (_) {}

      if (handler == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final isPlaying = _ref.read(isPlayingProvider);
      final isActive = _ref.read(isRecentlyAddedActiveProvider);

      // If active and currently playing, pause
      if (isActive && isPlaying && startIndex == 0) {
        await handler.pause();
        return;
      }

      // If active and paused, resume
      if (isActive && !isPlaying && startIndex == 0) {
        await handler.play();
        return;
      }

      // Start fresh playback from Recently Added queue
      final tracks = _ref.read(recentlyAddedTracksProvider);
      if (tracks.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final safeIndex = startIndex.clamp(0, tracks.length - 1);
      final targetTrack = tracks[safeIndex];

      await handler.playTrack(
        targetTrack,
        queue: tracks,
        startIndex: safeIndex,
      );

      // Record play count metric in storage
      final storage = RecentlyAddedSharedPreferencesStore();
      final currentCount = await storage.getInt(kRecentlyAddedPrefPlayCount) ?? 0;
      await storage.setInt(kRecentlyAddedPrefPlayCount, currentCount + 1);
    } catch (_) {
      // Gracefully handle playback exceptions
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Shuffles the top 100 additions and starts immediate playback.
  Future<void> shufflePlay() async {
    final tracks = List<Track>.from(_ref.read(recentlyAddedTracksProvider));
    if (tracks.isEmpty) return;

    tracks.shuffle(math.Random());

    try {
      final handler = _ref.read(audioHandlerProvider);
      await handler.playTrack(
        tracks.first,
        queue: tracks,
        startIndex: 0,
      );
    } catch (_) {}
  }
}

/// Provider for the Recently Added playback controller.
final recentlyAddedPlayControllerProvider =
    ChangeNotifierProvider<RecentlyAddedPlayController>((ref) {
  return RecentlyAddedPlayController(ref);
});

// ============================================================================
// Material 3 UI Widgets
// ============================================================================

/// Signature visual tile representing the "Recently Added (Top 100)" smart playlist.
///
/// Conforms to Requirement 3:
/// "RecentlyAddedPlaylistTile widget with thumbnail and play button."
class RecentlyAddedPlaylistTile extends ConsumerWidget {
  /// Callback triggered when the tile body is tapped.
  final VoidCallback? onTap;

  /// Callback triggered when the play/pause button is tapped.
  final VoidCallback? onPlayTap;

  /// Outer margin around the tile.
  final EdgeInsetsGeometry? margin;

  /// Inner padding inside the tile.
  final EdgeInsetsGeometry? padding;

  /// Whether to render in compact format.
  final bool isDense;

  /// Whether to display the artwork collage thumbnail.
  final bool showThumbnail;

  /// Whether to display the trailing play button.
  final bool showPlayButton;

  /// Whether to display the track count & duration subtitle.
  final bool showTrackCount;

  /// Optional trailing widget overriding the standard play button.
  final Widget? trailing;

  /// Optional custom title overriding "Recently Added".
  final String? customTitle;

  /// Optional custom subtitle overriding track count and duration.
  final String? customSubtitle;

  const RecentlyAddedPlaylistTile({
    super.key,
    this.onTap,
    this.onPlayTap,
    this.margin,
    this.padding,
    this.isDense = false,
    this.showThumbnail = true,
    this.showPlayButton = true,
    this.showTrackCount = true,
    this.trailing,
    this.customTitle,
    this.customSubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final playlistAsync = ref.watch(recentlyAddedPlaylistStreamProvider);
    final isPlaying = ref.watch(isRecentlyAddedPlayingProvider);
    final playCtrl = ref.watch(recentlyAddedPlayControllerProvider);

    return playlistAsync.when(
      loading: () => _buildLoadingTile(tokens),
      error: (_, __) => _buildErrorTile(context, ref, tokens),
      data: (playlist) {
        return _buildContentTile(
          context: context,
          ref: ref,
          tokens: tokens,
          playlist: playlist,
          isPlaying: isPlaying,
          isLoadingPlay: playCtrl.isLoading,
        );
      },
    );
  }

  Widget _buildLoadingTile(AppTokens tokens) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: isDense ? 44 : 52,
            height: isDense ? 44 : 52,
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Icon(Icons.history_rounded, color: tokens.textMuted, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customTitle ?? 'Recently Added',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: isDense ? 14 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Loading recent library additions...',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorTile(BuildContext context, WidgetRef ref, AppTokens tokens) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: tokens.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load Recently Added additions',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: tokens.accent,
            onPressed: () {
              ref.read(recentlyAddedRefreshTickProvider.notifier).state++;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContentTile({
    required BuildContext context,
    required WidgetRef ref,
    required AppTokens tokens,
    required RecentlyAddedSmartPlaylist playlist,
    required bool isPlaying,
    required bool isLoadingPlay,
  }) {
    final titleText = customTitle ?? playlist.title;
    final subtitleText = customSubtitle ??
        (showTrackCount
            ? '${playlist.length} songs • ${playlist.formattedTotalDuration}'
            : 'Top 100 • Library additions');

    final effectiveBorder = isPlaying
        ? Border.all(color: tokens.accent.withValues(alpha: 0.6), width: 1.5)
        : Border.all(color: tokens.divider.withValues(alpha: 0.12), width: 1.0);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: effectiveBorder,
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          onTap: onTap ?? () => RecentlyAddedPlaylistSheet.show(context),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(12),
            child: Row(
              children: [
                // 1. Thumbnail collage or fallback
                if (showThumbnail) ...[
                  RecentlyAddedThumbnail(
                    covers: playlist.previewCovers,
                    size: isDense ? 44 : 54,
                    isPlaying: isPlaying,
                  ),
                  const SizedBox(width: 14),
                ],

                // 2. Title, Subtitle, and Playing Wave
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPlaying ? tokens.accent : tokens.textPrimary,
                                fontSize: isDense ? 14 : 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isPlaying) ...[
                            const SizedBox(width: 8),
                            AnimatedMusicWaveIndicator(
                              isPlaying: true,
                              color: tokens.accent,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: isDense ? 11.5 : 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Play Button / Trailing Action
                if (trailing != null)
                  trailing!
                else if (showPlayButton)
                  _buildPlayButton(
                    tokens: tokens,
                    isPlaying: isPlaying,
                    isLoading: isLoadingPlay,
                    isEmpty: playlist.isEmpty,
                    onTap: onPlayTap ??
                        () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(recentlyAddedPlayControllerProvider)
                              .playOrPause();
                        },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton({
    required AppTokens tokens,
    required bool isPlaying,
    required bool isLoading,
    required bool isEmpty,
    required VoidCallback onTap,
  }) {
    if (isLoading) {
      return SizedBox(
        width: isDense ? 36 : 40,
        height: isDense ? 36 : 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.accent,
            ),
          ),
        ),
      );
    }

    return BouncingScaleButton(
      onTap: isEmpty ? null : onTap,
      scaleDown: 0.90,
      child: Tooltip(
        message: isPlaying ? 'Pause Recently Added' : 'Play Recently Added',
        child: Container(
          width: isDense ? 36 : 42,
          height: isDense ? 36 : 42,
          decoration: BoxDecoration(
            color: isPlaying ? tokens.accent : tokens.surfaceHighlight,
            shape: BoxShape.circle,
            boxShadow: isPlaying
                ? [
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: isPlaying ? Colors.white : tokens.textPrimary,
            size: isDense ? 20 : 24,
          ),
        ),
      ),
    );
  }
}

/// Standalone visual thumbnail widget displaying up to a 2x2 collage
/// of recent album covers or an elegant gradient fallback.
class RecentlyAddedThumbnail extends StatelessWidget {
  final List<String> covers;
  final double size;
  final bool isPlaying;

  const RecentlyAddedThumbnail({
    super.key,
    required this.covers,
    this.size = 52,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final borderRadius = BorderRadius.circular(tokens.radiusSm);

    if (covers.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEC4899), // Pink
              Color(0xFF8B5CF6), // Purple
            ],
          ),
        ),
        child: const Icon(
          Icons.history_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    if (covers.length == 1) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: size,
          height: size,
          child: AppNetworkImage(
            imageUrl: covers.first,
            width: size,
            height: size,
            fit: BoxFit.cover,
            fallbackIcon: Icons.music_note_rounded,
          ),
        ),
      );
    }

    // 2 to 4 covers: 2x2 collage
    final half = size / 2;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Row(
              children: [
                _buildCell(covers[0], half),
                _buildCell(covers[1], half),
              ],
            ),
            Row(
              children: [
                _buildCell(covers.length > 2 ? covers[2] : covers[0], half),
                _buildCell(covers.length > 3 ? covers[3] : covers[1], half),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String url, double cellSize) {
    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: AppNetworkImage(
        imageUrl: url,
        width: cellSize,
        height: cellSize,
        fit: BoxFit.cover,
        fallbackIcon: Icons.music_note_rounded,
      ),
    );
  }
}

/// An individual track item row inside the Recently Added list view.
class RecentlyAddedTrackTile extends StatelessWidget {
  final RecentlyAddedTrackItem item;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;

  const RecentlyAddedTrackTile({
    super.key,
    required this.item,
    this.isPlaying = false,
    this.onTap,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final track = item.track;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? onPlayTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Chronological index badge or playing wave
              SizedBox(
                width: 28,
                child: isPlaying
                    ? AnimatedMusicWaveIndicator(
                        isPlaying: true,
                        color: tokens.accent,
                        size: 14,
                      )
                    : Text(
                        '${item.orderIndex}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(width: 8),

              // Artwork thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: AppNetworkImage(
                    imageUrl: track.coverUrl,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title, Artist, & Relative addition time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying ? tokens.accent : tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          ' • ${item.formattedRelativeTime}',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Play / pause action button
              BouncingScaleButton(
                onTap: onPlayTap ?? onTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tokens.surfaceHighlight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: isPlaying ? tokens.accent : tokens.textPrimary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comprehensive modal bottom sheet displaying the full 100 tracks of Recently Added,
/// with instant filter chips, search filtering, and header statistics.
class RecentlyAddedPlaylistSheet extends ConsumerStatefulWidget {
  const RecentlyAddedPlaylistSheet({super.key});

  /// Displays the modal bottom sheet above the current navigation stack.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RecentlyAddedPlaylistSheet(),
    );
  }

  @override
  ConsumerState<RecentlyAddedPlaylistSheet> createState() =>
      _RecentlyAddedPlaylistSheetState();
}

class _RecentlyAddedPlaylistSheetState
    extends ConsumerState<RecentlyAddedPlaylistSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final playlistAsync = ref.watch(recentlyAddedPlaylistStreamProvider);
    final config = ref.watch(recentlyAddedConfigProvider);
    final isPlaying = ref.watch(isRecentlyAddedPlayingProvider);
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playCtrl = ref.watch(recentlyAddedPlayControllerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: tokens.divider.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: tokens.divider.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          playlistAsync.maybeWhen(
            data: (playlist) => _buildHeader(
              tokens: tokens,
              playlist: playlist,
              isPlaying: isPlaying,
              isLoadingPlay: playCtrl.isLoading,
            ),
            orElse: () => const SizedBox.shrink(),
          ),

          // Filter bar & Search
          _buildFilterAndSearchBar(tokens, config),

          const Divider(height: 1),

          // Content list
          Expanded(
            child: playlistAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: tokens.accent),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Failed to load recent additions',
                  style: TextStyle(color: tokens.error),
                ),
              ),
              data: (playlist) {
                var filtered = playlist.items;
                if (_searchQuery.trim().isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered.where((item) {
                    final t = item.track.title.toLowerCase();
                    final a = item.track.artist.toLowerCase();
                    final alb = (item.track.album ?? '').toLowerCase();
                    return t.contains(q) || a.contains(q) || alb.contains(q);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_music_rounded, size: 48, color: tokens.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching tracks found'
                              : 'No tracks in library yet',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.only(bottom: 24, top: 4),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isCurrentPlaying =
                        currentTrack?.id == item.track.id && isPlaying;
                    return RecentlyAddedTrackTile(
                      item: item,
                      isPlaying: isCurrentPlaying,
                      onPlayTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(recentlyAddedPlayControllerProvider)
                            .playOrPause(startIndex: index);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required AppTokens tokens,
    required RecentlyAddedSmartPlaylist playlist,
    required bool isPlaying,
    required bool isLoadingPlay,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          RecentlyAddedThumbnail(
            covers: playlist.previewCovers,
            size: 64,
            isPlaying: isPlaying,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playlist.title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${playlist.length} tracks • ${playlist.formattedTotalDuration}',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Shuffle button
          BouncingScaleButton(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(recentlyAddedPlayControllerProvider).shufflePlay();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.surfaceHighlight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shuffle_rounded, color: tokens.textPrimary, size: 20),
            ),
          ),

          const SizedBox(width: 8),

          // Main Play / Pause button
          BouncingScaleButton(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(recentlyAddedPlayControllerProvider).playOrPause();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tokens.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tokens.accent.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar(AppTokens tokens, RecentlyAddedConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: RecentlyAddedSourceFilter.values.map((filter) {
                final isSelected = config.filter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(recentlyAddedConfigProvider.notifier)
                          .setFilter(filter);
                    },
                    avatar: Icon(
                      filter.icon,
                      size: 16,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                    ),
                    backgroundColor: tokens.card,
                    selectedColor: tokens.accent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? tokens.accent
                          : tokens.divider.withValues(alpha: 0.15),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(color: tokens.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search recent additions...',
                hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: tokens.textMuted, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        color: tokens.textMuted,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
