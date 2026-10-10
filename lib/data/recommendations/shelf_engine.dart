import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../domain/entities/shelf.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_bandit_calibrator.dart';
import '../../domain/ports/i_cooccurrence_repository.dart';
import '../../domain/ports/i_diversity_controller.dart';
import '../../domain/ports/i_event_logger.dart';
import '../../domain/ports/i_recommendation_ranker.dart';
import '../../domain/ports/i_remote_config.dart';
import '../../domain/ports/i_shelf_repository.dart';
import '../../domain/ports/i_taste_profile_repository.dart';
import '../database/app_database.dart';
import '../repositories/remote_config_repository.dart';
import '../services/spotify_api_service.dart';
import 'logistic_regression_ranker.dart';

class ShelfEngine implements IShelfRepository {
  final AppDatabase _db;
  final ITasteProfileRepository _tasteProfileRepo;
  final ICooccurrenceRepository _cooccurrenceRepo;
  final LogisticRegressionRanker _ranker;
  final IRemoteConfig? _remoteConfig;
  final IEventLogger? _eventLogger;
  final IBanditCalibrator? _banditCalibrator;
  final IDiversityController? _diversityController;
  final SpotifyApiService _spotifyApi;

  List<Shelf>? _cachedShelves;
  DateTime? _lastRefreshedAt;

  static const Duration cacheValidity = Duration(hours: 1);

  ShelfEngine({
    required AppDatabase db,
    required ITasteProfileRepository tasteProfileRepo,
    required ICooccurrenceRepository cooccurrenceRepo,
    required LogisticRegressionRanker ranker,
    IRemoteConfig? remoteConfig,
    IEventLogger? eventLogger,
    IBanditCalibrator? banditCalibrator,
    IDiversityController? diversityController,
    SpotifyApiService? spotifyApi,
  })  : _db = db,
        _tasteProfileRepo = tasteProfileRepo,
        _cooccurrenceRepo = cooccurrenceRepo,
        _ranker = ranker,
        _remoteConfig = remoteConfig,
        _eventLogger = eventLogger,
        _banditCalibrator = banditCalibrator,
        _diversityController = diversityController,
        _spotifyApi = spotifyApi ?? SpotifyApiService();

  @override
  Future<List<Shelf>> loadShelves({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedShelves != null &&
        _lastRefreshedAt != null &&
        now.difference(_lastRefreshedAt!) < cacheValidity) {
      return _cachedShelves!;
    }

    final definitions = _remoteConfig?.getShelfDefinitions() ??
        RemoteConfigRepository.defaultShelfDefinitions;

    final shelves = <Shelf>[];

    for (final def in definitions) {
      Shelf? shelf;
      switch (def.rule) {
        case 'frequency_recency':
          shelf = await _buildJumpBackInShelf(def);
          break;
        case 'kmeans_clusters':
          shelf = await _buildDailyMixShelf(def);
          break;
        case 'novelty_with_familiar_anchor':
          shelf = await _buildDiscoverWeeklyShelf(def);
          break;
        default:
          shelf = await _buildJumpBackInShelf(def);
          break;
      }

      if (shelf.tracks.isNotEmpty) {
        shelves.add(shelf);
      }
    }

    // Log impressions for displayed shelves
    final logger = _eventLogger;
    if (logger != null) {
      for (int i = 0; i < shelves.length; i++) {
        logger.logImpression(
          surface: 'home_shelf',
          itemId: shelves[i].id,
          position: i,
        );
      }
    }

    _cachedShelves = shelves;
    _lastRefreshedAt = now;
    return shelves;
  }

