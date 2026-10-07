import 'dart:isolate';

import 'cooccurrence_graph_builder.dart';

class RecommendationIsolates {
  /// Computes PMI / co-occurrence matrix off the UI and audio threads inside a dedicated background isolate.
  static Future<List<CooccurrencePairScore>> computePPMIOffThread(
    List<List<String>> sentences, {
    int windowSize = 3,
  }) async {
    if (sentences.isEmpty) return [];

    return Isolate.run(() {
      return CooccurrenceGraphBuilder.computePPMIScores(
        sentences,
        windowSize: windowSize,
      );
    });
  }
}
