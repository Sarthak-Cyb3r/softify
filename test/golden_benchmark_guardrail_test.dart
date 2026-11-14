import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/evaluation/guardrail_runner.dart';
import 'package:softify/data/search/linear_search_reranker.dart';
import 'package:softify/data/search/rule_intent_router.dart';
import 'package:softify/data/search/text_normalizer.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('Golden Query Benchmark & Latency Guardrails', () {
    late List<Map<String, dynamic>> goldenQueries;
    late LinearSearchReranker reranker;
    late RuleIntentRouter intentRouter;

    setUpAll(() async {
      final file = File('test/fixtures/golden_query_benchmarks.json');
      expect(file.existsSync(), isTrue);
      final jsonString = await file.readAsString();
      final list = json.decode(jsonString) as List<dynamic>;
      goldenQueries = list.cast<Map<String, dynamic>>();
      expect(goldenQueries.length, greaterThanOrEqualTo(50));

      reranker = LinearSearchReranker();
      intentRouter = RuleIntentRouter();
    });

    test('p75 query execution and reranking latency must strictly not exceed 100ms over 50+ queries', () async {
      final queryStrings = goldenQueries.map((q) => q['query'] as String).toList();

      final report = await GuardrailRunner.evaluateLatencyGuardrail(
        queries: queryStrings,
        executor: (query) async {
          // Normalize query
          final normalized = TextNormalizer.normalize(query);
          // Route intent
          final intent = intentRouter.resolve(normalized);
          expect(intent, isNotNull);

          // Mock candidates pool representing FTS and catalog outputs
          final mockCandidates = [
            SearchCandidate(
              track: Track(
                id: '1',
                sourceId: 'src_1',
                title: query,
                artist: 'Matching Artist',
                duration: const Duration(minutes: 3),
              ),
              source: 'local_fts',
              features: {'fts_bm25': 0.9, 'recency': 0.8},
            ),
            SearchCandidate(
              track: const Track(
                id: '2',
                sourceId: 'src_2',
                title: 'Different Title',
                artist: 'Other Artist',
                duration: Duration(minutes: 3),
              ),
              source: 'network',
              features: {'fts_bm25': 0.2, 'recency': 0.1},
            ),
          ];

          // Run linear reranker
          final reranked = reranker.rerank(
            query: query,
            candidates: mockCandidates,
          );
          expect(reranked.isNotEmpty, isTrue);
        },
        p75ThresholdMs: 100.0,
      );

      // Verify execution stats
      expect(report.totalQueries, greaterThanOrEqualTo(50));
      expect(report.p75Ms, lessThanOrEqualTo(100.0));
      expect(report.passedP75Guardrail, isTrue);
    });

    test('Regression Ban guardrail prevents > 10% degradation in early-skip rate', () {
      const baselineSkipRate = 0.15; // 15% skip rate

      // Candidate with 16% skip rate (6.6% degradation -> within 10% tolerance)
      final acceptableCandidate = GuardrailRunner.checkRegressionBan(
        baselineEarlySkipRate: baselineSkipRate,
        candidateEarlySkipRate: 0.16,
        maxDegradationTolerance: 0.10,
      );
      expect(acceptableCandidate, isTrue);

      // Candidate with 20% skip rate (33.3% degradation -> violates 10% tolerance)
      final degradedCandidate = GuardrailRunner.checkRegressionBan(
        baselineEarlySkipRate: baselineSkipRate,
        candidateEarlySkipRate: 0.20,
        maxDegradationTolerance: 0.10,
      );
      expect(degradedCandidate, isFalse);
    });

    test('Exact match queries always rank exact matching title/artist at position 0 with high score', () {
      final exactItem = goldenQueries.firstWhere((q) => q['type'] == 'exact');
      final query = exactItem['query'] as String;
      final expectedArtist = exactItem['expectedArtist'] as String;

      final candidates = [
        SearchCandidate(
          track: const Track(
            id: 'unrelated',
            sourceId: 's1',
            title: 'Unrelated Generic Track',
            artist: 'Generic Artist',
            duration: Duration(minutes: 3),
          ),
          source: 'network',
          features: {'fts_bm25': 0.5},
        ),
        SearchCandidate(
          track: Track(
            id: 'exact_match',
            sourceId: 's2',
            title: query,
            artist: expectedArtist,
            duration: const Duration(minutes: 3),
          ),
          source: 'local_fts',
          features: {'fts_bm25': 0.8},
        ),
      ];

      final reranked = reranker.rerank(query: query, candidates: candidates);

      expect(reranked.first.track.id, 'exact_match');
      expect(reranked.first.score, greaterThan(10.0)); // Exact match invariant +10.0 boost
    });
  });
}
