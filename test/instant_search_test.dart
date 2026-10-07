import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/history_item.dart';
import 'package:softify/domain/entities/interaction_events.dart';
import 'package:softify/domain/entities/playlist.dart';
import 'package:softify/domain/entities/playlist_entry.dart';
import 'package:softify/domain/entities/queue_state.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_catalog_repository.dart';
import 'package:softify/domain/ports/i_event_logger.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/presentation/providers/search_providers.dart';

class FakeLibraryRepository implements ILibraryRepository {
  List<Track> localTracksToReturn = [];
  Duration localDelay = Duration.zero;
  int searchCallCount = 0;
  String? lastSearchQuery;

  @override
  Future<List<Track>> searchLocalTracks(String query, {int limit = 20}) async {
    searchCallCount++;
    lastSearchQuery = query;
    if (localDelay > Duration.zero) {
      await Future<void>.delayed(localDelay);
    }
    return localTracksToReturn;
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
  Future<void> setLiked(String trackId, bool isLiked, {Track? track}) async {}
  @override
  Future<bool> isLiked(String trackId) async => false;
  @override
  Stream<List<Track>> watchLikedTracks() => const Stream.empty();
  @override
  Future<List<Track>> getLikedTracks() async => [];
  @override
  Future<Playlist> createPlaylist(String name, {String? description, bool isImported = false, String? sourceUrl}) async =>
      Playlist(id: '1', name: name, createdAt: DateTime.now());
  @override
  Future<void> updatePlaylist(String playlistId, {String? name, String? description}) async {}
  @override
  Future<void> deletePlaylist(String playlistId) async {}
  @override
  Stream<List<Playlist>> watchPlaylists() => const Stream.empty();
  @override
  Future<List<Playlist>> getPlaylists() async => [];
  @override
  Stream<PlaylistWithTracks?> watchPlaylistWithTracks(String playlistId) => const Stream.empty();
  @override
  Future<PlaylistWithTracks?> getPlaylistWithTracks(String playlistId) async => null;
  @override
  Future<void> addTrackToPlaylist(String playlistId, Track track) async {}
  @override
  Future<void> addTracksToPlaylist(String playlistId, List<Track> tracks) async {}
  @override
  Future<void> removeTrackFromPlaylist(String playlistId, int position) async {}
  @override
  Future<void> reorderPlaylistTrack(String playlistId, int oldPosition, int newPosition) async {}
  @override
  Future<void> recordPlayHistory(Track track, double completedRatio) async {}
  @override
  Stream<List<HistoryItem>> watchPlayHistory({int limit = 50}) => const Stream.empty();
  @override
  Future<void> clearPlayHistory() async {}
  @override
  Future<void> saveQueueState(List<Track> queue, int currentIndex, Duration position) async {}
  @override
  Future<QueueState> getQueueState() async =>
      const QueueState(tracks: [], currentIndex: 0, position: Duration.zero);
  @override
  Future<void> clearQueueState() async {}
  @override
  Future<void> cacheLyrics(String trackId, {String? syncedLrc, String? plainText, bool isNotFound = false}) async {}
  @override
  Future<({bool isNotFound, String? plainText, String? syncedLrc})?> getCachedLyrics(String trackId) async => null;
}

class FakeCatalogRepository implements ICatalogRepository {
  List<Track> networkTracksToReturn = [];
  Duration networkDelay = Duration.zero;
  int searchCallCount = 0;
  String? lastSearchQuery;

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    searchCallCount++;
    lastSearchQuery = query;
    if (networkDelay > Duration.zero) {
      await Future<void>.delayed(networkDelay);
    }
    return networkTracksToReturn;
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

class FakeEventLogger implements IEventLogger {
  final List<Map<String, dynamic>> loggedSearches = [];

  @override
  void logSearch({
    required String query,
    required List<String> resultIds,
    String? clickedId,
    int? clickedPosition,
    int? msToClick,
    required String rankerVersion,
  }) {
    loggedSearches.add({
      'query': query,
      'resultIds': resultIds,
      'clickedId': clickedId,
      'clickedPosition': clickedPosition,
      'msToClick': msToClick,
      'rankerVersion': rankerVersion,
    });
  }

  @override
  void logPlay({
    required String trackId,
    required String source,
    required int listenedMs,
    required int durationMs,
    required bool saved,
    required bool addedToPlaylist,
    required String rankerVersion,
    Map<String, double>? features,
  }) {}

  @override
  void logImpression({required String surface, required String itemId, required int position}) {}

  @override
  Future<DebugMetricsSummary> getMetricsSummary() async => const DebugMetricsSummary(
        streamRate: 1.0,
        earlySkipRate: 0.0,
        searchTop1ClickRate: 1.0,
        medianMsToClick: 500,
      );

  @override
  Future<void> clearAllLearningData() async {}
}

Track _makeTrack(String id, String title, String artist) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title,
    artist: artist,
    duration: const Duration(seconds: 180),
  );
}

