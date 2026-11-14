import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/catalog/keyless_youtube_catalog.dart';
import 'package:softify/data/search/linear_search_reranker.dart';
import 'package:softify/data/search/text_normalizer.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('Canonical Song Root Extraction & Derivative Detection', () {
    test('extractCanonicalSongRoot strips movie, video, and derivative tags', () {
      expect(TextNormalizer.extractCanonicalSongRoot('Tum Hi Ho (From "Aashiqui 2")'), 'tum hi ho');
      expect(TextNormalizer.extractCanonicalSongRoot('Tum Hi Ho - Official Video'), 'tum hi ho');
      expect(TextNormalizer.extractCanonicalSongRoot('Tum Hi Ho (Cover)'), 'tum hi ho');
      expect(TextNormalizer.extractCanonicalSongRoot('Tum Hi Ho [Lofi Remake]'), 'tum hi ho');
      expect(TextNormalizer.extractCanonicalSongRoot('Tum Hi Ho (Slowed + Reverb)'), 'tum hi ho');
      expect(TextNormalizer.extractCanonicalSongRoot('Tum Hi Ho | Acoustic Version'), 'tum hi ho');
      expect(TextNormalizer.extractCanonicalSongRoot('Kesariya (From "Brahmastra")'), 'kesariya');
      expect(TextNormalizer.extractCanonicalSongRoot('Shape of You (Official Music Video)'), 'shape of you');
    });

    test('isDerivativeTrack flags cover, lofi, slowed, karaoke, remix tracks', () {
      expect(TextNormalizer.isDerivativeTrack('Tum Hi Ho (Cover)'), isTrue);
      expect(TextNormalizer.isDerivativeTrack('Tum Hi Ho [Lofi]'), isTrue);
      expect(TextNormalizer.isDerivativeTrack('Tum Hi Ho', artist: 'Karaoke Stars'), isTrue);
      expect(TextNormalizer.isDerivativeTrack('Tum Hi Ho', artist: 'Arijit Singh'), isFalse);
    });

    test('isSameSongCluster detects multiple results of same song from different people', () {
      const originalTrack = Track(
        id: 'saavn_101',
        sourceId: 'saavn_101',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: Duration(seconds: 262),
        matchConfidence: 1.0,
      );

      const coverTrack = Track(
        id: 'yt_cover1',
        sourceId: 'yt_cover1',
        title: 'Tum Hi Ho (Cover by Sanam)',
        artist: 'Sanam',
        duration: Duration(seconds: 260),
        matchConfidence: 0.8,
      );

      const lofiTrack = Track(
        id: 'yt_lofi1',
        sourceId: 'yt_lofi1',
        title: 'Tum Hi Ho [Lofi Remake]',
        artist: 'DJ Lofi Chill',
        duration: Duration(seconds: 200),
        matchConfidence: 0.7,
      );

      const differentSong = Track(
        id: 'saavn_202',
        sourceId: 'saavn_202',
        title: 'Sunn Raha Hai',
        artist: 'Ankit Tiwari',
        album: 'Aashiqui 2',
        duration: Duration(seconds: 390),
        matchConfidence: 1.0,
      );

      // Same song from different people/uploaders matches cluster
      expect(TextNormalizer.isSameSongCluster(a: originalTrack, b: coverTrack), isTrue);
      expect(TextNormalizer.isSameSongCluster(a: originalTrack, b: lofiTrack), isTrue);

      // Different songs do NOT match cluster
      expect(TextNormalizer.isSameSongCluster(a: originalTrack, b: differentSong), isFalse);
    });

    test('scoreTrackOriginality gives highest authority to official studio track', () {
      const original = Track(
        id: 'spotify_orig',
        sourceId: 'spotify_orig',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: Duration(seconds: 262),
        matchConfidence: 1.0,
      );

      const cover = Track(
        id: 'yt_cover',
        sourceId: 'yt_cover',
        title: 'Tum Hi Ho - Cover by Someone',
        artist: 'Someone',
        duration: Duration(seconds: 250),
        matchConfidence: 0.8,
      );

      const lofi = Track(
        id: 'yt_lofi',
        sourceId: 'yt_lofi',
        title: 'Tum Hi Ho (Lofi Flip)',
        artist: 'DJ XYZ',
        duration: Duration(seconds: 200),
        matchConfidence: 0.7,
      );

      final origScore = TextNormalizer.scoreTrackOriginality(original, query: 'Tum Hi Ho');
      final coverScore = TextNormalizer.scoreTrackOriginality(cover, query: 'Tum Hi Ho');
      final lofiScore = TextNormalizer.scoreTrackOriginality(lofi, query: 'Tum Hi Ho');

      expect(origScore, greaterThan(coverScore));
      expect(origScore, greaterThan(lofiScore));
      expect(origScore, greaterThan(10.0));
      expect(coverScore, lessThan(5.0));
    });
  });

  group('LinearSearchReranker Deduplication & Canonical Ranking', () {
    test('rerank puts original song on top and filters out redundant cover clones from different people', () {
      final reranker = LinearSearchReranker();

      const originalTrack = Track(
        id: 'saavn_orig',
        sourceId: 'saavn_orig',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: Duration(seconds: 262),
        matchConfidence: 1.0,
      );

      const coverTrack = Track(
        id: 'yt_cover',
        sourceId: 'yt_cover',
        title: 'Tum Hi Ho - Acoustic Cover',
        artist: 'Random Singer',
        duration: Duration(seconds: 250),
        matchConfidence: 0.8,
      );

      const lofiTrack = Track(
        id: 'yt_lofi',
        sourceId: 'yt_lofi',
        title: 'Tum Hi Ho [Slowed + Reverb]',
        artist: 'Lofi Beats',
        duration: Duration(seconds: 300),
        matchConfidence: 0.7,
      );

      const otherSong = Track(
        id: 'saavn_other',
        sourceId: 'saavn_other',
        title: 'Sunn Raha Hai',
        artist: 'Ankit Tiwari',
        album: 'Aashiqui 2',
        duration: Duration(seconds: 390),
        matchConfidence: 1.0,
      );

      final candidates = [
        SearchCandidate(track: coverTrack, source: 'network', features: {}),
        SearchCandidate(track: lofiTrack, source: 'network', features: {}),
        SearchCandidate(track: otherSong, source: 'network', features: {}),
        SearchCandidate(track: originalTrack, source: 'network', features: {}),
      ];

      final reranked = reranker.rerank(
        query: 'Tum Hi Ho',
        candidates: candidates,
        deduplicate: true,
      );

      // The original track must be on top!
      expect(reranked.first.track.id, 'saavn_orig');
      expect(reranked.first.track.artist, 'Arijit Singh');

      // The redundant cover clones (coverTrack, lofiTrack) must be deduplicated
      final tumHiHoTracks = reranked.where((c) =>
          TextNormalizer.extractCanonicalSongRoot(c.track.title) == 'tum hi ho').toList();
      expect(tumHiHoTracks.length, 1, reason: 'Duplicate versions of the same song from different people must be cleaned');

      // Distinct songs like "Sunn Raha Hai" must be preserved
      final hasOtherSong = reranked.any((c) => c.track.id == 'saavn_other');
      expect(hasOtherSong, isTrue);
    });
  });

  group('Catalog Deduplication Integration', () {
    test('KeylessYouTubeCatalog search Tum Hi Ho returns single pristine Aashiqui 2 track', () async {
      final catalog = KeylessYouTubeCatalog();
      final results = await catalog.search('Tum Hi Ho', limit: 20);

      // Verify no duplicate "Tum Hi Ho" from the same album Aashiqui 2
      final aashiquiTracks = results.where((t) =>
          TextNormalizer.extractCanonicalSongRoot(t.title) == 'tum hi ho' &&
          (t.album?.contains('Aashiqui') ?? false)).toList();
      expect(aashiquiTracks.length, 1, reason: 'There must be only ONE canonical "Tum Hi Ho" from Aashiqui 2, not duplicates!');

      final mainTrack = aashiquiTracks.first;
      expect(mainTrack.artist.contains('Arijit Singh'), isTrue);
    });
  });
}

