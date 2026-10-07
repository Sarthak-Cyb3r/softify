import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/search/vector_search_engine.dart';

void main() {
  group('VectorSearchEngine Tests', () {
    late AppDatabase db;
    late VectorSearchEngine engine;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      engine = VectorSearchEngine(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('computeCosineSimilarity returns expected mathematical results', () {
      final v1 = Float32List.fromList([1.0, 0.0, 0.0, 0.0]);
      final v2 = Float32List.fromList([1.0, 0.0, 0.0, 0.0]);
      final v3 = Float32List.fromList([0.0, 1.0, 0.0, 0.0]);
      final v4 = Float32List.fromList([-1.0, 0.0, 0.0, 0.0]);

      // Identical vectors = 1.0
      expect(engine.computeCosineSimilarity(v1, v2), closeTo(1.0, 0.0001));

      // Orthogonal vectors = 0.0
      expect(engine.computeCosineSimilarity(v1, v3), closeTo(0.0, 0.0001));

      // Opposite vectors = -1.0
      expect(engine.computeCosineSimilarity(v1, v4), closeTo(-1.0, 0.0001));
    });

    test('storeEmbedding persists vector to Drift database and searchNearest retrieves nearest track', () async {
      final vecA = VectorSearchEngine.generateEmbeddingFromText('Tum Hi Ho Arijit Singh');
      final vecB = VectorSearchEngine.generateEmbeddingFromText('Channa Mereya Arijit Singh');
      final vecC = VectorSearchEngine.generateEmbeddingFromText('Blinding Lights The Weeknd');

      await engine.storeEmbedding('track_tum_hi_ho', vecA);
      await engine.storeEmbedding('track_channa_mereya', vecB);
      await engine.storeEmbedding('track_blinding_lights', vecC);

      // Verify persistence in Drift database
      final rows = await db.select(db.trackEmbeddings).get();
      expect(rows.length, 3);

      // Query vector for "Tum Hi Ho"
      final queryVec = VectorSearchEngine.generateEmbeddingFromText('Tum Hi Ho');
      final nearest = await engine.searchNearest(queryVec, limit: 3);

      expect(nearest.isNotEmpty, isTrue);
      // "track_tum_hi_ho" should be top-1 result
      expect(nearest.first, 'track_tum_hi_ho');
    });

    test('generateEmbeddingFromText produces normalized vectors with semantic affinity', () {
      final v1 = VectorSearchEngine.generateEmbeddingFromText('Taylor Swift Lover');
      final v2 = VectorSearchEngine.generateEmbeddingFromText('Taylor Swift Blank Space');
      final v3 = VectorSearchEngine.generateEmbeddingFromText('Heavy Metal Guitar Solo');

      // Shared artist terms have positive similarity
      final simSwift = engine.computeCosineSimilarity(v1, v2);
      final simMetal = engine.computeCosineSimilarity(v1, v3);

      expect(simSwift, greaterThan(simMetal));
    });
  });
}