void main() {
  late FakeLibraryRepository fakeLib;
  late FakeCatalogRepository fakeCatalog;
  late FakeEventLogger fakeLogger;
  late SearchNotifier notifier;

  setUp(() {
    fakeLib = FakeLibraryRepository();
    fakeCatalog = FakeCatalogRepository();
    fakeLogger = FakeEventLogger();
    notifier = SearchNotifier(
      libraryRepo: fakeLib,
      catalogRepo: fakeCatalog,
      eventLogger: fakeLogger,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('S1: Local-First Instant Search', () {
    test('Debounces keystrokes at 120ms', () async {
      notifier.setQuery('ar');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // Not yet executed at 60ms
      expect(fakeLib.searchCallCount, 0);

      notifier.setQuery('ari');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // Reset timer, still not executed
      expect(fakeLib.searchCallCount, 0);

      // Now wait until 130ms passes
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(fakeLib.searchCallCount, 1);
      expect(fakeLib.lastSearchQuery, 'ari');
    });

    test('Local results populate immediately before slow network returns', () async {
      fakeLib.localTracksToReturn = [
        _makeTrack('loc_1', 'Tum Hi Ho', 'Arijit Singh'),
      ];
      fakeCatalog.networkTracksToReturn = [
        _makeTrack('net_1', 'Channa Mereya', 'Arijit Singh'),
      ];
      fakeCatalog.networkDelay = const Duration(milliseconds: 150);

      notifier.setQuery('arijit');
      // Wait for debounce (120ms) + quick local search (~10ms)
      await Future<void>.delayed(const Duration(milliseconds: 140));

      // Local results are ready (<100ms budget)
      expect(notifier.state.localResults.length, 1);
      expect(notifier.state.localResults.first.id, 'loc_1');
      expect(notifier.state.isLocalLoading, isFalse);
      expect(notifier.state.isNetworkLoading, isTrue);
      // Combined results already show local track!
      expect(notifier.state.combinedResults.length, 1);
      expect(notifier.state.combinedResults.first.title, 'Tum Hi Ho');

      // Now let network finish
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(notifier.state.isNetworkLoading, isFalse);
      expect(notifier.state.combinedResults.length, 2);
    });

    test('Out-of-order request cancellation: stale response does not overwrite latest', () async {
      fakeLib.localTracksToReturn = [];

      // Query 1 will be slow (200ms)
      fakeCatalog.networkTracksToReturn = [_makeTrack('net_1', 'Slow Song', 'Artist')];
      fakeCatalog.networkDelay = const Duration(milliseconds: 200);

      notifier.executeSearch('slow');

      // 50ms later, user executes query 2 which is fast (10ms)
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fakeCatalog.networkTracksToReturn = [_makeTrack('net_2', 'Fast Song', 'Artist')];
      fakeCatalog.networkDelay = const Duration(milliseconds: 10);
      notifier.executeSearch('fast');

      // Wait 30ms for query 2 to finish
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(notifier.state.query, 'fast');
      expect(notifier.state.networkResults.first.id, 'net_2');

      // Wait for query 1's slow response to complete
      await Future<void>.delayed(const Duration(milliseconds: 250));
      // State must remain query 2! Stale query 1 was cancelled/discarded.
      expect(notifier.state.query, 'fast');
      expect(notifier.state.networkResults.first.id, 'net_2');
    });

    test('Non-jumping merge deduplicates items and maintains local item head position', () async {
      final sharedTrack = _makeTrack('track_shared', 'Kesariya', 'Arijit Singh');
      final localOnly = _makeTrack('track_loc', 'Ae Dil Hai Mushkil', 'Arijit Singh');
      final netOnly = _makeTrack('track_net', 'Ilahi', 'Arijit Singh');

      fakeLib.localTracksToReturn = [localOnly, sharedTrack];
      // Remote catalog returns duplicate of sharedTrack plus netOnly
      fakeCatalog.networkTracksToReturn = [sharedTrack, netOnly];

      await notifier.executeSearch('arijit');

      final combined = notifier.state.combinedResults;
      expect(combined.length, 3);
      // Local tracks are head items and are never shifted
      expect(combined[0].id, 'track_loc');
      expect(combined[1].id, 'track_shared');
      // Network item appended at tail
      expect(combined[2].id, 'track_net');
    });

    test('Track click logs search event with query, position, and positive latency', () async {
      final track = _makeTrack('t1', 'Starboy', 'The Weeknd');
      fakeLib.localTracksToReturn = [track];

      await notifier.executeSearch('starboy');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      notifier.onTrackClicked(track, 0);

      expect(fakeLogger.loggedSearches.length, 1);
      final log = fakeLogger.loggedSearches.first;
      expect(log['query'], 'starboy');
      expect(log['clickedId'], 't1');
      expect(log['clickedPosition'], 0);
      expect(log['rankerVersion'], 'v2');
      expect(log['msToClick'], greaterThanOrEqualTo(0));
    });
  });
}
