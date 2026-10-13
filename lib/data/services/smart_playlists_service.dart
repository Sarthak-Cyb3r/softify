import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../database/app_database.dart';

enum InsightsTimeframe {
  allTime('All Time'),
  past30Days('Past 30 Days'),
  past7Days('Past 7 Days');

  final String label;
  const InsightsTimeframe(this.label);
}

class ArtistInsight {
  final String name;
  final int playCount;
  final Duration totalTime;
  final double sharePercentage; // 0.0 to 1.0

  const ArtistInsight({
    required this.name,
    required this.playCount,
    required this.totalTime,
    required this.sharePercentage,
  });
}

class TrackInsight {
  final Track track;
  final int playCount;
  final Duration totalTime;

  const TrackInsight({
    required this.track,
    required this.playCount,
    required this.totalTime,
  });
}

enum ListeningArchetype {
  nightExplorer(
    'Night Explorer',
    'Deep nocturnal sessions when the world is quiet and music hits deepest.',
    '🌙',
  ),
  morningStarter(
    'Morning Energizer',
    'Kickstarting daily momentum and waking up with sonic rhythms.',
    '☀️',
  ),
  afternoonFlow(
    'Afternoon Flow',
    'Uninterrupted sonic focus carrying you through the midday stride.',
    '⚡',
  ),
  eveningChiller(
    'Evening Chill',
    'Unwinding as the sun sets with warm, soul-soothing melodies.',
    '🌆',
  ),
  deepDiver(
    'Deep Diver',
    'Intensely devoted to a tight circle of favorite artists and albums.',
    '🔁',
  ),
  sonicVoyager(
    'Sonic Voyager',
    'An adventurous listener wandering far and wide across genres.',
    '🧭',
  );

  final String title;
  final String description;
  final String emoji;

  const ListeningArchetype(this.title, this.description, this.emoji);
}

/// Summary model for 100% on-device private listening insights ("Softify Wrapped").
class ListeningInsights {
  final InsightsTimeframe timeframe;
  final Duration totalListeningTime;
  final int totalTracksPlayed;
  final int uniqueArtistsCount;
  final int uniqueTracksCount;
  final double completionRate;
  final List<ArtistInsight> detailedTopArtists;
  final List<TrackInsight> detailedTopTracks;
  final String primeListeningTime;
  final List<int> hourlyDistribution; // 24 entries: 0..23
  final ListeningArchetype archetype;

  // Backwards compatibility with existing tests and calls
  List<MapEntry<String, int>> get topArtists =>
      detailedTopArtists.map((a) => MapEntry(a.name, a.playCount)).toList();

  List<Track> get topTracks =>
      detailedTopTracks.map((t) => t.track).toList();

  const ListeningInsights({
    this.timeframe = InsightsTimeframe.allTime,
    required this.totalListeningTime,
    required this.totalTracksPlayed,
    required this.uniqueArtistsCount,
    required this.uniqueTracksCount,
    required this.completionRate,
    required this.detailedTopArtists,
    required this.detailedTopTracks,
    required this.primeListeningTime,
    required this.hourlyDistribution,
    required this.archetype,
  });
}

/// Service computing dynamic smart playlists and on-device offline insights.
class SmartPlaylistsService {
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

