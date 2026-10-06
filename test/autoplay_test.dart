import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_catalog_repository.dart';

import 'softify_audio_handler_test.dart';

class MockCatalogRepository implements ICatalogRepository {
  final List<Track> relatedTracksToReturn;
  final List<Track> recordedGetRelatedCalls = [];

  MockCatalogRepository({this.relatedTracksToReturn = const []});

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    recordedGetRelatedCalls.add(track);
    return relatedTracksToReturn;
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async => [];

  @override
  Future<List<Track>> getTrendingTracks({int limit = 30}) async => [];

  @override
  Future<List<String>> getSearchSuggestions(String query) async => [];

  @override
  Future<List<Track>> getArtistTracks(String artist, {int limit = 25}) async => [];

  @override
  Future<List<Track>> getAlbumTracks(String album, String artist, {int limit = 25}) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftLibraryRepository libraryRepo;
  late MockStreamResolver streamResolver;
  late MockDownloadRepository downloadRepo;
  late FakeSoftifyAudioPlayer fakePlayer;

  const track1 = Track(
    id: 't-1',
    sourceId: 's-1',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    duration: Duration(seconds: 200),
  );

  const track2 = Track(
    id: 't-2',
    sourceId: 's-2',
    title: 'Save Your Tears',
    artist: 'The Weeknd',
    duration: Duration(seconds: 215),
  );

  const recTrack1 = Track(
    id: 'rec-1',
    sourceId: 'rec-s1',
    title: 'After Hours',
    artist: 'The Weeknd',
    duration: Duration(seconds: 360),
  );

  const recTrack2 = Track(
    id: 'rec-2',
    sourceId: 'rec-s2',
    title: 'Starboy',
    artist: 'The Weeknd',
    duration: Duration(seconds: 230),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    libraryRepo = DriftLibraryRepository(db);
    streamResolver = MockStreamResolver();
    downloadRepo = MockDownloadRepository();
    fakePlayer = FakeSoftifyAudioPlayer();
  });

  tearDown(() async {
    await db.close();
  });

  group('Autoplay & Recommendation System', () {
    test('Background pre-fetching populates queue when playing a single track', () async {
      final mockCatalog = MockCatalogRepository(
        relatedTracksToReturn: [recTrack1, recTrack2],
      );

      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
        catalogRepo: mockCatalog,
        autoRestoreState: false,
      );

      // Play a single track
      await handler.playTrack(track1);

      expect(handler.currentTrack?.id, track1.id);
      expect(fakePlayer.playing, isTrue);

      // Allow background prefetch to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Queue should now contain track1 plus the recommended tracks!
      expect(handler.currentQueue.length, 3);
      expect(handler.currentQueue[0].id, track1.id);
      expect(handler.currentQueue[1].id, recTrack1.id);
      expect(handler.currentQueue[2].id, recTrack2.id);
      expect(mockCatalog.recordedGetRelatedCalls.length, 1);

      await handler.dispose();
    });

    test('Automatically transitions to recommended track when queue finishes', () async {
      final mockCatalog = MockCatalogRepository(
        relatedTracksToReturn: [recTrack1],
      );

      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
        catalogRepo: mockCatalog,
        autoRestoreState: false,
      );

      // Start with queue containing only track1
      await handler.playTrack(track1);
      expect(handler.currentIndex, 0);

      // Skip to next at end of queue
      await handler.skipToNext();

      // Autoplay transitioned to recTrack1
      expect(handler.currentIndex, 1);
      expect(handler.currentTrack?.id, recTrack1.id);
      expect(fakePlayer.lastLoadedUrl, 'https://example.com/audio_rec-1.m4a');
      expect(fakePlayer.playing, isTrue);

      await handler.dispose();
    });

    test('Stops playback at end of queue when autoplay is disabled', () async {
      final mockCatalog = MockCatalogRepository(
        relatedTracksToReturn: [recTrack1],
      );

      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
        catalogRepo: mockCatalog,
        autoRestoreState: false,
      );

      await handler.setAutoPlayEnabled(false);
      expect(handler.isAutoPlayEnabled, isFalse);

      await handler.playTrack(track1);
      // Wait to ensure prefetch did NOT run
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(mockCatalog.recordedGetRelatedCalls, isEmpty);

      // Skip to next at end of queue
      await handler.skipToNext();

      // Should stop, not fetch recommendations
      expect(fakePlayer.playing, isFalse);
      expect(mockCatalog.recordedGetRelatedCalls, isEmpty);

      await handler.dispose();
    });

    test('Multiple tracks in queue auto-advance sequentially before fetching recommendations', () async {
      final mockCatalog = MockCatalogRepository(
        relatedTracksToReturn: [recTrack1],
      );

      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
        catalogRepo: mockCatalog,
        autoRestoreState: false,
      );

      await handler.setQueue([track1, track2], startIndex: 0);
      expect(handler.currentIndex, 0);
      expect(handler.currentTrack?.id, track1.id);

      // Advance to track2
      await handler.skipToNext();
      expect(handler.currentIndex, 1);
      expect(handler.currentTrack?.id, track2.id);

      await handler.dispose();
    });

    test('Track completion (ProcessingState.completed) automatically triggers next track', () async {
      final mockCatalog = MockCatalogRepository(
        relatedTracksToReturn: [recTrack1],
      );

      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
        catalogRepo: mockCatalog,
        autoRestoreState: false,
      );

      await handler.setQueue([track1, track2], startIndex: 0);
      expect(handler.currentIndex, 0);
      expect(handler.currentTrack?.id, track1.id);

      // Simulate track finishing
      fakePlayer.simulateTrackCompletion();

      // Give event loop time to process onTrackCompleted
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should automatically be playing track2!
      expect(handler.currentIndex, 1);
      expect(handler.currentTrack?.id, track2.id);
      expect(fakePlayer.playing, isTrue);

      await handler.dispose();
    });
  });
}
