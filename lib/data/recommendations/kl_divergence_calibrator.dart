import 'dart:math' as math;

import '../../domain/entities/track.dart';
import '../../domain/ports/i_bandit_calibrator.dart';
import 'epsilon_greedy_bandit.dart';

class KlDivergenceCalibrator implements IBanditCalibrator {
  final EpsilonGreedyBandit _bandit;

  KlDivergenceCalibrator({EpsilonGreedyBandit? bandit})
      : _bandit = bandit ?? EpsilonGreedyBandit();

  @override
  Future<double> getNoveltyRatio(String shelfId) =>
      _bandit.getNoveltyRatio(shelfId);

  @override
  Future<void> recordFeedback({
    required String shelfId,
    required double ratioUsed,
    required bool success,
  }) =>
      _bandit.recordFeedback(
        shelfId: shelfId,
        ratioUsed: ratioUsed,
        success: success,
      );

  /// Computes Kullback-Leibler divergence D_KL(P || Q) between target distribution P and candidate distribution Q.
  /// Returns 0.0 when P and Q are identical.
  static double computeKlDivergence(
    Map<String, double> targetP,
    Map<String, double> slateQ,
  ) {
    if (targetP.isEmpty) return 0.0;

    // Normalize P
    final sumP = targetP.values.fold(0.0, (a, b) => a + b);
    if (sumP <= 0.0) return 0.0;
    final pNorm = targetP.map((k, v) => MapEntry(k, v / sumP));

    // Normalize Q
    final sumQ = slateQ.values.fold(0.0, (a, b) => a + b);
    final qNorm = sumQ > 0.0
        ? slateQ.map((k, v) => MapEntry(k, v / sumQ))
        : <String, double>{};

    const epsilon = 1e-6;
    double kl = 0.0;

    for (final entry in pNorm.entries) {
      final pVal = entry.value;
      if (pVal <= 0.0) continue;
      final qVal = (qNorm[entry.key] ?? 0.0) + epsilon;
      kl += pVal * math.log(pVal / qVal);
    }

    return math.max(0.0, kl);
  }

  /// Calibrates a slate of candidate tracks against targetGenreDistribution using KL-divergence minimization.
  @override
  List<Track> calibrateSlate({
    required List<Track> candidates,
    required Map<String, double> targetGenreDistribution,
    double maxKlDivergence = 0.5,
  }) {
    if (candidates.length <= 1 || targetGenreDistribution.isEmpty) {
      return List.unmodifiable(candidates);
    }

    final remaining = List<Track>.from(candidates);
    final slate = <Track>[];
    final slateGenreCounts = <String, double>{};

    while (remaining.isNotEmpty) {
      Track? bestCandidate;
      double lowestPenalty = double.infinity;

      for (int i = 0; i < remaining.length; i++) {
        final cand = remaining[i];
        final genre = _extractGenre(cand);

        // Hypothetical distribution if cand is added
        final hypotheticalCounts = Map<String, double>.from(slateGenreCounts);
        hypotheticalCounts[genre] = (hypotheticalCounts[genre] ?? 0.0) + 1.0;

        final kl = computeKlDivergence(targetGenreDistribution, hypotheticalCounts);

        // Position bias penalty: prefer candidates that keep KL divergence small
        final penalty = kl + (i * 0.05);

        if (penalty < lowestPenalty) {
          lowestPenalty = penalty;
          bestCandidate = cand;
        }
      }

      if (bestCandidate != null) {
        slate.add(bestCandidate);
        remaining.remove(bestCandidate);
        final genre = _extractGenre(bestCandidate);
        slateGenreCounts[genre] = (slateGenreCounts[genre] ?? 0.0) + 1.0;
      } else {
        break;
      }
    }

    return slate;
  }

  String _extractGenre(Track track) {
    // Proxy genre extraction from track metadata or artist
    final text = '${track.title} ${track.artist} ${track.album ?? ""}'.toLowerCase();
    if (text.contains('hindi') || text.contains('arijit') || text.contains('bollywood')) {
      return 'hindi';
    }
    if (text.contains('punjabi') || text.contains('diljit')) {
      return 'punjabi';
    }
    if (text.contains('rock') || text.contains('metal')) {
      return 'rock';
    }
    if (text.contains('pop') || text.contains('taylor') || text.contains('weeknd')) {
      return 'pop';
    }
    if (text.contains('jazz') || text.contains('blues')) {
      return 'jazz';
    }
    return 'general';
  }
}
