// ============================================================================
// Softify Quality of Life (QoL): Smart Playlist - Heavy Rotation (Top 50)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/database/app_database.dart';
import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/animated_music_wave_indicator.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';

// ============================================================================
// 1. Enums & Trend Models
// ============================================================================

/// Trend of a track's position in the Heavy Rotation chart compared to a
/// prior evaluation window.
enum HeavyRotationTrend {
  rising('Rising', Icons.trending_up_rounded),
  steady('Steady', Icons.trending_flat_rounded),
  falling('Falling', Icons.trending_down_rounded),
  newEntry('New Entry', Icons.auto_awesome_rounded);

  final String label;
  final IconData icon;

  const HeavyRotationTrend(this.label, this.icon);

  Color color(AppTokens tokens) {
    switch (this) {
      case HeavyRotationTrend.rising:
        return const Color(0xFF4ADE80); // Emerald Green
      case HeavyRotationTrend.steady:
        return tokens.textMuted;
      case HeavyRotationTrend.falling:
        return tokens.error;
      case HeavyRotationTrend.newEntry:
        return tokens.accent;
    }
  }
}

/// Dynamic algorithm modes for ranking tracks in the Heavy Rotation playlist.
enum HeavyRotationRankingMode {
  mostPlayed('Most Played', 'Ranked strictly by play count over the last 30 days', Icons.repeat_rounded),
  weightedRecency('Recency-Weighted', 'Recent plays within 30 days carry higher weight than older plays', Icons.bolt_rounded),
  totalDuration('Time Spent', 'Ranked by total cumulative duration listened', Icons.timer_rounded);

  final String label;
  final String description;
  final IconData icon;

  const HeavyRotationRankingMode(this.label, this.description, this.icon);

  static HeavyRotationRankingMode fromString(String? val) {
    if (val == null) return HeavyRotationRankingMode.mostPlayed;
    for (final mode in HeavyRotationRankingMode.values) {
      if (mode.name == val) return mode;
    }
    return HeavyRotationRankingMode.mostPlayed;
  }
}

// ============================================================================
// 2. Data Models
// ============================================================================

/// Represents an individual listening log entry for ranking calculations.
@immutable
class ListeningLogEntry {
  final String trackId;
  final DateTime playedAt;
  final double completedRatio;
  final Duration? duration;
  final Track? track;

  const ListeningLogEntry({
    required this.trackId,
    required this.playedAt,
    this.completedRatio = 1.0,
    this.duration,
    this.track,
  });

