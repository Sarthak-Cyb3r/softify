import 'dart:typed_data';

abstract class IVectorSearchEngine {
  /// Searches nearest tracks by computing cosine similarity against stored 128-dimensional track embeddings.
  Future<List<String>> searchNearest(Float32List queryVector, {int limit = 20});

  /// Stores or updates an embedding vector for a given track in the local database.
  Future<void> storeEmbedding(String trackId, Float32List vector);

  /// Computes cosine similarity between two float32 vectors.
  /// Formulated as: dot(a, b) / (||a|| * ||b||)
  double computeCosineSimilarity(Float32List a, Float32List b);
}
