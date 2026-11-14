abstract class ICooccurrenceRepository {
  /// Incremental or batch update of co-occurrence graph from session sentences
  Future<void> rebuildGraphIncremental(List<List<String>> sentences);

  /// Returns top related tracks by Pointwise Mutual Information (PMI) score
  Future<List<String>> getTopNeighbors(String trackId, {int limit = 20});

  /// Returns pairwise PMI score between trackA and trackB
  Future<double> getPairScore(String trackA, String trackB);
}
