import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/evaluation/team_draft_interleaver.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  SearchCandidate makeCand(String id, String title, String artist, String source) {
    return SearchCandidate(
      track: Track(
        id: id,
        sourceId: 'src_$id',
        title: title,
        artist: artist,
        duration: const Duration(minutes: 3),
      ),
      source: source,
      features: {'score': 1.0},
    );
  }

  group('TeamDraftInterleaver Tests', () {
    late AppDatabase db;
    late TeamDraftInterleaver interleaver;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      interleaver = TeamDraftInterleaver(
        db: db,
        random: math.Random(123), // Deterministic seed
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('interleave merges candidates without duplicates and balances models', () {
      final listA = [
        makeCand('a1', 'Song A1', 'Artist 1', 'model_a'),
        makeCand('a2', 'Song A2', 'Artist 2', 'model_a'),
        makeCand('shared', 'Shared Song', 'Artist 3', 'model_a'),
        makeCand('a4', 'Song A4', 'Artist 4', 'model_a'),
      ];

      final listB = [
        makeCand('shared', 'Shared Song', 'Artist 3', 'model_b'),
        makeCand('b2', 'Song B2', 'Artist 5', 'model_b'),
        makeCand('b3', 'Song B3', 'Artist 6', 'model_b'),
        makeCand('b4', 'Song B4', 'Artist 7', 'model_b'),
      ];

      final result = interleaver.interleave(
        listA: listA,
        listB: listB,
        modelAId: 'model_a',
        modelBId: 'model_b',
        holdbackRatio: 0.1,
      );

      // Verify no duplicates
      final ids = result.map((c) => c.track.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.contains('shared'), isTrue);

      // Verify both models contributed candidates
      final credits = ids.map((id) => interleaver.getCreditedModelForTrack(id)).toList();
      expect(credits.contains('model_a'), isTrue);
      expect(credits.contains('model_b'), isTrue);
    });

    test('recordClickOrStream persists outcome to Drift database and aggregates win rates', () async {
      await interleaver.recordClickOrStream(
        itemId: 'track_1',
        creditedModelId: 'model_a',
        queryOrContext: 'arijit',
      );

      await interleaver.recordClickOrStream(
        itemId: 'track_2',
        creditedModelId: 'model_a',
        queryOrContext: 'arijit',
      );

      await interleaver.recordClickOrStream(
        itemId: 'track_3',
        creditedModelId: 'model_b',
        queryOrContext: 'the weeknd',
      );

      // Verify persistence in database
      final rows = await db.select(db.interleaveOutcomes).get();
      expect(rows.length, 3);

      final winRates = await interleaver.getModelWinRates();
      expect(winRates['model_a'], 2);
      expect(winRates['model_b'], 1);
    });

    test('holdback slot assigns baseline_holdback attribution', () {
      final listA = List.generate(
        15,
        (i) => makeCand('a_$i', 'Song A $i', 'Artist A', 'model_a'),
      );
      final listB = List.generate(
        15,
        (i) => makeCand('b_$i', 'Song B $i', 'Artist B', 'model_b'),
      );

      final result = interleaver.interleave(
        listA: listA,
        listB: listB,
        modelAId: 'model_a',
        modelBId: 'model_b',
        holdbackRatio: 0.1, // 10% holdback -> every 10th slot (index 9)
      );

      expect(result.length, greaterThanOrEqualTo(10));
      final trackAt9 = result[9].track.id;
      final credit = interleaver.getCreditedModelForTrack(trackAt9);
      expect(credit, 'baseline_holdback');
    });
  });
}
