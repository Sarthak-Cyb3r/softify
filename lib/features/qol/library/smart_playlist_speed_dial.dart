// ============================================================================
// Softify Quality of Life (QoL) - Feature 22: Smart Playlist: Speed Dial Mix
// ============================================================================
//
// Fast dynamic generator creating a custom 25-track mix across the user's top
// 3 genres with instant 1-tap playback from Home or Library screens.
//
// Features:
// - SpeedDialMixGenerator: High-performance pure Dart algorithmic generator
//   balanced across user's top 3 genres (~9 + 8 + 8 = 25 tracks).
// - Dynamic genre affinity scoring from taste profiles, tagged tracks, and history.
// - Interleaved round-robin sequencing for diverse sonic flow and pacing.
// - Curated high-fidelity genre catalogs providing seamless offline/zero-config fallback.
// - SpeedDialMixCard: Production-grade Material 3 hero card with 1-tap playback.
// - SpeedDialMixSheet: Detailed modal sheet with genre breakdown bar and track list.
// - Self-contained SharedPreferences persistence with mock harness for testing.
// - Riverpod state management via speedDialMixProvider.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/taste_profile.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/ports/i_library_repository.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Configuration Constants
// ============================================================================

/// Target track count for the Speed Dial Mix (standard 25 tracks).
const int kSpeedDialMixTargetCount = 25;

/// Default top genres used when user taste profile has insufficient history.
const List<String> kDefaultTopGenres = ['Pop', 'Rock', 'Electronic'];

/// Storage keys for Speed Dial persistence.
const String kSpeedDialPrefLastGeneratedTs = 'softify_speed_dial_last_gen_ts';
const String kSpeedDialPrefCachedTrackIds = 'softify_speed_dial_cached_ids';
const String kSpeedDialPrefTopGenres = 'softify_speed_dial_top_genres';
const String kSpeedDialPrefPinnedGenres = 'softify_speed_dial_pinned_genres';
const String kSpeedDialPrefPlayCount = 'softify_speed_dial_play_count';

// ============================================================================
// Data Model: SpeedDialMix
// ============================================================================

/// Represents a generated 25-track smart mix balanced across top 3 genres.
@immutable
class SpeedDialMix {
  /// Unique identifier for this generated mix instance.
  final String id;

  /// Display title of the mix (e.g. "Speed Dial Mix").
  final String title;

  /// Ordered list of top 3 genres used to generate this mix.
  final List<String> topGenres;

  /// Exactly 25 tracks included in this mix, interleaved across genres.
  final List<Track> tracks;

  /// Map of genre name to the count of tracks allocated in this mix.
  final Map<String, int> genreCounts;

  /// Map of track ID to its resolved genre tag.
  final Map<String, String> trackGenreMap;

  /// Timestamp when the mix was dynamically generated.
  final DateTime createdAt;

  const SpeedDialMix({
    required this.id,
    this.title = 'Speed Dial Mix',
    required this.topGenres,
    required this.tracks,
    required this.genreCounts,
    required this.trackGenreMap,
    required this.createdAt,
  });

  /// Total number of tracks in this mix.
  int get length => tracks.length;

  /// Whether the mix contains no tracks.
  bool get isEmpty => tracks.isEmpty;

  /// Whether the mix contains one or more tracks.
  bool get isNotEmpty => tracks.isNotEmpty;

  /// Total combined playback duration of all tracks in the mix.
  Duration get totalDuration {
    return tracks.fold<Duration>(
      Duration.zero,
      (total, track) => total + track.duration,
    );
  }

  /// Formatted duration string (e.g. "1 hr 32 min" or "48 min").
  String get formattedTotalDuration {
    final minutes = totalDuration.inMinutes;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '$hours hr $remainingMinutes min' : '$hours hr';
  }

  /// Formatted subtitle describing the genre distribution and track count.
  String get formattedSubtitle {
    if (topGenres.isEmpty) return '$length Tracks';
    final genreStr = topGenres.join(', ');
    return '$length Tracks • $genreStr';
  }

  /// Checks if a track with [trackId] is in this mix.
  bool containsTrack(String trackId) {
    return tracks.any((t) => t.id == trackId);
  }

  /// Resolves the genre tag for a specific track ID.
  String? getGenreForTrack(String trackId) => trackGenreMap[trackId];

