import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/repositories/drift_event_logger.dart';

void main() {
  late AppDatabase db;
  late DriftEventLogger logger;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    logger = DriftEventLogger(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('F0: Local Event Logger & Stream Rules', () {
    test('30-second rule at 29.9s is classified as early skip', () async {
      logger.logPlay(
        trackId: 'track_299',
        source: 'search',
        listenedMs: 29900,
        durationMs: 200000,
        saved: false,
        addedToPlaylist: false,
        rankerVersion: 'v1',
      );

      // Allow async fire-and-forget to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final rows = await db.select(db.playEvents).get();
      expect(rows.length, 1);
      expect(rows.first.listenedMs, 29900);
      expect(rows.first.skippedEarly, isTrue);
    });

    test('30-second rule at exactly 30.0s is classified as valid stream', () async {
      logger.logPlay(
        trackId: 'track_300',
        source: 'autoplay',
        listenedMs: 30000,
        durationMs: 200000,
        saved: false,
        addedToPlaylist: false,
        rankerVersion: 'v1',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final rows = await db.select(db.playEvents).get();
      expect(rows.length, 1);
      expect(rows.first.listenedMs, 30000);
      expect(rows.first.skippedEarly, isFalse);
    });

    test('30-second rule at 30.1s is classified as valid stream', () async {
      logger.logPlay(
        trackId: 'track_301',
        source: 'library',
        listenedMs: 30100,
        durationMs: 200000,
        saved: true,
        addedToPlaylist: false,
        rankerVersion: 'v1',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final rows = await db.select(db.playEvents).get();
      expect(rows.length, 1);
      expect(rows.first.listenedMs, 30100);
      expect(rows.first.skippedEarly, isFalse);
      expect(rows.first.saved, isTrue);
    });

    test('logPlay and logSearch do not throw or block execution (fire-and-forget)', () {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 20; i++) {
        logger.logPlay(
          trackId: 'track_$i',
          source: 'radio',
          listenedMs: 15000,
          durationMs: 180000,
          saved: false,
          addedToPlaylist: false,
          rankerVersion: 'v1',
        );

        logger.logSearch(
          query: 'query $i',
          resultIds: ['id1', 'id2'],
          clickedId: 'id1',
          clickedPosition: 0,
          msToClick: 350,
          rankerVersion: 'v1',
        );
      }

      stopwatch.stop();
      // 40 fire-and-forget dispatches must return execution without blocking
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('getMetricsSummary calculates accurate rates and median latency', () async {
      // 1 stream, 1 early skip
      logger.logPlay(
        trackId: 't1',
        source: 'search',
        listenedMs: 45000,
        durationMs: 180000,
        saved: false,
        addedToPlaylist: false,
        rankerVersion: 'v1',
      );
      logger.logPlay(
        trackId: 't2',
        source: 'search',
        listenedMs: 10000,
        durationMs: 180000,
        saved: false,
        addedToPlaylist: false,
        rankerVersion: 'v1',
      );

      // Searches:
      // Click at 0 with 200ms
      logger.logSearch(
        query: 'test 1',
        resultIds: ['t1', 't2'],
        clickedId: 't1',
        clickedPosition: 0,
        msToClick: 200,
        rankerVersion: 'v1',
      );
      // Click at 1 with 800ms
      logger.logSearch(
        query: 'test 2',
        resultIds: ['t2', 't3'],
        clickedId: 't3',
        clickedPosition: 1,
        msToClick: 800,
        rankerVersion: 'v1',
      );
      // Click at 0 with 400ms
      logger.logSearch(
        query: 'test 3',
        resultIds: ['t4'],
        clickedId: 't4',
        clickedPosition: 0,
        msToClick: 400,
        rankerVersion: 'v1',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final metrics = await logger.getMetricsSummary();

      expect(metrics.totalPlays, 2);
      expect(metrics.streamRate, closeTo(0.5, 0.01)); // 1 / 2
      expect(metrics.earlySkipRate, closeTo(0.5, 0.01)); // 1 / 2
      expect(metrics.totalSearches, 3);
      expect(metrics.searchTop1ClickRate, closeTo(2 / 3, 0.01)); // 2 of 3 clicked pos 0
      // Latencies: [200, 400, 800] -> median is 400
      expect(metrics.medianMsToClick, 400);
    });

    test('clearAllLearningData purges all logged tables', () async {
      logger.logPlay(
        trackId: 't1',
        source: 'search',
        listenedMs: 50000,
        durationMs: 180000,
        saved: false,
        addedToPlaylist: false,
        rankerVersion: 'v1',
      );
      logger.logSearch(
        query: 'q',
        resultIds: ['t1'],
        clickedId: 't1',
        clickedPosition: 0,
        msToClick: 150,
        rankerVersion: 'v1',
      );
      logger.logImpression(surface: 'search', itemId: 't1', position: 0);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await logger.clearAllLearningData();

      final plays = await db.select(db.playEvents).get();
      final searches = await db.select(db.searchEvents).get();
      final impressions = await db.select(db.impressions).get();

      expect(plays, isEmpty);
      expect(searches, isEmpty);
      expect(impressions, isEmpty);
    });
  });
}
