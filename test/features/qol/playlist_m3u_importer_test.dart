import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/history_item.dart';
import 'package:softify/domain/entities/playlist.dart';
import 'package:softify/domain/entities/playlist_entry.dart';
import 'package:softify/domain/entities/queue_state.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/features/qol/playlist_m3u_importer.dart';

class FakeLibraryRepository implements ILibraryRepository {
  final List<Playlist> createdPlaylists = [];
  final Map<String, List<Track>> tracksByPlaylist = {};
  final Map<String, List<({String title, String artist})>?> metadataByPlaylist =
      {};

  @override
  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    bool isImported = false,
    String? sourceUrl,
  }) async {
    final pl = Playlist(
      id: 'pl_${createdPlaylists.length + 1}',
      name: name,
      description: description,
      isImported: isImported,
      sourceUrl: sourceUrl,
      createdAt: DateTime.now(),
      trackCount: 0,
    );
    createdPlaylists.add(pl);
    tracksByPlaylist[pl.id] = [];
    return pl;
  }

  @override
  Future<void> addTracksToPlaylist(
    String playlistId,
    List<Track> tracks, {
    List<({String title, String artist})>? originalMetadata,
  }) async {
    tracksByPlaylist[playlistId] = [
      ...?tracksByPlaylist[playlistId],
      ...tracks,
    ];
    metadataByPlaylist[playlistId] = originalMetadata;
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    tracksByPlaylist[playlistId] = [
      ...?tracksByPlaylist[playlistId],
      track,
    ];
  }

  @override
  Future<void> upsertTrack(Track track) async {}

  @override
  Future<Track?> getTrackById(String id) async => null;

  @override
  Future<Track?> getTrackBySourceId(String sourceId) async => null;

  @override
  Future<void> markTrackUnavailable(String id, bool isUnavailable) async {}

  @override
  Future<List<Track>> searchLocalTracks(String query, {int limit = 20}) async =>
      [];

  @override
  Future<void> setLiked(String trackId, bool isLiked, {Track? track}) async {}

  @override
  Future<bool> isLiked(String trackId) async => false;

  @override
  Stream<List<Track>> watchLikedTracks() => Stream.value([]);

  @override
  Stream<Set<String>> watchLikedTrackIds() => Stream.value({});

  @override
  Future<List<Track>> getLikedTracks() async => [];

  @override
  Future<void> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
  }) async {}

  @override
  Future<void> deletePlaylist(String playlistId) async {}

  @override
  Stream<List<Playlist>> watchPlaylists() => Stream.value(createdPlaylists);

  @override
  Future<List<Playlist>> getPlaylists() async => createdPlaylists;

  @override
  Stream<PlaylistWithTracks?> watchPlaylistWithTracks(String playlistId) =>
      Stream.value(null);

  @override
  Future<PlaylistWithTracks?> getPlaylistWithTracks(String playlistId) async =>
      null;

  @override
  Future<void> removeTrackFromPlaylist(
          String playlistId, int position) async {}

  @override
  Future<void> reorderPlaylistTrack(
          String playlistId, int oldPosition, int newPosition) async {}

  @override
  Future<void> recordPlayHistory(Track track, double completedRatio) async {}

  @override
  Stream<List<HistoryItem>> watchPlayHistory({int limit = 50}) =>
      Stream.value([]);

  @override
  Future<void> clearPlayHistory() async {}

  @override
  Future<void> saveQueueState(
      List<Track> queue, int currentIndex, Duration position) async {}

  @override
  Future<QueueState> getQueueState() async => QueueState.empty;

  @override
  Future<void> clearQueueState() async {}

  @override
  Future<void> cacheLyrics(
    String trackId, {
    String? syncedLrc,
    String? plainText,
    bool isNotFound = false,
  }) async {}

  @override
  Future<({String? syncedLrc, String? plainText, bool isNotFound})?>
      getCachedLyrics(String trackId) async => null;
}

