import '../entities/interaction_events.dart';

abstract class IEventLogger {
  void logSearch({
    required String query,
    required List<String> resultIds,
    String? clickedId,
    int? clickedPosition,
    int? msToClick,
    required String rankerVersion,
  });

  void logPlay({
    required String trackId,
    required String source,
    required int listenedMs,
    required int durationMs,
    required bool saved,
    required bool addedToPlaylist,
    required String rankerVersion,
    Map<String, double>? features,
  });

  void logImpression({
    required String surface,
    required String itemId,
    required int position,
  });

  Future<DebugMetricsSummary> getMetricsSummary();

  Future<void> clearAllLearningData();
}