  SpeedDialMix copyWith({
    String? id,
    String? title,
    List<String>? topGenres,
    List<Track>? tracks,
    Map<String, int>? genreCounts,
    Map<String, String>? trackGenreMap,
    DateTime? createdAt,
  }) {
    return SpeedDialMix(
      id: id ?? this.id,
      title: title ?? this.title,
      topGenres: topGenres ?? this.topGenres,
      tracks: tracks ?? this.tracks,
      genreCounts: genreCounts ?? this.genreCounts,
      trackGenreMap: trackGenreMap ?? this.trackGenreMap,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'top_genres': topGenres,
      'track_ids': tracks.map((t) => t.id).toList(),
      'genre_counts': genreCounts,
      'track_genre_map': trackGenreMap,
      'created_at_ms': createdAt.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeedDialMix &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tracks.length == other.tracks.length;

  @override
  int get hashCode => Object.hash(id, tracks.length, createdAt);

  @override
  String toString() =>
      'SpeedDialMix(id: $id, genres: $topGenres, tracks: ${tracks.length})';
}

// ============================================================================
// State: SpeedDialMixState
// ============================================================================

/// Reactive UI state for the Speed Dial Mix feature.
@immutable
class SpeedDialMixState {
  /// The active speed dial mix, or null if not yet loaded.
  final SpeedDialMix? mix;

  /// Whether a mix is currently being dynamically generated.
  final bool isLoading;

  /// Whether the Speed Dial Mix is currently playing in the active audio handler.
  final bool isPlaying;

  /// Index of currently playing track within the mix (if playing).
  final int activeTrackIndex;

  /// Total number of times a Speed Dial mix has been launched.
  final int playCount;

  /// Optional error message if generation failed.
  final String? errorMessage;

  /// User-pinned custom top genres (overrides automatic detection if set).
  final List<String>? pinnedGenres;

  const SpeedDialMixState({
    this.mix,
    this.isLoading = false,
    this.isPlaying = false,
    this.activeTrackIndex = 0,
    this.playCount = 0,
    this.errorMessage,
    this.pinnedGenres,
  });

  SpeedDialMixState copyWith({
    SpeedDialMix? mix,
    bool? isLoading,
    bool? isPlaying,
    int? activeTrackIndex,
    int? playCount,
    String? errorMessage,
    List<String>? pinnedGenres,
    bool clearError = false,
  }) {
    return SpeedDialMixState(
      mix: mix ?? this.mix,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      activeTrackIndex: activeTrackIndex ?? this.activeTrackIndex,
      playCount: playCount ?? this.playCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pinnedGenres: pinnedGenres ?? this.pinnedGenres,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeedDialMixState &&
          runtimeType == other.runtimeType &&
          mix == other.mix &&
          isLoading == other.isLoading &&
          isPlaying == other.isPlaying &&
          activeTrackIndex == other.activeTrackIndex &&
          playCount == other.playCount &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        mix,
        isLoading,
        isPlaying,
        activeTrackIndex,
        playCount,
        errorMessage,
      );
}

// ============================================================================
// SharedPreferences Persistence Engine (Self-Contained)
// ============================================================================

/// Contract for persistent storage compatible with SharedPreferences semantics.
abstract class SpeedDialPrefsStorage {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<List<String>?> getStringList(String key);
  Future<bool> setStringList(String key, List<String> value);
  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);
  Future<bool> remove(String key);
  Future<bool> clear();
}

/// Durable disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class SpeedDialMixSharedPreferences implements SpeedDialPrefsStorage {
  static final SpeedDialMixSharedPreferences _instance =
      SpeedDialMixSharedPreferences._internal();
  factory SpeedDialMixSharedPreferences() => _instance;
  SpeedDialMixSharedPreferences._internal();

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
        _cacheFile = File('${dir.path}/speed_dial_preferences.json');
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

  Future<void> _flushToDisk() async {
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
    await _flushToDisk();
    return true;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    await _ensureLoaded();
    final val = _memoryCache[key];
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    await _flushToDisk();
    return true;
  }

  @override
  Future<int?> getInt(String key) async {
    await _ensureLoaded();
    final val = _memoryCache[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    return null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    await _flushToDisk();
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    await _ensureLoaded();
    _memoryCache.remove(key);
    await _flushToDisk();
    return true;
  }

  @override
  Future<bool> clear() async {
    await _ensureLoaded();
    _memoryCache.clear();
    await _flushToDisk();
    return true;
  }
}

// ============================================================================
// Fallback Curated Catalogs (Zero-Config / Cold Startup Guarantee)
// ============================================================================

/// Curated high-fidelity fallback catalogue categorized by genres.
/// Ensures the Speed Dial generator always creates a vibrant 25-track mix even
/// on fresh installs or when local/remote track libraries are empty.
class SpeedDialGenreCatalogs {
  SpeedDialGenreCatalogs._();

  static const List<Track> popTracks = [
    Track(
      id: 'sd_pop_01',
      sourceId: 'sd_src_pop_01',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      duration: Duration(seconds: 200),
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
    ),
    Track(
      id: 'sd_pop_02',
      sourceId: 'sd_src_pop_02',
      title: 'Levitating',
      artist: 'Dua Lipa',
      album: 'Future Nostalgia',
      duration: Duration(seconds: 203),
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
    ),
    Track(
      id: 'sd_pop_03',
      sourceId: 'sd_src_pop_03',
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      album: '÷ (Divide)',
      duration: Duration(seconds: 233),
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
    ),
    Track(
      id: 'sd_pop_04',
      sourceId: 'sd_src_pop_04',
      title: 'As It Was',
      artist: 'Harry Styles',
      album: "Harry's House",
      duration: Duration(seconds: 167),
      coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=300',
    ),
    Track(
      id: 'sd_pop_05',
      sourceId: 'sd_src_pop_05',
      title: 'Bad Guy',
      artist: 'Billie Eilish',
      album: 'WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?',
      duration: Duration(seconds: 194),
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
    ),
    Track(
      id: 'sd_pop_06',
      sourceId: 'sd_src_pop_06',
      title: 'Stay',
      artist: 'The Kid LAROI & Justin Bieber',
      album: 'F*CK LOVE 3: OVER YOU',
      duration: Duration(seconds: 141),
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300',
    ),
    Track(
      id: 'sd_pop_07',
      sourceId: 'sd_src_pop_07',
      title: 'Flowers',
      artist: 'Miley Cyrus',
      album: 'Endless Summer Vacation',
      duration: Duration(seconds: 200),
      coverUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=300',
    ),
    Track(
      id: 'sd_pop_08',
      sourceId: 'sd_src_pop_08',
      title: 'Cruel Summer',
      artist: 'Taylor Swift',
      album: 'Lover',
      duration: Duration(seconds: 178),
      coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
    ),
    Track(
      id: 'sd_pop_09',
      sourceId: 'sd_src_pop_09',
      title: 'Watermelon Sugar',
      artist: 'Harry Styles',
      album: 'Fine Line',
      duration: Duration(seconds: 174),
      coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300',
    ),
    Track(
      id: 'sd_pop_10',
      sourceId: 'sd_src_pop_10',
      title: 'Starboy',
      artist: 'The Weeknd ft. Daft Punk',
      album: 'Starboy',
      duration: Duration(seconds: 230),
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300',
    ),
  ];

  static const List<Track> rockTracks = [
    Track(
      id: 'sd_rock_01',
      sourceId: 'sd_src_rock_01',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      duration: Duration(seconds: 354),
      coverUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=300',
    ),
    Track(
      id: 'sd_rock_02',
      sourceId: 'sd_src_rock_02',
      title: 'Do I Wanna Know?',
      artist: 'Arctic Monkeys',
      album: 'AM',
      duration: Duration(seconds: 272),
      coverUrl: 'https://images.unsplash.com/photo-1445985543469-433ecba6244f?w=300',
    ),
    Track(
      id: 'sd_rock_03',
      sourceId: 'sd_src_rock_03',
      title: 'Smells Like Teen Spirit',
      artist: 'Nirvana',
      album: 'Nevermind',
      duration: Duration(seconds: 301),
      coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300',
    ),
    Track(
      id: 'sd_rock_04',
      sourceId: 'sd_src_rock_04',
      title: 'In the End',
      artist: 'Linkin Park',
      album: 'Hybrid Theory',
      duration: Duration(seconds: 216),
      coverUrl: 'https://images.unsplash.com/photo-1464375117522-1311d6a5b81f?w=300',
    ),
    Track(
      id: 'sd_rock_05',
      sourceId: 'sd_src_rock_05',
      title: 'Everlong',
      artist: 'Foo Fighters',
      album: 'The Colour and the Shape',
      duration: Duration(seconds: 250),
      coverUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=300',
    ),
    Track(
      id: 'sd_rock_06',
      sourceId: 'sd_src_rock_06',
      title: 'Seven Nation Army',
      artist: 'The White Stripes',
      album: 'Elephant',
      duration: Duration(seconds: 231),
      coverUrl: 'https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?w=300',
    ),
    Track(
      id: 'sd_rock_07',
      sourceId: 'sd_src_rock_07',
      title: 'Californication',
      artist: 'Red Hot Chili Peppers',
      album: 'Californication',
      duration: Duration(seconds: 329),
      coverUrl: 'https://images.unsplash.com/photo-1520523839898-507127054976?w=300',
    ),
    Track(
      id: 'sd_rock_08',
      sourceId: 'sd_src_rock_08',
      title: "Sweet Child O' Mine",
      artist: "Guns N' Roses",
      album: 'Appetite for Destruction',
      duration: Duration(seconds: 356),
      coverUrl: 'https://images.unsplash.com/photo-1511735111819-9a3f7709049c?w=300',
    ),
    Track(
      id: 'sd_rock_09',
      sourceId: 'sd_src_rock_09',
      title: 'Back In Black',
      artist: 'AC/DC',
      album: 'Back In Black',
      duration: Duration(seconds: 255),
      coverUrl: 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=300',
    ),
    Track(
      id: 'sd_rock_10',
      sourceId: 'sd_src_rock_10',
      title: 'Come As You Are',
      artist: 'Nirvana',
      album: 'Nevermind',
      duration: Duration(seconds: 219),
      coverUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=300',
    ),
  ];

  static const List<Track> electronicTracks = [
    Track(
      id: 'sd_elec_01',
      sourceId: 'sd_src_elec_01',
      title: 'One More Time',
      artist: 'Daft Punk',
      album: 'Discovery',
      duration: Duration(seconds: 320),
      coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300',
    ),
    Track(
      id: 'sd_elec_02',
      sourceId: 'sd_src_elec_02',
      title: 'Wake Me Up',
      artist: 'Avicii',
      album: 'True',
      duration: Duration(seconds: 247),
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
    ),
    Track(
      id: 'sd_elec_03',
      sourceId: 'sd_src_elec_03',
      title: 'Closer',
      artist: 'The Chainsmokers ft. Halsey',
      album: 'Collage',
      duration: Duration(seconds: 244),
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
    ),
    Track(
      id: 'sd_elec_04',
      sourceId: 'sd_src_elec_04',
      title: 'Titanium',
      artist: 'David Guetta ft. Sia',
      album: 'Nothing but the Beat',
      duration: Duration(seconds: 245),
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300',
    ),
    Track(
      id: 'sd_elec_05',
      sourceId: 'sd_src_elec_05',
      title: 'Get Lucky',
      artist: 'Daft Punk ft. Pharrell Williams',
      album: 'Random Access Memories',
      duration: Duration(seconds: 248),
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
    ),
    Track(
      id: 'sd_elec_06',
      sourceId: 'sd_src_elec_06',
      title: 'Faded',
      artist: 'Alan Walker',
      album: 'Different World',
      duration: Duration(seconds: 212),
      coverUrl: 'https://images.unsplash.com/photo-1464375117522-1311d6a5b81f?w=300',
    ),
    Track(
      id: 'sd_elec_07',
      sourceId: 'sd_src_elec_07',
      title: 'Levels',
      artist: 'Avicii',
      album: 'Levels EP',
      duration: Duration(seconds: 198),
      coverUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=300',
    ),
    Track(
      id: 'sd_elec_08',
      sourceId: 'sd_src_elec_08',
      title: 'Strobe',
      artist: 'deadmau5',
      album: 'For Lack of a Better Name',
      duration: Duration(seconds: 334),
      coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300',
    ),
    Track(
      id: 'sd_elec_09',
      sourceId: 'sd_src_elec_09',
      title: 'Midnight City',
      artist: 'M83',
      album: 'Hurry Up, We\'re Dreaming',
      duration: Duration(seconds: 243),
      coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
    ),
    Track(
      id: 'sd_elec_10',
      sourceId: 'sd_src_elec_10',
      title: 'Scary Monsters and Nice Sprites',
      artist: 'Skrillex',
      album: 'Scary Monsters and Nice Sprites',
      duration: Duration(seconds: 243),
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300',
    ),
  ];

  static const List<Track> hipHopTracks = [
    Track(
      id: 'sd_hip_01',
      sourceId: 'sd_src_hip_01',
      title: 'HUMBLE.',
      artist: 'Kendrick Lamar',
      album: 'DAMN.',
      duration: Duration(seconds: 177),
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
    ),
    Track(
      id: 'sd_hip_02',
      sourceId: 'sd_src_hip_02',
      title: "God's Plan",
      artist: 'Drake',
      album: 'Scorpion',
      duration: Duration(seconds: 198),
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
    ),
    Track(
      id: 'sd_hip_03',
      sourceId: 'sd_src_hip_03',
      title: 'Lose Yourself',
      artist: 'Eminem',
      album: '8 Mile Soundtrack',
      duration: Duration(seconds: 326),
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
    ),
    Track(
      id: 'sd_hip_04',
      sourceId: 'sd_src_hip_04',
      title: 'SICKO MODE',
      artist: 'Travis Scott',
      album: 'ASTROWORLD',
      duration: Duration(seconds: 312),
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
    ),
    Track(
      id: 'sd_hip_05',
      sourceId: 'sd_src_hip_05',
      title: 'Sunflower',
      artist: 'Post Malone & Swae Lee',
      album: 'Spider-Man: Into the Spider-Verse',
      duration: Duration(seconds: 158),
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300',
    ),
    Track(
      id: 'sd_hip_06',
      sourceId: 'sd_src_hip_06',
      title: 'Stronger',
      artist: 'Kanye West',
      album: 'Graduation',
      duration: Duration(seconds: 311),
      coverUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=300',
    ),
    Track(
      id: 'sd_hip_07',
      sourceId: 'sd_src_hip_07',
      title: 'No Role Modelz',
      artist: 'J. Cole',
      album: '2014 Forest Hills Drive',
      duration: Duration(seconds: 292),
      coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
    ),
    Track(
      id: 'sd_hip_08',
      sourceId: 'sd_src_hip_08',
      title: 'Lucid Dreams',
      artist: 'Juice WRLD',
      album: 'Goodbye & Good Riddance',
      duration: Duration(seconds: 239),
      coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300',
    ),
    Track(
      id: 'sd_hip_09',
      sourceId: 'sd_src_hip_09',
      title: 'Rockstar',
      artist: 'Post Malone ft. 21 Savage',
      album: 'beerbongs & bentleys',
      duration: Duration(seconds: 218),
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300',
    ),
    Track(
      id: 'sd_hip_10',
      sourceId: 'sd_src_hip_10',
      title: 'All of the Lights',
      artist: 'Kanye West ft. Rihanna',
      album: 'My Beautiful Dark Twisted Fantasy',
      duration: Duration(seconds: 299),
      coverUrl: 'https://images.unsplash.com/photo-1445985543469-433ecba6244f?w=300',
    ),
  ];

  static const List<Track> indieTracks = [
    Track(
      id: 'sd_indie_01',
      sourceId: 'sd_src_indie_01',
      title: 'Motion Sickness',
      artist: 'Phoebe Bridgers',
      album: 'Stranger in the Alps',
      duration: Duration(seconds: 231),
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
    ),
    Track(
      id: 'sd_indie_02',
      sourceId: 'sd_src_indie_02',
      title: 'The Less I Know The Better',
      artist: 'Tame Impala',
      album: 'Currents',
      duration: Duration(seconds: 216),
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
    ),
    Track(
      id: 'sd_indie_03',
      sourceId: 'sd_src_indie_03',
      title: 'Chamber of Reflection',
      artist: 'Mac DeMarco',
      album: 'Salad Days',
      duration: Duration(seconds: 231),
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
    ),
    Track(
      id: 'sd_indie_04',
      sourceId: 'sd_src_indie_04',
      title: 'Sofia',
      artist: 'Clairo',
      album: 'Immunity',
      duration: Duration(seconds: 188),
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
    ),
    Track(
      id: 'sd_indie_05',
      sourceId: 'sd_src_indie_05',
      title: 'Not Strong Enough',
      artist: 'boygenius',
      album: 'the record',
      duration: Duration(seconds: 234),
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300',
    ),
    Track(
      id: 'sd_indie_06',
      sourceId: 'sd_src_indie_06',
      title: 'Are You Bored Yet?',
      artist: 'Wallows ft. Clairo',
      album: 'Nothing Happens',
      duration: Duration(seconds: 178),
      coverUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=300',
    ),
    Track(
      id: 'sd_indie_07',
      sourceId: 'sd_src_indie_07',
      title: 'Ribs',
      artist: 'Lorde',
      album: 'Pure Heroine',
      duration: Duration(seconds: 258),
      coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
    ),
    Track(
      id: 'sd_indie_08',
      sourceId: 'sd_src_indie_08',
      title: 'Sweater Weather',
      artist: 'The Neighbourhood',
      album: 'I Love You.',
      duration: Duration(seconds: 240),
      coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300',
    ),
    Track(
      id: 'sd_indie_09',
      sourceId: 'sd_src_indie_09',
      title: 'Breezeblocks',
      artist: 'alt-J',
      album: 'An Awesome Wave',
      duration: Duration(seconds: 227),
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300',
    ),
    Track(
      id: 'sd_indie_10',
      sourceId: 'sd_src_indie_10',
      title: 'Take a Slice',
      artist: 'Glass Animals',
      album: 'How to Be a Human Being',
      duration: Duration(seconds: 229),
      coverUrl: 'https://images.unsplash.com/photo-1445985543469-433ecba6244f?w=300',
    ),
  ];

  static const List<Track> lofiTracks = [
    Track(
      id: 'sd_lofi_01',
      sourceId: 'sd_src_lofi_01',
      title: 'Snowman',
      artist: 'WYS',
      album: '1 AM Study Session',
      duration: Duration(seconds: 194),
      coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300',
    ),
    Track(
      id: 'sd_lofi_02',
      sourceId: 'sd_src_lofi_02',
      title: 'Affection',
      artist: 'Jinsang',
      album: 'Life',
      duration: Duration(seconds: 142),
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
    ),
    Track(
      id: 'sd_lofi_03',
      sourceId: 'sd_src_lofi_03',
      title: 'Again',
      artist: 'Wun Two',
      album: 'Penthouse',
      duration: Duration(seconds: 135),
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
    ),
    Track(
      id: 'sd_lofi_04',
      sourceId: 'sd_src_lofi_04',
      title: 'Controlla',
      artist: 'Idealism',
      album: 'Rainy Evening',
      duration: Duration(seconds: 168),
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
    ),
    Track(
      id: 'sd_lofi_05',
      sourceId: 'sd_src_lofi_05',
      title: '5:32 PM',
      artist: 'The Deli',
      album: 'Vibes 2',
      duration: Duration(seconds: 122),
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
    ),
    Track(
      id: 'sd_lofi_06',
      sourceId: 'sd_src_lofi_06',
      title: 'Warm Breeze',
      artist: 'HM Surf',
      album: 'Summer Nights',
      duration: Duration(seconds: 154),
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300',
    ),
    Track(
      id: 'sd_lofi_07',
      sourceId: 'sd_src_lofi_07',
      title: 'Coffee',
      artist: 'Beowülf',
      album: 'Morning Routine',
      duration: Duration(seconds: 147),
      coverUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=300',
    ),
    Track(
      id: 'sd_lofi_08',
      sourceId: 'sd_src_lofi_08',
      title: 'Daydreaming',
      artist: 'Kupla',
      album: 'Kingdom in Blue',
      duration: Duration(seconds: 180),
      coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300',
    ),
    Track(
      id: 'sd_lofi_09',
      sourceId: 'sd_src_lofi_09',
      title: 'Lost in Thoughts',
      artist: 'Elijah Who',
      album: 'Gentle Breezes',
      duration: Duration(seconds: 139),
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300',
    ),
    Track(
      id: 'sd_lofi_10',
      sourceId: 'sd_src_lofi_10',
      title: 'French Inhale',
      artist: '[bsd.u]',
      album: 'Late Night Tapes',
      duration: Duration(seconds: 140),
      coverUrl: 'https://images.unsplash.com/photo-1445985543469-433ecba6244f?w=300',
    ),
  ];

  /// Resolves fallback tracks for a specific genre label.
  static List<Track> getTracksForGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    if (normalized.contains('rock') || normalized.contains('metal')) {
      return rockTracks;
    } else if (normalized.contains('elec') ||
        normalized.contains('dance') ||
        normalized.contains('edm') ||
        normalized.contains('house')) {
      return electronicTracks;
    } else if (normalized.contains('hip') ||
        normalized.contains('rap') ||
        normalized.contains('trap')) {
      return hipHopTracks;
    } else if (normalized.contains('indie') || normalized.contains('alt')) {
      return indieTracks;
    } else if (normalized.contains('lofi') ||
        normalized.contains('lo-fi') ||
        normalized.contains('chill')) {
      return lofiTracks;
    }
    // Default fallback to Pop
    return popTracks;
  }
}

// ============================================================================
// Algorithmic Generator: SpeedDialMixGenerator (Pure Dart Logic)
// ============================================================================

/// Pure Dart dynamic algorithmic generator for the Speed Dial Mix.
///
/// Analyzes user taste profiles, candidate tracks, and genre tags to select
/// the top 3 genres, allocate quota (~9 + 8 + 8 = 25 tracks), and interleave
/// them in a rhythmic round-robin sequence with sub-millisecond execution.
class SpeedDialMixGenerator {
  const SpeedDialMixGenerator._();

