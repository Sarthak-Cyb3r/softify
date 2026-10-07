import 'dart:math' as math;
import 'dart:typed_data';


import '../../domain/ports/i_vector_search_engine.dart';
import '../database/app_database.dart';

class VectorSearchEngine implements IVectorSearchEngine {
  final AppDatabase? _db;
  final Map<String, Float32List> _inMemoryEmbeddings = {};
  bool _isCacheLoaded = false;

  static const int defaultDimensions = 128;

  VectorSearchEngine({AppDatabase? db}) : _db = db;

  @override
  double computeCosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normASq = 0.0;
    double normBSq = 0.0;

    for (int i = 0; i < a.length; i++) {
      final valA = a[i];
      final valB = b[i];
      dotProduct += valA * valB;
      normASq += valA * valA;
      normBSq += valB * valB;
    }

    if (normASq <= 0.0 || normBSq <= 0.0) return 0.0;
    final similarity = dotProduct / (math.sqrt(normASq) * math.sqrt(normBSq));
    return similarity.clamp(-1.0, 1.0);
  }

  @override
  Future<void> storeEmbedding(String trackId, Float32List vector) async {
    _inMemoryEmbeddings[trackId] = vector;

    final db = _db;
    if (db != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final byteData = vector.buffer.asUint8List();

      await db.into(db.trackEmbeddings).insertOnConflictUpdate(
        TrackEmbeddingRow(
          trackId: trackId,
          vector: Uint8List.fromList(byteData),
          updatedAt: now,
        ),
      );
    }
  }

  @override
  Future<List<String>> searchNearest(Float32List queryVector, {int limit = 20}) async {
    await _ensureCacheLoaded();

    if (_inMemoryEmbeddings.isEmpty) return const [];

    final scored = <MapEntry<String, double>>[];

    for (final entry in _inMemoryEmbeddings.entries) {
      final sim = computeCosineSimilarity(queryVector, entry.value);
      scored.add(MapEntry(entry.key, sim));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Generates a normalized 128-dimensional float32 embedding vector on-device
  /// using subword n-gram feature hashing with L2 normalization.
  static Float32List generateEmbeddingFromText(String text, {int dimensions = defaultDimensions}) {
    final clean = text.trim().toLowerCase();
    final vector = Float32List(dimensions);
    if (clean.isEmpty) return vector;

    // Hash words
    final words = clean.split(RegExp(r'\s+'));
    for (final word in words) {
      final hash = _hashString(word);
      final idx = hash.abs() % dimensions;
      vector[idx] += 1.0;

      // Subword character trigrams
      if (word.length >= 3) {
        for (int i = 0; i <= word.length - 3; i++) {
          final trigram = word.substring(i, i + 3);
          final triHash = _hashString(trigram);
          final triIdx = triHash.abs() % dimensions;
          vector[triIdx] += 0.5;
        }
      }
    }

    // L2 Normalize vector
    double sumSq = 0.0;
    for (int i = 0; i < dimensions; i++) {
      sumSq += vector[i] * vector[i];
    }

    if (sumSq > 0.0) {
      final norm = math.sqrt(sumSq);
      for (int i = 0; i < dimensions; i++) {
        vector[i] = (vector[i] / norm);
      }
    }

    return vector;
  }

  static int _hashString(String str) {
    int hash = 5381;
    for (int i = 0; i < str.length; i++) {
      hash = ((hash << 5) + hash) + str.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash;
  }

  Future<void> _ensureCacheLoaded() async {
    if (_isCacheLoaded) return;
    final db = _db;
    if (db != null) {
      try {
        final rows = await db.select(db.trackEmbeddings).get();
        for (final row in rows) {
          final uint8 = row.vector;
          final float32 = Float32List.view(
            uint8.buffer,
            uint8.offsetInBytes,
            uint8.lengthInBytes ~/ 4,
          );
          _inMemoryEmbeddings[row.trackId] = float32;
        }
      } catch (_) {}
    }
    _isCacheLoaded = true;
  }
}
