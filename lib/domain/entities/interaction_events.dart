class DebugMetricsSummary {
  final double streamRate; // streams (listenedMs >= 30000) / total plays
  final double earlySkipRate; // early skips (skippedEarly == true) / total plays
  final double searchTop1ClickRate; // clicks at index 0 / total clicked searches
  final int medianMsToClick; // median ms from search display to click
  final int totalPlays;
  final int totalSearches;

  const DebugMetricsSummary({
    required this.streamRate,
    required this.earlySkipRate,
    required this.searchTop1ClickRate,
    required this.medianMsToClick,
    this.totalPlays = 0,
    this.totalSearches = 0,
  });

  static const empty = DebugMetricsSummary(
    streamRate: 0.0,
    earlySkipRate: 0.0,
    searchTop1ClickRate: 0.0,
    medianMsToClick: 0,
    totalPlays: 0,
    totalSearches: 0,
  );
}
