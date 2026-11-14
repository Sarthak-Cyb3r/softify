import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/catalog/keyless_youtube_catalog.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  test('getRelatedTracks returns diverse studio artists with ZERO YouTube and ZERO mashups/remixes', () async {
    final catalog = KeylessYouTubeCatalog();
    const seedTrack = Track(
      id: 'saavn_aRZbUYD7',
      sourceId: 'saavn_aRZbUYD7',
      title: 'Tum Hi Ho',
      artist: 'Arijit Singh',
      album: 'Aashiqui 2',
      duration: Duration(seconds: 262),
    );

    final recommendations = await catalog.getRelatedTracks(seedTrack, limit: 10);
    expect(recommendations, isNotEmpty);

    // Verify seed track itself is not recommended
    expect(recommendations.any((t) => t.title.toLowerCase() == 'tum hi ho'), isFalse);

    // Verify seed artist is not spammed (at most 1 song by Arijit Singh)
    final seedArtistCount = recommendations.where((t) => t.artist.toLowerCase().contains('arijit singh')).length;
    expect(seedArtistCount, lessThanOrEqualTo(1), reason: 'Seed artist must not dominate recommendations');

    // Verify artist diversity: diverse artists in the same genre
    final artists = recommendations.map((t) => t.artist.toLowerCase()).toSet();
    expect(artists.length, greaterThanOrEqualTo((recommendations.length * 0.7).round()), reason: 'Recommendations must come from diverse artists/bands');

    // Verify strict ZERO mashup, ZERO remix, ZERO lofi, ZERO YouTube
    for (final t in recommendations) {
      final fullText = '${t.title} ${t.album ?? ''} ${t.artist}'.toLowerCase();
      expect(fullText.contains('mashup'), isFalse, reason: 'No mashup allowed in recommendations: ${t.title}');
      expect(fullText.contains('remix'), isFalse, reason: 'No remix allowed in recommendations: ${t.title}');
      expect(fullText.contains('lofi') || fullText.contains('lo-fi'), isFalse, reason: 'No lofi allowed in recommendations: ${t.title}');
      expect(fullText.contains('dj '), isFalse, reason: 'No DJ mix allowed in recommendations: ${t.title}');
      expect(t.sourceId.startsWith('yt_'), isFalse, reason: 'Zero YouTube tracks in studio recommendations: ${t.sourceId}');
    }
  });

  test('English track queue and recommendations contain ZERO Hindi songs and stay strictly in genre', () async {
    final catalog = KeylessYouTubeCatalog();
    const seedTrack = Track(
      id: 'itunes_1440857781',
      sourceId: 'itunes_1440857781',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      duration: Duration(seconds: 200),
    );

    final recommendations = await catalog.getRelatedTracks(seedTrack, limit: 10);
    expect(recommendations, isNotEmpty);

    // Verify ZERO Hindi songs in English queue!
    final indianKeywords = ['arijit', 'kumar sanu', 'shreya', 'hindi', 'bollywood', 'aashiqui', 'pritam', 'neha kakkar', 'badshah', 'mithoon'];
    for (final t in recommendations) {
      final combined = '${t.title} ${t.album ?? ''} ${t.artist}'.toLowerCase();
      for (final kw in indianKeywords) {
        expect(combined.contains(kw), isFalse, reason: 'English track queue must NEVER contain Hindi song: ${t.title} by ${t.artist}');
      }
    }
  });

  test('Party songs return strictly party bangers with ZERO romantic songs in queue/recommendations', () async {
    final catalog = KeylessYouTubeCatalog();
    const seedTrack = Track(
      id: 'saavn_party_test',
      sourceId: 'saavn_party_test',
      title: 'Kala Chashma',
      artist: 'Amar Arshi, Badshah, Neha Kakkar',
      album: 'Baar Baar Dekho',
      duration: Duration(seconds: 187),
    );

    final recommendations = await catalog.getRelatedTracks(seedTrack, limit: 10);
    expect(recommendations, isNotEmpty);

    // Verify ZERO romantic ballads in party queue
    const romanticDisqualifiers = [
      'romantic', 'love songs', 'love ballad', 'dard', 'judaai', 'judai',
      'tanhai', 'tum hi ho', 'kesariya', 'apna bana le', 'channa mereya',
      'bekhayali', 'slowed', 'ballad', 'acoustic'
    ];

    for (final t in recommendations) {
      final combined = '${t.title} ${t.album ?? ''}'.toLowerCase();
      for (final dis in romanticDisqualifiers) {
        expect(combined.contains(dis), isFalse,
            reason: 'Party queue must NEVER contain romantic track: ${t.title}');
      }
    }
  });

  test('Romantic songs return strictly romantic love songs with ZERO party bangers in queue/recommendations', () async {
    final catalog = KeylessYouTubeCatalog();
    const seedTrack = Track(
      id: 'saavn_romantic_test',
      sourceId: 'saavn_romantic_test',
      title: 'Tum Hi Ho',
      artist: 'Arijit Singh',
      album: 'Aashiqui 2',
      duration: Duration(seconds: 262),
    );

    final recommendations = await catalog.getRelatedTracks(seedTrack, limit: 10);
    expect(recommendations, isNotEmpty);

    // Verify ZERO party bangers in romantic queue
    const partyDisqualifiers = [
      'party', 'dance club', 'daaru', 'daru', 'sharabi', 'kala chashma',
      'badtameez dil', 'tauba tauba', 'thumka', 'bhangra', 'disco beat',
      'saturday night', 'char botal', 'garmi', 'ghungroo', 'banger', 'edm'
    ];

    for (final t in recommendations) {
      final combined = '${t.title} ${t.album ?? ''}'.toLowerCase();
      for (final dis in partyDisqualifiers) {
        expect(combined.contains(dis), isFalse,
            reason: 'Romantic queue must NEVER contain party track: ${t.title}');
      }
    }
  });
}
