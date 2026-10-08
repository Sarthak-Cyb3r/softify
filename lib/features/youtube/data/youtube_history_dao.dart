import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';

class YoutubeHistoryDao {
  final AppDatabase _db;

  YoutubeHistoryDao(this._db);

  /// Upserts a played YouTube item into history.
  Future<void> upsertHistory({
    required String videoId,
    required String title,
    required String channel,
    String? thumbnailUrl,
    required int durationSeconds,
    required int lastPlayedAt,
  }) async {
    await _db.into(_db.youtubeHistory).insertOnConflictUpdate(
          YoutubeHistoryCompanion(
            videoId: Value(videoId),
            title: Value(title),
            channel: Value(channel),
            thumbnailUrl: Value(thumbnailUrl),
            durationSeconds: Value(durationSeconds),
            lastPlayedAt: Value(lastPlayedAt),
          ),
        );
  }

  /// Watches recent history items (limit default: 50, newest first).
  Stream<List<YoutubeHistoryRow>> watchRecent({int limit = 50}) {
    return (_db.select(_db.youtubeHistory)
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
  Future<List<YoutubeHistoryRow>> getRecent({int limit = 50}) {
    return (_db.select(_db.youtubeHistory)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastPlayedAt,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(limit))
        .get();
  }

  /// Deletes a single YouTube video history entry.
  Future<int> deleteEntry(String videoId) {
    return (_db.delete(_db.youtubeHistory)
          ..where((t) => t.videoId.equals(videoId)))
        .go();
  }

  /// Clears all YouTube link playback history.
  Future<int> clearAll() {
    return _db.delete(_db.youtubeHistory).go();
  }
}
