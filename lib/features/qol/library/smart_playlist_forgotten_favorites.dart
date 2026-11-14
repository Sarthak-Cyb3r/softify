// ============================================================================
// Softify Quality of Life (QoL): Feature 20 - Smart Playlist: Forgotten Favorites
// ============================================================================
//
// Dynamic smart playlist identifying favorited songs with zero plays in >= 60
// days based on listening history. Features:
// - Dynamic identification of dormant favorited tracks (>= 60 days or unplayed)
// - ForgottenFavoritesService ranking nostalgic tracks by past affinity & dormancy
// - Nostalgia tier categorization (Vintage Gold, Lost Classic, Rediscovery, Unplayed Gem)
// - Configurable dormancy thresholds (30, 60, 90, 180 days) & ranking modes
// - ForgottenFavoritesCard widget with prominent 1-tap Quick Play button
// - ForgottenFavoritesDetailSheet modal with full track list, filters, & export
// - Self-contained SharedPreferences persistence with mock test harness
// - Riverpod state management via forgottenFavoritesProvider & quick play controller
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
import '../../../domain/entities/history_item.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/ports/i_library_repository.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/animated_music_wave_indicator.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';

// ============================================================================
// 1. Constants & Pref Keys
// ============================================================================

const int kDefaultForgottenThresholdDays = 60;
const int kDefaultForgottenMaxTracks = 50;
const double kDefaultForgottenMinCompletionRatio = 0.3;

const String kForgottenFavPrefThresholdDays = 'softify_forgotten_fav_threshold_days';
const String kForgottenFavPrefRankingMode = 'softify_forgotten_fav_ranking_mode';
const String kForgottenFavPrefIncludeNeverPlayed = 'softify_forgotten_fav_include_never_played';
const String kForgottenFavPrefMaxTracks = 'softify_forgotten_fav_max_tracks';
const String kForgottenFavPrefLastRefreshed = 'softify_forgotten_fav_last_refreshed';

// ============================================================================
// 2. Enums
// ============================================================================

/// Nostalgia tier reflecting how deeply forgotten a favorited track is.
enum ForgottenTier {
  vintageGold('Vintage Gold', '180+ days dormant', Icons.military_tech_rounded, Color(0xFFF59E0B)),
  lostClassic('Lost Classic', '90-179 days dormant', Icons.auto_awesome_rounded, Color(0xFF8B5CF6)),
  rediscovery('Rediscovery', '60-89 days dormant', Icons.history_rounded, Color(0xFF06B6D4)),
  unplayedGem('Unplayed Gem', 'Never played', Icons.fiber_new_rounded, Color(0xFF10B981));

  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const ForgottenTier(this.label, this.description, this.icon, this.color);

  static ForgottenTier fromDaysAndPlays(int? daysDormant, int historicalPlays) {
    if (daysDormant == null || historicalPlays == 0) {
      return ForgottenTier.unplayedGem;
    }
    if (daysDormant >= 180) {
      return ForgottenTier.vintageGold;
    }
    if (daysDormant >= 90) {
      return ForgottenTier.lostClassic;
    }
    return ForgottenTier.rediscovery;
  }
}

/// Algorithm modes for ranking nostalgic tracks.
enum ForgottenFavoritesRankingMode {
  nostalgiaScore(
    'Nostalgia Score',
    'Balances past devotion, time dormant, and completion rate',
    Icons.auto_awesome_rounded,
  ),
  longestForgotten(
    'Longest Dormant',
    'Tracks unplayed for the most consecutive days first',
    Icons.schedule_rounded,
  ),
  mostPlayedPast(
    'Most Played Past',
    'Your biggest historical hits that fell out of rotation',
    Icons.repeat_rounded,
  ),
  randomNostalgia(
    'Rediscovery Shuffle',
    'Serendipitous nostalgic mix across forgotten favorites',
    Icons.shuffle_rounded,
  );

  final String label;
  final String description;
  final IconData icon;

  const ForgottenFavoritesRankingMode(this.label, this.description, this.icon);

  static ForgottenFavoritesRankingMode fromString(String? val) {
    if (val == null) return ForgottenFavoritesRankingMode.nostalgiaScore;
    for (final mode in ForgottenFavoritesRankingMode.values) {
      if (mode.name == val) return mode;
    }
    return ForgottenFavoritesRankingMode.nostalgiaScore;
  }
}

// ============================================================================
// 3. Data Models
// ============================================================================

/// Represents a ranked, dormant favorited track with detailed nostalgia metrics.
@immutable
class ForgottenFavoriteTrack {
  final Track track;
  final int rank;
  final int? daysSinceLastPlayed;
  final DateTime? lastPlayedAt;
  final int historicalPlayCount;
  final double averageCompletionRatio;
  final double nostalgiaScore;
  final ForgottenTier tier;

  const ForgottenFavoriteTrack({
    required this.track,
    required this.rank,
    required this.daysSinceLastPlayed,
    this.lastPlayedAt,
    required this.historicalPlayCount,
    this.averageCompletionRatio = 1.0,
    required this.nostalgiaScore,
    required this.tier,
  });

  String get formattedDormancy {
    if (daysSinceLastPlayed == null) return 'Never played';
    if (daysSinceLastPlayed == 0) return 'Played today';
    if (daysSinceLastPlayed == 1) return 'Yesterday';
    if (daysSinceLastPlayed! < 30) return '$daysSinceLastPlayed days ago';
    if (daysSinceLastPlayed! < 60) return '1 month ago';
    final months = daysSinceLastPlayed! ~/ 30;
    if (months < 12) return '$months months ago';
    final years = (daysSinceLastPlayed! / 365.0).toStringAsFixed(1);
    return '${years}y ago';
  }

