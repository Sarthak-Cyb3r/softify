import '../entities/search_candidate.dart';

abstract class IInterleavingEngine {
  /// Team-Draft interleaving: alternates selection between ranker A and B
  /// with a [holdbackRatio] (default 10%) allocated to baseline order.
  List<SearchCandidate> interleave({
    required List<SearchCandidate> listA,
    required List<SearchCandidate> listB,
    required String modelAId,
    required String modelBId,
    double holdbackRatio = 0.1,
  });

  /// Records downstream click or stream attributed to the model that drafted the item.
  Future<void> recordClickOrStream({
    required String itemId,
    required String creditedModelId,
    String? queryOrContext,
  });

  /// Returns total win counts per model.
  Future<Map<String, int>> getModelWinRates();
}