  factory ListeningLogEntry.fromDbRow(
    PlayHistoryRow ph, {
    TrackRow? tr,
  }) {
    Track? track;
    if (tr != null) {
      track = Track(
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
    }

    return ListeningLogEntry(
      trackId: ph.trackId,
      playedAt: DateTime.fromMillisecondsSinceEpoch(ph.playedAt),
      completedRatio: ph.completedRatio.clamp(0.0, 1.0),
      duration: track?.duration,
      track: track,
    );
  }

  factory ListeningLogEntry.fromTrack(
    Track track, {
    DateTime? playedAt,
    double completedRatio = 1.0,
  }) {
    return ListeningLogEntry(
      trackId: track.id,
      playedAt: playedAt ?? DateTime.now(),
      completedRatio: completedRatio.clamp(0.0, 1.0),
      duration: track.duration,
      track: track,
    );
  }

  Map<String, dynamic> toMap() => {
        'track_id': trackId,
        'played_at': playedAt.millisecondsSinceEpoch,
        'completed_ratio': completedRatio,
        'duration_ms': duration?.inMilliseconds,
        if (track != null) 'track': track!.toMap(),
      };

  factory ListeningLogEntry.fromMap(Map<String, dynamic> map) {
    return ListeningLogEntry(
      trackId: map['track_id'] as String,
      playedAt: DateTime.fromMillisecondsSinceEpoch(map['played_at'] as int),
      completedRatio: (map['completed_ratio'] as num?)?.toDouble() ?? 1.0,
      duration: map['duration_ms'] != null
          ? Duration(milliseconds: map['duration_ms'] as int)
          : null,
      track: map['track'] != null
          ? Track.fromMap(map['track'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Represents a ranked track in the Heavy Rotation Top 50.
@immutable
class HeavyRotationRankedTrack {
  final int rank;
  final Track track;
  final int playCount;
  final double score;
  final Duration totalListenTime;
  final double completionRateAvg;
  final DateTime lastPlayed;
  final HeavyRotationTrend trend;
  final int? previousRank;

  const HeavyRotationRankedTrack({
    required this.rank,
    required this.track,
    required this.playCount,
    required this.score,
    required this.totalListenTime,
    required this.completionRateAvg,
    required this.lastPlayed,
    this.trend = HeavyRotationTrend.newEntry,
    this.previousRank,
  });

  String get formattedPlayCount =>
      playCount == 1 ? '1 play' : '$playCount plays';

  String get formattedListenTime {
    final minutes = totalListenTime.inMinutes;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
  }

  bool get isTopThree => rank <= 3;
  bool get isNumberOne => rank == 1;

  HeavyRotationRankedTrack copyWith({
    int? rank,
    Track? track,
    int? playCount,
    double? score,
    Duration? totalListenTime,
    double? completionRateAvg,
    DateTime? lastPlayed,
    HeavyRotationTrend? trend,
    int? previousRank,
  }) {
    return HeavyRotationRankedTrack(
      rank: rank ?? this.rank,
      track: track ?? this.track,
      playCount: playCount ?? this.playCount,
      score: score ?? this.score,
      totalListenTime: totalListenTime ?? this.totalListenTime,
      completionRateAvg: completionRateAvg ?? this.completionRateAvg,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      trend: trend ?? this.trend,
      previousRank: previousRank ?? this.previousRank,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeavyRotationRankedTrack &&
          runtimeType == other.runtimeType &&
          rank == other.rank &&
          track.id == other.track.id &&
          playCount == other.playCount;

  @override
  int get hashCode => Object.hash(rank, track.id, playCount);

  @override
  String toString() =>
      'HeavyRotationRankedTrack(#$rank ${track.title} by ${track.artist}, plays: $playCount, score: ${score.toStringAsFixed(1)})';
}

/// User preferences and tuning parameters for the Heavy Rotation algorithm.
@immutable
class HeavyRotationConfig {
  final int windowDays;
  final int maxTracks;
  final double minCompletionRatio;
  final HeavyRotationRankingMode rankingMode;
  final bool fallbackToLikedWhenEmpty;
  final bool excludeUnavailable;

  const HeavyRotationConfig({
    this.windowDays = 30,
    this.maxTracks = 50,
    this.minCompletionRatio = 0.25,
    this.rankingMode = HeavyRotationRankingMode.mostPlayed,
    this.fallbackToLikedWhenEmpty = true,
    this.excludeUnavailable = true,
  });

  HeavyRotationConfig copyWith({
    int? windowDays,
    int? maxTracks,
    double? minCompletionRatio,
    HeavyRotationRankingMode? rankingMode,
    bool? fallbackToLikedWhenEmpty,
    bool? excludeUnavailable,
  }) {
    return HeavyRotationConfig(
      windowDays: windowDays ?? this.windowDays,
      maxTracks: maxTracks ?? this.maxTracks,
      minCompletionRatio: minCompletionRatio ?? this.minCompletionRatio,
      rankingMode: rankingMode ?? this.rankingMode,
      fallbackToLikedWhenEmpty:
          fallbackToLikedWhenEmpty ?? this.fallbackToLikedWhenEmpty,
      excludeUnavailable: excludeUnavailable ?? this.excludeUnavailable,
    );
  }

  Map<String, dynamic> toMap() => {
        'window_days': windowDays,
        'max_tracks': maxTracks,
        'min_completion_ratio': minCompletionRatio,
        'ranking_mode': rankingMode.name,
        'fallback_to_liked': fallbackToLikedWhenEmpty,
        'exclude_unavailable': excludeUnavailable,
      };

  factory HeavyRotationConfig.fromMap(Map<String, dynamic> map) {
    return HeavyRotationConfig(
      windowDays: (map['window_days'] as num?)?.toInt() ?? 30,
      maxTracks: (map['max_tracks'] as num?)?.toInt() ?? 50,
      minCompletionRatio:
          (map['min_completion_ratio'] as num?)?.toDouble() ?? 0.25,
      rankingMode: HeavyRotationRankingMode.fromString(
          map['ranking_mode'] as String?),
      fallbackToLikedWhenEmpty:
          (map['fallback_to_liked'] as bool?) ?? true,
      excludeUnavailable:
          (map['exclude_unavailable'] as bool?) ?? true,
    );
  }
}

/// Complete generated Smart Playlist: Heavy Rotation (Top 50).
@immutable
class HeavyRotationPlaylist {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final DateTime generatedAt;
  final List<HeavyRotationRankedTrack> rankedTracks;
  final HeavyRotationConfig config;

  const HeavyRotationPlaylist({
    this.id = 'smart_playlist_heavy_rotation_top_50',
    this.title = 'Heavy Rotation',
    this.subtitle = 'Top 50 • Last 30 Days',
    this.description =
        'Your most played tracks over the last 30 days, updated dynamically based on your listening habits.',
    required this.generatedAt,
    required this.rankedTracks,
    this.config = const HeavyRotationConfig(),
  });

  List<Track> get tracks => rankedTracks.map((r) => r.track).toList();
  int get trackCount => rankedTracks.length;
  bool get isEmpty => rankedTracks.isEmpty;
  bool get isNotEmpty => rankedTracks.isNotEmpty;

  Duration get totalDuration => rankedTracks.fold(
        Duration.zero,
        (acc, item) => acc + item.track.duration,
      );

  String? get topArtist =>
      rankedTracks.isNotEmpty ? rankedTracks.first.track.artist : null;

  Track? get topTrack =>
      rankedTracks.isNotEmpty ? rankedTracks.first.track : null;

  List<String> get previewCovers {
    final covers = <String>[];
    for (final ranked in rankedTracks) {
      final url = ranked.track.coverUrl;
      if (url != null && url.isNotEmpty && !covers.contains(url)) {
        covers.add(url);
        if (covers.length >= 4) break;
      }
    }
    return covers;
  }

  String get formattedDuration {
    final minutes = totalDuration.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0 ? '${hours} hr' : '${hours}h ${remainingMinutes}m';
  }

  Playlist toDomainPlaylist() {
    return Playlist(
      id: id,
      name: title,
      description: description,
      isImported: false,
      createdAt: generatedAt,
      trackCount: trackCount,
    );
  }
}

// ============================================================================
// 3. Dynamic Ranking Calculator
// ============================================================================

/// Pure Dart calculator engine that evaluates listening logs and computes
/// dynamic rankings for Heavy Rotation.
class HeavyRotationRankingCalculator {
  const HeavyRotationRankingCalculator._();

  /// Calculates dynamic rankings from raw listening logs.
  ///
  /// [logs]: Listening records containing trackId, playedAt timestamp, and completedRatio.
  /// [trackLookup]: Map from trackId to Track metadata.
  /// [config]: Tuning parameters (windowDays, maxTracks, minCompletionRatio, rankingMode).
  /// [referenceTime]: Target "now" time (defaults to DateTime.now()).
  static List<HeavyRotationRankedTrack> calculateRankings({
    required List<ListeningLogEntry> logs,
    Map<String, Track>? trackLookup,
    HeavyRotationConfig config = const HeavyRotationConfig(),
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();
    final windowStart = now.subtract(Duration(days: config.windowDays));
    final prevWindowStart =
        now.subtract(Duration(days: config.windowDays * 2));

    final Map<String, Track> resolvedTracks = {};
    if (trackLookup != null) {
      resolvedTracks.addAll(trackLookup);
    }
    for (final entry in logs) {
      if (entry.track != null && !resolvedTracks.containsKey(entry.trackId)) {
        resolvedTracks[entry.trackId] = entry.track!;
      }
    }

    // 1. Partition logs into current window and prior comparison window
    final currentLogs = <ListeningLogEntry>[];
    final priorLogs = <ListeningLogEntry>[];

    for (final log in logs) {
      if (log.completedRatio < config.minCompletionRatio) {
        continue; // Skip accidental skips
      }

      if (config.excludeUnavailable &&
          resolvedTracks[log.trackId]?.isUnavailable == true) {
        continue;
      }

      final playedAt = log.playedAt;
      if (playedAt.isAfter(windowStart) && !playedAt.isAfter(now)) {
        currentLogs.add(log);
      } else if (playedAt.isAfter(prevWindowStart) &&
          !playedAt.isAfter(windowStart)) {
        priorLogs.add(log);
      }
    }

    // 2. Aggregate current window metrics
    final Map<String, _AggregateMetrics> currentMetrics = {};
    for (final log in currentLogs) {
      final tId = log.trackId;
      final m = currentMetrics.putIfAbsent(tId, () => _AggregateMetrics());
      m.playCount += 1;
      m.totalCompletionRatio += log.completedRatio;
      if (m.lastPlayed == null || log.playedAt.isAfter(m.lastPlayed!)) {
        m.lastPlayed = log.playedAt;
      }

      final trackDuration =
          log.duration ?? resolvedTracks[tId]?.duration ?? Duration.zero;
      m.totalListenTime += Duration(
        milliseconds:
            (trackDuration.inMilliseconds * log.completedRatio).round(),
      );

      // Score calculation based on mode
      switch (config.rankingMode) {
        case HeavyRotationRankingMode.mostPlayed:
          // Raw play count with small recency tiebreaker
          m.score = m.playCount.toDouble();
          break;
        case HeavyRotationRankingMode.weightedRecency:
          // Exponential / linear decay within the window (newer plays score higher)
          final ageDays = now.difference(log.playedAt).inHours / 24.0;
          final decay = math.max(
              0.2, 1.0 - (ageDays / math.max(1, config.windowDays)) * 0.7);
          final playWeight = decay * (0.5 + 0.5 * log.completedRatio);
          m.score += playWeight;
          break;
        case HeavyRotationRankingMode.totalDuration:
          // Milliseconds listened
          m.score = m.totalListenTime.inMilliseconds.toDouble();
          break;
      }
    }

    // 3. Aggregate prior window metrics for trend calculation
    final Map<String, int> priorPlayCounts = {};
    for (final log in priorLogs) {
      priorPlayCounts[log.trackId] = (priorPlayCounts[log.trackId] ?? 0) + 1;
    }
    final sortedPrior = priorPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final Map<String, int> priorRanks = {};
    for (int i = 0; i < sortedPrior.length; i++) {
      priorRanks[sortedPrior[i].key] = i + 1;
    }

    // 4. Sort current window tracks
    final sortedTrackIds = currentMetrics.keys.toList()
      ..sort((a, b) {
        final ma = currentMetrics[a]!;
        final mb = currentMetrics[b]!;

        final cmp = mb.score.compareTo(ma.score);
        if (cmp != 0) return cmp;

        // Secondary tiebreaker: Raw play count
        final playCmp = mb.playCount.compareTo(ma.playCount);
        if (playCmp != 0) return playCmp;

        // Tertiary tiebreaker: Last played recency
        final timeA = ma.lastPlayed?.millisecondsSinceEpoch ?? 0;
        final timeB = mb.lastPlayed?.millisecondsSinceEpoch ?? 0;
        return timeB.compareTo(timeA);
      });

    // 5. Build Top 50 Ranked Tracks
    final rankedTracks = <HeavyRotationRankedTrack>[];
    final limit = math.min(config.maxTracks, sortedTrackIds.length);

    for (int i = 0; i < limit; i++) {
      final tId = sortedTrackIds[i];
      final m = currentMetrics[tId]!;
      final rank = i + 1;
      final priorRank = priorRanks[tId];

      HeavyRotationTrend trend;
      if (priorRank == null || priorRank > config.maxTracks) {
        trend = HeavyRotationTrend.newEntry;
      } else if (priorRank > rank + 1) {
        trend = HeavyRotationTrend.rising;
      } else if (priorRank < rank - 1) {
        trend = HeavyRotationTrend.falling;
      } else {
        trend = HeavyRotationTrend.steady;
      }

      final track = resolvedTracks[tId] ??
          Track(
            id: tId,
            sourceId: tId,
            title: 'Track $rank',
            artist: 'Unknown Artist',
            duration: m.totalListenTime,
          );

      final avgCompletion = m.playCount > 0
          ? (m.totalCompletionRatio / m.playCount).clamp(0.0, 1.0)
          : 1.0;

      rankedTracks.add(HeavyRotationRankedTrack(
        rank: rank,
        track: track,
        playCount: m.playCount,
        score: m.score,
        totalListenTime: m.totalListenTime,
        completionRateAvg: avgCompletion,
        lastPlayed: m.lastPlayed ?? now,
        trend: trend,
        previousRank: priorRank,
      ));
    }

    return rankedTracks;
  }
}

class _AggregateMetrics {
  int playCount = 0;
  double score = 0.0;
  double totalCompletionRatio = 0.0;
  Duration totalListenTime = Duration.zero;
  DateTime? lastPlayed;
}

// ============================================================================
// 4. Playlist Generator
// ============================================================================

/// High-level playlist generator that produces a dynamic Heavy Rotation playlist
/// from either listening logs or SQLite database records.
class HeavyRotationPlaylistGenerator {
  const HeavyRotationPlaylistGenerator._();

  static Track _trackFromRow(TrackRow r) {
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

  /// Generates a [HeavyRotationPlaylist] from an explicit list of listening logs.
  static HeavyRotationPlaylist generateFromLogs({
    required List<ListeningLogEntry> logs,
    Map<String, Track>? trackLookup,
    HeavyRotationConfig config = const HeavyRotationConfig(),
    DateTime? referenceTime,
  }) {
    final ranked = HeavyRotationRankingCalculator.calculateRankings(
      logs: logs,
      trackLookup: trackLookup,
      config: config,
      referenceTime: referenceTime,
    );

    return HeavyRotationPlaylist(
      generatedAt: referenceTime ?? DateTime.now(),
      rankedTracks: ranked,
      config: config,
    );
  }

  /// Generates a [HeavyRotationPlaylist] by querying the application database.
  static Future<HeavyRotationPlaylist> generateFromDatabase(
    AppDatabase db, {
    HeavyRotationConfig config = const HeavyRotationConfig(),
    DateTime? referenceTime,
  }) async {
    final now = referenceTime ?? DateTime.now();
    final doubleWindowCutoff = now
        .subtract(Duration(days: config.windowDays * 2))
        .millisecondsSinceEpoch;

    // Fetch play histories joined with tracks for the double-window (to calculate trends)
    final historyRows = await (db.select(db.playHistories).join([
      drift.innerJoin(
        db.tracks,
        db.tracks.id.equalsExp(db.playHistories.trackId),
      ),
    ])..where(db.playHistories.playedAt.isBiggerOrEqualValue(doubleWindowCutoff)))
        .get();

    final logs = <ListeningLogEntry>[];
    final Map<String, Track> trackMap = {};

    for (final row in historyRows) {
      final ph = row.readTable(db.playHistories);
      final tr = row.readTable(db.tracks);
      final track = _trackFromRow(tr);
      trackMap[track.id] = track;

      logs.add(ListeningLogEntry(
        trackId: ph.trackId,
        playedAt: DateTime.fromMillisecondsSinceEpoch(ph.playedAt),
        completedRatio: ph.completedRatio,
        duration: track.duration,
        track: track,
      ));
    }

    var ranked = HeavyRotationRankingCalculator.calculateRankings(
      logs: logs,
      trackLookup: trackMap,
      config: config,
      referenceTime: now,
    );

    // Fallback: If listening history has fewer than 3 tracks and user has liked tracks,
    // gracefully complement with liked songs so new listeners enjoy a rich playlist
    if (ranked.length < 5 && config.fallbackToLikedWhenEmpty) {
      try {
        final likedRows = await (db.select(db.tracks)
              ..where((t) => t.isLiked.equals(true))
              ..limit(config.maxTracks))
            .get();

        final existingIds = ranked.map((r) => r.track.id).toSet();
        final supplementalTracks = <Track>[];
        for (final r in likedRows) {
          if (!existingIds.contains(r.id)) {
            supplementalTracks.add(_trackFromRow(r));
          }
        }

        if (supplementalTracks.isNotEmpty) {
          final extended = List<HeavyRotationRankedTrack>.from(ranked);
          var nextRank = extended.length + 1;
          for (final track in supplementalTracks) {
            if (extended.length >= config.maxTracks) break;
            extended.add(HeavyRotationRankedTrack(
              rank: nextRank++,
              track: track,
              playCount: 1,
              score: 1.0,
              totalListenTime: track.duration,
              completionRateAvg: 1.0,
              lastPlayed: now,
              trend: HeavyRotationTrend.newEntry,
            ));
          }
          ranked = extended;
        }
      } catch (_) {
        // Ignored if query fails
      }
    }

    return HeavyRotationPlaylist(
      generatedAt: now,
      rankedTracks: ranked,
      config: config,
    );
  }

  /// Exports the dynamic Heavy Rotation snapshot into a static user playlist.
  static Future<bool> exportToLibraryAsPlaylist(
    AppDatabase db,
    HeavyRotationPlaylist playlist, {
    String? customName,
  }) async {
    if (playlist.isEmpty) return false;

    try {
      final playlistId =
          'heavy_rotation_${DateTime.now().millisecondsSinceEpoch}';
      final name = customName ??
          'Heavy Rotation (${DateTime.now().month}/${DateTime.now().year})';

      await db.into(db.playlists).insert(
            PlaylistsCompanion.insert(
              id: playlistId,
              name: name,
              description: drift.Value(
                  'Snapshot of top 50 heavy rotation tracks on ${DateTime.now().toString().split('.').first}'),
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      for (int i = 0; i < playlist.tracks.length; i++) {
        final track = playlist.tracks[i];
        await db.into(db.playlistTracks).insert(
              PlaylistTracksCompanion.insert(
                playlistId: playlistId,
                trackId: drift.Value(track.id),
                position: i,
                originalTitle: track.title,
                originalArtist: track.artist,
                matchStatus: 'matched',
              ),
            );
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// 5. Persistent Preferences
// ============================================================================

/// Storage contract for saving user Heavy Rotation preferences.
abstract class HeavyRotationPreferencesStorage {
  Future<HeavyRotationConfig> load();
  Future<bool> save(HeavyRotationConfig config);
}

/// Fallback store saving preferences into a local JSON cache file.
class HeavyRotationDiskStore implements HeavyRotationPreferencesStorage {
  static const String _fileName = 'softify_heavy_rotation_prefs.json';
  static HeavyRotationConfig _memoryCache = const HeavyRotationConfig();
  static bool _hasLoaded = false;

  @override
  Future<HeavyRotationConfig> load() async {
    if (_hasLoaded) return _memoryCache;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _fileName));
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          _memoryCache = HeavyRotationConfig.fromMap(decoded);
        }
      }
    } catch (_) {
      // Memory fallback in test or headless environments
    } finally {
      _hasLoaded = true;
    }
    return _memoryCache;
  }

  @override
  Future<bool> save(HeavyRotationConfig config) async {
    _memoryCache = config;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _fileName));
      await file.writeAsString(jsonEncode(config.toMap()));
      return true;
    } catch (_) {
      return false;
    }
  }

  static void resetForTesting() {
    _memoryCache = const HeavyRotationConfig();
    _hasLoaded = false;
  }
}

// ============================================================================
// 6. Riverpod State Management & Providers
// ============================================================================

/// State notifier managing the active [HeavyRotationConfig].
class HeavyRotationConfigNotifier extends StateNotifier<HeavyRotationConfig> {
  final HeavyRotationPreferencesStorage _storage;

  HeavyRotationConfigNotifier([HeavyRotationPreferencesStorage? storage])
      : _storage = storage ?? HeavyRotationDiskStore(),
        super(const HeavyRotationConfig()) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await _storage.load();
    if (mounted) {
      state = loaded;
    }
  }

  Future<void> updateConfig(HeavyRotationConfig next) async {
    state = next;
    await _storage.save(next);
  }

  Future<void> setRankingMode(HeavyRotationRankingMode mode) =>
      updateConfig(state.copyWith(rankingMode: mode));

  Future<void> setMinCompletionRatio(double ratio) =>
      updateConfig(state.copyWith(minCompletionRatio: ratio));

  Future<void> setWindowDays(int days) =>
      updateConfig(state.copyWith(windowDays: days));

  Future<void> setMaxTracks(int max) =>
      updateConfig(state.copyWith(maxTracks: max));
}

/// Provider for user Heavy Rotation configuration.
final heavyRotationConfigProvider =
    StateNotifierProvider<HeavyRotationConfigNotifier, HeavyRotationConfig>(
        (ref) {
  return HeavyRotationConfigNotifier();
});

/// Asynchronously generates the Heavy Rotation playlist based on database records.
final heavyRotationPlaylistProvider =
    FutureProvider<HeavyRotationPlaylist>((ref) async {
  final config = ref.watch(heavyRotationConfigProvider);
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}

  if (db == null) {
    return HeavyRotationPlaylist(
      generatedAt: DateTime.now(),
      rankedTracks: const [],
      config: config,
    );
  }

  return HeavyRotationPlaylistGenerator.generateFromDatabase(db, config: config);
});

/// Convenience provider returning the list of top tracks.
final heavyRotationTracksProvider = FutureProvider<List<Track>>((ref) async {
  final playlist = await ref.watch(heavyRotationPlaylistProvider.future);
  return playlist.tracks;
});

/// Indicates whether any track from the Heavy Rotation Top 50 is currently playing.
final isHeavyRotationActiveProvider = Provider<bool>((ref) {
  final currentTrack = ref.watch(currentTrackProvider).value;
  if (currentTrack == null) return false;

  final tracksAsync = ref.watch(heavyRotationTracksProvider);
  return tracksAsync.maybeWhen(
    data: (tracks) => tracks.any((t) => t.id == currentTrack.id),
    orElse: () => false,
  );
});

/// Controller coordinating Quick Play of the Heavy Rotation playlist.
class HeavyRotationQuickPlayController extends ChangeNotifier {
  final Ref _ref;
  bool _isLoading = false;

  HeavyRotationQuickPlayController(this._ref);

  bool get isLoading => _isLoading;

  /// Starts or toggles playback of the Heavy Rotation playlist.
  Future<void> quickPlay({int startIndex = 0}) async {
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
      final isCurrentActive = _ref.read(isHeavyRotationActiveProvider);

      // If Heavy Rotation is currently active and playing, toggle pause
      if (isCurrentActive && isPlaying && startIndex == 0) {
        await handler.pause();
        return;
      }

      // If Heavy Rotation is currently active but paused, resume
      if (isCurrentActive && !isPlaying && startIndex == 0) {
        await handler.play();
        return;
      }

      // Start fresh playback from Heavy Rotation queue
      final playlist = await _ref.read(heavyRotationPlaylistProvider.future);
      if (playlist.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final tracks = playlist.tracks;
      final safeIndex = startIndex.clamp(0, tracks.length - 1);
      final targetTrack = tracks[safeIndex];

      await handler.playTrack(
        targetTrack,
        queue: tracks,
        startIndex: safeIndex,
      );
    } catch (_) {
      // Ignored: Gracefully handle audio failures
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// Provider for the Heavy Rotation quick play controller.
final heavyRotationQuickPlayProvider =
    ChangeNotifierProvider<HeavyRotationQuickPlayController>((ref) {
  return HeavyRotationQuickPlayController(ref);
});

// ============================================================================
// 7. Material 3 UI Widgets
// ============================================================================

/// Signature visual card presenting the user's "Heavy Rotation (Top 50)" playlist
/// with album art collage, statistics, and an instant Quick Play button.
class HeavyRotationCard extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onQuickPlay;
  final EdgeInsetsGeometry? margin;
  final bool showTrackCount;
  final bool showRankBadge;

  const HeavyRotationCard({
    super.key,
    this.onTap,
    this.onQuickPlay,
    this.margin,
    this.showTrackCount = true,
    this.showRankBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final playlistAsync = ref.watch(heavyRotationPlaylistProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isRotActive = ref.watch(isHeavyRotationActiveProvider);
    final quickPlayCtrl = ref.watch(heavyRotationQuickPlayProvider);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(
          color: isRotActive && isPlaying
              ? tokens.accent.withValues(alpha: 0.5)
              : tokens.divider.withValues(alpha: 0.15),
          width: isRotActive && isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: playlistAsync.when(
              loading: () => _buildLoadingState(tokens),
              error: (_, __) => _buildErrorState(context, ref, tokens),
              data: (playlist) => _buildContent(
                context: context,
                ref: ref,
                playlist: playlist,
                tokens: tokens,
                isPlaying: isPlaying,
                isRotActive: isRotActive,
                isLoadingPlay: quickPlayCtrl.isLoading,
              ),
            ),
          ),
        ),
      ),
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
    BuildContext context,
    WidgetRef ref,
    AppTokens tokens,
  ) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: tokens.error, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not calculate Heavy Rotation.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => ref.refresh(heavyRotationPlaylistProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required WidgetRef ref,
    required HeavyRotationPlaylist playlist,
    required AppTokens tokens,
    required bool isPlaying,
    required bool isRotActive,
    required bool isLoadingPlay,
  }) {
    final topTrack = playlist.topTrack;
    final topRanked =
        playlist.rankedTracks.isNotEmpty ? playlist.rankedTracks.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Header Row ---
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(tokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: tokens.accent,
                    size: 14,
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
            if (showTrackCount)
              Text(
                '${playlist.trackCount} Tracks',
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
              tooltip: 'Algorithm Settings',
              visualDensity: VisualDensity.compact,
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: tokens.surfaceElevated,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const HeavyRotationSettingsSheet(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // --- Body Row (Cover Art + Info + Quick Play Button) ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Artwork / 2x2 Collage
            _buildArtworkDisplay(playlist, tokens, isPlaying && isRotActive),

            const SizedBox(width: 14),

            // Metadata info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
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
                    playlist.subtitle,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (topTrack != null && topRanked != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#1',
                            style: TextStyle(
                              color: tokens.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${topTrack.title} • ${topTrack.artist}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Listen to songs to build your rotation',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Quick Play Button
            _buildQuickPlayButton(
              context: context,
              ref: ref,
              tokens: tokens,
              playlist: playlist,
              isPlaying: isPlaying,
              isRotActive: isRotActive,
              isLoading: isLoadingPlay,
            ),
          ],
        ),

        // --- Bottom Stats Bar (Optional) ---
        if (playlist.isNotEmpty) ...[
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
                if (topRanked != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.repeat_one_rounded,
                      size: 14, color: tokens.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Peak: ${topRanked.formattedPlayCount}',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                if (topRanked != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        topRanked.trend.icon,
                        size: 14,
                        color: topRanked.trend.color(tokens),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        topRanked.trend.label,
                        style: TextStyle(
                          color: topRanked.trend.color(tokens),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArtworkDisplay(
    HeavyRotationPlaylist playlist,
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
              ? _buildCoversGrid(covers)
              : covers.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: covers.first,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Icon(
                        Icons.rotate_right_rounded,
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

  Widget _buildCoversGrid(List<String> covers) {
    return Column(
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
    );
  }

  Widget _buildQuickPlayButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppTokens tokens,
    required HeavyRotationPlaylist playlist,
    required bool isPlaying,
    required bool isRotActive,
    required bool isLoading,
  }) {
    final isCurrentlyPlayingRotation = isRotActive && isPlaying;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: isCurrentlyPlayingRotation
            ? 'Pause Heavy Rotation'
            : 'Quick Play Heavy Rotation',
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusFull),
          onTap: playlist.isEmpty
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  if (onQuickPlay != null) {
                    onQuickPlay!();
                  } else {
                    ref.read(heavyRotationQuickPlayProvider).quickPlay();
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
                        color: tokens.textPrimary,
                      ),
                    )
                  : Icon(
                      isCurrentlyPlayingRotation
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: playlist.isEmpty
                          ? tokens.textMuted
                          : Colors.white,
                      size: 26,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single track item rendered inside the Heavy Rotation playlist view.
class HeavyRotationTrackTile extends ConsumerWidget {
  final HeavyRotationRankedTrack rankedTrack;
  final VoidCallback? onTap;
  final bool isCurrent;

  const HeavyRotationTrackTile({
    super.key,
    required this.rankedTrack,
    this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final track = rankedTrack.track;

    Color rankColor;
    if (rankedTrack.rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
    } else if (rankedTrack.rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
    } else if (rankedTrack.rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = tokens.textMuted;
    }

    return ListTile(
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '#${rankedTrack.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: AppNetworkImage(
              imageUrl: track.coverUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? tokens.accent : tokens.textPrimary,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            rankedTrack.trend.icon,
            size: 12,
            color: rankedTrack.trend.color(tokens),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.surfaceHighlight,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
        child: Text(
          rankedTrack.formattedPlayCount,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet dialog to customize the ranking algorithm and threshold parameters.
class HeavyRotationSettingsSheet extends ConsumerWidget {
  const HeavyRotationSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final config = ref.watch(heavyRotationConfigProvider);
    final notifier = ref.read(heavyRotationConfigProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: tokens.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Heavy Rotation Algorithm',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Select ranking criterion for your Top 50:',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final mode in HeavyRotationRankingMode.values) ...[
              RadioListTile<HeavyRotationRankingMode>(
                value: mode,
                groupValue: config.rankingMode,
                activeColor: tokens.accent,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  mode.label,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  mode.description,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                onChanged: (val) {
                  if (val != null) {
                    notifier.setRankingMode(val);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    ref.invalidate(heavyRotationPlaylistProvider);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply & Recalculate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
