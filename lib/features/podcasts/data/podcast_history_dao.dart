import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';

class PodcastHistoryDao {
  final AppDatabase _db;

  PodcastHistoryDao(this._db);

  /// Upserts a played podcast episode into history.
  Future<void> upsertHistory({
    required String episodeId,
    required String showId,
    required String showName,
    required String title,
    String? description,
    String? thumbnailUrl,
    required int durationSeconds,
    int resumePositionMs = 0,
    required int lastPlayedAt,
  }) async {
    await _db.into(_db.podcastHistory).insertOnConflictUpdate(
          PodcastHistoryCompanion(
            episodeId: Value(episodeId),
            showId: Value(showId),
            showName: Value(showName),
            title: Value(title),
            description: Value(description),
            thumbnailUrl: Value(thumbnailUrl),
            durationSeconds: Value(durationSeconds),
            resumePositionMs: Value(resumePositionMs),
            lastPlayedAt: Value(lastPlayedAt),
          ),
        );
  }

  /// Updates the playback resume position for an episode.
  Future<int> updatePosition(String episodeId, int positionMs) {
    return (_db.update(_db.podcastHistory)
          ..where((t) => t.episodeId.equals(episodeId)))
        .write(
      PodcastHistoryCompanion(
        resumePositionMs: Value(positionMs),
        lastPlayedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Watches recent history items (limit default: 50, newest first).
  Stream<List<PodcastHistoryRow>> watchRecent({int limit = 50}) {
    return (_db.select(_db.podcastHistory)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastPlayedAt,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(limit))
        .watch();
  }

  /// Fetches recent history snapshot (limit default: 50, newest first).
  Future<List<PodcastHistoryRow>> getRecent({int limit = 50}) {
    return (_db.select(_db.podcastHistory)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastPlayedAt,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(limit))
        .get();
  }

  /// Deletes a single episode history entry.
  Future<int> deleteEntry(String episodeId) {
    return (_db.delete(_db.podcastHistory)
          ..where((t) => t.episodeId.equals(episodeId)))
        .go();
  }

  /// Clears all podcast history entries.
  Future<int> clearAll() {
    return _db.delete(_db.podcastHistory).go();
  }
}
