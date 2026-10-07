import '../../domain/entities/track.dart';
import '../../domain/ports/i_automix_tail_reorderer.dart';
import '../../domain/ports/i_recommendation_ranker.dart';
import 'logistic_regression_ranker.dart';

class AutomixTailReorderer implements IAutomixTailReorderer {
  final LogisticRegressionRanker _ranker;

  AutomixTailReorderer({LogisticRegressionRanker? ranker})
      : _ranker = ranker ?? LogisticRegressionRanker();

  @override
  List<Track> reorderTail({
    required List<Track> currentQueue,
    required int currentIndex,
    required bool hasBufferedNext,
    required int sessionConsecutiveSkips,
  }) {
    if (currentQueue.isEmpty || currentIndex < 0) return currentQueue;

    // Hard Invariant: Track N (currentIndex) and Track N+1 (pre-buffered engine)
    // are locked and MUST NEVER be touched or reordered!
    final tailStartIndex = hasBufferedNext ? currentIndex + 2 : currentIndex + 1;

    // If tail has 0 or 1 track, no re-ordering needed
    if (tailStartIndex >= currentQueue.length - 1) {
      return List.unmodifiable(currentQueue);
    }

    final headAndBuffer = currentQueue.sublist(0, tailStartIndex);
    final tail = currentQueue.sublist(tailStartIndex);

    final currentTrack = currentQueue[currentIndex];

    // Build candidates for tail
    final candidates = <RecommendationCandidate>[];
    for (final track in tail) {
      final isSameArtist = track.artist.toLowerCase() == currentTrack.artist.toLowerCase();
      final isSameAlbum = track.album != null &&
          currentTrack.album != null &&
          track.album!.toLowerCase() == currentTrack.album!.toLowerCase();

      // Style similarity (genre/artist isolation proxy)
      final styleSimilarity = (isSameArtist ? 0.6 : 0.2) + (isSameAlbum ? 0.3 : 0.0);

      // Fast interest weight boost when sessionConsecutiveSkips >= 2
      final fastInterestBoost = sessionConsecutiveSkips >= 2 ? 0.4 : 0.0;
      final skipPenalty = sessionConsecutiveSkips >= 2
          ? (isSameArtist ? 1.5 : 0.0)
          : 0.0;

      final features = <String, double>{
        'taste_sim': (styleSimilarity + fastInterestBoost).clamp(0.0, 1.0),
        'cooccurrence': 0.5,
        'recency': sessionConsecutiveSkips >= 2 ? 0.9 : 0.3,
        'novelty': sessionConsecutiveSkips >= 2 ? 0.1 : 0.5,
        'artist_skip_penalty': skipPenalty,
      };

      candidates.add(
        RecommendationCandidate(
          track: track,
          features: features,
        ),
      );
    }

    // Rank tail candidates
    final rankedTail = _ranker.rank(candidates).map((c) => c.track).toList();

    return [...headAndBuffer, ...rankedTail];
  }
}
