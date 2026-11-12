// ============================================================================
// Softify Quality of Life (QoL) - Feature 20: Smart Playlist: Forgotten Favorites Tests
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/history_item.dart';
import 'package:softify/domain/entities/playlist.dart';
import 'package:softify/domain/entities/playlist_entry.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/features/qol/library/smart_playlist_forgotten_favorites.dart';
import 'package:softify/presentation/providers/player_providers.dart';

/// Fake repository providing liked tracks and listening history.
class FakeLibraryRepo implements ILibraryRepository {
  List<Track> likedTracks = [];
  List<HistoryItem> historyItems = [];
  final Map<String, PlaylistWithTracks> playlists = {};

  @override
  Future<List<Track>> getLikedTracks() async => likedTracks;

  @override
  Stream<List<Track>> watchLikedTracks() => Stream.value(likedTracks);

  @override
  Stream<List<HistoryItem>> watchPlayHistory({int limit = 50}) =>
      Stream.value(historyItems);

  @override
  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    bool isImported = false,
    String? sourceUrl,
  }) async {
    final playlist = Playlist(
      id: 'pl-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      trackCount: 0,
      createdAt: DateTime.now(),
    );
    playlists[playlist.id] = PlaylistWithTracks(playlist: playlist, entries: []);
    return playlist;
  }

  @override
  Future<void> addTracksToPlaylist(
    String playlistId,
    List<Track> tracks, {
    List<({String title, String artist})>? originalMetadata,
  }) async {
    final current = playlists[playlistId];
    if (current != null) {
      final entries = List<PlaylistEntry>.from(current.entries);
      for (final track in tracks) {
        entries.add(PlaylistEntry(
          playlistId: playlistId,
          position: entries.length,
          track: track,
          originalTitle: track.title,
          originalArtist: track.artist,
          matchStatus: MatchStatus.matched,
        ));
      }
      playlists[playlistId] = PlaylistWithTracks(
        playlist: current.playlist.copyWith(trackCount: entries.length),
        entries: entries,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake audio handler recording playTrack calls and controlling playback state.
class FakeAudioHandler implements SoftifyAudioHandler {
  Track? lastPlayedTrack;
  List<Track>? lastPlayedQueue;
  int? lastPlayedIndex;
  bool isPlayingState = false;

  @override
  Future<void> playTrack(Track track, {List<Track>? queue, int? startIndex}) async {
    lastPlayedTrack = track;
    lastPlayedQueue = queue;
    lastPlayedIndex = startIndex;
    isPlayingState = true;
  }

  @override
  Future<void> play() async {
    isPlayingState = true;
  }

  @override
  Future<void> pause() async {
    isPlayingState = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final refTime = DateTime(2025, 6, 1, 12, 0, 0);

  // Sample tracks
  const trackStarboy = Track(
    id: 't-starboy',
    sourceId: 'src-1',
    title: 'Starboy',
    artist: 'The Weeknd',
    album: 'Starboy',
    duration: Duration(seconds: 230),
    isLiked: true,
  );

  const trackBlindingLights = Track(
    id: 't-blinding',
    sourceId: 'src-2',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    album: 'After Hours',
    duration: Duration(seconds: 200),
    isLiked: true,
  );

  const trackSaveYourTears = Track(
    id: 't-save',
    sourceId: 'src-3',
    title: 'Save Your Tears',
    artist: 'The Weeknd',
    album: 'After Hours',
    duration: Duration(seconds: 215),
    isLiked: true,
  );

  const trackMidnightCity = Track(
    id: 't-midnight',
    sourceId: 'src-4',
    title: 'Midnight City',
    artist: 'M83',
    album: 'Hurry Up, We\'re Dreaming',
    duration: Duration(seconds: 243),
    isLiked: true,
  );

  const trackNotLiked = Track(
    id: 't-not-liked',
    sourceId: 'src-5',
    title: 'Random Song',
    artist: 'Someone',
    duration: Duration(seconds: 180),
    isLiked: false,
  );

  setUp(() {
    ForgottenFavoritesSharedPreferences.reset();
  });

  group('ForgottenFavoritesService: Dormancy & Filtering Logic', () {
    test('identifies favorited songs with zero plays in >= 60 days', () {
      // trackStarboy played 75 days ago (dormant)
      // trackBlindingLights played 10 days ago (recently played)
      // trackSaveYourTears has 0 plays in history (unplayed gem)
      final history = [
        HistoryItem(
          id: 1,
          track: trackStarboy,
          playedAt: refTime.subtract(const Duration(days: 75)),
          completedRatio: 1.0,
        ),
        HistoryItem(
          id: 2,
          track: trackBlindingLights,
          playedAt: refTime.subtract(const Duration(days: 10)),
          completedRatio: 1.0,
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackStarboy, trackBlindingLights, trackSaveYourTears],
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(thresholdDays: 60),
      );

      // Starboy (75d) and Save Your Tears (unplayed) qualify; Blinding Lights (10d) is excluded
      expect(ranked.length, 2);
      expect(ranked.any((r) => r.track.id == 't-starboy'), isTrue);
      expect(ranked.any((r) => r.track.id == 't-save'), isTrue);
      expect(ranked.any((r) => r.track.id == 't-blinding'), isFalse);
    });

    test('excludes tracks played 59 days ago and includes tracks played 60 days ago', () {
      final track59 = trackStarboy.copyWith(id: 't-59', title: '59 Days Ago');
      final track60 = trackStarboy.copyWith(id: 't-60', title: '60 Days Ago');

      final history = [
        HistoryItem(
          id: 1,
          track: track59,
          playedAt: refTime.subtract(const Duration(days: 59)),
          completedRatio: 1.0,
        ),
        HistoryItem(
          id: 2,
          track: track60,
          playedAt: refTime.subtract(const Duration(days: 60)),
          completedRatio: 1.0,
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [track59, track60],
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(thresholdDays: 60),
      );

      expect(ranked.length, 1);
      expect(ranked.first.track.id, 't-60');
      expect(ranked.first.daysSinceLastPlayed, 60);
    });

    test('excludes non-favorited tracks even if dormant for 100 days', () {
      final history = [
        HistoryItem(
          id: 1,
          track: trackNotLiked,
          playedAt: refTime.subtract(const Duration(days: 100)),
          completedRatio: 1.0,
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackNotLiked],
        history: history,
        referenceTime: refTime,
      );

      expect(ranked, isEmpty);
    });

    test('honors includeNeverPlayed config toggle', () {
      // trackSaveYourTears has zero plays
      final rankedWithUnplayed = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackSaveYourTears],
        history: const [],
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(includeNeverPlayed: true),
      );
      expect(rankedWithUnplayed.length, 1);
      expect(rankedWithUnplayed.first.tier, ForgottenTier.unplayedGem);

      final rankedWithoutUnplayed = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackSaveYourTears],
        history: const [],
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(includeNeverPlayed: false),
      );
      expect(rankedWithoutUnplayed, isEmpty);
    });

    test('ignores accidental skip plays below minCompletionRatio', () {
      // trackStarboy had a play 5 days ago, but only 0.1 completion (skipped in 10s)
      // and a real play 80 days ago (1.0 completion)
      final history = [
        HistoryItem(
          id: 1,
          track: trackStarboy,
          playedAt: refTime.subtract(const Duration(days: 80)),
          completedRatio: 1.0,
        ),
        HistoryItem(
          id: 2,
          track: trackStarboy,
          playedAt: refTime.subtract(const Duration(days: 5)),
          completedRatio: 0.1, // Below 0.3 threshold
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackStarboy],
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(
          thresholdDays: 60,
          minCompletionRatio: 0.3,
        ),
      );

      expect(ranked.length, 1);
      expect(ranked.first.daysSinceLastPlayed, 80);
      expect(ranked.first.historicalPlayCount, 1);
    });

    test('respects custom thresholdDays (e.g. 90 days)', () {
      // Starboy: 75 days ago
      // Midnight City: 120 days ago
      final history = [
        HistoryItem(
          id: 1,
          track: trackStarboy,
          playedAt: refTime.subtract(const Duration(days: 75)),
          completedRatio: 1.0,
        ),
        HistoryItem(
          id: 2,
          track: trackMidnightCity,
          playedAt: refTime.subtract(const Duration(days: 120)),
          completedRatio: 1.0,
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackStarboy, trackMidnightCity],
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(thresholdDays: 90),
      );

      expect(ranked.length, 1);
      expect(ranked.first.track.id, 't-midnight');
    });
  });

  group('ForgottenFavoritesService: Ranking & Nostalgia Scoring', () {
    test('calculates higher nostalgia score for tracks with higher past plays', () {
      // Track A: played 1 time, 100 days ago
      // Track B: played 15 times, 100 days ago
      final history = [
        HistoryItem(
          id: 1,
          track: trackStarboy,
          playedAt: refTime.subtract(const Duration(days: 100)),
          completedRatio: 1.0,
        ),
        ...List.generate(
          15,
          (i) => HistoryItem(
            id: 10 + i,
            track: trackMidnightCity,
            playedAt: refTime.subtract(Duration(days: 100 + i)),
            completedRatio: 1.0,
          ),
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackStarboy, trackMidnightCity],
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(
          rankingMode: ForgottenFavoritesRankingMode.nostalgiaScore,
        ),
      );

      expect(ranked.first.track.id, 't-midnight');
      expect(ranked.first.nostalgiaScore, greaterThan(ranked.last.nostalgiaScore));
    });

    test('ranks correctly by longestForgotten mode', () {
      final history = [
        HistoryItem(
          id: 1,
          track: trackStarboy,
          playedAt: refTime.subtract(const Duration(days: 70)),
          completedRatio: 1.0,
        ),
        HistoryItem(
          id: 2,
          track: trackMidnightCity,
          playedAt: refTime.subtract(const Duration(days: 220)),
          completedRatio: 1.0,
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackStarboy, trackMidnightCity, trackSaveYourTears],
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(
          rankingMode: ForgottenFavoritesRankingMode.longestForgotten,
        ),
      );

      expect(ranked.first.track.id, 't-midnight'); // 220 days
      expect(ranked[1].track.id, 't-starboy'); // 70 days
      expect(ranked[2].track.id, 't-save'); // never played (null) at end
    });

    test('ranks correctly by mostPlayedPast mode', () {
      final history = [
        ...List.generate(
          3,
          (i) => HistoryItem(
            id: 1 + i,
            track: trackStarboy,
            playedAt: refTime.subtract(const Duration(days: 80)),
            completedRatio: 1.0,
          ),
        ),
        ...List.generate(
          8,
          (i) => HistoryItem(
            id: 10 + i,
            track: trackMidnightCity,
            playedAt: refTime.subtract(const Duration(days: 80)),
            completedRatio: 1.0,
          ),
        ),
      ];

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: [trackStarboy, trackMidnightCity],
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(
          rankingMode: ForgottenFavoritesRankingMode.mostPlayedPast,
        ),
      );

      expect(ranked.first.track.id, 't-midnight');
      expect(ranked.first.historicalPlayCount, 8);
      expect(ranked.last.historicalPlayCount, 3);
    });

    test('classifies ForgottenTier accurately', () {
      expect(
        ForgottenTier.fromDaysAndPlays(200, 5),
        ForgottenTier.vintageGold,
      );
      expect(
        ForgottenTier.fromDaysAndPlays(120, 3),
        ForgottenTier.lostClassic,
      );
      expect(
        ForgottenTier.fromDaysAndPlays(70, 2),
        ForgottenTier.rediscovery,
      );
      expect(
        ForgottenTier.fromDaysAndPlays(null, 0),
        ForgottenTier.unplayedGem,
      );
    });

    test('enforces maxTracks limit', () {
      final manyTracks = List.generate(
        10,
        (i) => Track(
          id: 'track-$i',
          sourceId: 'src-$i',
          title: 'Track $i',
          artist: 'Artist',
          duration: const Duration(seconds: 180),
          isLiked: true,
        ),
      );

      final history = manyTracks.map((t) {
        return HistoryItem(
          id: t.hashCode,
          track: t,
          playedAt: refTime.subtract(const Duration(days: 100)),
          completedRatio: 1.0,
        );
      }).toList();

      final ranked = ForgottenFavoritesService.filterAndRankTracks(
        likedTracks: manyTracks,
        history: history,
        referenceTime: refTime,
        config: const ForgottenFavoritesConfig(maxTracks: 4),
      );

      expect(ranked.length, 4);
      expect(ranked.last.rank, 4);
    });
  });

  group('ForgottenFavoritesService: Stats & Library Export', () {
    test('computes comprehensive aggregate statistics', () {
      final history = [
        HistoryItem(
          id: 1,
          track: trackStarboy,
          playedAt: refTime.subtract(const Duration(days: 100)),
          completedRatio: 1.0,
        ),
        HistoryItem(
          id: 2,
          track: trackMidnightCity,
          playedAt: refTime.subtract(const Duration(days: 200)),
          completedRatio: 1.0,
        ),
      ];

      final playlist = ForgottenFavoritesService.generatePlaylist(
        likedTracks: [trackStarboy, trackMidnightCity, trackSaveYourTears],
        history: history,
        referenceTime: refTime,
      );

      final stats = playlist.stats;
      expect(stats.totalForgottenCount, 3);
      expect(stats.maxDaysDormant, 200);
      expect(stats.averageDaysDormant, 150.0); // (100 + 200) / 2
      expect(stats.neverPlayedCount, 1);
      expect(stats.totalDuration, trackStarboy.duration + trackMidnightCity.duration + trackSaveYourTears.duration);
      expect(stats.tierBreakdown[ForgottenTier.vintageGold], 1);
      expect(stats.tierBreakdown[ForgottenTier.lostClassic], 1);
      expect(stats.tierBreakdown[ForgottenTier.unplayedGem], 1);
    });

    test('exports smart playlist into ILibraryRepository as permanent playlist', () async {
      final fakeRepo = FakeLibraryRepo();
      final playlist = ForgottenFavoritesService.generatePlaylist(
        likedTracks: [trackStarboy, trackMidnightCity],
        history: [
          HistoryItem(
            id: 1,
            track: trackStarboy,
            playedAt: refTime.subtract(const Duration(days: 80)),
            completedRatio: 1.0,
          ),
        ],
        referenceTime: refTime,
      );

      final created = await ForgottenFavoritesService.exportToLibrary(
        repo: fakeRepo,
        playlist: playlist,
        customName: 'My 2025 Nostalgia',
      );

      expect(created.name, 'My 2025 Nostalgia');
      final saved = fakeRepo.playlists[created.id];
      expect(saved, isNotNull);
      expect(saved!.entries.length, playlist.tracks.length);
      expect(saved.entries.first.track?.id, playlist.tracks.first.id);
    });
  });

  group('ForgottenFavoritesSharedPreferences Persistence', () {
    test('stores and retrieves configuration values with mock backing', () async {
      ForgottenFavoritesSharedPreferences.setMockInitialValues({
        kForgottenFavPrefThresholdDays: 90,
        kForgottenFavPrefMaxTracks: 75,
        kForgottenFavPrefRankingMode: 'mostPlayedPast',
        kForgottenFavPrefIncludeNeverPlayed: false,
      });

      final prefs = ForgottenFavoritesSharedPreferences();
      expect(await prefs.getInt(kForgottenFavPrefThresholdDays), 90);
      expect(await prefs.getInt(kForgottenFavPrefMaxTracks), 75);
      expect(await prefs.getString(kForgottenFavPrefRankingMode), 'mostPlayedPast');
      expect(await prefs.getBool(kForgottenFavPrefIncludeNeverPlayed), isFalse);

      await prefs.setInt(kForgottenFavPrefThresholdDays, 180);
      expect(await prefs.getInt(kForgottenFavPrefThresholdDays), 180);
    });
  });

  group('Riverpod State Management & Quick Play', () {
    test('ForgottenFavoritesConfigNotifier syncs changes to storage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(forgottenFavoritesConfigProvider.notifier);
      await notifier.setThresholdDays(90);
      await notifier.setRankingMode(ForgottenFavoritesRankingMode.longestForgotten);

      final config = container.read(forgottenFavoritesConfigProvider);
      expect(config.thresholdDays, 90);
      expect(config.rankingMode, ForgottenFavoritesRankingMode.longestForgotten);
    });

    test('ForgottenFavoritesQuickPlayController starts playback on SoftifyAudioHandler', () async {
      final fakeRepo = FakeLibraryRepo()
        ..likedTracks = [trackStarboy]
        ..historyItems = [
          HistoryItem(
            id: 1,
            track: trackStarboy,
            playedAt: refTime.subtract(const Duration(days: 90)),
            completedRatio: 1.0,
          ),
        ];

      final fakeAudioHandler = FakeAudioHandler();

      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
          audioHandlerProvider.overrideWithValue(fakeAudioHandler),
          isPlayingProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final quickPlayCtrl = container.read(forgottenFavoritesQuickPlayProvider);
      await quickPlayCtrl.quickPlay();

      expect(fakeAudioHandler.isPlayingState, isTrue);
      expect(fakeAudioHandler.lastPlayedTrack?.id, 't-starboy');
      expect(fakeAudioHandler.lastPlayedQueue?.length, 1);
    });

    test('isForgottenFavoritesActiveProvider correctly identifies current playing track', () async {
      final fakeRepo = FakeLibraryRepo()
        ..likedTracks = [trackStarboy]
        ..historyItems = [
          HistoryItem(
            id: 1,
            track: trackStarboy,
            playedAt: refTime.subtract(const Duration(days: 90)),
            completedRatio: 1.0,
          ),
        ];

      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
          currentTrackProvider.overrideWith((ref) => Stream.value(trackStarboy)),
        ],
      );
      addTearDown(container.dispose);

      // Await playlist generation
      await container.read(forgottenFavoritesPlaylistProvider.future);

      final isActive = container.read(isForgottenFavoritesActiveProvider);
      expect(isActive, isTrue);
    });
  });

  group('ForgottenFavoritesCard Widget Tests', () {
    testWidgets('renders title, track count, dormancy, and quick play button', (tester) async {
      final fakeRepo = FakeLibraryRepo()
        ..likedTracks = [trackStarboy, trackMidnightCity]
        ..historyItems = [
          HistoryItem(
            id: 1,
            track: trackStarboy,
            playedAt: DateTime.now().subtract(const Duration(days: 95)),
            completedRatio: 1.0,
          ),
          HistoryItem(
            id: 2,
            track: trackMidnightCity,
            playedAt: DateTime.now().subtract(const Duration(days: 110)),
            completedRatio: 1.0,
          ),
        ];

      final fakeAudioHandler = FakeAudioHandler();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
            audioHandlerProvider.overrideWithValue(fakeAudioHandler),
            isPlayingProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ForgottenFavoritesCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Forgotten Favorites'), findsOneWidget);
      expect(find.text('SMART PLAYLIST'), findsOneWidget);
      expect(find.text('2 Tracks'), findsOneWidget);
      expect(find.byKey(const Key('forgotten_favorites_quick_play_button')), findsOneWidget);

      // Verify Quick Play tap triggers playback
      await tester.tap(find.byKey(const Key('forgotten_favorites_quick_play_button')));
      await tester.pumpAndSettle();

      expect(fakeAudioHandler.isPlayingState, isTrue);
      expect(fakeAudioHandler.lastPlayedTrack, isNotNull);
    });

    testWidgets('displays empty state when zero tracks qualify', (tester) async {
      final fakeRepo = FakeLibraryRepo()
        ..likedTracks = [trackStarboy]
        ..historyItems = [
          HistoryItem(
            id: 1,
            track: trackStarboy,
            playedAt: DateTime.now().subtract(const Duration(days: 5)), // Played 5d ago
            completedRatio: 1.0,
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
            audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
            isPlayingProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ForgottenFavoritesCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('All Caught Up!'), findsOneWidget);
    });

    testWidgets('tapping card opens ForgottenFavoritesDetailSheet modal', (tester) async {
      final fakeRepo = FakeLibraryRepo()
        ..likedTracks = [trackStarboy]
        ..historyItems = [
          HistoryItem(
            id: 1,
            track: trackStarboy,
            playedAt: DateTime.now().subtract(const Duration(days: 85)),
            completedRatio: 1.0,
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
            audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
            isPlayingProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ForgottenFavoritesCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on card
      await tester.tap(find.byType(ForgottenFavoritesCard));
      await tester.pumpAndSettle();

      // Detail sheet should now be visible
      expect(find.byType(ForgottenFavoritesDetailSheet), findsOneWidget);
      expect(find.text('Play All'), findsOneWidget);
      expect(find.text('60+ Days'), findsOneWidget);
    });
  });
}
