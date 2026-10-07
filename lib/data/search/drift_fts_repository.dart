import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_fts_repository.dart';
import '../database/app_database.dart';
import 'text_normalizer.dart';

class DriftFtsRepository implements IFtsRepository {
  final AppDatabase _db;
  bool _tableEnsured = false;

  DriftFtsRepository(this._db);

  Future<void> _ensureTable() async {
    if (_tableEnsured) return;
    await _db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS track_fts USING fts5(
        track_id UNINDEXED,
        title,
        artist,
        album,
        tokenize = 'unicode61 remove_diacritics 2'
      );
    ''');
    _tableEnsured = true;
  }

  @override
  Future<void> indexTrack(Track track) async {
    await _ensureTable();
    await removeTrack(track.id);
    await _db.customInsert(
      'INSERT INTO track_fts (track_id, title, artist, album) VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString(track.id),
        Variable.withString(TextNormalizer.normalize(track.title)),
        Variable.withString(TextNormalizer.normalize(track.artist)),
        Variable.withString(TextNormalizer.normalize(track.album ?? '')),
      ],
    );
  }

  @override
  Future<void> removeTrack(String trackId) async {
    await _ensureTable();
    await _db.customStatement(
      'DELETE FROM track_fts WHERE track_id = ?',
      [trackId],
    );
  }

  @override
  Future<List<String>> queryFts(String query) async {
    await _ensureTable();
    final clean = TextNormalizer.normalize(query);
    if (clean.isEmpty) return [];

    final rawTokens = clean
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^\w]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) return [];

    // FTS5 prefix match: "term1"* "term2"*
    final ftsQuery = rawTokens.map((t) => '"$t"*').join(' ');

    try {
      final rows = await _db.customSelect(
        'SELECT track_id, rank FROM track_fts WHERE track_fts MATCH ? ORDER BY rank LIMIT 30',
        variables: [Variable.withString(ftsQuery)],
      ).get();

      return rows.map((r) => r.read<String>('track_id')).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> rebuildFullIndex() async {
    await _ensureTable();
    await _db.customStatement('DELETE FROM track_fts');
    final allTracks = await _db.select(_db.tracks).get();
    for (final row in allTracks) {
      await _db.customInsert(
        'INSERT INTO track_fts (track_id, title, artist, album) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(row.id),
          Variable.withString(TextNormalizer.normalize(row.title)),
          Variable.withString(TextNormalizer.normalize(row.artist)),
          Variable.withString(TextNormalizer.normalize(row.album ?? '')),
        ],
      );
    }
  }
}
