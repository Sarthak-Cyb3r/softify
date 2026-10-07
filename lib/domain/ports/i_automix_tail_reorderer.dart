import '../entities/track.dart';

abstract class IAutomixTailReorderer {
  /// Strictly reorders queue items from index >= (currentIndex + 2) when hasBufferedNext is true.
  /// Preserves currentTrack and pre-buffered next track (Dual-Engine Pre-Buffer Invariant).
  List<Track> reorderTail({
    required List<Track> currentQueue,
    required int currentIndex,
    required bool hasBufferedNext,
    required int sessionConsecutiveSkips,
  });
}