  /// Known artist to genre mappings for heuristic genre resolution.
  static const Map<String, String> artistGenreHeuristics = {
    'the weeknd': 'Pop',
    'dua lipa': 'Pop',
    'ed sheeran': 'Pop',
    'harry styles': 'Pop',
    'billie eilish': 'Pop',
    'taylor swift': 'Pop',
    'miley cyrus': 'Pop',
    'justin bieber': 'Pop',
    'queen': 'Rock',
    'arctic monkeys': 'Rock',
    'nirvana': 'Rock',
    'linkin park': 'Rock',
    'foo fighters': 'Rock',
    'the white stripes': 'Rock',
    'red hot chili peppers': 'Rock',
    'ac/dc': 'Rock',
    "guns n' roses": 'Rock',
    'daft punk': 'Electronic',
    'avicii': 'Electronic',
    'the chainsmokers': 'Electronic',
    'david guetta': 'Electronic',
    'alan walker': 'Electronic',
    'deadmau5': 'Electronic',
    'm83': 'Electronic',
    'skrillex': 'Electronic',
    'kendrick lamar': 'Hip-Hop',
    'drake': 'Hip-Hop',
    'eminem': 'Hip-Hop',
    'travis scott': 'Hip-Hop',
    'post malone': 'Hip-Hop',
    'kanye west': 'Hip-Hop',
    'j. cole': 'Hip-Hop',
    'phoebe bridgers': 'Indie',
    'tame impala': 'Indie',
    'mac demarco': 'Indie',
    'clairo': 'Indie',
    'boygenius': 'Indie',
    'wallows': 'Indie',
    'lorde': 'Indie',
    'the neighbourhood': 'Indie',
    'alt-j': 'Indie',
    'glass animals': 'Indie',
    'wys': 'Lo-Fi',
    'jinsang': 'Lo-Fi',
    'idealism': 'Lo-Fi',
    'the deli': 'Lo-Fi',
  };