  /// On Repeat: Songs played frequently in the last 14 days.
  static Future<List<Track>> getOnRepeatTracks(
    AppDatabase db, {
    int limit = 30,
  }) async {
    final fourteenDaysAgo =
        DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;

    // Fetch from playHistories joined with tracks
    final historyRows = await (db.select(db.playHistories).join([
      innerJoin(db.tracks, db.tracks.id.equalsExp(db.playHistories.trackId)),
    ])..where(db.playHistories.playedAt.isBiggerOrEqualValue(fourteenDaysAgo)))
        .get();

    final counts = <String, int>{};
    final trackMap = <String, Track>{};

    for (final r in historyRows) {
      final ph = r.readTable(db.playHistories);
      final t = r.readTable(db.tracks);
      counts[ph.trackId] = (counts[ph.trackId] ?? 0) + 1;
      trackMap[ph.trackId] = _trackFromRow(t);
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <Track>[];
    for (final entry in sortedEntries.take(limit)) {
      final track = trackMap[entry.key];
      if (track != null) {
        result.add(track);
      }
    }

    // Fallback if user is new: use liked tracks
    if (result.isEmpty) {
      final likedRows = await (db.select(db.tracks)
            ..where((t) => t.isLiked.equals(true))
            ..limit(limit))
          .get();
      return likedRows.map(_trackFromRow).toList();
    }

    return result;
  }

  /// Most Played This Month: Tracks played in the last 30 days.
  static Future<List<Track>> getMostPlayedThisMonth(
    AppDatabase db, {
    int limit = 30,
  }) async {
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;

    final historyRows = await (db.select(db.playHistories).join([
      innerJoin(db.tracks, db.tracks.id.equalsExp(db.playHistories.trackId)),
    ])..where(db.playHistories.playedAt.isBiggerOrEqualValue(thirtyDaysAgo)))
        .get();

    final counts = <String, int>{};
    final trackMap = <String, Track>{};

    for (final r in historyRows) {
      final ph = r.readTable(db.playHistories);
      final t = r.readTable(db.tracks);
      counts[ph.trackId] = (counts[ph.trackId] ?? 0) + 1;
      trackMap[ph.trackId] = _trackFromRow(t);
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <Track>[];
    for (final entry in sorted.take(limit)) {
      final track = trackMap[entry.key];
      if (track != null) {
        result.add(track);
      }
    }

    if (result.isEmpty) {
      final recentRows = await (db.select(db.tracks)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();
      return recentRows.map(_trackFromRow).toList();
    }

    return result;
  }

  /// Forgotten Favorites: Liked songs not played in the last 21 days.
  static Future<List<Track>> getForgottenFavorites(
    AppDatabase db, {
    int limit = 30,
  }) async {
    final twentyOneDaysAgo =
        DateTime.now().subtract(const Duration(days: 21)).millisecondsSinceEpoch;

    // 1. Get IDs of tracks played recently
    final recentHistory = await (db.select(db.playHistories)
          ..where((ph) => ph.playedAt.isBiggerOrEqualValue(twentyOneDaysAgo)))
        .get();
    final recentlyPlayedIds = recentHistory.map((ph) => ph.trackId).toSet();

    // 2. Query liked tracks not in recentlyPlayedIds
    final likedRows = await (db.select(db.tracks)
          ..where((t) => t.isLiked.equals(true)))
        .get();

    final candidates = likedRows
        .where((t) => !recentlyPlayedIds.contains(t.id))
        .map(_trackFromRow)
        .take(limit)
        .toList();

    return candidates;
  }

  /// Calculates 100% on-device listening insights ("Softify Wrapped").
  static Future<ListeningInsights> getListeningInsights(
    AppDatabase db, {
    InsightsTimeframe timeframe = InsightsTimeframe.allTime,
  }) async {
    final int? cutoffTs;
    switch (timeframe) {
      case InsightsTimeframe.past7Days:
        cutoffTs = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
        break;
      case InsightsTimeframe.past30Days:
        cutoffTs = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
        break;
      case InsightsTimeframe.allTime:
        cutoffTs = null;
        break;
    }

    // 1. Prefer high-precision playEvents telemetry if available
    var eventsQuery = db.select(db.playEvents).join([
      innerJoin(db.tracks, db.tracks.id.equalsExp(db.playEvents.trackId)),
    ]);
    if (cutoffTs != null) {
      eventsQuery = eventsQuery..where(db.playEvents.ts.isBiggerOrEqualValue(cutoffTs));
    }
    final eventRows = await eventsQuery.get();

    int totalMs = 0;
    int validStreamCount = 0;
    int completedSessions = 0;
    final artistCounts = <String, int>{};
    final artistMsMap = <String, int>{};
    final trackCounts = <String, int>{};
    final trackMsMap = <String, int>{};
    final trackMap = <String, Track>{};
    final hourBuckets = List<int>.filled(24, 0);

    if (eventRows.isNotEmpty) {
      for (final r in eventRows) {
        final pe = r.readTable(db.playEvents);
        final t = r.readTable(db.tracks);
        final isPodcast = t.id.startsWith('podcast_') ||
            (t.album != null && t.album!.toLowerCase() == 'podcast');
        if (isPodcast) continue;

        final track = _trackFromRow(t);
        totalMs += pe.listenedMs;

        // Count as a stream if listened for >= 20 seconds or completed
        if (pe.listenedMs >= 20000 || !pe.skippedEarly) {
          validStreamCount++;
          if (!pe.skippedEarly) completedSessions++;

          artistCounts[t.artist] = (artistCounts[t.artist] ?? 0) + 1;
          artistMsMap[t.artist] = (artistMsMap[t.artist] ?? 0) + pe.listenedMs;

          trackCounts[t.id] = (trackCounts[t.id] ?? 0) + 1;
          trackMsMap[t.id] = (trackMsMap[t.id] ?? 0) + pe.listenedMs;
          trackMap[t.id] = track;

          final dt = DateTime.fromMillisecondsSinceEpoch(pe.ts);
          hourBuckets[dt.hour]++;
        }
      }
    }

    // 2. Fallback to playHistories if playEvents had no valid streams
    if (validStreamCount == 0) {
      var historiesQuery = db.select(db.playHistories).join([
        innerJoin(db.tracks, db.tracks.id.equalsExp(db.playHistories.trackId)),
      ]);
      if (cutoffTs != null) {
        historiesQuery = historiesQuery..where(db.playHistories.playedAt.isBiggerOrEqualValue(cutoffTs));
      }
      final historyRows = await historiesQuery.get();

      for (final r in historyRows) {
        final ph = r.readTable(db.playHistories);
        final t = r.readTable(db.tracks);
        final isPodcast = t.id.startsWith('podcast_') ||
            (t.album != null && t.album!.toLowerCase() == 'podcast');
        if (isPodcast) continue;

        final track = _trackFromRow(t);
        final durationEst = (t.durationMs * ph.completedRatio).toInt();

        if (ph.completedRatio > 0.0) {
          totalMs += durationEst;
        }

        // Only count towards streams/artists if completedRatio >= 0.2
        if (ph.completedRatio >= 0.2) {
          validStreamCount++;
          if (ph.completedRatio >= 0.8) completedSessions++;

          artistCounts[t.artist] = (artistCounts[t.artist] ?? 0) + 1;
          artistMsMap[t.artist] = (artistMsMap[t.artist] ?? 0) + durationEst;

          trackCounts[t.id] = (trackCounts[t.id] ?? 0) + 1;
          trackMsMap[t.id] = (trackMsMap[t.id] ?? 0) + durationEst;
          trackMap[t.id] = track;

          final dt = DateTime.fromMillisecondsSinceEpoch(ph.playedAt);
          hourBuckets[dt.hour]++;
        }
      }

      // If still 0 valid streams but historyRows is not empty, count unmeasured plays conservatively
      if (validStreamCount == 0 && historyRows.isNotEmpty) {
        for (final r in historyRows) {
          final ph = r.readTable(db.playHistories);
          final t = r.readTable(db.tracks);
          final isPodcast = t.id.startsWith('podcast_') ||
              (t.album != null && t.album!.toLowerCase() == 'podcast');
          if (isPodcast) continue;

          validStreamCount++;
          completedSessions++;
          totalMs += 45000;
          artistCounts[t.artist] = (artistCounts[t.artist] ?? 0) + 1;
          artistMsMap[t.artist] = (artistMsMap[t.artist] ?? 0) + 45000;

          trackCounts[t.id] = (trackCounts[t.id] ?? 0) + 1;
          trackMsMap[t.id] = (trackMsMap[t.id] ?? 0) + 45000;
          trackMap[t.id] = _trackFromRow(t);

          final dt = DateTime.fromMillisecondsSinceEpoch(ph.playedAt);
          hourBuckets[dt.hour]++;
        }
      }
    }

    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return (artistMsMap[b.key] ?? 0).compareTo(artistMsMap[a.key] ?? 0);
      });

    final sortedTracks = trackCounts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return (trackMsMap[b.key] ?? 0).compareTo(trackMsMap[a.key] ?? 0);
      });

