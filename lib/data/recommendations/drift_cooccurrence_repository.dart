import 'package:drift/drift.dart';

import '../../domain/ports/i_cooccurrence_repository.dart';
import '../database/app_database.dart';
import 'recommendation_isolates.dart';

class DriftCooccurrenceRepository implements ICooccurrenceRepository {
  final AppDatabase _db;

  DriftCooccurrenceRepository(this._db);

  @override
  Future<void> rebuildGraphIncremental(List<List<String>> sentences) async {
    if (sentences.isEmpty) return;

    // Run heavy PMI calculation off the main thread
    final pairs = await RecommendationIsolates.computePPMIOffThread(sentences);
    if (pairs.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.batch((batch) {
      for (final p in pairs) {
        batch.insert(
          _db.cooccurrences,
          CooccurrencesCompanion.insert(
            trackA: p.trackA,
            trackB: p.trackB,
            score: p.score,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<List<String>> getTopNeighbors(String trackId, {int limit = 20}) async {
    final rows = await (_db.select(_db.cooccurrences)
          ..where((t) => t.trackA.equals(trackId))
          ..orderBy([(t) => OrderingTerm.desc(t.score)])
          ..limit(limit))
        .get();

    return rows.map((r) => r.trackB).toList();
  }

  @override
  Future<double> getPairScore(String trackA, String trackB) async {
    final row = await (_db.select(_db.cooccurrences)
          ..where((t) => t.trackA.equals(trackA) & t.trackB.equals(trackB)))
        .getSingleOrNull();

    return row?.score ?? 0.0;
  }
}