void main() {
  group('PlaylistM3uImporter Parsing', () {
    test('parses extended .m3u format with #EXTINF and #PLAYLIST', () {
      const m3u = '''
#EXTM3U
#PLAYLIST:Rock Anthems
#EXTINF:354,Queen - Bohemian Rhapsody
queen_bohemian.mp3
#EXTINF:482,Led Zeppelin - Stairway to Heaven
led_zeppelin_stairway.flac
#EXTINF:180,Radiohead - Creep
https://music.example.com/creep.mp3
''';

      final result = PlaylistM3uImporter.parseContent(m3u);

      expect(result.playlistName, equals('Rock Anthems'));
      expect(result.tracks.length, equals(3));

      expect(result.tracks[0].title, equals('Bohemian Rhapsody'));
      expect(result.tracks[0].artist, equals('Queen'));
      expect(result.tracks[0].duration, equals(const Duration(seconds: 354)));
      expect(result.tracks[0].pathOrUrl, equals('queen_bohemian.mp3'));

      expect(result.tracks[1].title, equals('Stairway to Heaven'));
      expect(result.tracks[1].artist, equals('Led Zeppelin'));
      expect(result.tracks[1].duration, equals(const Duration(seconds: 482)));

      expect(result.tracks[2].title, equals('Creep'));
      expect(result.tracks[2].artist, equals('Radiohead'));
      expect(result.tracks[2].duration, equals(const Duration(seconds: 180)));
    });

    test('parses .m3u8 format with attributes and live stream -1 duration', () {
      const m3u8 = '''
#EXTM3U
#EXT-X-NAME:Indie Live
#EXTINF:-1 tvg-id="123" tvg-name="Arctic Monkeys - Do I Wanna Know?",Arctic Monkeys - Do I Wanna Know?
http://streams.com/live.m3u8
#EXTINF:225,The Strokes - Last Nite
strokes.mp3
''';

      final result = PlaylistM3uImporter.parseContent(m3u8);

      expect(result.playlistName, equals('Indie Live'));
      expect(result.tracks.length, equals(2));

      expect(result.tracks[0].title, equals('Do I Wanna Know?'));
      expect(result.tracks[0].artist, equals('Arctic Monkeys'));
      expect(result.tracks[0].duration, equals(Duration.zero));

      expect(result.tracks[1].title, equals('Last Nite'));
      expect(result.tracks[1].artist, equals('The Strokes'));
      expect(result.tracks[1].duration, equals(const Duration(seconds: 225)));
    });

    test('parses plain text tracklist with Artist - Title and durations', () {
      const plainText = '''
1. Pink Floyd - Time (06:53)
2. The Who - Baba O'Riley [5:00]
3. Jimi Hendrix - Purple Haze - 2:50
Fleetwood Mac - Dreams
Dire Straits - Sultans of Swing 5:48
Hotel California by Eagles
''';

      final result = PlaylistM3uImporter.parseContent(plainText,
          defaultPlaylistName: 'Classic Rock');

      expect(result.playlistName, equals('Classic Rock'));
      expect(result.tracks.length, equals(6));

      expect(result.tracks[0].artist, equals('Pink Floyd'));
      expect(result.tracks[0].title, equals('Time'));
      expect(result.tracks[0].duration, equals(const Duration(minutes: 6, seconds: 53)));

      expect(result.tracks[1].artist, equals("The Who"));
      expect(result.tracks[1].title, equals("Baba O'Riley"));
      expect(result.tracks[1].duration, equals(const Duration(minutes: 5)));

      expect(result.tracks[2].artist, equals('Jimi Hendrix'));
      expect(result.tracks[2].title, equals('Purple Haze'));
      expect(result.tracks[2].duration, equals(const Duration(minutes: 2, seconds: 50)));

      expect(result.tracks[3].artist, equals('Fleetwood Mac'));
      expect(result.tracks[3].title, equals('Dreams'));
      expect(result.tracks[3].duration, equals(Duration.zero));

      expect(result.tracks[4].artist, equals('Dire Straits'));
      expect(result.tracks[4].title, equals('Sultans of Swing'));
      expect(result.tracks[4].duration, equals(const Duration(minutes: 5, seconds: 48)));

      expect(result.tracks[5].artist, equals('Eagles'));
      expect(result.tracks[5].title, equals('Hotel California'));
    });

    test('handles en-dash and em-dash separators cleanly', () {
      const text = '''
Daft Punk – Get Lucky
Arctic Monkeys — 505
Coldplay − Yellow
''';

      final result = PlaylistM3uImporter.parseContent(text);

      expect(result.tracks.length, equals(3));
      expect(result.tracks[0].artist, equals('Daft Punk'));
      expect(result.tracks[0].title, equals('Get Lucky'));

      expect(result.tracks[1].artist, equals('Arctic Monkeys'));
      expect(result.tracks[1].title, equals('505'));

      expect(result.tracks[2].artist, equals('Coldplay'));
      expect(result.tracks[2].title, equals('Yellow'));
    });
  });

  group('PlaylistM3uImporter ILibraryRepository Integration', () {
    test('creates playlist and batch adds tracks into repository', () async {
      final repo = FakeLibraryRepository();
      const text = '''
Queen - Radio Ga Ga (5:48)
Queen - Under Pressure (4:08)
David Bowie - Space Oddity (5:18)
''';

      final parsed = PlaylistM3uImporter.parseContent(text,
          defaultPlaylistName: 'Queen & Bowie');

      final playlist = await PlaylistM3uImporter.importTracks(
        repository: repo,
        playlistName: parsed.playlistName,
        tracks: parsed.tracks,
      );

      expect(repo.createdPlaylists.length, equals(1));
      expect(repo.createdPlaylists.first.name, equals('Queen & Bowie'));
      expect(repo.createdPlaylists.first.isImported, isTrue);

      final tracks = repo.tracksByPlaylist[playlist.id];
      expect(tracks, isNotNull);
      expect(tracks!.length, equals(3));
      expect(tracks[0].title, equals('Radio Ga Ga'));
      expect(tracks[0].artist, equals('Queen'));
      expect(tracks[0].duration, equals(const Duration(minutes: 5, seconds: 48)));

      expect(tracks[1].title, equals('Under Pressure'));
      expect(tracks[2].title, equals('Space Oddity'));
      expect(tracks[2].artist, equals('David Bowie'));

      final metadata = repo.metadataByPlaylist[playlist.id];
      expect(metadata, isNotNull);
      expect(metadata!.length, equals(3));
      expect(metadata[0].title, equals('Radio Ga Ga'));
      expect(metadata[0].artist, equals('Queen'));
    });
  });
}
