// ============================================================================
// Softify Quality of Life (QoL) - Feature 21: Smart Playlist - Recently Added Tests
// ============================================================================

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/features/qol/library/smart_playlist_recently_added.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_tokens.dart';
import 'package:softify/presentation/widgets/animated_music_wave_indicator.dart';

// ============================================================================
// Test Doubles
// ============================================================================

class FakeAudioHandler extends Fake implements SoftifyAudioHandler {
  List<Track> internalQueue = [];
  int startIndex = 0;
  Track? playingTrack;
  bool isPlaying = false;
  int playCallCount = 0;
  int pauseCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  Future<void> playTrack(Track track, {List<Track>? queue, int? startIndex}) async {
    playingTrack = track;
    if (queue != null) internalQueue = List.of(queue);
    this.startIndex = startIndex ?? 0;
    isPlaying = true;
    playCallCount++;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    playCallCount++;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    pauseCallCount++;
  }
}

Track _makeTrack({
  required String id,
  required String title,
  required String artist,
  String? album,
  Duration duration = const Duration(minutes: 3, seconds: 30),
  String? coverUrl,
  bool isLiked = false,
}) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    coverUrl: coverUrl,
    matchConfidence: 1.0,
    isLiked: isLiked,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RecentlyAddedSharedPreferencesStore.reset();
  });

  tearDown(() {
    RecentlyAddedSharedPreferencesStore.reset();
  });

  // ==========================================================================
  // 1. Data Models & Value Objects
  // ==========================================================================
  group('RecentlyAddedTrackItem Models', () {
    test('initializes properties accurately', () {
      final now = DateTime.now();
      final track = _makeTrack(id: 't1', title: 'Song 1', artist: 'Artist 1', album: 'Album A');
      final item = RecentlyAddedTrackItem(
        track: track,
        addedAt: now,
        orderIndex: 1,
        albumTitle: 'Album A',
        isAlbumTrack: true,
      );

      expect(item.track.id, 't1');
      expect(item.orderIndex, 1);
      expect(item.albumTitle, 'Album A');
      expect(item.isAlbumTrack, true);
      expect(item.addedAt, now);
    });

    test('calculates relative addition timestamps correctly', () {
      final now = DateTime.now();
      final track = _makeTrack(id: 't1', title: 'Song', artist: 'Artist');

      // 1. Just added (< 60s)
      final itemJustNow = RecentlyAddedTrackItem(
        track: track,
        addedAt: now.subtract(const Duration(seconds: 20)),
        orderIndex: 1,
      );
      expect(itemJustNow.formattedRelativeTime, 'Just added');

      // 2. Minutes ago (e.g., 15 mins)
      final itemMinutes = RecentlyAddedTrackItem(
        track: track,
        addedAt: now.subtract(const Duration(minutes: 15)),
        orderIndex: 2,
      );
      expect(itemMinutes.formattedRelativeTime, '15 mins ago');

      // 3. Hours ago (e.g., 3 hours)
      final itemHours = RecentlyAddedTrackItem(
        track: track,
        addedAt: now.subtract(const Duration(hours: 3)),
        orderIndex: 3,
      );
      expect(itemHours.formattedRelativeTime, '3 hrs ago');

      // 4. Days ago (e.g., 4 days)
      final itemDays = RecentlyAddedTrackItem(
        track: track,
        addedAt: now.subtract(const Duration(days: 4)),
        orderIndex: 4,
      );
      expect(itemDays.formattedRelativeTime, '4 days ago');

      // 5. Weeks ago (e.g., 2 weeks)
      final itemWeeks = RecentlyAddedTrackItem(
        track: track,
        addedAt: now.subtract(const Duration(days: 16)),
        orderIndex: 5,
      );
      expect(itemWeeks.formattedRelativeTime, '2 weeks ago');
    });

    test('supports copyWith, equality and toMap serialization', () {
      final now = DateTime.now();
      final track = _makeTrack(id: 't1', title: 'Song 1', artist: 'Artist 1');
      final item = RecentlyAddedTrackItem(
        track: track,
        addedAt: now,
        orderIndex: 1,
      );

      final copy = item.copyWith(orderIndex: 2);
      expect(copy.orderIndex, 2);
      expect(copy.track.id, 't1');

      final map = item.toMap();
      expect(map['track_id'], 't1');
      expect(map['title'], 'Song 1');
      expect(map['order_index'], 1);

      final itemIdentical = RecentlyAddedTrackItem(
        track: track,
        addedAt: now,
        orderIndex: 1,
      );
      expect(item, equals(itemIdentical));
      expect(item.hashCode, equals(itemIdentical.hashCode));
    });
  });

  group('RecentlyAddedConfig Models', () {
    test('default configuration has max 100 tracks and newestFirst sorting', () {
      const config = RecentlyAddedConfig();
      expect(config.maxTracks, 100);
      expect(config.filter, RecentlyAddedSourceFilter.all);
      expect(config.sortOrder, RecentlyAddedSortOrder.newestFirst);
      expect(config.autoRefresh, isTrue);
      expect(config.deduplicate, isTrue);
    });

    test('serializes to and from map', () {
      const config = RecentlyAddedConfig(
        maxTracks: 50,
        filter: RecentlyAddedSourceFilter.songs,
        sortOrder: RecentlyAddedSortOrder.oldestFirst,
        autoRefresh: false,
        deduplicate: false,
      );

      final map = config.toMap();
      final deserialized = RecentlyAddedConfig.fromMap(map);
      expect(deserialized, equals(config));
    });

    test('parses enums safely with fallback defaults', () {
      expect(RecentlyAddedSourceFilter.fromString('songs'), RecentlyAddedSourceFilter.songs);
      expect(RecentlyAddedSourceFilter.fromString('albums'), RecentlyAddedSourceFilter.albums);
      expect(RecentlyAddedSourceFilter.fromString(null), RecentlyAddedSourceFilter.all);
      expect(RecentlyAddedSourceFilter.fromString('invalid'), RecentlyAddedSourceFilter.all);

      expect(RecentlyAddedSortOrder.fromString('oldestFirst'), RecentlyAddedSortOrder.oldestFirst);
      expect(RecentlyAddedSortOrder.fromString(null), RecentlyAddedSortOrder.newestFirst);
      expect(RecentlyAddedSortOrder.fromString('invalid'), RecentlyAddedSortOrder.newestFirst);
    });
  });

  group('RecentlyAddedSmartPlaylist Aggregations', () {
    test('computes counts, duration, and preview covers accurately', () {
      final now = DateTime.now();
      final track1 = _makeTrack(
        id: '1',
        title: 'Track One',
        artist: 'Artist A',
        album: 'Album X',
        coverUrl: 'https://example.com/cover1.jpg',
        duration: const Duration(minutes: 3),
      );
      final track2 = _makeTrack(
        id: '2',
        title: 'Track Two',
        artist: 'Artist B',
        album: 'Album Y',
        coverUrl: 'https://example.com/cover2.jpg',
        duration: const Duration(minutes: 4),
      );
      final track3 = _makeTrack(
        id: '3',
        title: 'Track Three',
        artist: 'Artist A',
        album: 'Album X',
        coverUrl: 'https://example.com/cover1.jpg', // Duplicate cover
        duration: const Duration(minutes: 2),
      );

      final items = [
        RecentlyAddedTrackItem(track: track1, addedAt: now, orderIndex: 1),
        RecentlyAddedTrackItem(track: track2, addedAt: now.subtract(const Duration(hours: 2)), orderIndex: 2),
        RecentlyAddedTrackItem(track: track3, addedAt: now.subtract(const Duration(days: 2)), orderIndex: 3),
      ];

      final playlist = RecentlyAddedSmartPlaylist(
        generatedAt: now,
        items: items,
      );

      expect(playlist.length, 3);
      expect(playlist.isEmpty, isFalse);
      expect(playlist.isNotEmpty, isTrue);
      expect(playlist.tracks.map((t) => t.id).toList(), ['1', '2', '3']);
      expect(playlist.totalDuration, const Duration(minutes: 9));
      expect(playlist.formattedTotalDuration, '9 min');

      // Preview covers must deduplicate and retain unique artworks
      expect(playlist.previewCovers, ['https://example.com/cover1.jpg', 'https://example.com/cover2.jpg']);
      expect(playlist.uniqueAlbumsCount, 2);
      expect(playlist.uniqueArtistsCount, 2);
      expect(playlist.additionsTodayCount, 2);
      expect(playlist.additionsThisWeekCount, 3);

      final domainPlaylist = playlist.toDomainPlaylist();
      expect(domainPlaylist.id, kRecentlyAddedSmartPlaylistId);
      expect(domainPlaylist.name, 'Recently Added');
      expect(domainPlaylist.trackCount, 3);
    });

    test('handles empty playlist cleanly without exceptions', () {
      final empty = RecentlyAddedSmartPlaylist(
        generatedAt: DateTime.now(),
        items: const [],
      );

      expect(empty.length, 0);
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
      expect(empty.totalDuration, Duration.zero);
      expect(empty.formattedTotalDuration, '0 min');
      expect(empty.previewCovers, isEmpty);
      expect(empty.uniqueAlbumsCount, 0);
      expect(empty.uniqueArtistsCount, 0);
    });
  });

  // ==========================================================================
  // 2. Pure Dart Algorithmic Generator Tests
  // ==========================================================================
  group('RecentlyAddedPlaylistEngine Generator', () {
    test('sorts entries in reverse chronological order (newest first)', () {
      final now = DateTime.now();
      final t1 = _makeTrack(id: 't1', title: 'Oldest', artist: 'Art');
      final t2 = _makeTrack(id: 't2', title: 'Middle', artist: 'Art');
      final t3 = _makeTrack(id: 't3', title: 'Newest', artist: 'Art');

      final entries = [
        (track: t1, addedAt: now.subtract(const Duration(days: 10))),
        (track: t3, addedAt: now),
        (track: t2, addedAt: now.subtract(const Duration(days: 2))),
      ];

      final playlist = RecentlyAddedPlaylistEngine.generateFromTracks(
        entries: entries,
        config: const RecentlyAddedConfig(sortOrder: RecentlyAddedSortOrder.newestFirst),
      );

      expect(playlist.items.length, 3);
      expect(playlist.items[0].track.id, 't3');
      expect(playlist.items[0].orderIndex, 1);
      expect(playlist.items[1].track.id, 't2');
      expect(playlist.items[1].orderIndex, 2);
      expect(playlist.items[2].track.id, 't1');
      expect(playlist.items[2].orderIndex, 3);
    });

    test('caps at maxTracks (defaults to top 100)', () {
      final now = DateTime.now();
      final entries = List.generate(120, (i) {
        return (
          track: _makeTrack(id: 't_$i', title: 'Track $i', artist: 'Artist'),
          addedAt: now.subtract(Duration(minutes: i)),
        );
      });

      final playlist = RecentlyAddedPlaylistEngine.generateFromTracks(
        entries: entries,
        config: const RecentlyAddedConfig(maxTracks: 100),
      );

      expect(playlist.items.length, 100);
      expect(playlist.items.first.track.id, 't_0');
      expect(playlist.items.last.track.id, 't_99');
    });

    test('deduplicates tracks by keeping the newest addition timestamp', () {
      final now = DateTime.now();
      final trackA = _makeTrack(id: 'track_A', title: 'Duplicate Song', artist: 'Artist');
      final trackB = _makeTrack(id: 'track_B', title: 'Other Song', artist: 'Artist');

      final entries = [
        (track: trackA, addedAt: now.subtract(const Duration(days: 10))),
        (track: trackB, addedAt: now.subtract(const Duration(days: 5))),
        (track: trackA, addedAt: now), // Re-added recently!
      ];

      final playlist = RecentlyAddedPlaylistEngine.generateFromTracks(
        entries: entries,
        config: const RecentlyAddedConfig(deduplicate: true),
      );

      expect(playlist.items.length, 2);
      expect(playlist.items.first.track.id, 'track_A');
      expect(playlist.items.first.addedAt, now);
      expect(playlist.items[1].track.id, 'track_B');
    });

    test('filters properly by Liked Songs and Album Tracks', () {
      final now = DateTime.now();
      final likedTrack = _makeTrack(id: 't1', title: 'Liked', artist: 'A', isLiked: true);
      final albumTrack = _makeTrack(id: 't2', title: 'Album Track', artist: 'B', album: 'Great Album');
      final plainTrack = _makeTrack(id: 't3', title: 'Plain', artist: 'C');

      final entries = [
        (track: likedTrack, addedAt: now),
        (track: albumTrack, addedAt: now.subtract(const Duration(minutes: 1))),
        (track: plainTrack, addedAt: now.subtract(const Duration(minutes: 2))),
      ];

      // 1. All
      final allPlaylist = RecentlyAddedPlaylistEngine.generateFromTracks(
        entries: entries,
        config: const RecentlyAddedConfig(filter: RecentlyAddedSourceFilter.all),
      );
      expect(allPlaylist.items.length, 3);

      // 2. Songs (Liked)
      final songsPlaylist = RecentlyAddedPlaylistEngine.generateFromTracks(
        entries: entries,
        config: const RecentlyAddedConfig(filter: RecentlyAddedSourceFilter.songs),
      );
      expect(songsPlaylist.items.length, 1);
      expect(songsPlaylist.items.first.track.id, 't1');

      // 3. Albums
      final albumsPlaylist = RecentlyAddedPlaylistEngine.generateFromTracks(
        entries: entries,
        config: const RecentlyAddedConfig(filter: RecentlyAddedSourceFilter.albums),
      );
      expect(albumsPlaylist.items.length, 1);
      expect(albumsPlaylist.items.first.track.id, 't2');
    });

    test('sorts oldestFirst when requested', () {
      final now = DateTime.now();
      final t1 = _makeTrack(id: 't1', title: 'Oldest', artist: 'Art');
      final t2 = _makeTrack(id: 't2', title: 'Newest', artist: 'Art');

      final entries = [
        (track: t2, addedAt: now),
        (track: t1, addedAt: now.subtract(const Duration(days: 10))),
      ];

      final playlist = RecentlyAddedPlaylistEngine.generateFromTracks(
        entries: entries,
        config: const RecentlyAddedConfig(sortOrder: RecentlyAddedSortOrder.oldestFirst),
      );

      expect(playlist.items.first.track.id, 't1');
      expect(playlist.items.last.track.id, 't2');
    });
  });

  // ==========================================================================
  // 3. Database & Real-Time Auto-Refresh Integration Tests
  // ==========================================================================
  group('Database & Auto-Refresh Integration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('generateFromDatabase queries library additions chronologically', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert 3 tracks with different createdAt timestamps
      await db.into(db.tracks).insert(
            TrackRow(
              id: 'row_1',
              sourceId: 'src_1',
              title: 'First Added',
              artist: 'Artist A',
              album: 'Album 1',
              durationMs: 180000,
              createdAt: now - 100000,
              isLiked: true,
              isUnavailable: false,
            ),
          );

      await db.into(db.tracks).insert(
            TrackRow(
              id: 'row_2',
              sourceId: 'src_2',
              title: 'Latest Added',
              artist: 'Artist B',
              album: 'Album 2',
              durationMs: 210000,
              createdAt: now,
              isLiked: false,
              isUnavailable: false,
            ),
          );

      final playlist = await RecentlyAddedPlaylistEngine.generateFromDatabase(db);
      expect(playlist.items.length, 2);
      expect(playlist.items.first.track.id, 'row_2'); // Newest first
      expect(playlist.items.first.track.title, 'Latest Added');
      expect(playlist.items[1].track.id, 'row_1');
    });

    test('watchFromDatabase auto-refreshes stream when a new song or album is saved', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Seed initial track
      await db.into(db.tracks).insert(
            TrackRow(
              id: 'initial_track',
              sourceId: 'src_initial',
              title: 'Initial Jam',
              artist: 'Initial Artist',
              album: 'Initial Album',
              durationMs: 200000,
              createdAt: now,
              isLiked: true,
              isUnavailable: false,
            ),
          );

      final stream = RecentlyAddedPlaylistEngine.watchFromDatabase(db);
      final streamQueue = <RecentlyAddedSmartPlaylist>[];
      final subscription = stream.listen(streamQueue.add);

      // Wait for initial emission
      await pumpEventQueue();
      expect(streamQueue.isNotEmpty, isTrue);
      expect(streamQueue.last.items.length, 1);
      expect(streamQueue.last.items.first.track.id, 'initial_track');

      // Now simulate a newly saved song / album insertion in the library
      final futureTime = now + 50000;
      await db.into(db.tracks).insert(
            TrackRow(
              id: 'newly_saved_album_track',
              sourceId: 'src_new',
              title: 'Freshly Saved Hit',
              artist: 'Fresh Artist',
              album: 'Fresh Album',
              durationMs: 190000,
              createdAt: futureTime,
              isLiked: true,
              isUnavailable: false,
            ),
          );

      // Let Drift trigger the reactive table stream
      await pumpEventQueue();

      // Verify auto-refresh occurred!
      expect(streamQueue.length, greaterThanOrEqualTo(2));
      final latestEmission = streamQueue.last;
      expect(latestEmission.items.length, 2);
      expect(latestEmission.items.first.track.id, 'newly_saved_album_track');
      expect(latestEmission.items.first.track.title, 'Freshly Saved Hit');

      await subscription.cancel();
    });
  });

  // ==========================================================================
  // 4. SharedPreferences Persistence Tests
  // ==========================================================================
  group('RecentlyAddedSharedPreferencesStore', () {
    test('stores and retrieves settings via mock storage', () async {
      RecentlyAddedSharedPreferencesStore.setMockInitialValues({
        kRecentlyAddedPrefMaxTracks: 75,
        kRecentlyAddedPrefFilter: 'songs',
        kRecentlyAddedPrefSortOrder: 'oldestFirst',
        kRecentlyAddedPrefDeduplicate: false,
      });

      final storage = RecentlyAddedSharedPreferencesStore();
      expect(await storage.getInt(kRecentlyAddedPrefMaxTracks), 75);
      expect(await storage.getString(kRecentlyAddedPrefFilter), 'songs');
      expect(await storage.getString(kRecentlyAddedPrefSortOrder), 'oldestFirst');
      expect(await storage.getBool(kRecentlyAddedPrefDeduplicate), isFalse);

      await storage.setInt(kRecentlyAddedPrefMaxTracks, 100);
      expect(await storage.getInt(kRecentlyAddedPrefMaxTracks), 100);

      await storage.clear();
      expect(await storage.getInt(kRecentlyAddedPrefMaxTracks), isNull);
    });

    test('RecentlyAddedConfigNotifier persists user preferences', () async {
      final storage = RecentlyAddedSharedPreferencesStore();
      final notifier = RecentlyAddedConfigNotifier(storage);

      await notifier.setMaxTracks(80);
      expect(notifier.state.maxTracks, 80);
      expect(await storage.getInt(kRecentlyAddedPrefMaxTracks), 80);

      await notifier.setFilter(RecentlyAddedSourceFilter.albums);
      expect(notifier.state.filter, RecentlyAddedSourceFilter.albums);
      expect(await storage.getString(kRecentlyAddedPrefFilter), 'albums');

      await notifier.setSortOrder(RecentlyAddedSortOrder.oldestFirst);
      expect(notifier.state.sortOrder, RecentlyAddedSortOrder.oldestFirst);
      expect(await storage.getString(kRecentlyAddedPrefSortOrder), 'oldestFirst');

      await notifier.setDeduplicate(false);
      expect(notifier.state.deduplicate, isFalse);
      expect(await storage.getBool(kRecentlyAddedPrefDeduplicate), isFalse);
    });
  });

  // ==========================================================================
  // 5. Playback Controller Tests
  // ==========================================================================
  group('RecentlyAddedPlayController', () {
    test('starts playback and sets queue when triggered', () async {
      final fakeHandler = FakeAudioHandler();
      final sampleTrack = _makeTrack(id: 't_play', title: 'Play Me', artist: 'Singer');
      final playlist = RecentlyAddedSmartPlaylist(
        generatedAt: DateTime.now(),
        items: [
          RecentlyAddedTrackItem(track: sampleTrack, addedAt: DateTime.now(), orderIndex: 1),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(fakeHandler),
          recentlyAddedPlaylistStreamProvider.overrideWith(
            (ref) => Stream.value(playlist),
          ),
          isPlayingProvider.overrideWithValue(false),
          currentTrackProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );

      // Trigger play
      final controller = container.read(recentlyAddedPlayControllerProvider);
      await controller.playOrPause();

      expect(fakeHandler.isPlaying, isTrue);
      expect(fakeHandler.playingTrack?.id, 't_play');
      expect(fakeHandler.internalQueue.length, 1);
      expect(fakeHandler.playCallCount, 1);

      container.dispose();
    });

    test('pauses when active track is currently playing', () async {
      final fakeHandler = FakeAudioHandler()..isPlaying = true;
      final sampleTrack = _makeTrack(id: 't_active', title: 'Active', artist: 'Singer');
      final playlist = RecentlyAddedSmartPlaylist(
        generatedAt: DateTime.now(),
        items: [
          RecentlyAddedTrackItem(track: sampleTrack, addedAt: DateTime.now(), orderIndex: 1),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(fakeHandler),
          recentlyAddedPlaylistStreamProvider.overrideWith(
            (ref) => Stream.value(playlist),
          ),
          isPlayingProvider.overrideWithValue(true),
          currentTrackProvider.overrideWith((ref) => Stream.value(sampleTrack)),
        ],
      );

      final controller = container.read(recentlyAddedPlayControllerProvider);
      await controller.playOrPause();

      expect(fakeHandler.pauseCallCount, 1);
      container.dispose();
    });
  });

  // ==========================================================================
  // 6. Material 3 Widget Tests
  // ==========================================================================
  group('RecentlyAddedPlaylistTile Widget Tests', () {
    testWidgets('renders tile with title, subtitle, thumbnail, and play button',
        (tester) async {
      final track1 = _makeTrack(
        id: '1',
        title: 'Song Alpha',
        artist: 'Artist A',
        duration: const Duration(minutes: 3, seconds: 40),
        coverUrl: 'https://example.com/cover1.jpg',
      );
      final track2 = _makeTrack(
        id: '2',
        title: 'Song Beta',
        artist: 'Artist B',
        duration: const Duration(minutes: 4, seconds: 20),
        coverUrl: 'https://example.com/cover2.jpg',
      );

      final playlist = RecentlyAddedSmartPlaylist(
        generatedAt: DateTime.now(),
        items: [
          RecentlyAddedTrackItem(track: track1, addedAt: DateTime.now(), orderIndex: 1),
          RecentlyAddedTrackItem(track: track2, addedAt: DateTime.now(), orderIndex: 2),
        ],
      );

      bool tileTapped = false;
      bool playTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentlyAddedPlaylistStreamProvider.overrideWith(
              (ref) => Stream.value(playlist),
            ),
            isRecentlyAddedPlayingProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: Scaffold(
              body: RecentlyAddedPlaylistTile(
                onTap: () => tileTapped = true,
                onPlayTap: () => playTapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify visual elements
      expect(find.text('Recently Added'), findsOneWidget);
      expect(find.textContaining('2 songs'), findsOneWidget);
      expect(find.byType(RecentlyAddedThumbnail), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap play button
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(playTapped, isTrue);

      // Tap tile body
      await tester.tap(find.text('Recently Added'));
      await tester.pumpAndSettle();
      expect(tileTapped, isTrue);
    });

    testWidgets('shows pause icon and wave indicator when currently playing',
        (tester) async {
      final track = _makeTrack(id: '1', title: 'Playing Song', artist: 'Singer');
      final playlist = RecentlyAddedSmartPlaylist(
        generatedAt: DateTime.now(),
        items: [
          RecentlyAddedTrackItem(track: track, addedAt: DateTime.now(), orderIndex: 1),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentlyAddedPlaylistStreamProvider.overrideWith(
              (ref) => Stream.value(playlist),
            ),
            isRecentlyAddedPlayingProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: const Scaffold(
              body: RecentlyAddedPlaylistTile(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byType(AnimatedMusicWaveIndicator), findsOneWidget);
    });
  });

  group('RecentlyAddedThumbnail & TrackTile Widgets', () {
    testWidgets('renders gradient fallback when covers list is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTokens.standardTokens],
          ),
          home: const Scaffold(
            body: RecentlyAddedThumbnail(
              covers: [],
              size: 54,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('RecentlyAddedTrackTile renders track item with order index',
        (tester) async {
      final item = RecentlyAddedTrackItem(
        track: _makeTrack(id: 't_item', title: 'Star Song', artist: 'Star Artist'),
        addedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        orderIndex: 42,
      );

      bool playTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTokens.standardTokens],
          ),
          home: Scaffold(
            body: RecentlyAddedTrackTile(
              item: item,
              onPlayTap: () => playTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Star Song'), findsOneWidget);
      expect(find.textContaining('Star Artist'), findsOneWidget);
      expect(find.textContaining('5 mins ago'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(playTapped, isTrue);
    });
  });

  group('RecentlyAddedPlaylistSheet Widget Tests', () {
    testWidgets('renders bottom sheet header and filters items by search query',
        (tester) async {
      final trackA = _makeTrack(id: 'a', title: 'Bohemian Rhapsody', artist: 'Queen');
      final trackB = _makeTrack(id: 'b', title: 'Starboy', artist: 'The Weeknd');

      final playlist = RecentlyAddedSmartPlaylist(
        generatedAt: DateTime.now(),
        items: [
          RecentlyAddedTrackItem(track: trackA, addedAt: DateTime.now(), orderIndex: 1),
          RecentlyAddedTrackItem(track: trackB, addedAt: DateTime.now(), orderIndex: 2),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentlyAddedPlaylistStreamProvider.overrideWith(
              (ref) => Stream.value(playlist),
            ),
            isRecentlyAddedPlayingProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: const Scaffold(
              body: RecentlyAddedPlaylistSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recently Added'), findsOneWidget);
      expect(find.text('Bohemian Rhapsody'), findsOneWidget);
      expect(find.text('Starboy'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(3));

      // Filter by search query "Queen"
      await tester.enterText(find.byType(TextField), 'Queen');
      await tester.pumpAndSettle();

      expect(find.text('Bohemian Rhapsody'), findsOneWidget);
      expect(find.text('Starboy'), findsNothing);
    });
  });
}
