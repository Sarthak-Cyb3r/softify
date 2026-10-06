import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/importer/keyless_spotify_importer.dart';
import 'package:softify/domain/entities/spotify_import.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_catalog_repository.dart';

class MockCatalogRepository implements ICatalogRepository {
  final Map<String, List<Track>> searchMap;

  MockCatalogRepository({this.searchMap = const {}});

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    for (final entry in searchMap.entries) {
      if (query.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return [];
  }

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
  group('Milestone 5: Spotify Playlist Importer', () {
    late KeylessSpotifyImporter importer;

    setUp(() {
      importer = KeylessSpotifyImporter();
    });

    test('extractPlaylistId parses all Spotify URL formats correctly', () {
      // Standard web URL with tracking query parameters
      expect(
        importer.extractPlaylistId('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=ab12cd34ef'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Embed URL
      expect(
        importer.extractPlaylistId('https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Spotify desktop URI
      expect(
        importer.extractPlaylistId('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Raw 22-character ID
      expect(
        importer.extractPlaylistId('37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Invalid links
      expect(importer.extractPlaylistId('https://youtube.com/watch?v=123'), isNull);
      expect(importer.extractPlaylistId('not-a-valid-url'), isNull);
      expect(importer.extractPlaylistId(''), isNull);
    });

    test('matchTrack calculates high confidence for matching catalog tracks', () async {
      final mockCatalog = MockCatalogRepository(
        searchMap: {
          'Blinding Lights': [
            const Track(
              id: 'itunes_123',
              sourceId: 'itunes_123',
              title: 'Blinding Lights',
              artist: 'The Weeknd',
              album: 'After Hours',
              duration: Duration(seconds: 200),
              coverUrl: 'https://example.com/cover.jpg',
              matchConfidence: 1.0,
            ),
          ],
        },
      );

      final matchingImporter = KeylessSpotifyImporter(catalog: mockCatalog);

      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(seconds: 200),
      );

      final matched = await matchingImporter.matchTrack(spotifyItem);

      expect(matched, isNotNull);
      expect(matched!.title, equals('Blinding Lights'));
      expect(matched.artist, equals('The Weeknd'));
      expect(matched.matchConfidence, greaterThanOrEqualTo(0.85));
    });

    test('matchTrack rejects tracks with confidence below threshold', () async {
      final mockCatalog = MockCatalogRepository(
        searchMap: {
          'Starboy': [
            const Track(
              id: 'yt_abc',
              sourceId: 'abc',
              title: 'Completely Different Song',
              artist: 'Unknown Singer',
              duration: Duration(seconds: 600),
              matchConfidence: 0.1,
            ),
          ],
        },
      );

      final matchingImporter = KeylessSpotifyImporter(catalog: mockCatalog);

      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:xyz',
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: Duration(seconds: 230),
      );

      final matched = await matchingImporter.matchTrack(spotifyItem);

      // Should be rejected because confidence < 0.50
      expect(matched, isNull);
    });

    test('SpotifyImportPlaylist computes match stats accurately', () {
      final tracks = [
        const SpotifyTrackItem(
          spotifyUri: 'uri_1',
          title: 'Track 1',
          artist: 'Artist 1',
          duration: Duration(seconds: 180),
          isMatched: true,
          confidence: 0.95,
        ),
        const SpotifyTrackItem(
          spotifyUri: 'uri_2',
          title: 'Track 2',
          artist: 'Artist 2',
          duration: Duration(seconds: 200),
          isMatched: true,
          confidence: 0.88,
        ),
        const SpotifyTrackItem(
          spotifyUri: 'uri_3',
          title: 'Track 3',
          artist: 'Artist 3',
          duration: Duration(seconds: 220),
          isMatched: false,
          confidence: 0.0,
        ),
      ];

      final playlist = SpotifyImportPlaylist(
        id: 'test_playlist_1',
        name: 'My Spotify Favorites',
        description: 'Test Description',
        tracks: tracks,
      );

      expect(playlist.totalCount, equals(3));
      expect(playlist.matchedCount, equals(2));
      expect(playlist.matchPercentage, closeTo(66.66, 0.1));
    });
  });
}
