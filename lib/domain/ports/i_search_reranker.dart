import '../entities/search_candidate.dart';

abstract class ISearchReranker {
  List<SearchCandidate> rerank({
    required String query,
    required List<SearchCandidate> candidates,
    Map<String, double>? weights,
  });
}
