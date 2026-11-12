import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/queue/queue_duration_counter.dart';
import 'package:softify/presentation/providers/player_providers.dart';

// ============================================================================
// Test Doubles
// ============================================================================

class FakeAudioHandler extends Fake implements SoftifyAudioHandler {
  List<Track> trackQueue = [];
  int index = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  List<Track> get currentQueue => List.unmodifiable(trackQueue);

  @override
  int get currentIndex => index;

  @override
  Stream<List<Track>> get tracksQueueStream => Stream.value(trackQueue);
}

Track _makeTrack(String id, String title, Duration duration) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title,
    artist: 'Test Artist',
    album: 'Test Album',
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    QueueDurationPrefsStorage.reset();
  });

  tearDown(() {
    QueueDurationPrefsStorage.reset();
  });

  // ==========================================================================
  // 1. Calculator Unit Tests
  // ==========================================================================
  group('QueueDurationCalculator', () {
    final trackA = _makeTrack('a', 'Song A', const Duration(minutes: 3));
    final trackB = _makeTrack('b', 'Song B', const Duration(minutes: 4));
    final trackC = _makeTrack('c', 'Song C', const Duration(minutes: 5));
    final trackD = _makeTrack('d', 'Song D', const Duration(minutes: 2));
    final sampleQueue = [trackA, trackB, trackC, trackD]; // Total: 14 min

    test('empty queue returns zero duration and zero remaining tracks', () {
      final summary = QueueDurationCalculator.computeSummary(
        queue: const [],
        currentIndex: 0,
      );

      expect(summary.remainingDuration, Duration.zero);
      expect(summary.remainingTrackCount, 0);
      expect(summary.totalDuration, Duration.zero);
      expect(summary.totalTrackCount, 0);
      expect(summary.isEmpty, isTrue);
      expect(summary.isNotEmpty, isFalse);
      expect(summary.hasRemaining, isFalse);
    });

    test('unstarted queue (currentIndex = -1) treats all tracks as remaining', () {
      final summary = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: -1,
      );

      expect(summary.remainingDuration, const Duration(minutes: 14));
      expect(summary.remainingTrackCount, 4);
      expect(summary.totalDuration, const Duration(minutes: 14));
      expect(summary.totalTrackCount, 4);
      expect(summary.completedTrackCount, 0);
      expect(summary.completedDuration, Duration.zero);
      expect(summary.progressFraction, 0.0);
    });

    test('currentIndex = 0 with zero position includes entire queue', () {
      final summary = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 0,
        currentPosition: Duration.zero,
        includeCurrentTrack: true,
      );

      expect(summary.remainingDuration, const Duration(minutes: 14));
      expect(summary.remainingTrackCount, 4);
      expect(summary.completedDuration, Duration.zero);
      expect(summary.completedTrackCount, 0);
      expect(summary.progressFraction, 0.0);
    });

    test('currentIndex = 0 with 1 min position deducts played portion of current track', () {
      final summary = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 0,
        currentPosition: const Duration(minutes: 1),
        includeCurrentTrack: true,
      );

      // Current track has (3 - 1) = 2 min remaining, plus upcoming 11 min = 13 min total
      expect(summary.remainingDuration, const Duration(minutes: 13));
      expect(summary.remainingTrackCount, 4);
      expect(summary.completedDuration, const Duration(minutes: 1));
      expect(summary.progressFraction, closeTo(1 / 14, 0.001));
    });

    test('includeCurrentTrack = false counts only strictly upcoming tracks', () {
      final summary = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 0,
        currentPosition: Duration.zero,
        includeCurrentTrack: false,
      );

      // Only tracks B (4m), C (5m), D (2m) = 11m
      expect(summary.remainingDuration, const Duration(minutes: 11));
      expect(summary.remainingTrackCount, 3);
    });

    test('currentIndex in middle (index 2: track C) calculates upcoming correctly', () {
      // Index 2 is track C (5m), position 2m. Track D is 2m.
      // Remaining: (5 - 2) + 2 = 5 min. Remaining tracks: 2 (C and D).
      final summary = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 2,
        currentPosition: const Duration(minutes: 2),
        includeCurrentTrack: true,
      );

      expect(summary.remainingDuration, const Duration(minutes: 5));
      expect(summary.remainingTrackCount, 2);
      expect(summary.completedDuration, const Duration(minutes: 9));
      expect(summary.completedTrackCount, 2);
    });

    test('currentIndex at last track (index 3: track D)', () {
      final summaryWithCurrent = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 3,
        currentPosition: const Duration(minutes: 1),
        includeCurrentTrack: true,
      );

      // Track D is 2m, 1m played => 1m remaining, 1 track
      expect(summaryWithCurrent.remainingDuration, const Duration(minutes: 1));
      expect(summaryWithCurrent.remainingTrackCount, 1);

      final summaryWithoutCurrent = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 3,
        currentPosition: const Duration(minutes: 1),
        includeCurrentTrack: false,
      );

      // No upcoming tracks left
      expect(summaryWithoutCurrent.remainingDuration, Duration.zero);
      expect(summaryWithoutCurrent.remainingTrackCount, 0);
    });

    test('currentIndex past queue bounds returns zero duration', () {
      final summary = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 10,
        includeCurrentTrack: true,
      );

      expect(summary.remainingDuration, Duration.zero);
      expect(summary.remainingTrackCount, 0);
    });

    test('position exceeding track duration clamps cleanly to zero remaining on current', () {
      final summary = QueueDurationCalculator.computeSummary(
        queue: [trackA], // 3 min
        currentIndex: 0,
        currentPosition: const Duration(minutes: 5), // Exceeds 3 min
      );

      expect(summary.remainingDuration, Duration.zero);
      expect(summary.remainingTrackCount, 1);
    });

    test('tracks with negative or zero durations are handled safely without exceptions', () {
      final zeroTrack = _makeTrack('z', 'Zero', Duration.zero);
      final negTrack = _makeTrack('n', 'Neg', const Duration(seconds: -30));
      final normal = _makeTrack('norm', 'Normal', const Duration(minutes: 2));

      final summary = QueueDurationCalculator.computeSummary(
        queue: [zeroTrack, negTrack, normal],
        currentIndex: 0,
      );

      expect(summary.remainingDuration, const Duration(minutes: 2));
      expect(summary.totalDuration, const Duration(minutes: 2));
      expect(summary.remainingTrackCount, 3);
    });

    test('estimatedEndTime adds remaining duration to given timestamp', () {
      final base = DateTime(2026, 11, 12, 10, 0, 0);
      final summary = QueueDurationCalculator.computeSummary(
        queue: [trackA], // 3 min
        currentIndex: 0,
      );

      final end = summary.estimatedEndTime(fromTime: base);
      expect(end, DateTime(2026, 11, 12, 10, 3, 0));
    });

    test('QueueDurationSummary value equality, copyWith and toString', () {
      final summary1 = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 1,
      );
      final summary2 = QueueDurationCalculator.computeSummary(
        queue: sampleQueue,
        currentIndex: 1,
      );

      expect(summary1, equals(summary2));
      expect(summary1.hashCode, equals(summary2.hashCode));

      final modified = summary1.copyWith(currentIndex: 2);
      expect(modified.currentIndex, 2);
      expect(summary1.toString(), contains('QueueDurationSummary'));
    });
  });

  // ==========================================================================
  // 2. Formatter Unit Tests
  // ==========================================================================
  group('QueueDurationFormatter', () {
    test('exact prompt requirement: "1 hr 14 min remaining · 18 tracks"', () {
      final formatted = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(hours: 1, minutes: 14),
        trackCount: 18,
      );

      expect(formatted, equals('1 hr 14 min remaining · 18 tracks'));
    });

    test('hours and minutes formatted correctly', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(hours: 2, minutes: 45),
        trackCount: 30,
      );
      expect(result, equals('2 hr 45 min remaining · 30 tracks'));
    });

    test('plural hours option supported when requested', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(hours: 2, minutes: 45),
        trackCount: 30,
        pluralHours: true,
      );
      expect(result, equals('2 hrs 45 min remaining · 30 tracks'));
    });

    test('exact hours with 0 minutes formatted cleanly', () {
      final result1 = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(hours: 1),
        trackCount: 10,
      );
      expect(result1, equals('1 hr remaining · 10 tracks'));

      final result2 = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(hours: 3),
        trackCount: 25,
      );
      expect(result2, equals('3 hr remaining · 25 tracks'));
    });

    test('minutes only (< 1 hour) formatted without hours prefix', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(minutes: 45),
        trackCount: 12,
      );
      expect(result, equals('45 min remaining · 12 tracks'));
    });

    test('singular track label used when trackCount is 1', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(minutes: 3, seconds: 20),
        trackCount: 1,
      );
      expect(result, equals('3 min remaining · 1 track'));
    });

    test('sub-minute durations display "< 1 min" by default', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(seconds: 45),
        trackCount: 1,
      );
      expect(result, equals('< 1 min remaining · 1 track'));
    });

    test('sub-minute durations display seconds when allowSeconds is true', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(seconds: 45),
        trackCount: 1,
        allowSeconds: true,
      );
      expect(result, equals('45 sec remaining · 1 track'));
    });

    test('zero duration and zero tracks format cleanly', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: Duration.zero,
        trackCount: 0,
      );
      expect(result, equals('0 min remaining · 0 tracks'));
    });

    test('omits "remaining" word when includeRemainingWord is false', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(hours: 1, minutes: 14),
        trackCount: 18,
        includeRemainingWord: false,
      );
      expect(result, equals('1 hr 14 min · 18 tracks'));
    });

    test('omits track count when showTrackCount is false', () {
      final result = QueueDurationFormatter.formatHumanizedRemaining(
        remainingDuration: const Duration(hours: 1, minutes: 14),
        trackCount: 18,
        showTrackCount: false,
      );
      expect(result, equals('1 hr 14 min remaining'));
    });

    test('compact formatting produces compact tokens', () {
      const summary = QueueDurationSummary(
        remainingDuration: Duration(hours: 1, minutes: 14),
        remainingTrackCount: 18,
        totalDuration: Duration(hours: 2),
        totalTrackCount: 25,
        currentIndex: 7,
      );

      final compact = QueueDurationFormatter.formatCompact(summary);
      expect(compact, equals('1h 14m · 18 tracks'));
    });

    test('formatTimeOfDay formats 12-hour AM/PM and 24-hour accurately', () {
      final afternoon = DateTime(2026, 11, 12, 16, 32);
      expect(QueueDurationFormatter.formatTimeOfDay(afternoon), equals('4:32 PM'));
      expect(
        QueueDurationFormatter.formatTimeOfDay(afternoon, use24Hour: true),
        equals('16:32'),
      );

      final morning = DateTime(2026, 11, 12, 9, 5);
      expect(QueueDurationFormatter.formatTimeOfDay(morning), equals('9:05 AM'));
    });

    test('formatDigital formats MM:SS and HH:MM:SS correctly', () {
      expect(
        QueueDurationFormatter.formatDigital(const Duration(minutes: 3, seconds: 45)),
        equals('3:45'),
      );
      expect(
        QueueDurationFormatter.formatDigital(
            const Duration(hours: 1, minutes: 14, seconds: 5)),
        equals('1:14:05'),
      );
    });
  });

  // ==========================================================================
  // 3. SharedPreferences & Riverpod Provider Tests
  // ==========================================================================
  group('QueueDurationPrefsStorage & Providers', () {
    test('loads mock values and toggles includeCurrent preference', () async {
      QueueDurationPrefsStorage.setMockInitialValues({
        kQueueDurationIncludeCurrentPrefKey: false,
      });

      final storage = QueueDurationPrefsStorage();
      final initial = await storage.getBool(kQueueDurationIncludeCurrentPrefKey);
      expect(initial, isFalse);

      await storage.setBool(kQueueDurationIncludeCurrentPrefKey, true);
      final updated = await storage.getBool(kQueueDurationIncludeCurrentPrefKey);
      expect(updated, isTrue);
    });

    test('queueDurationSummaryProvider computes metrics from state', () {
      final fakeHandler = FakeAudioHandler();
      final tracks = [
        _makeTrack('t1', 'Track 1', const Duration(hours: 1)),
        _makeTrack('t2', 'Track 2', const Duration(minutes: 14)),
      ];
      fakeHandler.trackQueue = tracks;
      fakeHandler.index = 0;

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(fakeHandler),
          queueProvider.overrideWith((ref) => Stream.value(tracks)),
          positionStreamProvider.overrideWith((ref) => Stream.value(Duration.zero)),
          queueDurationIncludeCurrentTrackProvider
              .overrideWith((ref) => QueueDurationIncludeCurrentNotifier(initialValue: true)),
        ],
      );
      addTearDown(container.dispose);

      final summary = container.read(queueDurationSummaryProvider);
      expect(summary.totalTrackCount, 2);
      expect(summary.remainingTrackCount, 2);
      expect(summary.remainingDuration, const Duration(hours: 1, minutes: 14));

      final formatted = container.read(queueRemainingDurationFormattedProvider);
      expect(formatted, equals('1 hr 14 min remaining · 2 tracks'));
    });
  });

  // ==========================================================================
  // 4. Widget Tests: QueueRemainingDurationChip
  // ==========================================================================
  group('QueueRemainingDurationChip Widget', () {
    testWidgets('renders humanized text "1 hr 14 min remaining · 18 tracks"',
        (tester) async {
      const summary = QueueDurationSummary(
        remainingDuration: Duration(hours: 1, minutes: 14),
        remainingTrackCount: 18,
        totalDuration: Duration(hours: 2, minutes: 30),
        totalTrackCount: 30,
        currentIndex: 12,
        currentPosition: Duration.zero,
        includeCurrentTrack: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: QueueRemainingDurationChip(summary: summary),
            ),
          ),
        ),
      );

      expect(
        find.text('1 hr 14 min remaining · 18 tracks'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('respects compact mode and hides icon when requested',
        (tester) async {
      const summary = QueueDurationSummary(
        remainingDuration: Duration(hours: 1, minutes: 14),
        remainingTrackCount: 18,
        totalDuration: Duration(hours: 2),
        totalTrackCount: 25,
        currentIndex: 7,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: QueueRemainingDurationChip(
                summary: summary,
                compact: true,
                showIcon: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('1h 14m · 18 tracks'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('invokes custom onTap callback when tapped', (tester) async {
      bool tapped = false;
      const summary = QueueDurationSummary(
        remainingDuration: Duration(minutes: 10),
        remainingTrackCount: 3,
        totalDuration: Duration(minutes: 15),
        totalTrackCount: 5,
        currentIndex: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QueueRemainingDurationChip(
                summary: summary,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(QueueRemainingDurationChip));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('opens detail modal when tapped without custom onTap',
        (tester) async {
      const summary = QueueDurationSummary(
        remainingDuration: Duration(hours: 1, minutes: 14),
        remainingTrackCount: 18,
        totalDuration: Duration(hours: 2, minutes: 30),
        totalTrackCount: 30,
        currentIndex: 12,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: QueueRemainingDurationChip(summary: summary),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(QueueRemainingDurationChip));
      await tester.pumpAndSettle();

      expect(find.byType(QueueDurationDetailModal), findsOneWidget);
      expect(find.text('Queue Duration Statistics'), findsOneWidget);
      expect(find.text('Include currently playing song'), findsOneWidget);
    });

    testWidgets('applies custom background and text colors correctly',
        (tester) async {
      const summary = QueueDurationSummary(
        remainingDuration: Duration(minutes: 20),
        remainingTrackCount: 5,
        totalDuration: Duration(minutes: 30),
        totalTrackCount: 8,
        currentIndex: 3,
      );

      const customBg = Color(0xFF1E293B);
      const customFg = Color(0xFF38BDF8);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: QueueRemainingDurationChip(
                summary: summary,
                backgroundColor: customBg,
                foregroundColor: customFg,
              ),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('20 min remaining · 5 tracks'));
      expect(textWidget.style?.color, equals(customFg));
    });
  });
}
