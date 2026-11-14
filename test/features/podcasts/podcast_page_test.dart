import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';
import 'package:softify/features/podcasts/presentation/podcast_controller.dart';
import 'package:softify/features/podcasts/presentation/podcast_page.dart';
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
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  double get speed => 1.0;

  @override
  Stream<double> get speedStream => Stream.value(1.0);

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
        podcastRecentHistoryProvider
            .overrideWith((ref) => Stream.value(<PodcastHistoryRow>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const PodcastPage(),
      ),
    );
  }

  testWidgets('PodcastPage renders AppBar, input, buttons and empty history state',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Check AppBar title
    expect(find.text('Podcasts'), findsOneWidget);

    // Check Input field
    expect(
      find.byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.hintText?.contains('Paste Spotify episode') == true),
      findsOneWidget,
    );

    // Check Load & Play button
    expect(find.text('Load & Play'), findsOneWidget);

    // Check Empty State message
    expect(
      find.text('No podcast episodes played yet'),
      findsOneWidget,
    );

    // Check Recently Played header
    expect(find.text('RECENTLY PLAYED'), findsOneWidget);
  });

  testWidgets('Submitting invalid link shows user-friendly error card with retry',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'https://notapodcastlink.com');
    await tester.tap(find.text('Load & Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Retry'), findsOneWidget);
  });
}
