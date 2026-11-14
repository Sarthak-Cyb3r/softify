import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/widgets/sleep_timer_bottom_sheet.dart';
import 'package:softify/presentation/widgets/track_options_bottom_sheet.dart';

import 'sleep_timer_test.dart';
import 'package:drift/native.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftLibraryRepository libraryRepo;
  late FakeSoftifyAudioPlayer fakePlayer;
  late MockStreamResolver mockResolver;
  late MockDownloadRepository mockDownloads;
  late SoftifyAudioHandler handler;

  const sampleTrack = Track(
    id: 'track_test',
    sourceId: 'src_test',
    title: 'Test Song',
    artist: 'Test Artist',
    duration: Duration(minutes: 3),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    libraryRepo = DriftLibraryRepository(db);
    fakePlayer = FakeSoftifyAudioPlayer();
    mockResolver = MockStreamResolver();
    mockDownloads = MockDownloadRepository();

    handler = SoftifyAudioHandler(
      player: fakePlayer,
      streamResolver: mockResolver,
      libraryRepo: libraryRepo,
      downloadRepo: mockDownloads,
      enableAudioSession: false,
      autoRestoreState: false,
    );
  });

  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        libraryRepositoryProvider.overrideWithValue(libraryRepo),
        downloadRepositoryProvider.overrideWithValue(mockDownloads),
        isTrackLikedProvider(sampleTrack.id).overrideWith((ref) => Stream.value(false)),
        isTrackDownloadedProvider(sampleTrack.id).overrideWith((ref) => Stream.value(false)),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('TrackOptionsBottomSheet renders Sleep timer option', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const TrackOptionsBottomSheet(track: sampleTrack),
      ),
    );
    await tester.pump();

    expect(find.text('Sleep timer'), findsOneWidget);
    expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('SleepTimerBottomSheet renders presets and triggers timer selection', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => SleepTimerBottomSheet.show(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep timer'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);
    expect(find.text('15 minutes'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
    expect(find.text('End of this song'), findsOneWidget);
    expect(find.text('Custom duration...'), findsOneWidget);

    // Tap 15 minutes preset
    await tester.tap(find.text('15 minutes'));
    // Pump animation of bottom sheet dismissal
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify timer was set in handler
    expect(handler.isSleepTimerActive, isTrue);
    expect(handler.sleepTimerRemaining!.inMinutes, 15);

    // Disarm timer and flush snackbar so fake_async has no pending timers
    handler.cancelSleepTimer();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('SleepTimerBottomSheet shows active banner and allows turning off timer', (tester) async {
    handler.setSleepTimer(const Duration(minutes: 25));

    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => SleepTimerBottomSheet.show(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    // pump sheet open without pumpAndSettle due to active periodic ticker
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Active:'), findsOneWidget);
    expect(find.text('Turn off'), findsOneWidget);

    // Tap turn off
    await tester.tap(find.text('Turn off'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(handler.isSleepTimerActive, isFalse);
    expect(handler.sleepTimerRemaining, isNull);

    // Flush snackbar
    await tester.pump(const Duration(seconds: 4));
  });
}
