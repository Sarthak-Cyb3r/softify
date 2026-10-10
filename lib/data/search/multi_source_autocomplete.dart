import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../domain/ports/i_autocomplete_repository.dart';
import '../../domain/ports/i_diversity_controller.dart';
import '../../domain/ports/i_remote_config.dart';
import '../database/app_database.dart';
import '../services/spotify_api_service.dart';
import 'text_normalizer.dart';

class MultiSourceAutocomplete implements IAutocompleteRepository {
  final AppDatabase _db;
  final IRemoteConfig? _remoteConfig;
  final IDiversityController? _diversityController;
  final SpotifyApiService? _spotifyApi;

  MultiSourceAutocomplete({
    required AppDatabase db,
    IRemoteConfig? remoteConfig,
    IDiversityController? diversityController,
    SpotifyApiService? spotifyApi,
  })  : _db = db,
        _remoteConfig = remoteConfig,
        _diversityController = diversityController,
        _spotifyApi = spotifyApi;

  @override
  Future<List<String>> getSuggestions(String prefix) async {
    final cleanPrefix = TextNormalizer.normalize(prefix);
    if (cleanPrefix.isEmpty) return const [];

    final now = DateTime.now().millisecondsSinceEpoch;
    final candidateScores = <String, _ScoredSuggestion>{};

    void addCandidate(String text, double score) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;
      final key = TextNormalizer.normalize(trimmed);
      if (key.isEmpty) return;

      if (!candidateScores.containsKey(key)) {
        candidateScores[key] = _ScoredSuggestion(trimmed, score);
      } else {
        // Boost if appearing across multiple sources
        final current = candidateScores[key]!;
        candidateScores[key] = _ScoredSuggestion(
          current.text,
          math.max(current.score, score) + (score * 0.1),
        );
      }
    }

    // 1. Source 1: Historical Successful Queries (QueryCompletions)
    try {
      final successfulRows = await (_db.select(_db.queryCompletions)
            ..where((tbl) =>
                tbl.normalizedPrefix.like('$cleanPrefix%') |
                tbl.query.like('$cleanPrefix%') |
                tbl.query.like('%$cleanPrefix%'))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.streamCount)])
            ..limit(15))
          .get();

      for (final row in successfulRows) {
        // High base score: past successful queries rank above untested ones
        final recencyBoost =
            1.0 / (1.0 + (now - row.lastUsedTs) / 86400000.0);
        final score = 100.0 + (row.streamCount * 20.0) + (recencyBoost * 5.0);
        addCandidate(row.query, score);
      }
    } catch (_) {}

    // 2. Source 2: Local Library Titles & Artists (Tracks)
    try {
      final trackRows = await (_db.select(_db.tracks)
            ..where((tbl) =>
                tbl.title.like('$cleanPrefix%') |
                tbl.artist.like('$cleanPrefix%'))
            ..limit(15))
          .get();

      for (final track in trackRows) {
        if (TextNormalizer.normalize(track.title).startsWith(cleanPrefix)) {
          addCandidate(track.title, 50.0);
        }
        if (TextNormalizer.normalize(track.artist).startsWith(cleanPrefix)) {
          addCandidate(track.artist, 55.0);
        }
      }
    } catch (_) {}

    // 3. Source 3: Expansion Rules ([prefix] songs, [prefix] live, etc.)
    if (cleanPrefix.length >= 2) {
      addCandidate('$cleanPrefix songs', 40.0);
      addCandidate('$cleanPrefix hits', 35.0);
      addCandidate('$cleanPrefix live', 32.0);
      addCandidate('$cleanPrefix remix', 30.0);
    }

    // 4. Source 4: Recent Searches (SearchEvents)
    try {
      final searchRows = await (_db.select(_db.searchEvents)
            ..where((tbl) =>
                tbl.query.like('$cleanPrefix%') |
                tbl.query.like('%$cleanPrefix%'))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.ts)])
            ..limit(10))
          .get();

      for (final s in searchRows) {
        final recency = 1.0 / (1.0 + (now - s.ts) / 86400000.0);
        addCandidate(s.query, 25.0 + recency * 5.0);
      }
    } catch (_) {}

    // 5. Source 5: Aliases Expansion from RemoteConfig
    if (_remoteConfig != null) {
      try {
        final aliases = _remoteConfig.getSearchAliases();
        final expanded = TextNormalizer.expandAliases(cleanPrefix, aliases);
        for (final aliasTarget in expanded) {
          if (aliasTarget != cleanPrefix) {
            addCandidate(aliasTarget, 45.0);
          }
        }
      } catch (_) {}
    }

    // 6. Source 6: Reverse Engineered Spotify Real-Time Search Suggestions
    if (_spotifyApi != null && cleanPrefix.length >= 2) {
      try {
        final spotifySuggestions = await _spotifyApi.getSearchSuggestions(prefix);
        for (var i = 0; i < spotifySuggestions.length; i++) {
          final rankScore = 75.0 - (i * 3.0);
          addCandidate(spotifySuggestions[i], rankScore);
        }
      } catch (_) {}
    }

    // Sort descending by score
    final sorted = candidateScores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final diversity = _diversityController;
    if (diversity != null) {
      final snoozed = (await diversity.getSnoozedArtists())
          .map((a) => a.toLowerCase().trim())
          .toSet();
      if (snoozed.isNotEmpty) {
        sorted.removeWhere((s) {
          final sLower = s.text.toLowerCase();
          return snoozed.any((artist) => sLower.contains(artist));
        });
      }
    }

    return sorted.map((s) => s.text).take(8).toList();
  }

  @override
  Future<void> recordSuccessfulQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final normalized = TextNormalizer.normalize(trimmed);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final existing = await (_db.select(_db.queryCompletions)
            ..where((tbl) => tbl.query.equals(trimmed)))
          .getSingleOrNull();

      if (existing != null) {
        await (_db.update(_db.queryCompletions)
              ..where((tbl) => tbl.query.equals(trimmed)))
            .write(
          QueryCompletionsCompanion(
            streamCount: Value(existing.streamCount + 1),
            lastUsedTs: Value(now),
          ),
        );
      } else {
        await _db.into(_db.queryCompletions).insert(
              QueryCompletionsCompanion.insert(
                query: trimmed,
                normalizedPrefix: normalized,
                streamCount: const Value(1),
                lastUsedTs: now,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    } catch (_) {}
  }
}

class _ScoredSuggestion {
  final String text;
  final double score;

  const _ScoredSuggestion(this.text, this.score);
}
