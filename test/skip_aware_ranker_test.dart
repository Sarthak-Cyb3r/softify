import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/recommendations/logistic_regression_ranker.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_recommendation_ranker.dart';

void main() {
  group('LogisticRegressionRanker', () {
    test('computes sigmoid probability score from feature vector', () {
      final ranker = LogisticRegressionRanker(
        initialWeights: {
          'bias': 0.0,
          'taste_sim': 2.0,
          'cooccurrence': 1.0,
          'recency': 0.0,
          'novelty': 0.0,
          'artist_skip_penalty': -2.0,
        },
      );

      // z = 0.0 + 2.0(0.5) + 1.0(0.5) = 1.5
      // sigma(1.5) = 1 / (1 + e^-1.5) approx 0.81757
      final score = ranker.computeScore({
        'taste_sim': 0.5,
        'cooccurrence': 0.5,
        'recency': 0.0,
        'novelty': 0.0,
        'artist_skip_penalty': 0.0,
      });

      expect(score, closeTo(0.8175, 0.01));
    });

    test('3 consecutive skips penalizes candidate score by > 50%', () {
      final ranker = LogisticRegressionRanker();

      final cleanFeatures = {
        'taste_sim': 0.8,
        'cooccurrence': 0.6,
        'recency': 0.5,
        'novelty': 0.0,
        'artist_skip_penalty': 0.0,
      };

      final cleanScore = ranker.computeScore(cleanFeatures);

      // Candidate with 3 consecutive skips penalty (represented by artist_skip_penalty = 1.0)
      final penalizedFeatures = Map<String, double>.from(cleanFeatures)
        ..['artist_skip_penalty'] = 1.0;

      final penalizedScore = ranker.computeScore(penalizedFeatures);

      // Hard Invariant verification: penalizedScore must be strictly less than 50% of cleanScore
      expect(penalizedScore, lessThan(cleanScore * 0.5));
      expect(penalizedScore / cleanScore, lessThan(0.50));
    });

    test('ranks candidates in descending order of score', () {
      final ranker = LogisticRegressionRanker();

      const trackA = Track(
        id: 't_high',
        sourceId: 'src_high',
        title: 'High Taste Track',
        artist: 'Artist A',
        album: 'Album A',
        duration: Duration(minutes: 3),
      );
      const trackB = Track(
        id: 't_med',
        sourceId: 'src_med',
        title: 'Medium Track',
        artist: 'Artist B',
        album: 'Album B',
        duration: Duration(minutes: 3),
      );
      const trackC = Track(
        id: 't_skipped',
        sourceId: 'src_skipped',
        title: 'Skipped Artist Track',
        artist: 'Artist C',
        album: 'Album C',
        duration: Duration(minutes: 3),
      );

      final candidateA = RecommendationCandidate(
        track: trackA,
        features: {
          'taste_sim': 0.9,
          'cooccurrence': 0.8,
          'recency': 0.5,
          'novelty': 0.2,
          'artist_skip_penalty': 0.0,
        },
      );
      final candidateB = RecommendationCandidate(
        track: trackB,
        features: {
          'taste_sim': 0.4,
          'cooccurrence': 0.3,
          'recency': 0.2,
          'novelty': 0.1,
          'artist_skip_penalty': 0.0,
        },
      );
      final candidateC = RecommendationCandidate(
        track: trackC,
        features: {
          'taste_sim': 0.9, // High base taste
          'cooccurrence': 0.8,
          'recency': 0.5,
          'novelty': 0.2,
          'artist_skip_penalty': 1.0, // But 3 consecutive skips!
        },
      );

      final ranked = ranker.rank([candidateB, candidateC, candidateA]);

      // Candidate A must be #1
      expect(ranked[0].track.id, 't_high');
      expect(ranked[0].score, greaterThan(ranked[1].score));
      expect(ranked[1].score, greaterThan(ranked[2].score));

      // Candidate C with penalty must drop below candidate A despite identical clean features
      expect(candidateC.score, lessThan(candidateA.score * 0.5));
    });

    test('on-device SGD training step updates weights in gradient direction', () async {
      final ranker = LogisticRegressionRanker(
        initialWeights: {
          'bias': 0.0,
          'taste_sim': 1.0,
          'cooccurrence': 1.0,
          'recency': 0.5,
          'novelty': 0.5,
          'artist_skip_penalty': -1.0,
        },
      );

      final initialTasteWeight = ranker.weights['taste_sim']!;

      // Train with a positive label (stream / saved)
      await ranker.trainOnDeviceStep(
        features: {
          'taste_sim': 1.0,
          'cooccurrence': 0.0,
          'recency': 0.0,
          'novelty': 0.0,
          'artist_skip_penalty': 0.0,
        },
        positiveLabel: true,
        learningRate: 0.1,
      );

      // Weight for taste_sim should increase
      expect(ranker.weights['taste_sim']!, greaterThan(initialTasteWeight));

      // Train with a negative label (early skip)
      final preSkipWeight = ranker.weights['taste_sim']!;
      await ranker.trainOnDeviceStep(
        features: {
          'taste_sim': 1.0,
          'cooccurrence': 0.0,
          'recency': 0.0,
          'novelty': 0.0,
          'artist_skip_penalty': 0.0,
        },
        positiveLabel: false,
        learningRate: 0.1,
      );

      // Weight for taste_sim should decrease
      expect(ranker.weights['taste_sim']!, lessThan(preSkipWeight));
    });

    test('computes artist skip penalty accurately from Drift play events', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      final ranker = LogisticRegressionRanker(db: db);

      // Insert tracks
      final nowTime = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 't_skip1',
              sourceId: 'src_1',
              title: 'Song 1',
              artist: 'Arijit Singh',
              durationMs: 180000,
              createdAt: nowTime,
            ),
          );
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 't_skip2',
              sourceId: 'src_2',
              title: 'Song 2',
              artist: 'Arijit Singh',
              durationMs: 180000,
              createdAt: nowTime,
            ),
          );

      // 0 plays -> 0 penalty
      var penalty = await ranker.computeArtistSkipPenaltyFromHistory('Arijit Singh');
      expect(penalty, 0.0);

      // 2 consecutive early skips (< 3 skips)
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.playEvents).insert(PlayEventsCompanion.insert(
            ts: now - 3000,
            trackId: 't_skip1',
            source: 'search',
            listenedMs: 5000,
            durationMs: 180000,
            skippedEarly: true,
            saved: false,
            addedToPlaylist: false,
            rankerVersion: 'v2',
          ));
      await db.into(db.playEvents).insert(PlayEventsCompanion.insert(
            ts: now - 2000,
            trackId: 't_skip2',
            source: 'search',
            listenedMs: 8000,
            durationMs: 180000,
            skippedEarly: true,
            saved: false,
            addedToPlaylist: false,
            rankerVersion: 'v2',
          ));

      penalty = await ranker.computeArtistSkipPenaltyFromHistory('Arijit Singh');
      expect(penalty, lessThan(1.0)); // 2 skips is below threshold 1.0

      // Add 3rd consecutive early skip
      await db.into(db.playEvents).insert(PlayEventsCompanion.insert(
            ts: now - 1000,
            trackId: 't_skip1',
            source: 'search',
            listenedMs: 4000,
            durationMs: 180000,
            skippedEarly: true,
            saved: false,
            addedToPlaylist: false,
            rankerVersion: 'v2',
          ));

      penalty = await ranker.computeArtistSkipPenaltyFromHistory('Arijit Singh');
      expect(penalty, greaterThanOrEqualTo(1.0)); // 3 consecutive skips triggers penalty >= 1.0!

      // Now user completes a full stream of Arijit Singh
      await db.into(db.playEvents).insert(PlayEventsCompanion.insert(
            ts: now,
            trackId: 't_skip2',
            source: 'search',
            listenedMs: 180000,
            durationMs: 180000,
            skippedEarly: false,
            saved: false,
            addedToPlaylist: false,
            rankerVersion: 'v2',
          ));

      penalty = await ranker.computeArtistSkipPenaltyFromHistory('Arijit Singh');
      expect(penalty, 0.0); // Streak broken!
    });
  });
}