  /// Heuristically resolves a genre string for a track based on explicit map,
  /// artist lookup, or title patterns.
  static String resolveTrackGenre(
    Track track, {
    Map<String, String>? explicitTrackGenreMap,
  }) {
    // 1. Explicitly mapped track tag
    if (explicitTrackGenreMap != null &&
        explicitTrackGenreMap.containsKey(track.id)) {
      final tag = explicitTrackGenreMap[track.id]!.trim();
      if (tag.isNotEmpty) return _canonicalizeGenre(tag);
    }

    // 2. Artist heuristic lookup
    final artistKey = track.artist.trim().toLowerCase();
    for (final entry in artistGenreHeuristics.entries) {
      if (artistKey.contains(entry.key)) {
        return entry.value;
      }
    }

    // 3. Fallback to Pop
    return 'Pop';
  }

  /// Normalizes genre strings to Title Case standard representations.
  static String _canonicalizeGenre(String genre) {
    final lower = genre.trim().toLowerCase();
    if (lower.contains('rock') || lower.contains('metal')) return 'Rock';
    if (lower.contains('elec') ||
        lower.contains('edm') ||
        lower.contains('dance') ||
        lower.contains('house') ||
        lower.contains('techno')) {
      return 'Electronic';
    }
    if (lower.contains('hip') ||
        lower.contains('rap') ||
        lower.contains('trap')) {
      return 'Hip-Hop';
    }
    if (lower.contains('indie') || lower.contains('alt')) return 'Indie';
    if (lower.contains('lofi') ||
        lower.contains('lo-fi') ||
        lower.contains('chill')) {
      return 'Lo-Fi';
    }
    if (lower.contains('r&b') || lower.contains('soul')) return 'R&B';
    if (lower.contains('pop')) return 'Pop';

    // Capitalize first letter
    return lower.isEmpty
        ? 'Pop'
        : lower[0].toUpperCase() + lower.substring(1);
  }

