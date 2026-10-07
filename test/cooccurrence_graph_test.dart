import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/recommendations/cooccurrence_graph_builder.dart';
import 'package:softify/data/recommendations/drift_cooccurrence_repository.dart';

void main() {
  group('R2: Co-Occurrence Sentence Graph Tests', () {
    test('Session grouping: plays <= 60s gap form single sentence, > 60s splits', () {
      const now = 1000000;
      const plays = [
        // Session 1: 3 tracks continuous
        PlaySessionItem(trackId: 't1', playedAtMs: now, durationMs: 180000), // ends at now + 180s
        PlaySessionItem(trackId: 't2', playedAtMs: now + 190000, durationMs: 120000), // gap = 10s <= 60s
        PlaySessionItem(trackId: 't3', playedAtMs: now + 320000, durationMs: 200000), // gap = 10s <= 60s

        // Session 2: after a 30-minute break
        PlaySessionItem(trackId: 't4', playedAtMs: now + 2500000, durationMs: 150000),
        PlaySessionItem(trackId: 't5', playedAtMs: now + 2660000, durationMs: 180000), // gap = 10s <= 60s
      ];

      final sentences = CooccurrenceGraphBuilder.groupPlaysIntoSentences(plays, maxGapMs: 60000);
      expect(sentences.length, 2);
      expect(sentences[0], ['t1', 't2', 't3']);
      expect(sentences[1], ['t4', 't5']);
    });

    test('PPMI score computation gives positive scores to co-occurring tracks', () {
      final sentences = [
        ['t_arijit_1', 't_arijit_2', 't_arijit_3'],
        ['t_arijit_1', 't_arijit_2', 't_arijit_4'],
        ['t_weeknd_1', 't_weeknd_2', 't_weeknd_3'],
      ];

      final scores = CooccurrenceGraphBuilder.computePPMIScores(sentences, windowSize: 3);

      final pairArijit = scores.firstWhere(
        (s) => s.trackA == 't_arijit_1' && s.trackB == 't_arijit_2',
      );
      expect(pairArijit.score, greaterThan(0.0));

      // Cross-cluster pair (Arijit vs The Weeknd) never co-occurred, should not exist
      final crossPair = scores.where(
        (s) => s.trackA == 't_arijit_1' && s.trackB == 't_weeknd_1',
      );
      expect(crossPair, isEmpty);
    });

    test('DriftCooccurrenceRepository stores and queries top neighbors', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftCooccurrenceRepository(db);

      final sentences = [
        ['t1', 't2', 't3'],
        ['t1', 't2', 't4'],
        ['t1', 't2', 't3'],
      ];

      await repo.rebuildGraphIncremental(sentences);

      final neighbors = await repo.getTopNeighbors('t1');
      expect(neighbors, isNotEmpty);
      // t2 co-occurred with t1 in all 3 sentences, so it should be top neighbor
      expect(neighbors.first, 't2');

      final pairScore = await repo.getPairScore('t1', 't2');
      expect(pairScore, greaterThan(0.0));

      await db.close();
    });
  });
}