    final detailedTopArtists = sortedArtists.take(5).map((e) {
      final ms = artistMsMap[e.key] ?? 0;
      final share = totalMs > 0 ? (ms / totalMs).clamp(0.0, 1.0) : 0.0;
      return ArtistInsight(
        name: e.key,
        playCount: e.value,
        totalTime: Duration(milliseconds: ms),
        sharePercentage: share,
      );
    }).toList();

    final detailedTopTracks = sortedTracks.take(5).map((e) {
      final track = trackMap[e.key]!;
      final ms = trackMsMap[e.key] ?? (e.value * track.duration.inMilliseconds);
      return TrackInsight(
        track: track,
        playCount: e.value,
        totalTime: Duration(milliseconds: ms),
      );
    }).toList();

    // Determine prime listening time
    int primeHour = 18;
    int maxHourCount = -1;
    for (int h = 0; h < 24; h++) {
      if (hourBuckets[h] > maxHourCount) {
        maxHourCount = hourBuckets[h];
        primeHour = h;
      }
    }

    String timeLabel;
    if (primeHour >= 5 && primeHour < 12) {
      timeLabel = 'Morning Bird (5 AM - 12 PM)';
    } else if (primeHour >= 12 && primeHour < 17) {
      timeLabel = 'Afternoon Flow (12 PM - 5 PM)';
    } else if (primeHour >= 17 && primeHour < 22) {
      timeLabel = 'Evening Chill (5 PM - 10 PM)';
    } else {
      timeLabel = 'Night Owl (10 PM - 5 AM)';
    }

