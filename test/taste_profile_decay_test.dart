import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/recommendations/drift_taste_profile_repository.dart';
import 'package:softify/domain/entities/track.dart';

Track _makeTrack(String id, String title, String artist) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title,
    artist: artist,
    duration: const Duration(seconds: 180),
  );
}

void main() {
  late AppDatabase db;
  late DriftTasteProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftTasteProfileRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('R1: Dual-Band Taste Profile Decay Tests', () {
    test('Stream and save update fast and slow weights positively', () async {
      final track = _makeTrack('t1', 'Starboy', 'The Weeknd');

      await repo.updateFromPlay(
        track: track,
        isStream: true,
        isEarlySkip: false,
        isSave: false,
      );

      var top = await repo.getTopEntities(entityType: 'artist');
      expect(top.length, 1);
      expect(top.first.entityId, 'The Weeknd');
      expect(top.first.fastWeight, closeTo(1.0, 0.05));
      expect(top.first.slowWeight, closeTo(1.0, 0.05));

      // Now save track (+2.0)
      await repo.updateFromPlay(
        track: track,
        isStream: false,
        isEarlySkip: false,
        isSave: true,
      );

      top = await repo.getTopEntities(entityType: 'artist');
      expect(top.first.fastWeight, closeTo(3.0, 0.05));
      expect(top.first.slowWeight, closeTo(3.0, 0.05));
    });

    test('Early skip penalizes fast weight heavily and slow weight moderately', () async {
      final track = _makeTrack('t1', 'Song A', 'Artist A');

      // Start with stream (+1.0)
      await repo.updateFromPlay(
        track: track,
        isStream: true,
        isEarlySkip: false,
        isSave: false,
      );

      // Now early skip (-1.5 fast, -0.5 slow)
      await repo.updateFromPlay(
        track: track,
        isStream: false,
        isEarlySkip: true,
        isSave: false,
      );

      final top = await repo.getTopEntities(entityType: 'artist');
      expect(top.first.fastWeight, 0.0); // Floored at 0
      expect(top.first.slowWeight, closeTo(0.5, 0.05));
    });

    test('Exponential decay verification: fast decays at 4h half-life, slow at 14d half-life', () async {
      final track = _makeTrack('t1', 'Tum Hi Ho', 'Arijit Singh');

      // Base: stream + save = 3.0
      await repo.updateFromPlay(
        track: track,
        isStream: true,
        isEarlySkip: false,
        isSave: true,
      );

      // Simulate 4 hours elapsed in DB
      const fourHoursMs = 4 * 3600 * 1000;
      final pastTime = DateTime.now().millisecondsSinceEpoch - fourHoursMs;

      await (db.update(db.tasteProfiles)..where((t) => t.entityId.equals('Arijit Singh')))
          .write(TasteProfilesCompanion(updatedAt: Value(pastTime)));

      final top = await repo.getTopEntities(entityType: 'artist');
      // After 4 hours (1 half-life), fast weight should be ~50% of 3.0 = 1.5
      expect(top.first.fastWeight, closeTo(1.5, 0.05));

      // Slow weight (14-day half-life) should have barely decayed:
      // 3.0 * 2^(-4h / (14*24h)) = 3.0 * 2^(-4/336) = 3.0 * 0.9918 = ~2.975
      expect(top.first.slowWeight, closeTo(2.975, 0.05));
    });

    test('computeTasteSimilarity returns normalized score between 0.0 and 1.0', () async {
      final unknownTrack = _makeTrack('t_unk', 'Unknown Song', 'Unknown Artist');
      final knownTrack = _makeTrack('t_known', 'Kesariya', 'Arijit Singh');

      expect(await repo.computeTasteSimilarity(unknownTrack), 0.0);

      await repo.updateFromPlay(
        track: knownTrack,
        isStream: true,
        isEarlySkip: false,
        isSave: true,
      );

      final sim = await repo.computeTasteSimilarity(knownTrack);
      expect(sim, greaterThan(0.0));
      expect(sim, lessThanOrEqualTo(1.0));
    });
  });
}
