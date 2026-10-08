import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';
import 'package:softify/features/youtube/presentation/youtube_controller.dart';
import 'package:softify/features/youtube/presentation/youtube_page.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_theme.dart';

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
  void setTrackSource(String source) {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        audioHandlerProvider.overrideWithValue(DummyAudioHandler()),
        youtubeRecentHistoryProvider
            .overrideWith((ref) => Stream.value(<YoutubeHistoryRow>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const YoutubePage(),
      ),
    );
  }

  testWidgets('YoutubePage renders AppBar, input, buttons and empty state',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Check AppBar title
    expect(find.text('YouTube'), findsOneWidget);

    // Check Input field
    expect(
      find.byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.hintText?.contains('Paste YouTube link') == true),
      findsOneWidget,
    );

    // Check Play Audio button
    expect(find.text('Play Audio'), findsOneWidget);

    // Check Empty State message
    expect(
      find.text('Paste any YouTube link to listen audio-only.'),
      findsOneWidget,
    );

    // Check Recent Links header
    expect(find.text('Recent Links'), findsOneWidget);
  });

  testWidgets('Submitting invalid link shows user-friendly error card',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'https://notyoutube.com');
    await tester.tap(find.text('Play Audio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Playback Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    // Tap Dismiss
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Playback Error'), findsNothing);
  });
}