  String get formattedHistoricalPlays {
    if (historicalPlayCount == 0) return 'Unplayed favorite';
    if (historicalPlayCount == 1) return '1 prior play';
    return '$historicalPlayCount prior plays';
  }

  String get formattedSubtitle {
    final dormancy = formattedDormancy;
    if (historicalPlayCount > 0) {
      return '$dormancy • $formattedHistoricalPlays';
    }
    return dormancy;
  }

  ForgottenFavoriteTrack copyWith({
    Track? track,
    int? rank,
    int? daysSinceLastPlayed,
    DateTime? lastPlayedAt,
    int? historicalPlayCount,
    double? averageCompletionRatio,
    double? nostalgiaScore,
    ForgottenTier? tier,
  }) {
    return ForgottenFavoriteTrack(
      track: track ?? this.track,
      rank: rank ?? this.rank,
      daysSinceLastPlayed: daysSinceLastPlayed ?? this.daysSinceLastPlayed,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      historicalPlayCount: historicalPlayCount ?? this.historicalPlayCount,
      averageCompletionRatio: averageCompletionRatio ?? this.averageCompletionRatio,
      nostalgiaScore: nostalgiaScore ?? this.nostalgiaScore,
      tier: tier ?? this.tier,
    );
  }

  Map<String, dynamic> toMap() => {
        'track': track.toMap(),
        'rank': rank,
        'days_since_last_played': daysSinceLastPlayed,
        'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
        'historical_play_count': historicalPlayCount,
        'average_completion_ratio': averageCompletionRatio,
        'nostalgia_score': nostalgiaScore,
        'tier': tier.name,
      };

