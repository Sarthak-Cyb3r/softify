import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/recommendations/drift_cooccurrence_repository.dart';
import 'package:softify/data/recommendations/drift_taste_profile_repository.dart';
import 'package:softify/data/recommendations/logistic_regression_ranker.dart';
import 'package:softify/data/recommendations/shelf_engine.dart';

void main() {
  group('ShelfEngine', () {
    late AppDatabase db;
    late DriftTasteProfileRepository tasteRepo;
    late DriftCooccurrenceRepository cooccurRepo;
    late LogisticRegressionRanker ranker;
    late ShelfEngine engine;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tasteRepo = DriftTasteProfileRepository(db);
      cooccurRepo = DriftCooccurrenceRepository(db);
      ranker = LogisticRegressionRanker(db: db);
      engine = ShelfEngine(
        db: db,
        tasteProfileRepo: tasteRepo,
        cooccurrenceRepo: cooccurRepo,
        ranker: ranker,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('generates empty or fallback shelves safely when database has no tracks', () async {
      final shelves = await engine.loadShelves();
      expect(shelves, isA<List>());
      // Does not throw and returns cleanly
    });

    test('Discover Weekly invariant: exactly ~10% familiar tracks (1 in 10 anchor ratio)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Seed 2 familiar tracks (played in history)
      for (int i = 1; i <= 2; i++) {
        await db.into(db.tracks).insert(
              TracksCompanion.insert(
                id: 'familiar_$i',
                sourceId: 'src_f_$i',
                title: 'Familiar Track $i',
                artist: 'Familiar Artist',
                durationMs: 180000,
                createdAt: now,
                isLiked: const Value(true),
              ),
            );
        await db.into(db.playHistories).insert(
              PlayHistoriesCompanion.insert(
                trackId: 'familiar_$i',
                playedAt: now - (i * 10000),
                completedRatio: 1.0,
              ),
            );
      }

      // Seed 18 novel tracks (never played)
      for (int i = 1; i <= 18; i++) {
        await db.into(db.tracks).insert(
              TracksCompanion.insert(
                id: 'novel_$i',
                sourceId: 'src_n_$i',
                title: 'Novel Track $i',
                artist: 'New Artist $i',
                durationMs: 180000,
                createdAt: now,
              ),
            );
      }

      // Total 20 tracks: 18 novel + 2 familiar
      final shelves = await engine.loadShelves(forceRefresh: true);
      final discoverShelf = shelves.firstWhere((s) => s.id == 'discover_weekly');

      expect(discoverShelf, isNotNull);
      expect(discoverShelf.tracks.length, 20);

      // Verify familiar anchor placement: at index 9 and index 19 (1 in 10 slots)
      final trackAtIndex9 = discoverShelf.tracks[9];
      final trackAtIndex19 = discoverShelf.tracks[19];

      expect(trackAtIndex9.id.startsWith('familiar_'), isTrue);
      expect(trackAtIndex19.id.startsWith('familiar_'), isTrue);

      // Calculate familiar ratio: 2 familiar out of 20 tracks = 0.10 (10%)
      final familiarCount = discoverShelf.tracks
          .where((t) => t.id.startsWith('familiar_'))
          .length;
      final familiarRatio = familiarCount / discoverShelf.tracks.length;

      expect(familiarRatio, closeTo(0.10, 0.01));
    });

    test('generates all standard algotorial shelves from user listening history', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert taste profile
      await db.into(db.tasteProfiles).insert(
            TasteProfilesCompanion.insert(
              entityType: 'artist',
              entityId: 'The Weeknd',
              slowWeight: const Value(2.5),
              fastWeight: const Value(1.5),
              updatedAt: now,
            ),
          );

      // Insert tracks
      for (int i = 1; i <= 5; i++) {
        await db.into(db.tracks).insert(
              TracksCompanion.insert(
                id: 'track_$i',
                sourceId: 'src_$i',
                title: 'Song $i',
                artist: 'The Weeknd',
                durationMs: 200000,
                createdAt: now + i,
              ),
            );
        await db.into(db.playHistories).insert(
              PlayHistoriesCompanion.insert(
                trackId: 'track_$i',
                playedAt: now + i,
                completedRatio: 0.9,
              ),
            );
      }

      final shelves = await engine.loadShelves(forceRefresh: true);
      final shelfIds = shelves.map((s) => s.id).toSet();

      expect(shelfIds.contains('jump_back_in'), isTrue);
      expect(shelfIds.contains('daily_mix'), isTrue);
      expect(shelfIds.contains('discover_weekly'), isTrue);
    });

    test('caches shelves and respects forceRefresh', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'cache_test_1',
              sourceId: 'src_c1',
              title: 'Cache Song',
              artist: 'Cache Artist',
              durationMs: 180000,
              createdAt: now,
            ),
          );

      final firstLoad = await engine.loadShelves();
      final cachedLoad = await engine.loadShelves();

      // Should return identical cached reference
      expect(identical(firstLoad, cachedLoad), isTrue);

      final forceRefreshed = await engine.loadShelves(forceRefresh: true);
      expect(forceRefreshed.length, firstLoad.length);
    });
  });
}