  /// Automatically discovers the user's top 3 genres based on taste profile
  /// scores, explicit track tags, liked songs, and play history.
  static List<String> detectTopGenres({
    List<TasteProfileEntity>? tasteProfiles,
    List<Track>? candidateTracks,
    Map<String, String>? explicitGenreTags,
    List<String>? pinnedGenres,
  }) {
    // 1. If user pinned custom genres, prioritize them
    if (pinnedGenres != null && pinnedGenres.isNotEmpty) {
      final sanitized = pinnedGenres
          .map((g) => _canonicalizeGenre(g))
          .toSet()
          .take(3)
          .toList();
      if (sanitized.length == 3) {
        return sanitized;
      }
      // If fewer than 3, we fill the remainder from detected genres below
      final remainder = detectTopGenres(
        tasteProfiles: tasteProfiles,
        candidateTracks: candidateTracks,
        explicitGenreTags: explicitGenreTags,
      ).where((g) => !sanitized.contains(g)).take(3 - sanitized.length);
      return [...sanitized, ...remainder];
    }

    final genreScores = <String, double>{};

    // 2. Score from Drift TasteProfiles table (dual-band affinity: 40% fast, 60% slow)
    if (tasteProfiles != null && tasteProfiles.isNotEmpty) {
      for (final profile in tasteProfiles) {
        if (profile.entityType == 'genre') {
          final canon = _canonicalizeGenre(profile.entityId);
          genreScores[canon] = (genreScores[canon] ?? 0.0) +
              profile.blendedAffinity.clamp(0.1, 10.0);
        }
      }
    }

    // 3. Score from candidate tracks (liked tracks and recent history)
    if (candidateTracks != null && candidateTracks.isNotEmpty) {
      for (final track in candidateTracks) {
        final genre = resolveTrackGenre(
          track,
          explicitTrackGenreMap: explicitGenreTags,
        );
        final weight = track.isLiked ? 2.5 : 1.0;
        genreScores[genre] = (genreScores[genre] ?? 0.0) + weight;
      }
    }

    // 4. Sort discovered genres descending by score
    final sortedGenres = genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sortedGenres.map((e) => e.key).take(3).toList();

    // 5. Fill with default genres if fewer than 3 were detected
    for (final fallback in kDefaultTopGenres) {
      if (top.length >= 3) break;
      if (!top.contains(fallback)) {
        top.add(fallback);
      }
    }

    return top.take(3).toList();
  }

  /// Calculates proportional track quota for the top 3 genres to total [targetCount].
  /// Default for 25 tracks: Genre 1 gets 9 tracks, Genre 2 gets 8, Genre 3 gets 8.
  static Map<String, int> computeGenreQuota(
    List<String> top3Genres, {
    int targetCount = kSpeedDialMixTargetCount,
  }) {
    if (top3Genres.isEmpty) return {};
    if (top3Genres.length == 1) return {top3Genres[0]: targetCount};
    if (top3Genres.length == 2) {
      final half = targetCount ~/ 2;
      return {
        top3Genres[0]: targetCount - half,
        top3Genres[1]: half,
      };
    }

    // Proportional breakdown: ~36%, ~32%, ~32%
    final g1Count = (targetCount * 0.36).round(); // 9
    final g2Count = (targetCount * 0.32).round(); // 8
    final g3Count = targetCount - g1Count - g2Count; // 8

    return {
      top3Genres[0]: g1Count,
      top3Genres[1]: g2Count,
      top3Genres[2]: g3Count,
    };
  }

