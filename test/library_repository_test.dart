import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  late AppDatabase db;
  late DriftLibraryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftLibraryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  const testTrack1 = Track(
    id: 'track-uuid-1',
    sourceId: 'src-id-1',
    title: 'Starboy',
    artist: 'The Weeknd',
    album: 'Starboy',
    duration: Duration(seconds: 230),
    coverUrl: 'https://example.com/starboy.jpg',
  );

  const testTrack2 = Track(
    id: 'track-uuid-2',
    sourceId: 'src-id-2',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    album: 'After Hours',
    duration: Duration(seconds: 200),
    coverUrl: 'https://example.com/blinding.jpg',
  );

  group('DriftLibraryRepository: Tracks & Favorites', () {
    test('upsertTrack and query by id and sourceId', () async {
      await repo.upsertTrack(testTrack1);

      final byId = await repo.getTrackById('track-uuid-1');
      expect(byId, isNotNull);
      expect(byId!.title, 'Starboy');
      expect(byId.sourceId, 'src-id-1');

      final bySource = await repo.getTrackBySourceId('src-id-1');
      expect(bySource, isNotNull);
      expect(bySource!.id, 'track-uuid-1');

      // Update track
      await repo.upsertTrack(testTrack1.copyWith(album: 'Starboy (Deluxe)'));
      final updated = await repo.getTrackById('track-uuid-1');
      expect(updated!.album, 'Starboy (Deluxe)');
    });

    test('Liked tracks toggle and stream', () async {
      await repo.upsertTrack(testTrack1);
      await repo.upsertTrack(testTrack2);

      expect(await repo.isLiked(testTrack1.id), isFalse);

      await repo.setLiked(testTrack1.id, true);
      expect(await repo.isLiked(testTrack1.id), isTrue);

      final liked = await repo.getLikedTracks();
      expect(liked.length, 1);
      expect(liked.first.id, testTrack1.id);

      await repo.setLiked(testTrack1.id, false);
      expect(await repo.isLiked(testTrack1.id), isFalse);
    });
  });

  group('DriftLibraryRepository: Playlists', () {
    test('create, add tracks, read with count, remove track and reorder', () async {
      final playlist = await repo.createPlaylist('My Hits', description: 'Favorites 2026');
      expect(playlist.name, 'My Hits');
      expect(playlist.trackCount, 0);

      await repo.addTrackToPlaylist(playlist.id, testTrack1);
      await repo.addTrackToPlaylist(playlist.id, testTrack2);

      final withTracks = await repo.getPlaylistWithTracks(playlist.id);
      expect(withTracks, isNotNull);
      expect(withTracks!.playlist.trackCount, 2);
      expect(withTracks.entries.length, 2);
      expect(withTracks.entries[0].track?.id, testTrack1.id);
      expect(withTracks.entries[0].position, 0);
      expect(withTracks.entries[1].track?.id, testTrack2.id);
      expect(withTracks.entries[1].position, 1);

      // Reorder: move track 0 to position 1
      await repo.reorderPlaylistTrack(playlist.id, 0, 1);
      final reordered = await repo.getPlaylistWithTracks(playlist.id);
      expect(reordered!.entries[0].track?.id, testTrack2.id);
      expect(reordered.entries[1].track?.id, testTrack1.id);

      // Remove first track
      await repo.removeTrackFromPlaylist(playlist.id, 0);
      final afterRemove = await repo.getPlaylistWithTracks(playlist.id);
      expect(afterRemove!.entries.length, 1);
      expect(afterRemove.entries[0].track?.id, testTrack1.id);
      expect(afterRemove.entries[0].position, 0);

      // Delete playlist
      await repo.deletePlaylist(playlist.id);
      expect(await repo.getPlaylistWithTracks(playlist.id), isNull);
    });

    test('addTracksToPlaylist atomic batch insert preserves tracks and positions', () async {
      final playlist = await repo.createPlaylist('Batch Playlist');
      final tracks = [testTrack1, testTrack2];

      await repo.addTracksToPlaylist(playlist.id, tracks);

      final withTracks = await repo.getPlaylistWithTracks(playlist.id);
      expect(withTracks, isNotNull);
      expect(withTracks!.playlist.trackCount, 2);
      expect(withTracks.entries.length, 2);
      expect(withTracks.entries[0].track?.id, testTrack1.id);
      expect(withTracks.entries[0].position, 0);
      expect(withTracks.entries[1].track?.id, testTrack2.id);
      expect(withTracks.entries[1].position, 1);
    });

    test('watchPlaylists and watchPlaylistWithTracks update live when tracks are added', () async {
      final playlist = await repo.createPlaylist('Live Reactive Playlist');

      final playlistsStream = repo.watchPlaylists();
      final playlistWithTracksStream = repo.watchPlaylistWithTracks(playlist.id);

      // Verify initial state
      final initialList = await playlistsStream.first;
      final initialPl = initialList.firstWhere((p) => p.id == playlist.id);
      expect(initialPl.trackCount, 0);

      final initialDetails = await playlistWithTracksStream.first;
      expect(initialDetails!.entries.length, 0);

      // Add a track
      await repo.addTrackToPlaylist(playlist.id, testTrack1);

      // Verify updated count in watchPlaylists
      final updatedList = await playlistsStream.first;
      final updatedPl = updatedList.firstWhere((p) => p.id == playlist.id);
      expect(updatedPl.trackCount, 1);

      // Verify updated entries in watchPlaylistWithTracks
      final updatedDetails = await playlistWithTracksStream.first;
      expect(updatedDetails!.entries.length, 1);
      expect(updatedDetails.entries.first.track?.id, testTrack1.id);
    });
  });

  group('DriftLibraryRepository: Queue State & History', () {
    test('save and load queue state', () async {
      await repo.saveQueueState([testTrack1, testTrack2], 1, const Duration(seconds: 45));

      final state = await repo.getQueueState();
      expect(state.tracks.length, 2);
      expect(state.currentIndex, 1);
      expect(state.position, const Duration(seconds: 45));
      expect(state.currentTrack?.id, testTrack2.id);

      await repo.clearQueueState();
      final cleared = await repo.getQueueState();
      expect(cleared.tracks, isEmpty);
    });

    test('record play history', () async {
      await repo.recordPlayHistory(testTrack1, 0.95);
      await repo.recordPlayHistory(testTrack2, 0.40);

      final history = await repo.watchPlayHistory().first;
      expect(history.length, 2);
      expect(history[0].track.id, testTrack2.id); // Latest first
      expect(history[0].completedRatio, 0.40);
      expect(history[1].track.id, testTrack1.id);
      expect(history[1].completedRatio, 0.95);

      await repo.clearPlayHistory();
      final cleared = await repo.watchPlayHistory().first;
      expect(cleared, isEmpty);
    });

    test('record play history deduplicates and moves re-played track to the top', () async {
      await repo.recordPlayHistory(testTrack1, 0.0);
      await repo.recordPlayHistory(testTrack2, 0.0);

      var history = await repo.watchPlayHistory().first;
      expect(history.length, 2);
      expect(history[0].track.id, testTrack2.id);
      expect(history[1].track.id, testTrack1.id);

      // Now testTrack1 is played again
      await repo.recordPlayHistory(testTrack1, 1.0);

      history = await repo.watchPlayHistory().first;
      expect(history.length, 2); // Still 2 items, deduplicated!
      expect(history[0].track.id, testTrack1.id); // testTrack1 is now at the top!
      expect(history[0].completedRatio, 1.0);
      expect(history[1].track.id, testTrack2.id);
    });

    test('cache lyrics', () async {
      await repo.cacheLyrics(testTrack1.id, syncedLrc: '[00:10.00] Starboy line');

      final cached = await repo.getCachedLyrics(testTrack1.id);
      expect(cached, isNotNull);
      expect(cached!.syncedLrc, '[00:10.00] Starboy line');
      expect(cached.isNotFound, isFalse);
    });
  });
}
