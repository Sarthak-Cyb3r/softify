import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/screens/app_scaffold.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/desktop_player_bar.dart';
import 'package:softify/presentation/widgets/desktop_sidebar.dart';

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';

class DummyAudioHandler extends Fake implements SoftifyAudioHandler {
  @override
  Stream<double> get volumeStream => Stream.value(1.0);

  @override
  double get volume => 1.0;

  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject<PlaybackState>.seeded(PlaybackState(playing: false));

  @override
  Stream<AudioRepeatMode> get repeatModeStream =>
      Stream.value(AudioRepeatMode.off);

  @override
  Stream<bool> get shuffleModeStream => Stream.value(false);

  @override
  double get speed => 1.0;

  @override
  Stream<double> get speedStream => Stream.value(1.0);
}

void main() {
  testWidgets('DesktopSidebar renders branding, navigation tabs, and shortcuts cleanly',
      (tester) async {
    int selectedTab = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          likedTracksStreamProvider.overrideWith((ref) => Stream.value([])),
          downloadsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DesktopSidebar(
              currentIndex: selectedTab,
              onSelectTab: (idx) => selectedTab = idx,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify Softify Linux branding
    expect(find.text('Softify'), findsOneWidget);
    expect(find.text('LINUX v2.0'), findsOneWidget);

    // Verify primary navigation items
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsNWidgets(2)); // Nav item & shortcut hint
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Podcasts'), findsNWidgets(2)); // Nav item & shortcut hint
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify quick access and shortcuts card
    expect(find.text('QUICK ACCESS'), findsOneWidget);
    expect(find.text('Liked Songs'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('SHORTCUTS'), findsOneWidget);

    // Tap on Search nav item and verify callback
    await tester.tap(find.text('Search').first);
    expect(selectedTab, 1);
  });

  testWidgets('DesktopPlayerBar renders track title, artist, scrubber and volume slider',
      (tester) async {
    const testTrack = Track(
      id: 'test-track-1',
      sourceId: 'src-1',
      title: 'Neon Nights',
      artist: 'Linux Cyber Syndicate',
      duration: Duration(minutes: 4, seconds: 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(DummyAudioHandler()),
          currentTrackProvider.overrideWith((ref) => Stream.value(testTrack)),
          positionStreamProvider.overrideWith(
              (ref) => Stream.value(const Duration(minutes: 1, seconds: 30))),
          durationStreamProvider.overrideWith(
              (ref) => Stream.value(const Duration(minutes: 4, seconds: 12))),
          volumeStreamProvider.overrideWith((ref) => Stream.value(0.85)),
          isTrackLikedProvider(testTrack.id)
              .overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            bottomNavigationBar: DesktopPlayerBar(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Verify track metadata
    expect(find.text('Neon Nights'), findsOneWidget);
    expect(find.text('Linux Cyber Syndicate'), findsOneWidget);

    // Verify playback control buttons
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lyrics_rounded), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);

    // Verify timestamp formatting
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('4:12'), findsOneWidget);
  });

  testWidgets('Space key enters space inside EditableText without toggling play/pause',
      (tester) async {
    bool toggled = false;
    final controller = TextEditingController(text: 'tum');

    await tester.pumpWidget(
      MaterialApp(
        home: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): PlayPauseIntent(),
          },
          child: Actions(
            actions: {
              PlayPauseIntent: PlayPauseAction(() {
                toggled = true;
              }),
            },
            child: Scaffold(
              body: TextField(
                controller: controller,
                autofocus: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(controller.text, 'tum');

    final action = PlayPauseAction(() => toggled = true);
    expect(action.isEnabled(const PlayPauseIntent()), isFalse,
        reason: 'PlayPauseAction must be disabled when focused inside TextField');

    // Type space into the focused TextField
    await tester.sendKeyEvent(LogicalKeyboardKey.space, character: ' ');
    await tester.pump();

    // Verify play/pause was NOT triggered!
    expect(toggled, isFalse);
  });

  testWidgets('Space key toggles play/pause when focus is outside EditableText',
      (tester) async {
    bool toggled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): PlayPauseIntent(),
          },
          child: Actions(
            actions: {
              PlayPauseIntent: PlayPauseAction(() {
                toggled = true;
              }),
            },
            child: const Scaffold(
              body: Focus(
                autofocus: true,
                child: SizedBox(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(toggled, isFalse);

    // Send space key
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    // Verify play/pause was toggled!
    expect(toggled, isTrue);
  });
}

