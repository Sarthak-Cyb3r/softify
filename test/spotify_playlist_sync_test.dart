import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/playlist.dart';
import 'package:softify/domain/entities/playlist_entry.dart';
import 'package:softify/domain/entities/spotify_import.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/domain/ports/i_spotify_importer.dart';
import 'package:softify/presentation/providers/spotify_import_providers.dart';

class FakeSpotifyImporter implements ISpotifyImporter {
  final Map<String, SpotifyImportPlaylist> playlists = {};
  final Map<String, Track?> matches = {};

  @override
  String? extractPlaylistId(String input) {
    final match = RegExp(r'playlist/([a-zA-Z0-9]+)').firstMatch(input);
    return match?.group(1);
  }

  @override
  SpotifyEntityRef? parseSpotifyEntity(String input) => null;

  @override
  Future<SpotifyImportPlaylist> fetchPlaylist(String urlOrId, {void Function(int loaded)? onProgress}) async {
    final pl = playlists[urlOrId];
    if (pl != null) return pl;
    throw Exception('Playlist not found');
  }

  @override
  Future<Track?> matchTrack(SpotifyTrackItem spotifyTrack) async {
    return matches[spotifyTrack.spotifyUri];
  }
}

class FakeLibraryRepository implements ILibraryRepository {
  PlaylistWithTracks? playlistWithTracks;
  final List<Track> appendedTracks = [];

  @override
  Future<PlaylistWithTracks?> getPlaylistWithTracks(String playlistId) async {
    return playlistWithTracks;
  }

  @override
  Future<void> addTracksToPlaylist(String playlistId, List<Track> tracks) async {
    appendedTracks.addAll(tracks);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SpotifyPlaylistSyncService Tests', () {
    late FakeSpotifyImporter importer;
    late FakeLibraryRepository libraryRepo;
    late SpotifyPlaylistSyncService syncService;

    setUp(() {
      importer = FakeSpotifyImporter();
      libraryRepo = FakeLibraryRepository();
      syncService = SpotifyPlaylistSyncService(
        importer: importer,
        libraryRepo: libraryRepo,
      );
    });

    test('ignores non-imported or non-Spotify playlists', () async {
      libraryRepo.playlistWithTracks = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl_local',
          name: 'Local Favorites',
          isImported: false,
          createdAt: DateTime.now(),
        ),
        entries: const [],
      );

      final added = await syncService.syncPlaylist('pl_local');
      expect(added, 0);
      expect(libraryRepo.appendedTracks, isEmpty);
    });

    test('detects newly added songs in remote Spotify playlist and appends them to Softify', () async {
      const playlistId = 'pl_spotify_1';
      const spotifyId = '37i9dQZF1DXcBWIGoYBM5M';

      const existingTrack = Track(
        id: 'track_existing_1',
        sourceId: 'src_existing_1',
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: Duration(seconds: 230),
      );

      libraryRepo.playlistWithTracks = PlaylistWithTracks(
        playlist: Playlist(
          id: playlistId,
          name: 'Today Top Hits',
          isImported: true,
          sourceUrl: 'https://open.spotify.com/playlist/$spotifyId',
          createdAt: DateTime.now(),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: playlistId,
            position: 0,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
            matchStatus: MatchStatus.matched,
            track: existingTrack,
          ),
        ],
      );

      final remoteTracks = [
        const SpotifyTrackItem(
          spotifyUri: 'spotify:track:starboy123',
          title: 'Starboy',
          artist: 'The Weeknd',
          duration: Duration(seconds: 230),
        ),
        const SpotifyTrackItem(
          spotifyUri: 'spotify:track:blindinglights456',
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          duration: Duration(seconds: 200),
        ),
      ];

      importer.playlists[spotifyId] = SpotifyImportPlaylist(
        id: spotifyId,
        name: 'Today Top Hits',
        tracks: remoteTracks,
      );

      const matchedNewTrack = Track(
        id: 'track_matched_blinding',
        sourceId: 'src_blinding_yt',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(seconds: 200),
      );

      importer.matches['spotify:track:blindinglights456'] = matchedNewTrack;

      final addedCount = await syncService.syncPlaylist(playlistId);

      expect(addedCount, 1);
      expect(libraryRepo.appendedTracks.length, 1);
      expect(libraryRepo.appendedTracks.first.title, 'Blinding Lights');
    });

    test('returns 0 when remote Spotify playlist has no new songs', () async {
      const playlistId = 'pl_spotify_2';
      const spotifyId = '37i9dQZF1DXcBWIGoYBM5M';

      libraryRepo.playlistWithTracks = PlaylistWithTracks(
        playlist: Playlist(
          id: playlistId,
          name: 'Pop Hits',
          isImported: true,
          sourceUrl: 'https://open.spotify.com/playlist/$spotifyId',
          createdAt: DateTime.now(),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: playlistId,
            position: 0,
            originalTitle: 'Espresso',
            originalArtist: 'Sabrina Carpenter',
            matchStatus: MatchStatus.matched,
            track: Track(
              id: 't_espresso',
              sourceId: 'src_espresso',
              title: 'Espresso',
              artist: 'Sabrina Carpenter',
              duration: Duration(seconds: 175),
            ),
          ),
        ],
      );

      importer.playlists[spotifyId] = const SpotifyImportPlaylist(
        id: spotifyId,
        name: 'Pop Hits',
        tracks: [
          SpotifyTrackItem(
            spotifyUri: 'spotify:track:espresso123',
            title: 'Espresso',
            artist: 'Sabrina Carpenter',
            duration: Duration(seconds: 175),
          ),
        ],
      );

      final addedCount = await syncService.syncPlaylist(playlistId);
      expect(addedCount, 0);
      expect(libraryRepo.appendedTracks, isEmpty);
    });
  });
}
