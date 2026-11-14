import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/data/search/linear_search_reranker.dart';

Track _makeTrack(String id, String title, String artist, {double? confidence}) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title,
    artist: artist,
    duration: const Duration(seconds: 200),
    matchConfidence: confidence,
  );
}

void main() {
  late LinearSearchReranker reranker;

  setUp(() {
    reranker = LinearSearchReranker();
  });

  group('S3: LinearSearchReranker Tests', () {
    test('Exact match always ranks strictly higher than fuzzy and partial matches', () {
      final exactCandidate = SearchCandidate(
        track: _makeTrack('t_exact', 'Kesariya', 'Arijit Singh'),
        source: 'local_fts',
        features: {},
      );

      final partialCandidate = SearchCandidate(
        track: _makeTrack('t_partial', 'Kesariya Tera Ishq Hai Piya Remix', 'DJ Remix'),
        source: 'network',
        features: {},
      );

      final fuzzyCandidate = SearchCandidate(
        track: _makeTrack('t_fuzzy', 'Kesar', 'Unknown'),
        source: 'network',
        features: {},
      );

      final reranked = reranker.rerank(
        query: 'Kesariya',
        candidates: [fuzzyCandidate, partialCandidate, exactCandidate],
      );

      expect(reranked.first.track.id, 't_exact');
      expect(reranked.first.score, greaterThan(reranked[1].score));
    });

    test('Prefix match ranks higher than mid-string or distant fuzzy matches', () {
      final prefixCandidate = SearchCandidate(
        track: _makeTrack('t_prefix', 'Starboy', 'The Weeknd'),
        source: 'network',
        features: {},
      );

      final distantCandidate = SearchCandidate(
        track: _makeTrack('t_distant', 'All the Stars', 'Kendrick Lamar'),
        source: 'network',
        features: {},
      );

      final reranked = reranker.rerank(
        query: 'Star',
        candidates: [distantCandidate, prefixCandidate],
      );

      expect(reranked.first.track.id, 't_prefix');
    });

    test('Play count feature gives boost to frequently played tracks', () {
      final unplayedTrack = SearchCandidate(
        track: _makeTrack('t1', 'Tum Hi Ho', 'Arijit Singh'),
        source: 'network',
        features: {'played_count': 0.0},
      );

      final frequentlyPlayedTrack = SearchCandidate(
        track: _makeTrack('t2', 'Tum Mile', 'Neeraj Shridhar'),
        source: 'history',
        features: {'played_count': 5.0},
      );

      // Query "Tum" matches prefix for both
      final reranked = reranker.rerank(
        query: 'Tum',
        candidates: [unplayedTrack, frequentlyPlayedTrack],
      );

      expect(reranked.first.track.id, 't2');
      expect(frequentlyPlayedTrack.score, greaterThan(unplayedTrack.score));
    });

    test('Edit distance penalty reduces score of typos', () {
      final typoCandidate = SearchCandidate(
        track: _makeTrack('t1', 'Believer', 'Imagine Dragons'),
        source: 'network',
        features: {},
      );

      final exactCandidate = SearchCandidate(
        track: _makeTrack('t2', 'Believer', 'Imagine Dragons'),
        source: 'network',
        features: {},
      );

      // Query "Beliiver" (1 typo)
      final rerankedTypo = reranker.rerank(
        query: 'Beliiver',
        candidates: [typoCandidate],
      );

      // Query "Believer" (0 typo)
      final rerankedExact = reranker.rerank(
        query: 'Believer',
        candidates: [exactCandidate],
      );

      expect(rerankedExact.first.score, greaterThan(rerankedTypo.first.score));
    });

    test('Custom weights modify ranking behavior predictably', () {
      final candidateA = SearchCandidate(
        track: _makeTrack('tA', 'Song A', 'Artist A'),
        source: 'local_fts',
        features: {'played_count': 10.0},
      );

      final candidateB = SearchCandidate(
        track: _makeTrack('tB', 'Song B', 'Artist B'),
        source: 'network',
        features: {'popularity_proxy': 1.0},
      );

      // High popularity weight, zero play count weight
      final customReranker = LinearSearchReranker(weights: {
        'played_count': 0.0,
        'popularity_proxy': 10.0,
      });

      final reranked = customReranker.rerank(
        query: 'Song',
        candidates: [candidateA, candidateB],
      );

      expect(reranked.first.track.id, 'tB');
    });
  });
}
