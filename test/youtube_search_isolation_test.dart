import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/data/search/linear_search_reranker.dart';
import 'package:softify/data/catalog/keyless_youtube_catalog.dart';
import 'package:softify/data/services/spotify_api_service.dart';
import 'package:softify/data/services/spotify_auth_service.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:drift/native.dart';

void main() {
  group('YouTube Search Isolation Tests', () {
    test('Track.isYoutube properly flags youtube IDs, sourceIds, and album', () {
      const ytTrack1 = Track(
        id: 'yt_abc123',
        sourceId: 'abc123',
        title: 'Video',
        artist: 'Uploader',
        album: 'YouTube',
        duration: Duration(seconds: 180),
      );
      const ytTrack2 = Track(
        id: '123',
        sourceId: 'yt_abc123',
        title: 'Video',
        artist: 'Uploader',
        duration: Duration(seconds: 180),
      );
      const studioTrack = Track(
        id: 'spotify_abc123',
        sourceId: 'spotify_abc123',
        title: 'Studio Song',
        artist: 'Studio Artist',
        album: 'Studio Album',
        duration: Duration(seconds: 180),
      );

      expect(ytTrack1.isYoutube, isTrue);
      expect(ytTrack2.isYoutube, isTrue);
      expect(studioTrack.isYoutube, isFalse);
    });

    test('LinearSearchReranker strictly excludes any YouTube tracks', () {
      final reranker = LinearSearchReranker();

      final candidates = [
        SearchCandidate(
          track: const Track(
            id: 'yt_dQw4w9WgXcQ',
            sourceId: 'dQw4w9WgXcQ',
            title: 'Never Gonna Give You Up',
            artist: 'Rick Astley',
            album: 'YouTube',
            duration: Duration(seconds: 213),
          ),
          source: 'network',
          features: {},
        ),
        SearchCandidate(
          track: const Track(
            id: 'spotify_4cOdK2wGLETKBW3PvgPWqT',
            sourceId: '4cOdK2wGLETKBW3PvgPWqT',
            title: 'Never Gonna Give You Up',
            artist: 'Rick Astley',
            album: 'Whenever You Need Somebody',
            duration: Duration(seconds: 213),
          ),
          source: 'network',
          features: {},
        ),
      ];

      final results = reranker.rerank(query: 'Never Gonna Give You Up', candidates: candidates);

      expect(results.length, equals(1));
      expect(results.first.track.id, equals('spotify_4cOdK2wGLETKBW3PvgPWqT'));
      expect(results.any((c) => c.track.isYoutube), isFalse);
    });

    test('KeylessYouTubeCatalog.search strictly yields studio tracks and never YouTube', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final auth = SpotifyAuthService(db: db);
      final api = SpotifyApiService(authService: auth);
      final catalog = KeylessYouTubeCatalog(spotifyApi: api);

      final queries = [
        'student of the year 2 songs',
        'ariana grande live',
        'lofi hip hop radio',
        'unreleased juice wrld',
      ];

      for (final q in queries) {
        final tracks = await catalog.search(q, limit: 5);
        for (final t in tracks) {
          expect(t.isYoutube, isFalse, reason: 'Track ${t.id} must not be a YouTube track');
          expect(t.id.startsWith('yt_'), isFalse);
          expect(t.sourceId.startsWith('yt_'), isFalse);
          expect(t.album, isNot(equals('YouTube')));
        }
      }

      await db.close();
    });
  });
}
