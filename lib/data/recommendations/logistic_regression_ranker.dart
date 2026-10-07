import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../domain/ports/i_recommendation_ranker.dart';
import '../database/app_database.dart';

class LogisticRegressionRanker implements IRecommendationRanker {
  final AppDatabase? _db;

  static const String settingsKey = 'ranker_weights_v2';

  static const Map<String, double> defaultWeights = {
    'bias': -0.2,
    'taste_sim': 2.5,
    'cooccurrence': 1.8,
    'recency': 0.6,
    'novelty': 0.7,
    'artist_skip_penalty': -2.0,
  };

  late Map<String, double> _weights;

  LogisticRegressionRanker({
    AppDatabase? db,
    Map<String, double>? initialWeights,
  }) : _db = db {
    _weights = Map<String, double>.from(initialWeights ?? defaultWeights);
  }

  Map<String, double> get weights => Map.unmodifiable(_weights);

  /// Computes the predicted probability score for a given feature vector.
  /// Enforces hard invariant: 3 consecutive skips (artist_skip_penalty >= 1.0)
  /// penalizes the candidate score by > 50%.
  double computeScore(Map<String, double> features) {
    double z = _weights['bias'] ?? 0.0;
    for (final entry in features.entries) {
      z += (_weights[entry.key] ?? 0.0) * entry.value;
    }

    // Sigmoid: 1 / (1 + e^-z) clamped to prevent extreme overflow
    final clampedZ = z.clamp(-20.0, 20.0);
    double prob = 1.0 / (1.0 + math.exp(-clampedZ));

    // Hard Invariant: 3 consecutive skips of an artist must penalize score by > 50%
    final skipPenalty = features['artist_skip_penalty'] ?? 0.0;
    if (skipPenalty >= 1.0) {
      // 0.45 factor ensures at least a 55% penalty (> 50%)
      final penaltyFactor = (0.45 / (1.0 + 0.5 * (skipPenalty - 1.0))).clamp(0.05, 0.45);
      prob *= penaltyFactor;
    }

    return prob;
  }

  @override
  List<RecommendationCandidate> rank(List<RecommendationCandidate> candidates) {
    for (final candidate in candidates) {
      candidate.score = computeScore(candidate.features);
    }

    // Sort descending by score
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  @override
  Future<void> trainOnDeviceStep({
    required Map<String, double> features,
    required bool positiveLabel,
    double learningRate = 0.01,
  }) async {
    final y = positiveLabel ? 1.0 : 0.0;

    // Linear activation z for SGD
    double z = _weights['bias'] ?? 0.0;
    for (final entry in features.entries) {
      z += (_weights[entry.key] ?? 0.0) * entry.value;
    }
    final clampedZ = z.clamp(-20.0, 20.0);
    final yHat = 1.0 / (1.0 + math.exp(-clampedZ));

    // Gradient error: (yHat - y)
    final error = yHat - y;

    // Update weights
    for (final entry in features.entries) {
      final key = entry.key;
      final val = entry.value;
      final currentWeight = _weights[key] ?? 0.0;
      _weights[key] = currentWeight - (learningRate * error * val);
    }

    // Update bias
    final currentBias = _weights['bias'] ?? 0.0;
    _weights['bias'] = currentBias - (learningRate * error);

    // Persist weights asynchronously if database is available
    final db = _db;
    if (db != null) {
      try {
        await db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion(
            key: const Value(settingsKey),
            value: Value(jsonEncode(_weights)),
          ),
        );
      } catch (_) {
        // Fallback / ignore persistence failures in transient states
      }
    }
  }

  /// Initializes weights from Drift settings storage if available.
  Future<void> loadPersistedWeights() async {
    final db = _db;
    if (db == null) return;
    try {
      final row = await (db.select(db.settings)
            ..where((tbl) => tbl.key.equals(settingsKey)))
          .getSingleOrNull();
      if (row != null) {
        final decoded = jsonDecode(row.value) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is num) {
            _weights[entry.key] = (entry.value as num).toDouble();
          }
        }
      }
    } catch (_) {}
  }

  /// Computes artist skip penalty feature from recent play events.
  /// Returns 1.0 if 3 or more consecutive early skips occurred for the artist.
  Future<double> computeArtistSkipPenaltyFromHistory(String artist) async {
    final db = _db;
    if (db == null || artist.trim().isEmpty) return 0.0;
    try {
      // Query recent play events joined with tracks for this artist
      final query = db.select(db.playEvents).join([
        innerJoin(
          db.tracks,
          db.tracks.id.equalsExp(db.playEvents.trackId),
        ),
      ])
        ..where(db.tracks.artist.equals(artist))
        ..orderBy([
          OrderingTerm.desc(db.playEvents.ts),
        ])
        ..limit(10);

      final rows = await query.get();
      if (rows.isEmpty) return 0.0;

      int consecutiveSkips = 0;
      for (final row in rows) {
        final playEvent = row.readTable(db.playEvents);
        if (playEvent.skippedEarly) {
          consecutiveSkips++;
        } else {
          // Streak broken by completed stream
          break;
        }
      }

      if (consecutiveSkips >= 3) {
        return 1.0 + (consecutiveSkips - 3) * 0.2;
      }
      return consecutiveSkips * 0.15;
    } catch (_) {
      return 0.0;
    }
  }
}