  /// 1. Jump Back In (rule: frequency_recency)
  Future<Shelf> _buildJumpBackInShelf(ShelfDefinition def) async {
    try {
      final historyRows = await (_db.select(_db.playHistories).join([
        innerJoin(
          _db.tracks,
          _db.tracks.id.equalsExp(_db.playHistories.trackId),
        ),
      ])
            ..orderBy([OrderingTerm.desc(_db.playHistories.playedAt)])
            ..limit(100))
          .get();

      final trackCounts = <String, int>{};
      final latestPlayed = <String, int>{};
      final trackMap = <String, Track>{};

      for (final row in historyRows) {
        final h = row.readTable(_db.playHistories);
        final t = row.readTable(_db.tracks);
        trackCounts[t.id] = (trackCounts[t.id] ?? 0) + 1;
        if (!latestPlayed.containsKey(t.id) || h.playedAt > latestPlayed[t.id]!) {
          latestPlayed[t.id] = h.playedAt;
        }
        trackMap[t.id] = _mapRowToTrack(t);
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final candidates = trackMap.values.toList();
      candidates.sort((a, b) {
        final countA = trackCounts[a.id] ?? 1;
        final countB = trackCounts[b.id] ?? 1;
        final recencyA = 1.0 / (1.0 + (nowMs - (latestPlayed[a.id] ?? 0)) / 86400000.0);
        final recencyB = 1.0 / (1.0 + (nowMs - (latestPlayed[b.id] ?? 0)) / 86400000.0);
        final scoreA = countA * 2.0 + recencyA;
        final scoreB = countB * 2.0 + recencyB;
        return scoreB.compareTo(scoreA);
      });

      var tracks = candidates.take(def.limit).toList();

      // Fallback: If history is empty, populate from all available tracks
      if (tracks.isEmpty) {
        final allTrackRows = await (_db.select(_db.tracks)
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
              ..limit(def.limit))
            .get();
        tracks = allTrackRows.map(_mapRowToTrack).toList();
      }

      return Shelf(
        id: def.id,
        title: def.title,
        subtitle: 'Recently and frequently played',
        rule: def.rule,
        tracks: tracks,
      );
    } catch (_) {
      return Shelf(
        id: def.id,
        title: def.title,
        subtitle: 'Recently played',
        rule: def.rule,
        tracks: const [],
      );
    }
  }

  /// 2. Daily Mix (rule: kmeans_clusters)
  /// Blends familiar anchor tracks with rich Spotify recommendation engine training
  Future<Shelf> _buildDailyMixShelf(ShelfDefinition def) async {
    try {
      // Find top artists from taste profiles
      final topArtists = await (_db.select(_db.tasteProfiles)
            ..where((tbl) => tbl.entityType.equals('artist'))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.slowWeight)])
            ..limit(5))
          .get();

      final familiarTracks = <Track>[];
      final discoveryTracks = <Track>[];
      final seenKeys = <String>{};
      final seenIds = <String>{};

      // 1. Collect familiar tracks from local database
      if (topArtists.isNotEmpty) {
        for (final artistRow in topArtists) {
          final rows = await (_db.select(_db.tracks)
                ..where((tbl) => tbl.artist.equals(artistRow.entityId))
                ..limit(4))
              .get();
          for (final r in rows) {
            final t = _mapRowToTrack(r);
            final key = _normalizeKey(t.title, t.artist);
            if (seenIds.add(t.id) && seenKeys.add(key)) {
              familiarTracks.add(t);
            }
          }
        }
      }

      // If no taste profile artists yet, pull from recent tracks
      if (familiarTracks.isEmpty) {
        final recentRows = await (_db.select(_db.tracks)
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
              ..limit(8))
            .get();
        for (final r in recentRows) {
          final t = _mapRowToTrack(r);
          final key = _normalizeKey(t.title, t.artist);
          if (seenIds.add(t.id) && seenKeys.add(key)) {
            familiarTracks.add(t);
          }
        }
      }

      // 2. Train Daily Mix directly on Spotify recommendations for user's top tastes
      final targetArtists = topArtists.isNotEmpty
          ? topArtists.map((a) => a.entityId).toList()
          : familiarTracks.map((t) => t.artist).toSet().take(3).toList();