  /// Generates a complete 25-track SpeedDialMix balanced across the top 3 genres.
  ///
  /// - Fast: Executes purely in-memory in sub-millisecond time.
  /// - Balanced: Allocates exact quotas to each of the top 3 genres.
  /// - Unique: Deduplicates track IDs strictly.
  /// - Interleaved: Alternates genre tracks in a round-robin loop.
  /// - Guaranteed: Fills any shortages with curated high-fidelity genre tracks.
  static SpeedDialMix generate({
    List<Track> candidateTracks = const [],
    List<TasteProfileEntity>? tasteProfiles,
    Map<String, String>? explicitTrackGenreMap,
    List<String>? pinnedGenres,
    int targetCount = kSpeedDialMixTargetCount,
    int? randomSeed,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final random = randomSeed != null ? math.Random(randomSeed) : math.Random();

    // 1. Detect Top 3 Genres
    final topGenres = detectTopGenres(
      tasteProfiles: tasteProfiles,
      candidateTracks: candidateTracks,
      explicitGenreTags: explicitTrackGenreMap,
      pinnedGenres: pinnedGenres,
    );

    // 2. Compute Track Quotas
    final quotas = computeGenreQuota(topGenres, targetCount: targetCount);

    // 3. Partition Candidate Tracks into Genres
    final genreTrackBuckets = <String, List<Track>>{};
    for (final genre in topGenres) {
      genreTrackBuckets[genre] = [];
    }

    final usedTrackIds = <String>{};
    final resolvedTrackGenreMap = <String, String>{};

    for (final track in candidateTracks) {
      if (usedTrackIds.contains(track.id)) continue;
      final genre = resolveTrackGenre(
        track,
        explicitTrackGenreMap: explicitTrackGenreMap,
      );
      if (genreTrackBuckets.containsKey(genre)) {
        genreTrackBuckets[genre]!.add(track);
        usedTrackIds.add(track.id);
        resolvedTrackGenreMap[track.id] = genre;
      }
    }

    // 4. Fill Each Genre Bucket to Meet its Quota
    final selectedPerGenre = <String, List<Track>>{};

    for (final genre in topGenres) {
      final quota = quotas[genre] ?? 0;
      final available = List<Track>.from(genreTrackBuckets[genre] ?? []);
      available.shuffle(random);

      final bucketSelected = <Track>[];

      // Add from available candidate tracks
      for (final t in available) {
        if (bucketSelected.length >= quota) break;
        bucketSelected.add(t);
      }

      // If available was less than quota, fill from curated catalog
      if (bucketSelected.length < quota) {
        final catalogTracks = List<Track>.from(
          SpeedDialGenreCatalogs.getTracksForGenre(genre),
        )..shuffle(random);

        for (final fallbackTrack in catalogTracks) {
          if (bucketSelected.length >= quota) break;
          if (!usedTrackIds.contains(fallbackTrack.id)) {
            bucketSelected.add(fallbackTrack);
            usedTrackIds.add(fallbackTrack.id);
            resolvedTrackGenreMap[fallbackTrack.id] = genre;
          }
        }
      }

      selectedPerGenre[genre] = bucketSelected;
    }

    // 5. Interleave in Round-Robin Order for Dynamic Sonic Texture
    final interleavedTracks = <Track>[];
    final genreLists = topGenres.map((g) => List<Track>.from(selectedPerGenre[g] ?? [])).toList();

    int maxBucketSize = 0;
    for (final list in genreLists) {
      if (list.length > maxBucketSize) maxBucketSize = list.length;
    }

    for (int step = 0; step < maxBucketSize; step++) {
      for (int g = 0; g < topGenres.length; g++) {
        final list = genreLists[g];
        if (step < list.length) {
          interleavedTracks.add(list[step]);
        }
      }
    }

    // 6. Guarantee Exact Target Count
    List<Track> finalTracks = interleavedTracks;
    if (finalTracks.length > targetCount) {
      finalTracks = finalTracks.take(targetCount).toList();
    } else if (finalTracks.length < targetCount) {
      // Emergency fill if edge catalogs were somehow exhausted
      final emergencyFallbacks = [
        ...SpeedDialGenreCatalogs.popTracks,
        ...SpeedDialGenreCatalogs.rockTracks,
        ...SpeedDialGenreCatalogs.electronicTracks,
      ];
      for (final track in emergencyFallbacks) {
        if (finalTracks.length >= targetCount) break;
        if (!finalTracks.any((t) => t.id == track.id)) {
          finalTracks.add(track);
          resolvedTrackGenreMap[track.id] = 'Pop';
        }
      }
    }

    // 7. Calculate Actual Genre Track Counts
    final actualGenreCounts = <String, int>{};
    for (final genre in topGenres) {
      actualGenreCounts[genre] = 0;
    }
    for (final track in finalTracks) {
      final genre = resolvedTrackGenreMap[track.id] ?? 'Pop';
      actualGenreCounts[genre] = (actualGenreCounts[genre] ?? 0) + 1;
    }

    final mixId = 'speed_dial_${effectiveNow.millisecondsSinceEpoch}';

    return SpeedDialMix(
      id: mixId,
      title: 'Speed Dial Mix',
      topGenres: topGenres,
      tracks: finalTracks,
      genreCounts: actualGenreCounts,
      trackGenreMap: resolvedTrackGenreMap,
      createdAt: effectiveNow,
    );
  }
}

// ============================================================================
// StateNotifier & Business Logic: SpeedDialMixNotifier
// ============================================================================

/// StateNotifier managing the dynamic generation, caching, and 1-tap playback
/// of the 25-track Speed Dial Mix.
class SpeedDialMixNotifier extends StateNotifier<SpeedDialMixState> {
  final Ref? _ref;
  final SoftifyAudioHandler? _audioHandler;
  final AppDatabase? _db;
  final ILibraryRepository? _libraryRepo;
  final SpeedDialPrefsStorage _prefs;

  StreamSubscription? _playbackStateSub;
  StreamSubscription? _queueSub;

  SpeedDialMixNotifier({
    Ref? ref,
    SoftifyAudioHandler? audioHandler,
    AppDatabase? db,
    ILibraryRepository? libraryRepo,
    SpeedDialPrefsStorage? prefs,
    SpeedDialMixState? initialState,
  })  : _ref = ref,
        _audioHandler = audioHandler,
        _db = db,
        _libraryRepo = libraryRepo,
        _prefs = prefs ?? SpeedDialMixSharedPreferences(),
        super(initialState ?? const SpeedDialMixState()) {
    _initAndLoad();
  }

  SoftifyAudioHandler? get _handler =>
      _audioHandler ?? _ref?.read(audioHandlerProvider);

  AppDatabase? get _database =>
      _db ?? _ref?.read(databaseProvider);

  ILibraryRepository? get _repo =>
      _libraryRepo ?? _ref?.read(libraryRepositoryProvider);

  Future<void> _initAndLoad() async {
    _listenToPlaybackState();
    await _loadPersistedState();
    if (state.mix == null) {
      await generateMix();
    }
  }

