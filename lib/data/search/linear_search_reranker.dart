import 'dart:math';

import '../../domain/entities/search_candidate.dart';
import '../../domain/ports/i_search_reranker.dart';
import 'text_normalizer.dart';

class LinearSearchReranker implements ISearchReranker {
  static const Map<String, double> defaultWeights = {
    'is_exact': 3.0,
    'prefix_match': 2.0,
    'played_count': 1.5,
    'taste_similarity': 1.0,
    'popularity_proxy': 0.5,
    'edit_distance_penalty': -1.2,
  };

  final Map<String, double> _weights;

  LinearSearchReranker({Map<String, double>? weights})
      : _weights = weights ?? defaultWeights;

  @override
  List<SearchCandidate> rerank({
    required String query,
    required List<SearchCandidate> candidates,
    Map<String, double>? weights,
    bool deduplicate = false,
  }) {
    if (candidates.isEmpty) return [];

    final activeWeights = weights ?? _weights;
    final normalizedQuery = TextNormalizer.normalize(query);

    for (final candidate in candidates) {
      final track = candidate.track;
      final normTitle = TextNormalizer.normalize(track.title);
      final normArtist = TextNormalizer.normalize(track.artist);

      // 1. Exact match check
      final isExact = candidate.features['is_exact'] ??
          ((TextNormalizer.isExactMatch(normalizedQuery, normTitle) ||
                  TextNormalizer.isExactMatch(normalizedQuery, normArtist))
              ? 1.0
              : 0.0);

      // 2. Prefix match check
      final prefixMatch = candidate.features['prefix_match'] ??
          ((TextNormalizer.isPrefixMatch(normalizedQuery, normTitle) ||
                  TextNormalizer.isPrefixMatch(normalizedQuery, normArtist))
              ? 1.0
              : 0.0);

      // 3. Normalized edit distance penalty
      final minEditDist = min(
        TextNormalizer.levenshteinDistance(normalizedQuery, normTitle),
        TextNormalizer.levenshteinDistance(normalizedQuery, normArtist),
      );
      final maxLen = max(
        normalizedQuery.length,
        max(normTitle.length, normArtist.length),
      );
      final editPenalty = candidate.features['edit_distance_penalty'] ??
          (maxLen > 0 ? (minEditDist / maxLen) : 0.0);

      // 4. Play count history feature
      final playedCount = candidate.features['played_count'] ?? 0.0;

      // 5. Lexical taste similarity
      final tasteSimilarity = candidate.features['taste_similarity'] ??
          max(
            TextNormalizer.similarity(normalizedQuery, normTitle),
            TextNormalizer.similarity(normalizedQuery, normArtist),
          );

      // 6. Popularity proxy / match confidence
      final popularityProxy = candidate.features['popularity_proxy'] ??
          (track.matchConfidence ?? 0.5);

      // 7. Track originality / canonical studio authority
      final originality = candidate.features['originality'] ??
          TextNormalizer.scoreTrackOriginality(track, query: query);

      candidate.features['is_exact'] = isExact;
      candidate.features['prefix_match'] = prefixMatch;
      candidate.features['played_count'] = playedCount;
      candidate.features['taste_similarity'] = tasteSimilarity;
      candidate.features['popularity_proxy'] = popularityProxy;
      candidate.features['edit_distance_penalty'] = editPenalty;
      candidate.features['originality'] = originality;

      // Linear scoring: dot product of weights and features
      double score = 0.0;
      for (final entry in activeWeights.entries) {
        final featVal = candidate.features[entry.key] ?? 0.0;
        score += entry.value * featVal;
      }

      // Add originality bonus directly
      score += originality;

      // Hard constraint: Exact match always scores higher than fuzzy matches
      if (isExact == 1.0) {
        score += 10.0;
      }

      candidate.score = score;
    }

    final sorted = List<SearchCandidate>.from(candidates)
      ..sort((a, b) => b.score.compareTo(a.score));

    if (!deduplicate) {
      return sorted;
    }

    // Cluster deduplication: for tracks of the same song from different people,
    // keep the canonical original / most popular track on top and clean redundant clones.
    final List<SearchCandidate> deduped = [];
    for (final candidate in sorted) {
      final isDup = deduped.any((existing) =>
          TextNormalizer.isSameSongCluster(a: existing.track, b: candidate.track));
      if (!isDup) {
        deduped.add(candidate);
      }
    }

    return deduped;
  }
}
