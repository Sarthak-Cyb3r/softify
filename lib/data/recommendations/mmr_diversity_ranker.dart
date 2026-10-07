import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_diversity_controller.dart';
import '../database/app_database.dart';

class MmrDiversityRanker implements IDiversityController {
  final AppDatabase? _db;
  final Map<String, int> _inMemorySnoozes = {};
  bool _learningPaused = false;

  MmrDiversityRanker({AppDatabase? db}) : _db = db;

  @override
  List<Track> applyMmr(
    List<Track> ranked, {
    int maxPerArtist = 2,
    double lambda = 0.7,
  }) {
    if (ranked.isEmpty) return const [];
    if (ranked.length == 1) return List.unmodifiable(ranked);

    final n = ranked.length;
    // Map relevance as normalized rank: Rel(d_i) = 1.0 - (i / n)
    final relScores = <Track, double>{
      for (int i = 0; i < n; i++) ranked[i]: 1.0 - (i / n.toDouble()),
    };

    final selected = <Track>[];
    final remaining = List<Track>.from(ranked);
    final artistCounts = <String, int>{};

    while (remaining.isNotEmpty) {
      Track? bestCandidate;
      double highestMmrScore = -double.infinity;

      for (final candidate in remaining) {
        final artistKey = candidate.artist.trim().toLowerCase();
        final currentCount = artistCounts[artistKey] ?? 0;
        if (currentCount >= maxPerArtist) {
          // Hard invariant: Skip candidates exceeding maxPerArtist
          continue;
        }

        final rel = relScores[candidate] ?? 0.0;

        // Compute max similarity to already selected tracks
        double maxSim = 0.0;
        for (final s in selected) {
          final sim = _computeSimilarity(candidate, s);
          if (sim > maxSim) {
            maxSim = sim;
          }
        }

        // MMR = lambda * Rel(d) - (1 - lambda) * maxSim(d, S)
        final mmrScore = (lambda * rel) - ((1.0 - lambda) * maxSim);

        if (mmrScore > highestMmrScore) {
          highestMmrScore = mmrScore;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate != null) {
        selected.add(bestCandidate);
        remaining.remove(bestCandidate);
        final artistKey = bestCandidate.artist.trim().toLowerCase();
        artistCounts[artistKey] = (artistCounts[artistKey] ?? 0) + 1;
      } else {
        // If all remaining candidates violate maxPerArtist, break
        break;
      }
    }

    return selected;
  }

  double _computeSimilarity(Track a, Track b) {
    if (a.id == b.id) return 1.0;
    if (a.artist.trim().toLowerCase() == b.artist.trim().toLowerCase()) {
      return 1.0;
    }
    if (a.album != null &&
        b.album != null &&
        a.album!.trim().toLowerCase() == b.album!.trim().toLowerCase()) {
      return 0.5;
    }
    return 0.0;
  }

  @override
  Future<void> snoozeArtist(String artistId, Duration duration) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snoozedUntil = now + duration.inMilliseconds;
    final key = artistId.trim().toLowerCase();
    _inMemorySnoozes[key] = snoozedUntil;

    final db = _db;
    if (db != null) {
      try {
        await db.into(db.artistSnoozes).insertOnConflictUpdate(
          ArtistSnoozeRow(
            artistId: key,
            snoozedUntil: snoozedUntil,
          ),
        );
      } catch (_) {}
    }
  }

  @override
  Future<bool> isSnoozed(String artistId) async {
    final key = artistId.trim().toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_inMemorySnoozes.containsKey(key)) {
      final until = _inMemorySnoozes[key]!;
      if (until > now) return true;
      _inMemorySnoozes.remove(key);
    }

    final db = _db;
    if (db != null) {
      try {
        final row = await (db.select(db.artistSnoozes)
              ..where((tbl) => tbl.artistId.equals(key)))
            .getSingleOrNull();
        if (row != null) {
          if (row.snoozedUntil > now) {
            _inMemorySnoozes[key] = row.snoozedUntil;
            return true;
          } else {
            // Expired snooze
            await (db.delete(db.artistSnoozes)
                  ..where((tbl) => tbl.artistId.equals(key)))
                .go();
          }
        }
      } catch (_) {}
    }

    return false;
  }

  @override
  Future<List<String>> getSnoozedArtists() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = _db;
    if (db != null) {
      try {
        final rows = await (db.select(db.artistSnoozes)
              ..where((tbl) => tbl.snoozedUntil.isBiggerThan(Variable(now))))
            .get();
        return rows.map((r) => r.artistId).toList();
      } catch (_) {}
    }
    return _inMemorySnoozes.entries
        .where((e) => e.value > now)
        .map((e) => e.key)
        .toList();
  }

  @override
  Future<void> removeSnooze(String artistId) async {
    final key = artistId.trim().toLowerCase();
    _inMemorySnoozes.remove(key);

    final db = _db;
    if (db != null) {
      try {
        await (db.delete(db.artistSnoozes)
              ..where((tbl) => tbl.artistId.equals(key)))
            .go();
      } catch (_) {}
    }
  }

  @override
  Future<void> resetAllLearning() async {
    _inMemorySnoozes.clear();
    final db = _db;
    if (db != null) {
      await db.delete(db.tasteProfiles).go();
      await db.delete(db.cooccurrences).go();
      await db.delete(db.banditStates).go();
      await db.delete(db.queryCompletions).go();
      await db.delete(db.searchEvents).go();
      await db.delete(db.playEvents).go();
      await db.delete(db.artistSnoozes).go();
    }
  }

  @override
  Future<void> setLearningPaused(bool paused) async {
    _learningPaused = paused;
    final db = _db;
    if (db != null) {
      await db.into(db.settings).insertOnConflictUpdate(
        SettingRow(
          key: 'learning_paused',
          value: paused ? 'true' : 'false',
        ),
      );
    }
  }

  @override
  Future<bool> isLearningPaused() async {
    final db = _db;
    if (db != null) {
      final row = await (db.select(db.settings)
            ..where((tbl) => tbl.key.equals('learning_paused')))
          .getSingleOrNull();
      if (row != null) {
        _learningPaused = (row.value == 'true');
      }
    }
    return _learningPaused;
  }
}
