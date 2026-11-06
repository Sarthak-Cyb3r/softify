import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/importer/keyless_spotify_importer.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/spotify_import.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_catalog_repository.dart';

class MockCatalogRepository implements ICatalogRepository {
  final List<Track> candidates;
  MockCatalogRepository({this.candidates = const []});

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async => candidates;

  @override
  Future<List<Track>> getTrendingTracks({int limit = 30}) async => [];

  @override
  Future<List<String>> getSearchSuggestions(String query) async => [];

  @override
  Future<List<Track>> getArtistTracks(String artist, {int limit = 25}) async => [];

  @override
  Future<List<Track>> getAlbumTracks(String album, String artist, {int limit = 25}) async => [];

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async => [];
}

void main() {
  group('Spotify Metadata Fidelity & Anti-Remix Shield Tests', () {
    test('matchTrack strictly preserves canonical Spotify metadata and high-res cover', () async {
      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 200),
        coverUrl: 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
      );

      // Catalog returns a YouTube candidate with video noise in title
      const youtubeCandidate = Track(
        id: 'yt_4NRXx6U8ABQ',
        sourceId: 'yt_4NRXx6U8ABQ',
        title: 'The Weeknd - Blinding Lights (Official Video)',
        artist: 'TheWeekndVEVO',
        album: 'YouTube Music',
        duration: Duration(seconds: 202),
        coverUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
      );

      final catalog = MockCatalogRepository(candidates: [youtubeCandidate]);
      final importer = KeylessSpotifyImporter(catalog: catalog);

      final matched = await importer.matchTrack(spotifyItem);

      expect(matched, isNotNull);
      // Canonical Spotify ID must be preserved
      expect(matched!.id, equals('spotify_0VjIjW4GlUZAMYd2vXMi3b'));
      expect(matched.sourceId, equals('spotify_0VjIjW4GlUZAMYd2vXMi3b'));
      // Clean Spotify title & artist must NOT be overwritten by YouTube VEVO junk
      expect(matched.title, equals('Blinding Lights'));
      expect(matched.artist, equals('The Weeknd'));
      expect(matched.album, equals('After Hours'));
      expect(matched.duration, equals(const Duration(seconds: 200)));
      // High-res Spotify cover must take precedence over low-res YouTube hqdefault.jpg
      expect(matched.coverUrl, equals('https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36'));
      expect(matched.matchConfidence, greaterThanOrEqualTo(0.50));
    });

    test('matchTrack rejects Remix when target is an original studio track', () async {
      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 200),
        coverUrl: 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
      );

      // Catalog only returns an EDM remix
      const remixCandidate = Track(
        id: 'yt_remix_123',
        sourceId: 'yt_remix_123',
        title: 'The Weeknd - Blinding Lights (Major Lazer Remix)',
        artist: 'The Weeknd',
        duration: Duration(seconds: 198),
      );

      final catalog = MockCatalogRepository(candidates: [remixCandidate]);
      final importer = KeylessSpotifyImporter(catalog: catalog);

      final matched = await importer.matchTrack(spotifyItem);
      expect(matched, isNull, reason: 'Remixes must be strictly rejected when target is original track');
    });

    test('matchTrack rejects Cover version by an unrelated artist', () async {
      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(seconds: 200),
      );

      const coverCandidate = Track(
        id: 'yt_cover_123',
        sourceId: 'yt_cover_123',
        title: 'Blinding Lights - Acoustic Cover by John Doe',
        artist: 'John Doe',
        duration: Duration(seconds: 200),
      );

      final catalog = MockCatalogRepository(candidates: [coverCandidate]);
      final importer = KeylessSpotifyImporter(catalog: catalog);

      final matched = await importer.matchTrack(spotifyItem);
      expect(matched, isNull, reason: 'Cover versions and unrelated artists must be disqualified');
    });

    test('matchTrack rejects candidate with major duration discrepancy (> 25s)', () async {
      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(seconds: 200),
      );

      // Candidate that cuts a verse or is an extended version (245s vs 200s)
      const radioEditCandidate = Track(
        id: 'yt_edit_123',
        sourceId: 'yt_edit_123',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(seconds: 245),
      );

      final catalog = MockCatalogRepository(candidates: [radioEditCandidate]);
      final importer = KeylessSpotifyImporter(catalog: catalog);

      final matched = await importer.matchTrack(spotifyItem);
      expect(matched, isNull, reason: 'Duration discrepancy > 25s must be rejected');
    });

    test('matchTrack allows remix when the target Spotify track itself is a remix', () async {
      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:remix_target',
        title: 'Levitating (feat. DaBaby) - Don Diablo Remix',
        artist: 'Dua Lipa',
        duration: Duration(seconds: 210),
      );

      const remixCandidate = Track(
        id: 'yt_diablo_123',
        sourceId: 'yt_diablo_123',
        title: 'Dua Lipa - Levitating (Don Diablo Remix)',
        artist: 'Dua Lipa',
        duration: Duration(seconds: 212),
      );

      final catalog = MockCatalogRepository(candidates: [remixCandidate]);
      final importer = KeylessSpotifyImporter(catalog: catalog);

      final matched = await importer.matchTrack(spotifyItem);
      expect(matched, isNotNull);
      expect(matched!.title, equals('Levitating (feat. DaBaby) - Don Diablo Remix'));
    });
  });
}
