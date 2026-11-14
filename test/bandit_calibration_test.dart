import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/recommendations/epsilon_greedy_bandit.dart';
import 'package:softify/data/recommendations/kl_divergence_calibrator.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('EpsilonGreedyBandit Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('selects valid novelty ratios and updates feedback with persistence', () async {
      final bandit = EpsilonGreedyBandit(
        db: db,
        random: math.Random(42), // Seeded RNG for reproducible test
      );

      // Get initial ratio
      final ratio1 = await bandit.getNoveltyRatio('discover_weekly');
      expect(EpsilonGreedyBandit.arms.contains(ratio1), isTrue);

      // Record positive stream feedback
      await bandit.recordFeedback(
        shelfId: 'discover_weekly',
        ratioUsed: ratio1,
        success: true,
      );

      // Record negative early skip feedback
      await bandit.recordFeedback(
        shelfId: 'discover_weekly',
        ratioUsed: ratio1,
        success: false,
      );

      // Verify persistence in Drift database
      final persisted = await (db.select(db.banditStates)
            ..where((tbl) => tbl.shelfId.equals('discover_weekly')))
          .getSingle();

      expect(persisted.pullCount, 2);
      expect(persisted.cumulativeReward, 1.0);
      expect(persisted.epsilon, lessThan(0.1)); // Decayed epsilon
    });
  });

  group('KlDivergenceCalibrator Tests', () {
    Track makeTrack(String id, String title, String artist) {
      return Track(
        id: id,
        sourceId: 'src_$id',
        title: title,
        artist: artist,
        duration: const Duration(minutes: 3),
      );
    }

    test('computeKlDivergence returns 0.0 when distributions are identical', () {
      final p = {'pop': 0.6, 'rock': 0.4};
      final q = {'pop': 0.6, 'rock': 0.4};

      final kl = KlDivergenceCalibrator.computeKlDivergence(p, q);
      expect(kl, closeTo(0.0, 0.001));
    });

    test('computeKlDivergence returns positive divergence for differing distributions', () {
      final p = {'pop': 0.8, 'rock': 0.2};
      final q = {'pop': 0.2, 'rock': 0.8};

      final kl = KlDivergenceCalibrator.computeKlDivergence(p, q);
      expect(kl, greaterThan(0.5));
    });

    test('calibrateSlate balances slate genres to match target taste profile distribution', () {
      final calibrator = KlDivergenceCalibrator();

      // Pool of candidates: 5 rock tracks, 5 pop tracks
      final candidates = [
        makeTrack('r1', 'Rock Song 1', 'Rock Artist 1'),
        makeTrack('r2', 'Rock Song 2', 'Rock Artist 2'),
        makeTrack('r3', 'Rock Song 3', 'Rock Artist 3'),
        makeTrack('p1', 'Pop Song 1', 'Taylor Swift'),
        makeTrack('p2', 'Pop Song 2', 'The Weeknd'),
        makeTrack('p3', 'Pop Song 3', 'Pop Artist 3'),
      ];

      // Target distribution: 70% pop, 30% rock
      final targetDistribution = {'pop': 0.7, 'rock': 0.3};

      final calibrated = calibrator.calibrateSlate(
        candidates: candidates,
        targetGenreDistribution: targetDistribution,
      );

      expect(calibrated.length, candidates.length);

      // Verify that pop tracks appear early to satisfy the 70% target distribution
      final firstThree = calibrated.take(3).map((t) => t.id).toList();
      final popInFirstThree = firstThree.where((id) => id.startsWith('p')).length;
      expect(popInFirstThree, greaterThanOrEqualTo(2));
    });
  });
}
