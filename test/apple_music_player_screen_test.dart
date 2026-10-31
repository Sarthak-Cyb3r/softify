import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/ui_style_provider.dart';
import 'package:softify/presentation/screens/full_screen_player_screen.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/animated_artwork_card.dart';

class _FakePlayerAudioHandler extends Fake implements SoftifyAudioHandler {
  double currentVol = 0.8;
  int skipCount = 0;
  bool isShuffle = false;
  AudioRepeatMode repeat = AudioRepeatMode.off;
  double playbackSpeed = 1.0;
  int currentQIndex = 0;

  @override
  Stream<double> get volumeStream => Stream.value(currentVol);

  @override
  double get volume => currentVol;

  @override
  Future<void> setVolume(double val) async {
    currentVol = val;
  }

  @override
  double get speed => playbackSpeed;

  @override
  Future<void> setSpeed(double s) async {
    playbackSpeed = s;
  }

  @override
  final BehaviorSubject<MediaItem?> mediaItem =
      BehaviorSubject<MediaItem?>.seeded(
    const MediaItem(
      id: 'test_am_track',
      title: 'Save Your Tears',
      artist: 'The Weeknd',
      album: 'After Hours',
      duration: Duration(seconds: 215),
    ),
  );

  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject<PlaybackState>.seeded(
    PlaybackState(
      playing: true,
      processingState: AudioProcessingState.ready,
    ),
  );

  @override
  Stream<AudioRepeatMode> get repeatModeStream =>
      Stream.value(repeat);

  @override
  Stream<bool> get shuffleModeStream => Stream.value(isShuffle);

  @override
  Stream<bool> get autoPlayStream => Stream.value(true);

  @override
  Stream<Duration?> get sleepTimerRemainingStream => Stream.value(null);

  @override
  Stream<bool> get sleepEndOfTrackStream => Stream.value(false);

