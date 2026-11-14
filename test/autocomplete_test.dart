import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/search/multi_source_autocomplete.dart';

void main() {
  group('MultiSourceAutocomplete', () {
    late AppDatabase db;
    late MultiSourceAutocomplete autocomplete;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      autocomplete = MultiSourceAutocomplete(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns empty suggestions for empty prefix', () async {
      final suggestions = await autocomplete.getSuggestions('');
      expect(suggestions, isEmpty);
    });

    test('past successful queries rank above untested ones for the same prefix', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Seed an untested query in SearchEvents
      await db.into(db.searchEvents).insert(
            SearchEventsCompanion.insert(
              ts: now,
              query: 'arijit unplayed',
              resultIdsJson: '[]',
              shownCount: 5,
              rankerVersion: 'v1',
            ),
          );

      // Seed a track in library
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 't_arijit_1',
              sourceId: 's1',
              title: 'Arijit Hit Song',
              artist: 'Arijit Singh',
              durationMs: 200000,
              createdAt: now,
            ),
          );

      // Seed a successful query in QueryCompletions (streamCount = 5)
      await db.into(db.queryCompletions).insert(
            QueryCompletionsCompanion.insert(
              query: 'arijit romantic hits',
              normalizedPrefix: 'arijit romantic hits',
              streamCount: const Value(5),
              lastUsedTs: now,
            ),
          );

      final suggestions = await autocomplete.getSuggestions('arijit');

      expect(suggestions, isNotEmpty);
      // The successful query must be the top #1 suggestion
      expect(suggestions.first, 'arijit romantic hits');

      // The other sources follow below
      expect(suggestions.contains('arijit songs'), isTrue); // expansion rule
    });

    test('recordSuccessfulQuery inserts new entry and increments streamCount on repeats', () async {
      // First success for query
      await autocomplete.recordSuccessfulQuery('tum hi ho');

      var suggestions = await autocomplete.getSuggestions('tum');
      expect(suggestions.first, 'tum hi ho');

      var row = await (db.select(db.queryCompletions)
            ..where((tbl) => tbl.query.equals('tum hi ho')))
          .getSingle();
      expect(row.streamCount, 1);

      // Second success for same query (downstream repeat)
      await autocomplete.recordSuccessfulQuery('tum hi ho');

      row = await (db.select(db.queryCompletions)
            ..where((tbl) => tbl.query.equals('tum hi ho')))
          .getSingle();
      expect(row.streamCount, 2);
    });

    test('expansion rules generate relevant candidates for short prefix', () async {
      final suggestions = await autocomplete.getSuggestions('diljit');
      expect(suggestions.contains('diljit songs'), isTrue);
      expect(suggestions.contains('diljit hits'), isTrue);
    });

    test('deduplicates case-insensitively across multiple sources', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Same query in library and in recents with different case
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 't_coldplay',
              sourceId: 's_cp',
              title: 'Yellow',
              artist: 'Coldplay',
              durationMs: 260000,
              createdAt: now,
            ),
          );
      await db.into(db.searchEvents).insert(
            SearchEventsCompanion.insert(
              ts: now,
              query: 'coldplay',
              resultIdsJson: '[]',
              shownCount: 1,
              rankerVersion: 'v1',
            ),
          );

      final suggestions = await autocomplete.getSuggestions('cold');

      // Should contain Coldplay once, not duplicated
      final coldplayCount =
          suggestions.where((s) => s.toLowerCase() == 'coldplay').length;
      expect(coldplayCount, 1);
    });
  });
}
