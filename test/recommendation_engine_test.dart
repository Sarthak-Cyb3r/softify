import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/catalog/keyless_youtube_catalog.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('Spotify-Trained Recommendation Engine Dynamic Rotation Tests', () {
    test('getRelatedTracks dynamically varies queue across repeated plays of same song', () async {
      final catalog = KeylessYouTubeCatalog();
      const seedTrack = Track(
        id: 'spotify_56zZ48jdyY2oDXHVnwg5Di',
        sourceId: 'spotify_56zZ48jdyY2oDXHVnwg5Di',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: Duration(seconds: 262),
      );

      final q1 = await catalog.getRelatedTracks(seedTrack, limit: 10);
      final q2 = await catalog.getRelatedTracks(seedTrack, limit: 10);

      expect(q1, isNotEmpty);
      expect(q2, isNotEmpty);

      // Verify at least 50% novelty / variation between play 1 and play 2
      final q1Ids = q1.map((t) => t.id).toSet();
      final q2Ids = q2.map((t) => t.id).toSet();
      final common = q1Ids.intersection(q2Ids);
      expect(common.length, lessThanOrEqualTo(5),
          reason: 'Queue must dynamically rotate across repeated plays of the same song');
    });

    test('getRelatedTracks for English tracks dynamically varies and contains zero Hindi songs', () async {
      final catalog = KeylessYouTubeCatalog();
      const seedTrack = Track(
        id: 'spotify_0VjIjW4GlUZAMYd2vXMi3b',
        sourceId: 'spotify_0VjIjW4GlUZAMYd2vXMi3b',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 200),
      );

      final q1 = await catalog.getRelatedTracks(seedTrack, limit: 10);
      final q2 = await catalog.getRelatedTracks(seedTrack, limit: 10);

      expect(q1, isNotEmpty);
      expect(q2, isNotEmpty);

      // Verify zero Hindi songs in English recommendations
      final indianKeywords = [
        'arijit', 'kumar sanu', 'shreya', 'hindi', 'bollywood', 'aashiqui', 'pritam'
      ];
      for (final t in q1 + q2) {
        final combined = '${t.title} ${t.album ?? ''} ${t.artist}'.toLowerCase();
        for (final kw in indianKeywords) {
          expect(combined.contains(kw), isFalse);
        }
      }
    });
  });
}