  factory ForgottenFavoriteTrack.fromMap(Map<String, dynamic> map) {
    return ForgottenFavoriteTrack(
      track: Track.fromMap(map['track'] as Map<String, dynamic>),
      rank: map['rank'] as int? ?? 1,
      daysSinceLastPlayed: map['days_since_last_played'] as int?,
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at'] as int)
          : null,
      historicalPlayCount: map['historical_play_count'] as int? ?? 0,
      averageCompletionRatio:
          (map['average_completion_ratio'] as num?)?.toDouble() ?? 1.0,
      nostalgiaScore: (map['nostalgia_score'] as num?)?.toDouble() ?? 0.0,
      tier: ForgottenTier.values.firstWhere(
        (t) => t.name == map['tier'],
        orElse: () => ForgottenTier.rediscovery,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForgottenFavoriteTrack &&
          runtimeType == other.runtimeType &&
          track.id == other.track.id &&
          rank == other.rank;

  @override
  int get hashCode => Object.hash(track.id, rank);
}

/// User configuration and algorithmic parameters for Forgotten Favorites.
@immutable
class ForgottenFavoritesConfig {
  final int thresholdDays;
  final int maxTracks;
  final ForgottenFavoritesRankingMode rankingMode;
  final bool includeNeverPlayed;
  final double minCompletionRatio;
  final bool excludeUnavailable;

  const ForgottenFavoritesConfig({
    this.thresholdDays = kDefaultForgottenThresholdDays,
    this.maxTracks = kDefaultForgottenMaxTracks,
    this.rankingMode = ForgottenFavoritesRankingMode.nostalgiaScore,
    this.includeNeverPlayed = true,
    this.minCompletionRatio = kDefaultForgottenMinCompletionRatio,
    this.excludeUnavailable = true,
  });

  ForgottenFavoritesConfig copyWith({
    int? thresholdDays,
    int? maxTracks,
    ForgottenFavoritesRankingMode? rankingMode,
    bool? includeNeverPlayed,
    double? minCompletionRatio,
    bool? excludeUnavailable,
  }) {
    return ForgottenFavoritesConfig(
      thresholdDays: thresholdDays ?? this.thresholdDays,
      maxTracks: maxTracks ?? this.maxTracks,
      rankingMode: rankingMode ?? this.rankingMode,
      includeNeverPlayed: includeNeverPlayed ?? this.includeNeverPlayed,
      minCompletionRatio: minCompletionRatio ?? this.minCompletionRatio,
      excludeUnavailable: excludeUnavailable ?? this.excludeUnavailable,
    );
  }

  Map<String, dynamic> toMap() => {
        'threshold_days': thresholdDays,
        'max_tracks': maxTracks,
        'ranking_mode': rankingMode.name,
        'include_never_played': includeNeverPlayed,
        'min_completion_ratio': minCompletionRatio,
        'exclude_unavailable': excludeUnavailable,
      };

  factory ForgottenFavoritesConfig.fromMap(Map<String, dynamic> map) {
    return ForgottenFavoritesConfig(
      thresholdDays: map['threshold_days'] as int? ?? kDefaultForgottenThresholdDays,
      maxTracks: map['max_tracks'] as int? ?? kDefaultForgottenMaxTracks,
      rankingMode: ForgottenFavoritesRankingMode.fromString(
        map['ranking_mode'] as String?,
      ),
      includeNeverPlayed: map['include_never_played'] as bool? ?? true,
      minCompletionRatio: (map['min_completion_ratio'] as num?)?.toDouble() ??
          kDefaultForgottenMinCompletionRatio,
      excludeUnavailable: map['exclude_unavailable'] as bool? ?? true,
    );
  }
}

/// Aggregate metrics summarizing the user's forgotten favorite collection.
@immutable
class ForgottenFavoritesStats {
  final int totalForgottenCount;
  final double averageDaysDormant;
  final int maxDaysDormant;
  final int neverPlayedCount;
  final Duration totalDuration;
  final Map<ForgottenTier, int> tierBreakdown;

  const ForgottenFavoritesStats({
    required this.totalForgottenCount,
    required this.averageDaysDormant,
    required this.maxDaysDormant,
    required this.neverPlayedCount,
    required this.totalDuration,
    required this.tierBreakdown,
  });

  String get formattedDuration {
    final minutes = totalDuration.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0 ? '${hours} hr' : '${hours}h ${remainingMinutes}m';
  }

  String get formattedAverageDormancy {
    if (totalForgottenCount == 0 || averageDaysDormant == 0) return '0 days';
    final days = averageDaysDormant.round();
    if (days < 30) return '$days days';
    final months = (days / 30.0).toStringAsFixed(1);
    return '$months mos';
  }
}

/// The fully materialized Forgotten Favorites Smart Playlist.
@immutable
class ForgottenFavoritesPlaylist {
  final String id;
  final String title;
  final String description;
  final List<ForgottenFavoriteTrack> rankedTracks;
  final ForgottenFavoritesStats stats;
  final ForgottenFavoritesConfig config;
  final DateTime generatedAt;

  const ForgottenFavoritesPlaylist({
    this.id = 'smart_playlist_forgotten_favorites',
    this.title = 'Forgotten Favorites',
    this.description = 'Rediscover loved tracks with zero plays in 60+ days',
    required this.rankedTracks,
    required this.stats,
    required this.config,
    required this.generatedAt,
  });

  List<Track> get tracks => rankedTracks.map((r) => r.track).toList();
  int get length => rankedTracks.length;
  bool get isEmpty => rankedTracks.isEmpty;
  bool get isNotEmpty => rankedTracks.isNotEmpty;

  Duration get totalDuration => stats.totalDuration;
  String get formattedDuration => stats.formattedDuration;

  Track? get topTrack => rankedTracks.isNotEmpty ? rankedTracks.first.track : null;
  ForgottenFavoriteTrack? get topRanked =>
      rankedTracks.isNotEmpty ? rankedTracks.first : null;

  List<String> get previewCovers {
    final covers = <String>[];
    for (final item in rankedTracks) {
      final url = item.track.coverUrl;
      if (url != null && url.isNotEmpty && !covers.contains(url)) {
        covers.add(url);
        if (covers.length >= 4) break;
      }
    }
    return covers;
  }

  Playlist toDomainPlaylist() {
    return Playlist(
      id: id,
      name: title,
      description: description,
      isImported: false,
      createdAt: generatedAt,
      trackCount: length,
    );
  }
}

/// Reactive state for the Forgotten Favorites feature.
@immutable
class ForgottenFavoritesState {
  final ForgottenFavoritesPlaylist? playlist;
  final bool isLoading;
  final bool isPlaying;
  final String? activeTrackId;
  final String? errorMessage;

  const ForgottenFavoritesState({
    this.playlist,
    this.isLoading = false,
    this.isPlaying = false,
    this.activeTrackId,
    this.errorMessage,
  });

  ForgottenFavoritesState copyWith({
    ForgottenFavoritesPlaylist? playlist,
    bool? isLoading,
    bool? isPlaying,
    String? activeTrackId,
    String? errorMessage,
  }) {
    return ForgottenFavoritesState(
      playlist: playlist ?? this.playlist,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      activeTrackId: activeTrackId ?? this.activeTrackId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ============================================================================
// 4. Persistence Engine (Self-Contained SharedPreferences)
// ============================================================================

/// Storage interface adhering to SharedPreferences contract.
abstract class ForgottenFavoritesPrefsStorage {
  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<bool> remove(String key);
  Future<bool> clear();
}

/// Disk-backed key-value store for Forgotten Favorites settings.
class ForgottenFavoritesSharedPreferences
    implements ForgottenFavoritesPrefsStorage {
  static final ForgottenFavoritesSharedPreferences _instance =
      ForgottenFavoritesSharedPreferences._internal();
  factory ForgottenFavoritesSharedPreferences() => _instance;
  ForgottenFavoritesSharedPreferences._internal();

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
        _cacheFile = File('${dir.path}/forgotten_favorites_settings.json');
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
    } catch (_) {}
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
  Future<int?> getInt(String key) async {
    await _ensureLoaded();
    final val = _memoryCache[key];
    return val is int ? val : null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    await _flushToDisk();
    return true;
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
  Future<bool?> getBool(String key) async {
    await _ensureLoaded();
    final val = _memoryCache[key];
    return val is bool ? val : null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
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
// 5. Service: ForgottenFavoritesService
// ============================================================================

/// High-performance algorithmic service that scans the user's liked tracks and
/// listening history, filters songs with zero plays in >= 60 days, and ranks
/// them by emotional nostalgia value.
class ForgottenFavoritesService {
  const ForgottenFavoritesService._();

  /// Calculates an emotional nostalgia score for a dormant track based on:
  /// - Time dormant (days since last played)
  /// - Historical play count (past devotion)
  /// - Average completion ratio (listening quality)
  static double calculateNostalgiaScore({
    required int? daysSinceLastPlayed,
    required int historicalPlayCount,
    required double averageCompletionRatio,
    required int thresholdDays,
  }) {
    if (daysSinceLastPlayed != null) {
      final safeDays = math.max(thresholdDays, daysSinceLastPlayed);
      final daysRatio = safeDays / math.max(1, thresholdDays);
      // Logarithmic scaling rewards deep dormancy with diminishing returns
      final dormancyScore =
          (math.log(daysRatio) / math.ln2) * 22.0 + (safeDays * 0.15);
      final affinityScore = historicalPlayCount * 8.5;
      final devotionScore = averageCompletionRatio * 15.0;
      return (dormancyScore + affinityScore + devotionScore).clamp(0.0, 1000.0);
    } else {
      // Unplayed gem bonus: initial curiosity score
      return (thresholdDays * 0.35) + 20.0;
    }
  }

  /// Evaluates liked tracks and play history to identify and rank forgotten favorites.
  static List<ForgottenFavoriteTrack> filterAndRankTracks({
    required List<Track> likedTracks,
    required List<HistoryItem> history,
    DateTime? referenceTime,
    ForgottenFavoritesConfig config = const ForgottenFavoritesConfig(),
  }) {
    final now = referenceTime ?? DateTime.now();
    final thresholdDuration = Duration(days: config.thresholdDays);
    final cutoffDate = now.subtract(thresholdDuration);

    // 1. Group listening history by track ID
    final Map<String, List<HistoryItem>> historyByTrack = {};
    for (final item in history) {
      if (item.completedRatio >= config.minCompletionRatio) {
        historyByTrack.putIfAbsent(item.track.id, () => []).add(item);
      }
    }

    final candidateList = <({
      Track track,
      int? daysSinceLastPlayed,
      DateTime? lastPlayedAt,
      int playCount,
      double avgCompletion,
      double score,
      ForgottenTier tier,
    })>[];

    // 2. Scan every liked track
    for (final track in likedTracks) {
      // Verify track is favorited/liked
      if (!track.isLiked) continue;

      if (config.excludeUnavailable && track.isUnavailable) continue;

      final trackHistory = historyByTrack[track.id] ?? const [];

      if (trackHistory.isNotEmpty) {
        // Find most recent play
        DateTime latestPlay = trackHistory.first.playedAt;
        double totalRatio = 0.0;
        for (final h in trackHistory) {
          totalRatio += h.completedRatio;
          if (h.playedAt.isAfter(latestPlay)) {
            latestPlay = h.playedAt;
          }
        }

        // If played after cutoff, user listened within the last 60 days!
        // It has > 0 plays in the threshold window, so NOT forgotten.
        if (latestPlay.isAfter(cutoffDate)) {
          continue;
        }

        final daysSince = now.difference(latestPlay).inDays;
        if (daysSince < config.thresholdDays) {
          continue;
        }

        final playCount = trackHistory.length;
        final avgRatio = totalRatio / playCount;
        final score = calculateNostalgiaScore(
          daysSinceLastPlayed: daysSince,
          historicalPlayCount: playCount,
          averageCompletionRatio: avgRatio,
          thresholdDays: config.thresholdDays,
        );
        final tier = ForgottenTier.fromDaysAndPlays(daysSince, playCount);

        candidateList.add((
          track: track,
          daysSinceLastPlayed: daysSince,
          lastPlayedAt: latestPlay,
          playCount: playCount,
          avgCompletion: avgRatio,
          score: score,
          tier: tier,
        ));
      } else {
        // Zero lifetime plays in history
        if (!config.includeNeverPlayed) continue;

        final score = calculateNostalgiaScore(
          daysSinceLastPlayed: null,
          historicalPlayCount: 0,
          averageCompletionRatio: 1.0,
          thresholdDays: config.thresholdDays,
        );
        final tier = ForgottenTier.unplayedGem;

        candidateList.add((
          track: track,
          daysSinceLastPlayed: null,
          lastPlayedAt: null,
          playCount: 0,
          avgCompletion: 1.0,
          score: score,
          tier: tier,
        ));
      }
    }

    // 3. Sort candidates according to ranking mode
    switch (config.rankingMode) {
      case ForgottenFavoritesRankingMode.nostalgiaScore:
        candidateList.sort((a, b) {
          final cmp = b.score.compareTo(a.score);
          if (cmp != 0) return cmp;
          final daysA = a.daysSinceLastPlayed ?? 0;
          final daysB = b.daysSinceLastPlayed ?? 0;
          return daysB.compareTo(daysA);
        });
        break;

      case ForgottenFavoritesRankingMode.longestForgotten:
        candidateList.sort((a, b) {
          final daysA = a.daysSinceLastPlayed;
          final daysB = b.daysSinceLastPlayed;
          if (daysA == null && daysB == null) return 0;
          if (daysA == null) return 1; // Never played at end
          if (daysB == null) return -1;
          final cmp = daysB.compareTo(daysA);
          return cmp != 0 ? cmp : b.score.compareTo(a.score);
        });
        break;

      case ForgottenFavoritesRankingMode.mostPlayedPast:
        candidateList.sort((a, b) {
          final cmp = b.playCount.compareTo(a.playCount);
          if (cmp != 0) return cmp;
          return b.score.compareTo(a.score);
        });
        break;

      case ForgottenFavoritesRankingMode.randomNostalgia:
        final random = math.Random(1337);
        candidateList.shuffle(random);
        break;
    }

    // 4. Truncate to maxTracks and assign rank numbers
    final limit = math.min(config.maxTracks, candidateList.length);
    final ranked = <ForgottenFavoriteTrack>[];

    for (int i = 0; i < limit; i++) {
      final c = candidateList[i];
      ranked.add(ForgottenFavoriteTrack(
        track: c.track,
        rank: i + 1,
        daysSinceLastPlayed: c.daysSinceLastPlayed,
        lastPlayedAt: c.lastPlayedAt,
        historicalPlayCount: c.playCount,
        averageCompletionRatio: c.avgCompletion,
        nostalgiaScore: c.score,
        tier: c.tier,
      ));
    }

    return ranked;
  }

  /// Computes aggregate statistics across the ranked tracks.
  static ForgottenFavoritesStats computeStats(List<ForgottenFavoriteTrack> tracks) {
    if (tracks.isEmpty) {
      return const ForgottenFavoritesStats(
        totalForgottenCount: 0,
        averageDaysDormant: 0,
        maxDaysDormant: 0,
        neverPlayedCount: 0,
        totalDuration: Duration.zero,
        tierBreakdown: {},
      );
    }

    int totalDays = 0;
    int measuredCount = 0;
    int maxDays = 0;
    int neverPlayed = 0;
    Duration duration = Duration.zero;
    final Map<ForgottenTier, int> breakdown = {};

    for (final t in tracks) {
      duration += t.track.duration;
      breakdown[t.tier] = (breakdown[t.tier] ?? 0) + 1;
      if (t.daysSinceLastPlayed != null) {
        totalDays += t.daysSinceLastPlayed!;
        measuredCount++;
        if (t.daysSinceLastPlayed! > maxDays) {
          maxDays = t.daysSinceLastPlayed!;
        }
      } else {
        neverPlayed++;
      }
    }

    final avg = measuredCount > 0 ? (totalDays / measuredCount.toDouble()) : 0.0;

    return ForgottenFavoritesStats(
      totalForgottenCount: tracks.length,
      averageDaysDormant: avg,
      maxDaysDormant: maxDays,
      neverPlayedCount: neverPlayed,
      totalDuration: duration,
      tierBreakdown: breakdown,
    );
  }

  /// Generates the complete [ForgottenFavoritesPlaylist] from pure domain data.
  static ForgottenFavoritesPlaylist generatePlaylist({
    required List<Track> likedTracks,
    required List<HistoryItem> history,
    DateTime? referenceTime,
    ForgottenFavoritesConfig config = const ForgottenFavoritesConfig(),
  }) {
    final ranked = filterAndRankTracks(
      likedTracks: likedTracks,
      history: history,
      referenceTime: referenceTime,
      config: config,
    );
    final stats = computeStats(ranked);

    return ForgottenFavoritesPlaylist(
      rankedTracks: ranked,
      stats: stats,
      config: config,
      generatedAt: referenceTime ?? DateTime.now(),
    );
  }

  /// Generates the smart playlist by querying Drift database tables directly.
  static Future<ForgottenFavoritesPlaylist> generateFromDatabase(
    AppDatabase db, {
    ForgottenFavoritesConfig config = const ForgottenFavoritesConfig(),
    DateTime? referenceTime,
  }) async {
    final now = referenceTime ?? DateTime.now();

    // Query all liked tracks
    final trackRows = await (db.select(db.tracks)
          ..where((t) => t.isLiked.equals(true)))
        .get();

    final likedTracks = trackRows.map((r) {
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
    }).toList();

    // Query play histories joined with tracks
    final historyRows = await (db.select(db.playHistories).join([
      drift.innerJoin(
        db.tracks,
        db.tracks.id.equalsExp(db.playHistories.trackId),
      ),
    ])).get();

    final historyItems = historyRows.map((row) {
      final ph = row.readTable(db.playHistories);
      final tr = row.readTable(db.tracks);
      final track = Track(
        id: tr.id,
        sourceId: tr.sourceId,
        title: tr.title,
        artist: tr.artist,
        album: tr.album,
        duration: Duration(milliseconds: tr.durationMs),
        coverUrl: tr.coverUrl,
        matchConfidence: tr.matchConfidence,
        isLiked: tr.isLiked,
        isUnavailable: tr.isUnavailable,
      );

      return HistoryItem(
        id: ph.id,
        track: track,
        playedAt: DateTime.fromMillisecondsSinceEpoch(ph.playedAt),
        completedRatio: ph.completedRatio,
      );
    }).toList();

    return generatePlaylist(
      likedTracks: likedTracks,
      history: historyItems,
      referenceTime: now,
      config: config,
    );
  }

  /// Exports the smart playlist into a permanent user playlist in ILibraryRepository.
  static Future<Playlist> exportToLibrary({
    required ILibraryRepository repo,
    required ForgottenFavoritesPlaylist playlist,
    String? customName,
  }) async {
    final name = customName ??
        'Forgotten Favorites (${playlist.config.thresholdDays}+ days dormant)';
    final created = await repo.createPlaylist(
      name,
      description:
          'Snapshot of forgotten favorites generated on ${playlist.generatedAt.toIso8601String().split('T').first}',
    );

    if (playlist.tracks.isNotEmpty) {
      await repo.addTracksToPlaylist(created.id, playlist.tracks);
    }

    return created;
  }
}

// ============================================================================
// 6. Riverpod State Management & Providers
// ============================================================================

/// Manages user configuration for Forgotten Favorites.
class ForgottenFavoritesConfigNotifier
    extends StateNotifier<ForgottenFavoritesConfig> {
  final ForgottenFavoritesPrefsStorage _prefs;

  ForgottenFavoritesConfigNotifier([ForgottenFavoritesPrefsStorage? prefs])
      : _prefs = prefs ?? ForgottenFavoritesSharedPreferences(),
        super(const ForgottenFavoritesConfig()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final threshold = await _prefs.getInt(kForgottenFavPrefThresholdDays);
      final maxTracks = await _prefs.getInt(kForgottenFavPrefMaxTracks);
      final modeStr = await _prefs.getString(kForgottenFavPrefRankingMode);
      final includeUnplayed =
          await _prefs.getBool(kForgottenFavPrefIncludeNeverPlayed);

      state = state.copyWith(
        thresholdDays: threshold ?? state.thresholdDays,
        maxTracks: maxTracks ?? state.maxTracks,
        rankingMode: modeStr != null
            ? ForgottenFavoritesRankingMode.fromString(modeStr)
            : state.rankingMode,
        includeNeverPlayed: includeUnplayed ?? state.includeNeverPlayed,
      );
    } catch (_) {}
  }

  Future<void> updateConfig(ForgottenFavoritesConfig next) async {
    state = next;
    try {
      await _prefs.setInt(kForgottenFavPrefThresholdDays, next.thresholdDays);
      await _prefs.setInt(kForgottenFavPrefMaxTracks, next.maxTracks);
      await _prefs.setString(kForgottenFavPrefRankingMode, next.rankingMode.name);
      await _prefs.setBool(
          kForgottenFavPrefIncludeNeverPlayed, next.includeNeverPlayed);
    } catch (_) {}
  }

  Future<void> setThresholdDays(int days) =>
      updateConfig(state.copyWith(thresholdDays: days));

  Future<void> setRankingMode(ForgottenFavoritesRankingMode mode) =>
      updateConfig(state.copyWith(rankingMode: mode));

  Future<void> setMaxTracks(int max) =>
      updateConfig(state.copyWith(maxTracks: max));

  Future<void> toggleIncludeNeverPlayed() =>
      updateConfig(state.copyWith(includeNeverPlayed: !state.includeNeverPlayed));
}

/// Provider for user Forgotten Favorites configuration.
final forgottenFavoritesConfigProvider = StateNotifierProvider<
    ForgottenFavoritesConfigNotifier, ForgottenFavoritesConfig>((ref) {
  return ForgottenFavoritesConfigNotifier();
});

/// Future provider dynamically generating the [ForgottenFavoritesPlaylist].
final forgottenFavoritesPlaylistProvider =
    FutureProvider<ForgottenFavoritesPlaylist>((ref) async {
  final config = ref.watch(forgottenFavoritesConfigProvider);

  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}

  if (db != null) {
    try {
      return await ForgottenFavoritesService.generateFromDatabase(db, config: config);
    } catch (_) {}
  }

  // Fallback to library repository
  ILibraryRepository? repo;
  try {
    repo = ref.watch(libraryRepositoryProvider);
  } catch (_) {}

  if (repo != null) {
    try {
      final liked = await repo.getLikedTracks();
      final history = await repo.watchPlayHistory(limit: 500).first;
      return ForgottenFavoritesService.generatePlaylist(
        likedTracks: liked,
        history: history,
        config: config,
      );
    } catch (_) {}
  }

  return ForgottenFavoritesPlaylist(
    rankedTracks: const [],
    stats: const ForgottenFavoritesStats(
      totalForgottenCount: 0,
      averageDaysDormant: 0,
      maxDaysDormant: 0,
      neverPlayedCount: 0,
      totalDuration: Duration.zero,
      tierBreakdown: {},
    ),
    config: config,
    generatedAt: DateTime.now(),
  );
});

/// Convenience provider extracting the ranked tracks list.
final forgottenFavoritesTracksProvider =
    FutureProvider<List<Track>>((ref) async {
  final pl = await ref.watch(forgottenFavoritesPlaylistProvider.future);
  return pl.tracks;
});

/// Detects whether any forgotten favorite track is actively playing.
final isForgottenFavoritesActiveProvider = Provider<bool>((ref) {
  final currentTrack = ref.watch(currentTrackProvider).value;
  if (currentTrack == null) return false;

  final tracksAsync = ref.watch(forgottenFavoritesTracksProvider);
  return tracksAsync.maybeWhen(
    data: (tracks) => tracks.any((t) => t.id == currentTrack.id),
    orElse: () => false,
  );
});

/// Controller handling Quick Play actions for Forgotten Favorites.
class ForgottenFavoritesQuickPlayController extends ChangeNotifier {
  final Ref _ref;
  bool _isLoading = false;

  ForgottenFavoritesQuickPlayController(this._ref);

  bool get isLoading => _isLoading;

  /// Starts or toggles playback of the Forgotten Favorites playlist.
  Future<void> quickPlay({int startIndex = 0, bool shuffle = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      SoftifyAudioHandler? handler;
      try {
        handler = _ref.read(audioHandlerProvider);
      } catch (_) {}

      if (handler == null) return;

      final isPlaying = _ref.read(isPlayingProvider);
      final isFavActive = _ref.read(isForgottenFavoritesActiveProvider);

      // If active and playing, toggle pause
      if (isFavActive && isPlaying && startIndex == 0 && !shuffle) {
        await handler.pause();
        return;
      }

      // If active and paused, resume
      if (isFavActive && !isPlaying && startIndex == 0 && !shuffle) {
        await handler.play();
        return;
      }

      final playlist = await _ref.read(forgottenFavoritesPlaylistProvider.future);
      if (playlist.isEmpty) return;

      List<Track> queue = List<Track>.from(playlist.tracks);
      if (shuffle) {
        queue.shuffle();
      }

      final safeIndex = startIndex.clamp(0, queue.length - 1);
      final targetTrack = queue[safeIndex];

      await handler.playTrack(
        targetTrack,
        queue: queue,
        startIndex: safeIndex,
      );
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// Provider for the Forgotten Favorites quick play controller.
final forgottenFavoritesQuickPlayProvider =
    ChangeNotifierProvider<ForgottenFavoritesQuickPlayController>((ref) {
  return ForgottenFavoritesQuickPlayController(ref);
});

/// High-level state notifier orchestrating the UI experience.
class ForgottenFavoritesNotifier
    extends StateNotifier<ForgottenFavoritesState> {
  final Ref _ref;

  ForgottenFavoritesNotifier(this._ref)
      : super(const ForgottenFavoritesState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final pl = await _ref.refresh(forgottenFavoritesPlaylistProvider.future);
      state = state.copyWith(
        playlist: pl,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setThresholdDays(int days) {
    _ref.read(forgottenFavoritesConfigProvider.notifier).setThresholdDays(days);
    refresh();
  }

  void setRankingMode(ForgottenFavoritesRankingMode mode) {
    _ref.read(forgottenFavoritesConfigProvider.notifier).setRankingMode(mode);
    refresh();
  }

  Future<void> playAll({bool shuffle = false}) async {
    await _ref
        .read(forgottenFavoritesQuickPlayProvider)
        .quickPlay(shuffle: shuffle);
  }

  Future<void> playTrack(Track track) async {
    final pl = state.playlist;
    final tracks = pl?.tracks ?? [track];
    final index = tracks.indexWhere((t) => t.id == track.id);
    await _ref.read(forgottenFavoritesQuickPlayProvider).quickPlay(
          startIndex: index >= 0 ? index : 0,
        );
  }

  Future<Playlist?> exportToLibrary({String? customName}) async {
    final pl = state.playlist;
    if (pl == null || pl.isEmpty) return null;

    try {
      final repo = _ref.read(libraryRepositoryProvider);
      return await ForgottenFavoritesService.exportToLibrary(
        repo: repo,
        playlist: pl,
        customName: customName,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Root state notifier provider for Forgotten Favorites.
final forgottenFavoritesProvider =
    StateNotifierProvider<ForgottenFavoritesNotifier, ForgottenFavoritesState>(
        (ref) {
  return ForgottenFavoritesNotifier(ref);
});

// ============================================================================
// 7. UI Widgets: ForgottenFavoritesCard & Detail Sheet
// ============================================================================

/// Signature Material 3 card presenting the user's "Forgotten Favorites"
/// smart playlist with dormancy statistics, preview tracks, and an instant
/// 1-tap Quick Play button.
class ForgottenFavoritesCard extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onQuickPlay;
  final EdgeInsetsGeometry? margin;
  final bool showMiniTrackList;
  final int maxMiniTracks;
  final String? customTitle;

  const ForgottenFavoritesCard({
    super.key,
    this.onTap,
    this.onQuickPlay,
    this.margin,
    this.showMiniTrackList = true,
    this.maxMiniTracks = 3,
    this.customTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final playlistAsync = ref.watch(forgottenFavoritesPlaylistProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isFavActive = ref.watch(isForgottenFavoritesActiveProvider);
    final quickPlayCtrl = ref.watch(forgottenFavoritesQuickPlayProvider);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(
          color: isFavActive && isPlaying
              ? tokens.accent.withValues(alpha: 0.5)
              : tokens.divider.withValues(alpha: 0.15),
          width: isFavActive && isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          onTap: onTap ?? () => _showDetailSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: playlistAsync.when(
              loading: () => _buildLoadingState(tokens),
              error: (err, _) => _buildErrorState(context, ref, tokens),
              data: (playlist) {
                if (playlist.isEmpty) {
                  return _buildEmptyState(context, ref, tokens, playlist);
                }
                return _buildContent(
                  context: context,
                  ref: ref,
                  playlist: playlist,
                  tokens: tokens,
                  isPlaying: isPlaying,
                  isFavActive: isFavActive,
                  isLoadingPlay: quickPlayCtrl.isLoading,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ForgottenFavoritesDetailSheet(),
    );
  }

  Widget _buildLoadingState(AppTokens tokens) {
    return SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: tokens.accent,
        ),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, WidgetRef ref, AppTokens tokens) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: tokens.error, size: 24),
            const SizedBox(height: 8),
            Text(
              'Unable to load Forgotten Favorites',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
            TextButton(
              onPressed: () => ref.refresh(forgottenFavoritesPlaylistProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref,
      AppTokens tokens, ForgottenFavoritesPlaylist playlist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(tokens, playlist, context),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
              child: Icon(Icons.check_circle_outline_rounded,
                  color: tokens.accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Caught Up!',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All your favorited songs have been listened to within the last ${playlist.config.thresholdDays} days.',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(
      AppTokens tokens, ForgottenFavoritesPlaylist playlist, BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: tokens.accent,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                'SMART PLAYLIST',
                style: TextStyle(
                  color: tokens.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (playlist.isNotEmpty)
          Text(
            '${playlist.length} Tracks',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          tooltip: 'Configure Threshold',
          visualDensity: VisualDensity.compact,
          onPressed: () => _showDetailSheet(context),
        ),
      ],
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required WidgetRef ref,
    required ForgottenFavoritesPlaylist playlist,
    required AppTokens tokens,
    required bool isPlaying,
    required bool isFavActive,
    required bool isLoadingPlay,
  }) {
    final topRanked = playlist.topRanked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(tokens, playlist, context),
        const SizedBox(height: 12),

        // Main info row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildArtworkDisplay(playlist, tokens, isPlaying && isFavActive),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customTitle ?? playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.length} favorites dormant for >= ${playlist.config.thresholdDays} days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (topRanked != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: topRanked.tier.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            topRanked.tier.label,
                            style: TextStyle(
                              color: topRanked.tier.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '#1 ${topRanked.track.title} • ${topRanked.track.artist}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildQuickPlayButton(
              context: context,
              ref: ref,
              tokens: tokens,
              playlist: playlist,
              isPlaying: isPlaying,
              isFavActive: isFavActive,
              isLoading: isLoadingPlay,
            ),
          ],
        ),

        // Mini track preview list
        if (showMiniTrackList && playlist.rankedTracks.length > 1) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          ...playlist.rankedTracks
              .skip(0)
              .take(maxMiniTracks)
              .map((item) => _buildMiniTrackRow(item, tokens, ref)),
        ],

        // Bottom stats bar
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.surfaceHighlight.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
          child: Row(
            children: [
              Icon(Icons.timelapse_rounded, size: 14, color: tokens.textMuted),
              const SizedBox(width: 6),
              Text(
                playlist.formattedDuration,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.history_toggle_off_rounded,
                  size: 14, color: tokens.textMuted),
              const SizedBox(width: 6),
              Text(
                'Avg ${playlist.stats.formattedAverageDormancy} dormant',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                playlist.config.rankingMode.label,
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTrackRow(
      ForgottenFavoriteTrack item, AppTokens tokens, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        onTap: () {
          ref.read(forgottenFavoritesProvider.notifier).playTrack(item.track);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Row(
            children: [
              Text(
                '#${item.rank}',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.track.title} • ${item.track.artist}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: item.tier.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.formattedDormancy,
                  style: TextStyle(
                    color: item.tier.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkDisplay(
    ForgottenFavoritesPlaylist playlist,
    AppTokens tokens,
    bool isActivelyPlaying,
  ) {
    final covers = playlist.previewCovers;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            gradient: LinearGradient(
              colors: [
                tokens.accent.withValues(alpha: 0.4),
                tokens.surfaceElevated,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: covers.length >= 4
              ? Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: AppNetworkImage(
                              imageUrl: covers[0],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Expanded(
                            child: AppNetworkImage(
                              imageUrl: covers[1],
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
                              imageUrl: covers[2],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Expanded(
                            child: AppNetworkImage(
                              imageUrl: covers[3],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : covers.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: covers.first,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Icon(
                        Icons.history_toggle_off_rounded,
                        color: tokens.accent,
                        size: 32,
                      ),
                    ),
        ),
        if (isActivelyPlaying)
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Center(
              child: AnimatedMusicWaveIndicator(
                isPlaying: true,
                color: tokens.accent,
                size: 22,
                barCount: 4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickPlayButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppTokens tokens,
    required ForgottenFavoritesPlaylist playlist,
    required bool isPlaying,
    required bool isFavActive,
    required bool isLoading,
  }) {
    final isCurrentlyPlayingThis = isFavActive && isPlaying;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: isCurrentlyPlayingThis
            ? 'Pause Forgotten Favorites'
            : 'Quick Play Forgotten Favorites',
        child: InkWell(
          key: const Key('forgotten_favorites_quick_play_button'),
          borderRadius: BorderRadius.circular(tokens.radiusFull),
          onTap: playlist.isEmpty
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  if (onQuickPlay != null) {
                    onQuickPlay!();
                  } else {
                    ref.read(forgottenFavoritesQuickPlayProvider).quickPlay();
                  }
                },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: playlist.isEmpty
                  ? tokens.surfaceHighlight
                  : tokens.accent,
              boxShadow: playlist.isEmpty
                  ? null
                  : [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.textOnAccent,
                      ),
                    )
                  : Icon(
                      isCurrentlyPlayingThis
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: tokens.textOnAccent,
                      size: 28,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 8. Detailed Modal Sheet: ForgottenFavoritesDetailSheet
// ============================================================================

/// Full Material 3 modal sheet showcasing the complete list of forgotten favorites,
/// dormancy threshold filters (30d, 60d, 90d, 180d), ranking mode selector,
/// and permanent library export button.
class ForgottenFavoritesDetailSheet extends ConsumerWidget {
  const ForgottenFavoritesDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(forgottenFavoritesProvider);
    final playlist = state.playlist;
    final config = ref.watch(forgottenFavoritesConfigProvider);
    final notifier = ref.read(forgottenFavoritesProvider.notifier);
    final isFavPlaying = ref.watch(isForgottenFavoritesActiveProvider) &&
        ref.watch(isPlayingProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: tokens.cardShadow,
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                      ),
                      child: Icon(Icons.history_toggle_off_rounded,
                          color: tokens.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Forgotten Favorites',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${playlist?.length ?? 0} tracks dormant for >= ${config.thresholdDays} days',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Threshold Selector Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Threshold: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      for (final days in [30, 60, 90, 180])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$days+ Days'),
                            selected: config.thresholdDays == days,
                            onSelected: (_) => notifier.setThresholdDays(days),
                            selectedColor: tokens.accent.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Action Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(isFavPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        label: Text(isFavPlaying ? 'Pause' : 'Play All'),
                        onPressed: playlist == null || playlist.isEmpty
                            ? null
                            : () => notifier.playAll(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.shuffle_rounded),
                      tooltip: 'Shuffle Play',
                      onPressed: playlist == null || playlist.isEmpty
                          ? null
                          : () => notifier.playAll(shuffle: true),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.playlist_add_rounded),
                      tooltip: 'Save as Playlist',
                      onPressed: playlist == null || playlist.isEmpty
                          ? null
                          : () async {
                              final created = await notifier.exportToLibrary();
                              if (context.mounted && created != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved "${created.name}" to Library!'),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Track List
              Expanded(
                child: state.isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: tokens.accent))
                    : playlist == null || playlist.isEmpty
                        ? Center(
                            child: Text(
                              'No favorited tracks match the ${config.thresholdDays}-day dormancy filter.',
                              style: TextStyle(color: tokens.textMuted),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: playlist.rankedTracks.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 64),
                            itemBuilder: (context, index) {
                              final item = playlist.rankedTracks[index];
                              return _buildTrackListTile(
                                  item, tokens, notifier, ref);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackListTile(
    ForgottenFavoriteTrack item,
    AppTokens tokens,
    ForgottenFavoritesNotifier notifier,
    WidgetRef ref,
  ) {
    final currentTrack = ref.watch(currentTrackProvider).value;
    final isTrackActive = currentTrack?.id == item.track.id;

    return ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.track.coverUrl != null
                ? AppNetworkImage(
                    imageUrl: item.track.coverUrl,
                    fit: BoxFit.cover,
                  )
                : Icon(Icons.music_note_rounded,
                    color: tokens.textMuted, size: 20),
          ),
          if (isTrackActive)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              child: Center(
                child: AnimatedMusicWaveIndicator(
                  isPlaying: true,
                  color: tokens.accent,
                  size: 16,
                  barCount: 3,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        item.track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isTrackActive ? tokens.accent : tokens.textPrimary,
          fontWeight: isTrackActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              '${item.track.artist} • ${item.formattedSubtitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: item.tier.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          item.tier.label,
          style: TextStyle(
            color: item.tier.color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      onTap: () => notifier.playTrack(item.track),
    );
  }
}