      for (final artistName in targetArtists) {
        try {
          // Resolve Spotify Artist
          final searchRes = await _spotifyApi.search(artistName, limit: 1);
          if (searchRes.artists.isNotEmpty) {
            final artistRef = searchRes.artists.first;
            // A. Extract Spotify Artist Radio
            final radioTracks = await _spotifyApi.getArtistRadio(artistRef.id);
            for (final t in radioTracks) {
              final key = _normalizeKey(t.title, t.artist);
              if (seenIds.add(t.id) && seenKeys.add(key)) {
                discoveryTracks.add(t);
              }
            }
            // B. Extract Spotify Artist Top Tracks
            final topSpotifyTracks = await _spotifyApi.getArtistTopTracks(artistRef.id);
            for (final t in topSpotifyTracks) {
              final key = _normalizeKey(t.title, t.artist);
              if (seenIds.add(t.id) && seenKeys.add(key)) {
                discoveryTracks.add(t);
              }
            }
          }
        } catch (_) {}
      }

      // Also enrich from familiar seed tracks via Spotify Track Radio
      for (final seed in familiarTracks.take(3)) {
        try {
          String? sId;
          if (seed.sourceId.startsWith('spotify_')) {
            sId = seed.sourceId.replaceFirst('spotify_', '');
          } else {
            final searchRes = await _spotifyApi.search('${seed.title} ${seed.artist}', limit: 1);
            if (searchRes.tracks.isNotEmpty) {
              sId = searchRes.tracks.first.id.replaceFirst('spotify_', '');
            }
          }
          if (sId != null && sId.isNotEmpty && RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(sId)) {
            final trackRadio = await _spotifyApi.getTrackRadio(sId);
            for (final t in trackRadio) {
              final key = _normalizeKey(t.title, t.artist);
              if (seenIds.add(t.id) && seenKeys.add(key)) {
                discoveryTracks.add(t);
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fallback to co-occurrence neighbors and local catalog if offline / insufficient Spotify
      if (discoveryTracks.length + familiarTracks.length < def.limit) {
        for (final track in familiarTracks.take(5)) {
          final neighbors = await _cooccurrenceRepo.getTopNeighbors(track.id, limit: 3);
          for (final neighborId in neighbors) {
            if (!seenIds.contains(neighborId)) {
              final row = await (_db.select(_db.tracks)
                    ..where((tbl) => tbl.id.equals(neighborId)))
                  .getSingleOrNull();
              if (row != null) {
                final t = _mapRowToTrack(row);
                final key = _normalizeKey(t.title, t.artist);
                if (seenIds.add(t.id) && seenKeys.add(key)) {
                  discoveryTracks.add(t);
                }
              }
            }
          }
        }
      }

      // If still insufficient (e.g. unit tests without network), supplement from tracks table
      if (discoveryTracks.length + familiarTracks.length < def.limit) {
        final moreRows = await (_db.select(_db.tracks)
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
              ..limit(def.limit * 2))
            .get();
        for (final r in moreRows) {
          final t = _mapRowToTrack(r);
          final key = _normalizeKey(t.title, t.artist);
          if (seenIds.add(t.id) && seenKeys.add(key)) {
            discoveryTracks.add(t);
          }
          if (discoveryTracks.length + familiarTracks.length >= def.limit * 2) break;
        }
      }

      // 4. Score and Rank candidates
      final recCandidates = <RecommendationCandidate>[];
      for (final t in familiarTracks) {
        final tasteSim = await _tasteProfileRepo.computeTasteSimilarity(t);
        recCandidates.add(
          RecommendationCandidate(
            track: t,
            features: {
              'taste_sim': math.max(tasteSim, 0.8),
              'cooccurrence': 0.7,
              'recency': 0.8,
              'novelty': 0.1,
              'artist_skip_penalty': 0.0,
            },
          ),
        );
      }
      for (final t in discoveryTracks) {
        final tasteSim = await _tasteProfileRepo.computeTasteSimilarity(t);
        final skipPenalty = await _ranker.computeArtistSkipPenaltyFromHistory(t.artist);
        recCandidates.add(
          RecommendationCandidate(
            track: t,
            features: {
              'taste_sim': tasteSim,
              'cooccurrence': 0.5,
              'recency': 0.2,
              'novelty': 0.7,
              'artist_skip_penalty': skipPenalty,
            },
          ),
        );
      }

      final ranked = _ranker.rank(recCandidates);
      var tracks = ranked.take(def.limit).map((c) => c.track).toList();

      final diversity = _diversityController;
      if (diversity != null) {
        final snoozed = (await diversity.getSnoozedArtists()).map((a) => a.toLowerCase().trim()).toSet();
        if (snoozed.isNotEmpty) {
          tracks = tracks.where((t) => !snoozed.contains(t.artist.toLowerCase().trim())).toList();
        }
        tracks = diversity.applyMmr(tracks, maxPerArtist: 2);
      }

      // 5. Ensure authentic artwork resolution (guarantees real album art instead of radio banners)
      tracks = await _spotifyApi.resolveAuthenticCovers(tracks);

      return Shelf(
        id: def.id,
        title: def.title,
        subtitle: 'Personalized mix based on your taste',
        rule: def.rule,
        tracks: tracks,
      );
    } catch (_) {
      return Shelf(
        id: def.id,
        title: def.title,
        subtitle: 'Personalized mix',
        rule: def.rule,
        tracks: const [],
      );
    }
  }

  /// 3. Discover Weekly (rule: novelty_with_familiar_anchor)
  /// Guaranteed Invariant: ~10% familiar tracks inserted as trust anchors,
  /// with remainder extracted directly from Spotify's recommendation models.
  Future<Shelf> _buildDiscoverWeeklyShelf(ShelfDefinition def) async {
    try {
      // 1. Identify played/familiar tracks
      final historyTrackIds = (await (_db.selectOnly(_db.playHistories)
                ..addColumns([_db.playHistories.trackId]))
              .map((row) => row.read(_db.playHistories.trackId)!)
              .get())
          .toSet();

      final likedTrackRows = await (_db.select(_db.tracks)
            ..where((tbl) => tbl.isLiked.equals(true)))
          .get();
      for (final r in likedTrackRows) {
        historyTrackIds.add(r.id);
      }

      final allTracks = (await _db.select(_db.tracks).get())
          .map(_mapRowToTrack)
          .toList();

      final novelPool = <Track>[];
      final familiarPool = <Track>[];
      final seenKeys = <String>{};

      for (final t in allTracks) {
        final key = _normalizeKey(t.title, t.artist);
        seenKeys.add(key);
        if (historyTrackIds.contains(t.id)) {
          familiarPool.add(t);
        } else {
          novelPool.add(t);
        }
      }

      // 2. Extract deep recommendations directly from Spotify
      final seeds = familiarPool.isNotEmpty
          ? familiarPool.take(4).toList()
          : allTracks.take(4).toList();

      for (final seed in seeds) {
        try {
          String? sId;
          if (seed.sourceId.startsWith('spotify_')) {
            sId = seed.sourceId.replaceFirst('spotify_', '');
          } else {
            final searchRes = await _spotifyApi.search('${seed.title} ${seed.artist}', limit: 1);
            if (searchRes.tracks.isNotEmpty) {
              sId = searchRes.tracks.first.id.replaceFirst('spotify_', '');
            }
          }
          if (sId != null && sId.isNotEmpty && RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(sId)) {
            // A. Spotify Recommended Tracks
            final recs = await _spotifyApi.getRecommendedTracks(sId);
            for (final r in recs) {
              final key = _normalizeKey(r.title, r.artist);
              if (!historyTrackIds.contains(r.id) &&
                  !novelPool.any((x) => x.id == r.id) &&
                  seenKeys.add(key)) {
                novelPool.add(r);
              }
            }
            // B. Spotify Track Radio
            final radio = await _spotifyApi.getTrackRadio(sId);
            for (final r in radio) {
              final key = _normalizeKey(r.title, r.artist);
              if (!historyTrackIds.contains(r.id) &&
                  !novelPool.any((x) => x.id == r.id) &&
                  seenKeys.add(key)) {
                novelPool.add(r);
              }
            }
          }
        } catch (_) {}
      }

      // 3. Rank novel pool
      final novelCandidates = <RecommendationCandidate>[];
      for (final t in novelPool) {
        final tasteSim = await _tasteProfileRepo.computeTasteSimilarity(t);
        final skipPenalty =
            await _ranker.computeArtistSkipPenaltyFromHistory(t.artist);
        novelCandidates.add(
          RecommendationCandidate(
            track: t,
            features: {
              'taste_sim': tasteSim,
              'cooccurrence': 0.4,
              'recency': 0.0,
              'novelty': 1.0,
              'artist_skip_penalty': skipPenalty,
            },
          ),
        );
      }
      final rankedNovel =
          _ranker.rank(novelCandidates).map((c) => c.track).toList();

      // 4. Interleave familiar trust anchors according to novelty arm ratio
      final totalCapacity = math.min(def.limit, rankedNovel.length + familiarPool.length);
      final finalTracks = <Track>[];
      int novelIdx = 0;
      int familiarIdx = 0;

      int anchorInterval = 10;
      final bandit = _banditCalibrator;
      if (bandit != null) {
        final ratio = await bandit.getNoveltyRatio(def.id);
        if (ratio > 0.0) {
          anchorInterval = (1.0 / ratio).round().clamp(2, 20);
        }
      } else if (def.familiarRatio > 0.0) {
        anchorInterval = (1.0 / def.familiarRatio).round().clamp(2, 20);
      }

      for (int i = 0; i < totalCapacity; i++) {
        // Interval slots are familiar trust anchors
        final isAnchorSlot = (i % anchorInterval == anchorInterval - 1);
        if (isAnchorSlot && familiarIdx < familiarPool.length) {
          finalTracks.add(familiarPool[familiarIdx++]);
        } else if (novelIdx < rankedNovel.length) {
          finalTracks.add(rankedNovel[novelIdx++]);
        } else if (familiarIdx < familiarPool.length) {
          finalTracks.add(familiarPool[familiarIdx++]);
        }
      }

      var calibratedTracks = finalTracks;
      if (bandit != null) {
        final topGenres = await _tasteProfileRepo.getTopEntities(entityType: 'genre', limit: 4);
        if (topGenres.isNotEmpty) {
          final targetDist = {for (final g in topGenres) g.entityId: g.blendedAffinity};
          calibratedTracks = bandit.calibrateSlate(
            candidates: finalTracks,
            targetGenreDistribution: targetDist,
          );
        }
      }

      final diversity = _diversityController;
      if (diversity != null) {
        final snoozed = (await diversity.getSnoozedArtists()).map((a) => a.toLowerCase().trim()).toSet();
        if (snoozed.isNotEmpty) {
          calibratedTracks = calibratedTracks.where((t) => !snoozed.contains(t.artist.toLowerCase().trim())).toList();
        }
        calibratedTracks = diversity.applyMmr(calibratedTracks, maxPerArtist: 2);
      }

      // 5. Ensure authentic artwork resolution (guarantees real album art instead of radio banners)
      calibratedTracks = await _spotifyApi.resolveAuthenticCovers(calibratedTracks);

      return Shelf(
        id: def.id,
        title: def.title,
        subtitle: 'New discoveries tailored to your taste',
        rule: def.rule,
        tracks: calibratedTracks,
      );
    } catch (_) {
      return Shelf(
        id: def.id,
        title: def.title,
        subtitle: 'Discover Weekly',
        rule: def.rule,
        tracks: const [],
      );
    }
  }

  String _normalizeKey(String title, String artist) =>
      '${title.toLowerCase().trim()}:::${artist.toLowerCase().trim()}';

  Track _mapRowToTrack(TrackRow row) {
    return Track(
      id: row.id,
      sourceId: row.sourceId,
      title: row.title,
      artist: row.artist,
      album: row.album,
      duration: Duration(milliseconds: row.durationMs),
      coverUrl: row.coverUrl,
      isLiked: row.isLiked,
    );
  }
}
