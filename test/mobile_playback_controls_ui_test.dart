import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/screens/full_screen_player_screen.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/mini_player.dart';
import 'package:softify/presentation/widgets/play_pause_morph_button.dart';

class FakeAudioHandlerForUi extends Fake implements SoftifyAudioHandler {
  @override
  final BehaviorSubject<PlaybackState> playbackState;

  @override
  Track? currentTrack;

  @override
  AudioRepeatMode repeatMode = AudioRepeatMode.off;

  @override
  bool isShuffleEnabled = false;

  @override
  double speed = 1.0;

  @override
  double volume = 1.0;

  @override
  Stream<double> get volumeStream => Stream.value(1.0);

  @override
  Stream<double> get speedStream => Stream.value(1.0);

  @override
  Stream<AudioRepeatMode> get repeatModeStream => Stream.value(AudioRepeatMode.off);

  @override
  Stream<bool> get shuffleModeStream => Stream.value(false);

  @override
  Stream<Duration?> get durationStream => Stream.value(const Duration(minutes: 3));

  @override
  Stream<Duration?> get sleepTimerRemainingStream => Stream.value(null);

  @override
  Stream<bool> get sleepEndOfTrackStream => Stream.value(false);

  @override
  Stream<Track?> get currentTrackStream => Stream.value(null);

  @override
  Stream<bool> get autoPlayStream => Stream.value(true);

  FakeAudioHandlerForUi({
    PlaybackState? initialPlaybackState,
    this.currentTrack,
  }) : playbackState = BehaviorSubject<PlaybackState>.seeded(
          initialPlaybackState ?? PlaybackState(playing: false, processingState: AudioProcessingState.idle),
        );

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> seek(Duration position) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Playback Controls & Loading Screen Visibility', () {
    testWidgets('PlayPauseMorphButton displays CircularProgressIndicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: PlayPauseMorphButton(
                isPlaying: false,
                isLoading: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('PlayPauseMorphButton displays AnimatedIcon when isLoading is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: PlayPauseMorphButton(
                isPlaying: false,
                isLoading: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedIcon), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('MiniPlayer is visible during stream loading/buffering even when queue is empty', (tester) async {
      final fakeHandler = FakeAudioHandlerForUi(
        initialPlaybackState: PlaybackState(
          processingState: AudioProcessingState.buffering,
          playing: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
            currentTrackProvider.overrideWith((ref) => Stream.value(null)),
            playbackStateStreamProvider.overrideWith((ref) => fakeHandler.playbackState.stream),
            playHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            queueProvider.overrideWith((ref) => Stream.value([])),
            positionStreamProvider.overrideWith((ref) => Stream.value(Duration.zero)),
            durationStreamProvider.overrideWith((ref) => Stream.value(const Duration(minutes: 3))),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Center(child: Text('Main Content')),
              bottomNavigationBar: MiniPlayer(),
            ),
          ),
        ),
      );

      await tester.pump();

      // MiniPlayer MUST be visible and render loading state rather than SizedBox.shrink()
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.text('Loading audio...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('FullScreenPlayerScreen renders controls widget and placeholder in loading state', (tester) async {
      final fakeHandler = FakeAudioHandlerForUi(
        initialPlaybackState: PlaybackState(
          processingState: AudioProcessingState.buffering,
          playing: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
            currentTrackProvider.overrideWith((ref) => Stream.value(null)),
            playbackStateStreamProvider.overrideWith((ref) => fakeHandler.playbackState.stream),
            playHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            queueProvider.overrideWith((ref) => Stream.value([])),
            positionStreamProvider.overrideWith((ref) => Stream.value(Duration.zero)),
            durationStreamProvider.overrideWith((ref) => Stream.value(const Duration(minutes: 3))),
            repeatModeStreamProvider.overrideWith((ref) => Stream.value(AudioRepeatMode.off)),
            shuffleModeStreamProvider.overrideWith((ref) => Stream.value(false)),
            playbackSpeedStreamProvider.overrideWith((ref) => Stream.value(1.0)),
            isTrackDownloadedProvider.overrideWith((ref, arg) => Stream.value(false)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FullScreenPlayerScreen(),
          ),
        ),
      );

      await tester.pump();

      // Controls must be visible and NOT collapsed into an empty text screen
      expect(find.byType(PlayPauseMorphButton), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.text('Loading audio...'), findsOneWidget);
      expect(find.text('Nothing playing'), findsNothing);
    });
  });
}