  @override
  Track? get currentTrack => const Track(
        id: 'test_am_track',
        sourceId: 'mock_src',
        title: 'Save Your Tears',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 215),
        coverUrl: 'https://example.com/cover.jpg',
      );

  @override
  Stream<Track?> get currentTrackStream => Stream.value(currentTrack);

  @override
  List<Track> get currentQueue => [
        currentTrack!,
        const Track(
          id: 'queue_track_1',
          sourceId: 'src_1',
          title: 'In Your Eyes',
          artist: 'The Weeknd',
          album: 'After Hours',
          duration: Duration(seconds: 237),
        ),
      ];

  @override
  Stream<List<Track>> get tracksQueueStream => Stream.value(currentQueue);

  @override
  int get currentIndex => currentQIndex;

  @override
  Duration get position => const Duration(seconds: 45);

  @override
  Stream<Duration> get positionStream => Stream.value(position);

  @override
  Duration? get duration => const Duration(seconds: 215);

  @override
  Stream<Duration?> get durationStream => Stream.value(duration);

  @override
  AudioRepeatMode get repeatMode => repeat;

  @override
  bool get isShuffleEnabled => isShuffle;

  @override
  bool get isAutoPlayEnabled => true;

  @override
  bool get isSleepTimerActive => false;

  @override
  bool get isSleepTimerEndOfTrack => false;

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    isShuffle = enabled;
  }

  @override
  Future<void> setAudioRepeatMode(AudioRepeatMode mode) async {
    repeat = mode;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> playTrack(Track track, {List<Track>? queue}) async {}

  @override
  Future<void> skipToQueueItem(int index) async {
    currentQIndex = index;
  }

  @override
  Future<void> skipToNext() async {
    skipCount++;
  }

  @override
  Future<void> skipToPrevious() async {
    skipCount--;
  }

  @override
  Future<void> pause() async {
    playbackState.add(PlaybackState(playing: false));
  }

  @override
  Future<void> play() async {
    playbackState.add(PlaybackState(playing: true));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FullScreenPlayerScreen Apple Music vs. Classic Layout Tests', () {
    late AppDatabase db;
    late DriftLibraryRepository libraryRepo;
    late _FakePlayerAudioHandler fakeHandler;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      libraryRepo = DriftLibraryRepository(db);
      fakeHandler = _FakePlayerAudioHandler();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Classic mode renders single-column layout with turntable option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            libraryRepositoryProvider.overrideWithValue(libraryRepo),
            audioHandlerProvider.overrideWithValue(fakeHandler),
            likedTracksStreamProvider.overrideWith((ref) => Stream.value([])),
            downloadsStreamProvider.overrideWith((ref) => Stream.value([])),
            playHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            currentTrackProvider.overrideWith(
              (ref) => Stream.value(
                const Track(
                  id: 'test_am_track',
                  sourceId: 'mock_src',
                  title: 'Save Your Tears',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 215),
                  coverUrl: 'https://example.com/cover.jpg',
                ),
              ),
            ),
            mediaItemStreamProvider.overrideWith(
              (ref) => Stream.value(
                const MediaItem(
                  id: 'test_am_track',
                  title: 'Save Your Tears',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 215),
                ),
              ),
            ),
            queueProvider.overrideWith(
              (ref) => Stream.value([
                const Track(
                  id: 'test_am_track',
                  sourceId: 'mock_src',
                  title: 'Save Your Tears',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 215),
                  coverUrl: 'https://example.com/cover.jpg',
                ),
                const Track(
                  id: 'queue_track_1',
                  sourceId: 'src_1',
                  title: 'In Your Eyes',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 237),
                ),
              ]),
            ),
            nowPlayingStyleProvider.overrideWith((ref) {
              final n = NowPlayingStyleNotifier(db);
              n.state = NowPlayingStyle.classic;
              return n;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.themeFor(UiStyle.classic),
            home: const FullScreenPlayerScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies Classic layout top bar
      expect(find.text('PLAYING FROM'), findsOneWidget);
      expect(find.text('After Hours'), findsWidgets);

      // Verifies AnimatedArtworkCard is mounted in artwork slot
      expect(find.byType(AnimatedArtworkCard), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Apple Music mode renders dock, view swapping, and volume slider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            libraryRepositoryProvider.overrideWithValue(libraryRepo),
            audioHandlerProvider.overrideWithValue(fakeHandler),
            likedTracksStreamProvider.overrideWith((ref) => Stream.value([])),
            downloadsStreamProvider.overrideWith((ref) => Stream.value([])),
            playHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            currentTrackProvider.overrideWith(
              (ref) => Stream.value(
                const Track(
                  id: 'test_am_track',
                  sourceId: 'mock_src',
                  title: 'Save Your Tears',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 215),
                  coverUrl: 'https://example.com/cover.jpg',
                ),
              ),
            ),
            mediaItemStreamProvider.overrideWith(
              (ref) => Stream.value(
                const MediaItem(
                  id: 'test_am_track',
                  title: 'Save Your Tears',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 215),
                ),
              ),
            ),
            queueProvider.overrideWith(
              (ref) => Stream.value([
                const Track(
                  id: 'test_am_track',
                  sourceId: 'mock_src',
                  title: 'Save Your Tears',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 215),
                  coverUrl: 'https://example.com/cover.jpg',
                ),
                const Track(
                  id: 'queue_track_1',
                  sourceId: 'src_1',
                  title: 'In Your Eyes',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: Duration(seconds: 237),
                ),
              ]),
            ),
            nowPlayingStyleProvider.overrideWith((ref) {
              final n = NowPlayingStyleNotifier(db);
              n.state = NowPlayingStyle.appleMusic;
              return n;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.themeFor(UiStyle.auroraGlass),
            home: const FullScreenPlayerScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies Apple Music metadata header
      expect(find.text('Save Your Tears'), findsOneWidget);
      expect(find.text('The Weeknd'), findsWidgets);

      // Verifies Lossless audio badge
      expect(find.text('Lossless'), findsOneWidget);

      // Verifies Integrated Volume Bar is present
      expect(find.byType(Slider), findsWidgets);
      expect(find.byIcon(Icons.volume_mute_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      // Verifies Apple Music Persistent Dock buttons
      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
      expect(find.byIcon(Icons.airplay_rounded), findsOneWidget);
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);

      // 1. Test Dock: Tap Queue icon
      await tester.tap(find.byIcon(Icons.queue_music_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Verifies Up Next Queue view opened
      expect(find.text('Playing Next'), findsOneWidget);
      expect(find.text('In Your Eyes'), findsOneWidget);

      // Tap Queue button again to toggle back to Main view
      await tester.tap(find.byIcon(Icons.queue_music_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Save Your Tears'), findsOneWidget);

      // 2. Test Dock: Tap Lyrics icon
      await tester.tap(find.byIcon(Icons.format_quote_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
