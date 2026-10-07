import 'dart:math';

class CooccurrencePairScore {
  final String trackA;
  final String trackB;
  final double score;

  const CooccurrencePairScore({
    required this.trackA,
    required this.trackB,
    required this.score,
  });
}

class PlaySessionItem {
  final String trackId;
  final int playedAtMs;
  final int durationMs;

  const PlaySessionItem({
    required this.trackId,
    required this.playedAtMs,
    required this.durationMs,
  });
}

class CooccurrenceGraphBuilder {
  /// Groups historical track plays into continuous listening sessions (sentences).
  /// Two consecutive plays belong to the same session if the gap between track completion
  /// and the next track start is <= maxGapMs (default 60,000 ms).
  static List<List<String>> groupPlaysIntoSentences(
    List<PlaySessionItem> plays, {
    int maxGapMs = 60000,
  }) {
    if (plays.isEmpty) return [];

    final sorted = List<PlaySessionItem>.from(plays)
      ..sort((a, b) => a.playedAtMs.compareTo(b.playedAtMs));

    final sentences = <List<String>>[];
    List<String> currentSentence = [sorted.first.trackId];
    int prevEndMs = sorted.first.playedAtMs + sorted.first.durationMs;

    for (int i = 1; i < sorted.length; i++) {
      final item = sorted[i];
      final gap = item.playedAtMs - prevEndMs;

      if (gap <= maxGapMs) {
        currentSentence.add(item.trackId);
      } else {
        if (currentSentence.length >= 2) {
          sentences.add(currentSentence);
        }
        currentSentence = [item.trackId];
      }
      prevEndMs = item.playedAtMs + item.durationMs;
    }

    if (currentSentence.length >= 2) {
      sentences.add(currentSentence);
    }

    return sentences;
  }

  /// Calculates Positive Pointwise Mutual Information (PPMI) co-occurrence scores.
  /// Runs purely on Dart primitives, safe for Isolate.run().
  static List<CooccurrencePairScore> computePPMIScores(
    List<List<String>> sentences, {
    int windowSize = 3,
  }) {
    if (sentences.isEmpty) return [];

    final pairCounts = <String, int>{};
    final unigramCounts = <String, int>{};
    int totalPairs = 0;

    for (final sentence in sentences) {
      final len = sentence.length;
      for (int i = 0; i < len; i++) {
        final u = sentence[i];
        final maxJ = min(len, i + windowSize + 1);

        for (int j = i + 1; j < maxJ; j++) {
          final v = sentence[j];
          if (u == v) continue; // Skip self co-occurrence

          // Bidirectional keys
          final keyUV = '$u\t$v';
          final keyVU = '$v\t$u';

          pairCounts[keyUV] = (pairCounts[keyUV] ?? 0) + 1;
          pairCounts[keyVU] = (pairCounts[keyVU] ?? 0) + 1;

          unigramCounts[u] = (unigramCounts[u] ?? 0) + 1;
          unigramCounts[v] = (unigramCounts[v] ?? 0) + 1;

          totalPairs += 2;
        }
      }
    }

    if (totalPairs == 0) return [];

    final results = <CooccurrencePairScore>[];

    for (final entry in pairCounts.entries) {
      final parts = entry.key.split('\t');
      final u = parts[0];
      final v = parts[1];
      final cUV = entry.value;

      final cU = unigramCounts[u] ?? 1;
      final cV = unigramCounts[v] ?? 1;

      // PMI = ln( (C(u,v) * N) / (C(u) * C(v)) )
      final numerator = (cUV * totalPairs).toDouble();
      final denominator = (cU * cV).toDouble();

      final pmi = log(numerator / denominator);
      final ppmi = max(0.0, pmi);

      if (ppmi > 0.0) {
        results.add(CooccurrencePairScore(
          trackA: u,
          trackB: v,
          score: ppmi,
        ));
      }
    }

    return results;
  }
}