  void _listenToPlaybackState() {
    try {
      final handler = _handler;
      if (handler != null) {
        _playbackStateSub = handler.playbackState.listen((pState) {
          final isPlayingNow = pState.playing;
          if (state.isPlaying != isPlayingNow) {
            state = state.copyWith(isPlaying: isPlayingNow);
          }
        });

        _queueSub = handler.tracksQueueStream.listen((queue) {
          final currentMix = state.mix;
          if (currentMix != null && queue.isNotEmpty) {
            // Check if active queue starts with this mix's tracks
            final isMixInQueue = queue.length >= currentMix.tracks.length &&
                queue.first.id == currentMix.tracks.first.id;
            if (!isMixInQueue && state.isPlaying) {
              state = state.copyWith(isPlaying: false);
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _playbackStateSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  /// Loads cached mix metadata and play stats from SharedPreferences.
  Future<void> _loadPersistedState() async {
    try {
      final playCount = await _prefs.getInt(kSpeedDialPrefPlayCount) ?? 0;
      final pinned = await _prefs.getStringList(kSpeedDialPrefPinnedGenres);
      final cachedIds = await _prefs.getStringList(kSpeedDialPrefCachedTrackIds);
      final lastGenMs = await _prefs.getInt(kSpeedDialPrefLastGeneratedTs);

      state = state.copyWith(
        playCount: playCount,
        pinnedGenres: pinned,
      );

      // If we have recent cache (< 12 hours old) with 25 tracks, reconstruct mix
      if (cachedIds != null &&
          cachedIds.length == kSpeedDialMixTargetCount &&
          lastGenMs != null) {
        final lastGen = DateTime.fromMillisecondsSinceEpoch(lastGenMs);
        if (DateTime.now().difference(lastGen).inHours < 12) {
          final candidateTracks = await _fetchCandidateTracks();
          final candidateMap = {for (final t in candidateTracks) t.id: t};

          final restoredTracks = <Track>[];
          for (final id in cachedIds) {
            if (candidateMap.containsKey(id)) {
              restoredTracks.add(candidateMap[id]!);
            } else {
              // Find in fallback catalogs
              final fallback = [
                ...SpeedDialGenreCatalogs.popTracks,
                ...SpeedDialGenreCatalogs.rockTracks,
                ...SpeedDialGenreCatalogs.electronicTracks,
                ...SpeedDialGenreCatalogs.hipHopTracks,
                ...SpeedDialGenreCatalogs.indieTracks,
                ...SpeedDialGenreCatalogs.lofiTracks,
              ].cast<Track?>().firstWhere((t) => t?.id == id, orElse: () => null);
              if (fallback != null) restoredTracks.add(fallback);
            }
          }

          if (restoredTracks.length == kSpeedDialMixTargetCount) {
            final topGenres = await _prefs.getStringList(kSpeedDialPrefTopGenres) ??
                kDefaultTopGenres;
            final genreMap = <String, String>{};
            final genreCounts = <String, int>{for (final g in topGenres) g: 0};

            for (final t in restoredTracks) {
              final g = SpeedDialMixGenerator.resolveTrackGenre(t);
              genreMap[t.id] = g;
              genreCounts[g] = (genreCounts[g] ?? 0) + 1;
            }

            final cachedMix = SpeedDialMix(
              id: 'speed_dial_$lastGenMs',
              topGenres: topGenres,
              tracks: restoredTracks,
              genreCounts: genreCounts,
              trackGenreMap: genreMap,
              createdAt: lastGen,
            );

            state = state.copyWith(mix: cachedMix);
          }
        }
      }
    } catch (_) {}
  }

  /// Gathers candidate tracks from user's liked tracks, DB tracks, and history.
  Future<List<Track>> _fetchCandidateTracks() async {
    final results = <Track>[];
    try {
      if (_repo != null) {
        final liked = await _repo!.getLikedTracks();
        results.addAll(liked);
      }
    } catch (_) {}

    try {
      if (_database != null) {
        final dbRows = await _database!.select(_database!.tracks).get();
        for (final row in dbRows) {
          if (!results.any((t) => t.id == row.id)) {
            results.add(Track(
              id: row.id,
              sourceId: row.sourceId,
              title: row.title,
              artist: row.artist,
              album: row.album,
              duration: Duration(milliseconds: row.durationMs),
              coverUrl: row.coverUrl,
              matchConfidence: row.matchConfidence,
              isLiked: row.isLiked,
              isUnavailable: row.isUnavailable,
            ));
          }
        }
      }
    } catch (_) {}

    return results;
  }

  /// Gathers taste profile records from Drift database.
  Future<List<TasteProfileEntity>> _fetchTasteProfiles() async {
    final list = <TasteProfileEntity>[];
    try {
      if (_database != null) {
        final rows = await _database!.select(_database!.tasteProfiles).get();
        for (final r in rows) {
          list.add(TasteProfileEntity(
            id: r.id,
            entityType: r.entityType,
            entityId: r.entityId,
            slowWeight: r.slowWeight,
            fastWeight: r.fastWeight,
            updatedAt: r.updatedAt,
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  /// Gathers user-edited track genre tags from Settings table.
  Future<Map<String, String>> _fetchExplicitTrackGenreTags() async {
    final tags = <String, String>{};
    try {
      if (_database != null) {
        final settings = await _database!.select(_database!.settings).get();
        for (final s in settings) {
          if (s.key.startsWith('track_genre_')) {
            final trackId = s.key.replaceFirst('track_genre_', '');
            tags[trackId] = s.value;
          }
        }
      }
    } catch (_) {}
    return tags;
  }

  /// Dynamically generates or refreshes the 25-track Speed Dial Mix.
  Future<void> generateMix({
    bool forceRefresh = false,
    int? seed,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final candidateTracks = await _fetchCandidateTracks();
      final tasteProfiles = await _fetchTasteProfiles();
      final explicitGenreTags = await _fetchExplicitTrackGenreTags();

      final newMix = SpeedDialMixGenerator.generate(
        candidateTracks: candidateTracks,
        tasteProfiles: tasteProfiles,
        explicitTrackGenreMap: explicitGenreTags,
        pinnedGenres: state.pinnedGenres,
        targetCount: kSpeedDialMixTargetCount,
        randomSeed: seed,
      );

      // Persist to SharedPreferences
      await _prefs.setStringList(
        kSpeedDialPrefCachedTrackIds,
        newMix.tracks.map((t) => t.id).toList(),
      );
      await _prefs.setStringList(
        kSpeedDialPrefTopGenres,
        newMix.topGenres,
      );
      await _prefs.setInt(
        kSpeedDialPrefLastGeneratedTs,
        newMix.createdAt.millisecondsSinceEpoch,
      );

      state = state.copyWith(
        mix: newMix,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate Speed Dial mix: $e',
      );
    }
  }

  /// 1-Tap Playback: Immediately queues the 25 tracks into the audio handler
  /// and initiates playback at [startIndex].
  Future<void> playMix({int startIndex = 0}) async {
    var mix = state.mix;
    if (mix == null || mix.tracks.isEmpty) {
      await generateMix();
      mix = state.mix;
    }
    if (mix == null || mix.tracks.isEmpty) return;

    final handler = _handler;
    if (handler != null) {
      final safeIndex = (startIndex >= 0 && startIndex < mix.tracks.length)
          ? startIndex
          : 0;
      await handler.setQueue(mix.tracks, startIndex: safeIndex);
      await handler.play();

      final newPlayCount = state.playCount + 1;
      await _prefs.setInt(kSpeedDialPrefPlayCount, newPlayCount);

      state = state.copyWith(
        isPlaying: true,
        activeTrackIndex: safeIndex,
        playCount: newPlayCount,
      );
    }
  }

  /// Toggles playback between Play and Pause for the Speed Dial Mix.
  Future<void> togglePlayback() async {
    final handler = _handler;
    if (handler == null) return;

    if (state.isPlaying) {
      await handler.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await playMix(startIndex: state.activeTrackIndex);
    }
  }

  /// Re-rolls the mix dynamically with fresh randomization.
  Future<void> reRollMix() async {
    final freshSeed = DateTime.now().microsecondsSinceEpoch;
    await generateMix(forceRefresh: true, seed: freshSeed);
    HapticFeedback.mediumImpact();
  }

  /// Overrides automatic genre detection with user-specified top 3 genres.
  Future<void> setPinnedGenres(List<String>? genres) async {
    if (genres == null || genres.isEmpty) {
      await _prefs.remove(kSpeedDialPrefPinnedGenres);
      state = state.copyWith(pinnedGenres: null);
    } else {
      final sanitized = genres.take(3).toList();
      await _prefs.setStringList(kSpeedDialPrefPinnedGenres, sanitized);
      state = state.copyWith(pinnedGenres: sanitized);
    }
    await generateMix(forceRefresh: true);
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Provider managing the active SpeedDialMix state and actions.
final speedDialMixProvider =
    StateNotifierProvider<SpeedDialMixNotifier, SpeedDialMixState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  final db = ref.watch(databaseProvider);
  final libraryRepo = ref.watch(libraryRepositoryProvider);

  return SpeedDialMixNotifier(
    ref: ref,
    audioHandler: audioHandler,
    db: db,
    libraryRepo: libraryRepo,
  );
});

// ============================================================================
// UI Component: SpeedDialMixCard (Hero 1-Tap Widget)
// ============================================================================

/// Flagship Material 3 hero card widget providing instant 1-tap playback of the
/// 25-track Speed Dial Mix from the Home or Library screens.
///
/// Features:
/// - Prominent 1-tap Play/Pause action button.
/// - Top 3 genre badge pills with track allocations.
/// - Dynamic album mosaic preview.
/// - Re-roll / Refresh button for instant on-demand mix regeneration.
/// - Opens [SpeedDialMixSheet] modal upon card tap for full track browsing.
class SpeedDialMixCard extends ConsumerWidget {
  /// Whether to render a compact banner suitable for sidebars or tight list headers.
  final bool compact;

  /// Custom margin around the card container.
  final EdgeInsetsGeometry? margin;

  /// Optional override callback when the 1-tap play button is triggered.
  final VoidCallback? onPlayTapped;

  /// Optional override callback when the re-roll button is triggered.
  final VoidCallback? onRefreshTapped;

  /// Optional override callback when the card itself is tapped.
  final VoidCallback? onCardTapped;

  const SpeedDialMixCard({
    super.key,
    this.compact = false,
    this.margin,
    this.onPlayTapped,
    this.onRefreshTapped,
    this.onCardTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(speedDialMixProvider);
    final notifier = ref.read(speedDialMixProvider.notifier);

    final mix = state.mix;
    final isLoading = state.isLoading;
    final isPlaying = state.isPlaying;

    final topGenres = mix?.topGenres ?? kDefaultTopGenres;
    final genreCounts = mix?.genreCounts ?? {};

    // Dynamic genre accent color mapping
    Color getGenreColor(String genre, int index) {
      final lower = genre.toLowerCase();
      if (lower.contains('pop')) return tokens.accentRose;
      if (lower.contains('rock')) return const Color(0xFFFF8A65); // Warm Amber
      if (lower.contains('elec')) return tokens.accentCyan;
      if (lower.contains('hip')) return tokens.accentViolet;
      if (lower.contains('indie')) return const Color(0xFF81C784); // Soft Emerald
      if (lower.contains('lofi') || lower.contains('lo-fi')) {
        return const Color(0xFFBA68C8); // Soft Purple
      }
      return [tokens.accent, tokens.accentCyan, tokens.accentViolet][index % 3];
    }

    return Container(
      key: const Key('speed_dial_mix_card'),
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(
          color: isPlaying ? tokens.accent.withOpacity(0.4) : tokens.glassBorder,
          width: isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: tokens.cardShadow.isNotEmpty
            ? tokens.cardShadow
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCardTapped ??
              () {
                SpeedDialMixSheet.show(context);
              },
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          child: Stack(
            children: [
              // Subtle ambient background gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        getGenreColor(topGenres.first, 0).withOpacity(0.12),
                        tokens.card,
                        if (topGenres.length > 1)
                          getGenreColor(topGenres[1], 1).withOpacity(0.08)
                        else
                          tokens.card,
                      ],
                    ),
                  ),
                ),
              ),

              // Main Card Content
              Padding(
                padding: EdgeInsets.all(compact ? 14 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Header: Tag Badge & Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Micro-label Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                            border: Border.all(
                              color: tokens.accent.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 13,
                                color: tokens.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'SPEED DIAL • 25 TRACKS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: tokens.accent,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Re-roll / Refresh button
                        IconButton(
                          key: const Key('speed_dial_refresh_button'),
                          tooltip: 'Generate fresh mix',
                          icon: isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(tokens.accent),
                                  ),
                                )
                              : Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: tokens.textSecondary,
                                ),
                          onPressed: isLoading
                              ? null
                              : (onRefreshTapped ?? () => notifier.reRollMix()),
                          visualDensity: VisualDensity.compact,
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Middle Section: Title, Subtitle & 1-Tap Play Button
                    Row(
                      children: [
                        // Title & Subtitle Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Speed Dial Mix',
                                style: TextStyle(
                                  fontSize: compact ? 17 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mix != null
                                    ? mix.formattedSubtitle
                                    : 'Dynamic 25-track smart blend across top 3 genres',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: tokens.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Prominent 1-Tap Play / Pause Button
                        ElevatedButton(
                          key: const Key('speed_dial_play_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: EdgeInsets.all(compact ? 12 : 15),
                            elevation: 4,
                          ),
                          onPressed: isLoading
                              ? null
                              : (onPlayTapped ?? () => notifier.togglePlayback()),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: compact ? 24 : 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bottom: Top 3 Genre Chips with track counts
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: List.generate(topGenres.length, (index) {
                        final genre = topGenres[index];
                        final count = genreCounts[genre] ??
                            (index == 0 ? 9 : 8);
                        final color = getGenreColor(genre, index);

                        return Container(
                          key: Key('speed_dial_genre_chip_$index'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                            border: Border.all(
                              color: color.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$genre ($count)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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
}

// ============================================================================
// UI Component: SpeedDialMixSheet (Detailed Modal View)
// ============================================================================

/// Modal bottom sheet displaying the full 25 tracks of the Speed Dial Mix,
/// interactive genre balance bar, and individual track playback.
class SpeedDialMixSheet extends ConsumerWidget {
  const SpeedDialMixSheet({super.key});

  /// Displays the SpeedDialMixSheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SpeedDialMixSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(speedDialMixProvider);
    final notifier = ref.read(speedDialMixProvider.notifier);

    final mix = state.mix;
    final tracks = mix?.tracks ?? const [];
    final topGenres = mix?.topGenres ?? kDefaultTopGenres;
    final genreCounts = mix?.genreCounts ?? {};

    return Container(
      key: const Key('speed_dial_mix_sheet'),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tokens.glassBorder, width: 1),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Speed Dial Mix',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mix != null
                            ? '${mix.length} Tracks • ${mix.formattedTotalDuration}'
                            : '25 Tracks',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Re-roll mix',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => notifier.reRollMix(),
                ),
                ElevatedButton.icon(
                  key: const Key('speed_dial_sheet_play_all_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    notifier.playMix();
                    Navigator.of(context).pop();
                  },
                  icon: Icon(
                    state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  label: Text(
                    state.isPlaying ? 'Playing' : 'Play All',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Genre Balance Visual Progress Bar
          if (mix != null && mix.length > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: List.generate(topGenres.length, (i) {
                      final g = topGenres[i];
                      final count = genreCounts[g] ?? 0;
                      final flex = count > 0 ? count : 1;
                      final colors = [
                        tokens.accentRose,
                        const Color(0xFFFF8A65),
                        tokens.accentCyan,
                      ];
                      return Expanded(
                        flex: flex,
                        child: Container(color: colors[i % colors.length]),
                      );
                    }),
                  ),
                ),
              ),
            ),

          const Divider(height: 1),

          // Track List
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Text(
                      'No tracks in Speed Dial mix',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final genre = mix?.getGenreForTrack(track.id) ?? 'Pop';
                      final isCurrent = state.isPlaying &&
                          state.activeTrackIndex == index;

                      return ListTile(
                        leading: SizedBox(
                          width: 32,
                          child: Center(
                            child: isCurrent
                                ? Icon(
                                    Icons.equalizer_rounded,
                                    size: 18,
                                    color: tokens.accent,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          track.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? tokens.accent : tokens.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              track.artist,
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceHighlight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                genre,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          _formatDuration(track.duration),
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                          ),
                        ),
                        onTap: () {
                          notifier.playMix(startIndex: index);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
