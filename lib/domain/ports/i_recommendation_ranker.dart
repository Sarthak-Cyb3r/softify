import '../entities/track.dart';

class RecommendationCandidate {
  final Track track;
  final Map<String, double> features; // taste_sim, cooccurrence, recency, novelty, artist_skip_penalty
  double score;

  RecommendationCandidate({
    required this.track,
    required this.features,
    this.score = 0.0,
  });
}

abstract class IRecommendationRanker {
  /// Ranks candidates using pointwise logistic scoring and sorts descending by score.
  List<RecommendationCandidate> rank(List<RecommendationCandidate> candidates);

  /// Performs an on-device SGD training step on the given feature vector.
  /// positiveLabel: true for stream (>=30s) or save, false for early skip (<30s).
  Future<void> trainOnDeviceStep({
    required Map<String, double> features,
    required bool positiveLabel,
    double learningRate = 0.01,
  });
}