    // Determine archetype
    final double completionRate = validStreamCount > 0
        ? (completedSessions / validStreamCount).clamp(0.0, 1.0)
        : 0.0;
    final int uniqueArtists = artistCounts.length;
    final int topArtistPlays = sortedArtists.isNotEmpty ? sortedArtists.first.value : 0;

    ListeningArchetype archetype;
    if (uniqueArtists >= 12 && (topArtistPlays / (validStreamCount > 0 ? validStreamCount : 1)) < 0.25) {
      archetype = ListeningArchetype.sonicVoyager;
    } else if (validStreamCount >= 5 && (topArtistPlays / (validStreamCount > 0 ? validStreamCount : 1)) >= 0.40) {
      archetype = ListeningArchetype.deepDiver;
    } else if (primeHour >= 22 || primeHour < 5) {
      archetype = ListeningArchetype.nightExplorer;
    } else if (primeHour >= 5 && primeHour < 12) {
      archetype = ListeningArchetype.morningStarter;
    } else if (primeHour >= 12 && primeHour < 17) {
      archetype = ListeningArchetype.afternoonFlow;
    } else {
      archetype = ListeningArchetype.eveningChiller;
    }

    return ListeningInsights(
      timeframe: timeframe,
      totalListeningTime: Duration(milliseconds: totalMs),
      totalTracksPlayed: validStreamCount,
      uniqueArtistsCount: artistCounts.length,
      uniqueTracksCount: trackCounts.length,
      completionRate: completionRate,
      detailedTopArtists: detailedTopArtists,
      detailedTopTracks: detailedTopTracks,
      primeListeningTime: timeLabel,
      hourlyDistribution: hourBuckets,
      archetype: archetype,
    );
  }
}
