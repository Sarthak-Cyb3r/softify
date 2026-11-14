import '../entities/track.dart';

abstract class IBanditCalibrator {
  /// Returns the selected novelty ratio for the given shelf using epsilon-greedy exploration/exploitation.
  Future<double> getNoveltyRatio(String shelfId);

  /// Records downstream interaction feedback (stream/save = success, early skip = failure).
  Future<void> recordFeedback({
    required String shelfId,
    required double ratioUsed,
    required bool success,
  });

  /// Calibrates a candidate recommendation slate against a target genre distribution using KL-divergence.
  List<Track> calibrateSlate({
    required List<Track> candidates,
    required Map<String, double> targetGenreDistribution,
    double maxKlDivergence = 0.5,
  });
}
