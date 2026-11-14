import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/queue/queue_history_stack.dart';
import 'package:softify/presentation/providers/player_providers.dart';

class FakeAudioHandler extends Fake implements SoftifyAudioHandler {
  List<Track> queueTracks = [];
  int lastStartIndex = 0;
  bool setQueueCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  List<Track> get currentQueue => List.unmodifiable(queueTracks);

  @override
  int get currentIndex => lastStartIndex;

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    setQueueCalled = true;
    queueTracks = List<Track>.from(tracks);
    lastStartIndex = startIndex;
  }
}

Track makeTrack(String id, [String? title]) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title ?? 'Track $id',
    artist: 'Artist $id',
    duration: const Duration(minutes: 3),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t1 = makeTrack('1', 'First Track');
  final t2 = makeTrack('2', 'Second Track');
  final t3 = makeTrack('3', 'Third Track');
  final t4 = makeTrack('4', 'Fourth Track');

  group('QueueSnapshot', () {
    test('creates immutable snapshot with properties', () {
      final snapshot = QueueSnapshot(
        tracks: [t1, t2],
        currentIndex: 1,
        description: 'Test Snapshot',
      );

      expect(snapshot.tracks.length, 2);
      expect(snapshot.currentIndex, 1);
      expect(snapshot.description, 'Test Snapshot');
      expect(snapshot.currentTrack, t2);
      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.isNotEmpty, isTrue);

      // Verify list immutability
      expect(() => snapshot.tracks.add(t3), throwsUnsupportedError);
    });

    test('equality checks match track IDs and index', () {
      final s1 = QueueSnapshot(tracks: [t1, t2], currentIndex: 0);
      final s2 = QueueSnapshot(tracks: [t1, t2], currentIndex: 0);
      final sDiffIndex = QueueSnapshot(tracks: [t1, t2], currentIndex: 1);
      final sDiffOrder = QueueSnapshot(tracks: [t2, t1], currentIndex: 0);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(sDiffIndex)));
      expect(s1, isNot(equals(sDiffOrder)));
    });

    test('currentTrack handles boundary index safely', () {
      final sEmpty = QueueSnapshot(tracks: const [], currentIndex: 0);
      expect(sEmpty.currentTrack, isNull);

      final sNegative = QueueSnapshot(tracks: [t1], currentIndex: -1);
      expect(sNegative.currentTrack, isNull);

      final sOutOfBounds = QueueSnapshot(tracks: [t1], currentIndex: 5);
      expect(sOutOfBounds.currentTrack, isNull);
    });

    test('copyWith produces updated snapshot', () {
      final original = QueueSnapshot(tracks: [t1], currentIndex: 0, description: 'A');
      final updated = original.copyWith(
        tracks: [t1, t2],
        currentIndex: 1,
        description: 'B',
      );

      expect(updated.tracks.length, 2);
      expect(updated.currentIndex, 1);
      expect(updated.description, 'B');
    });
  });

  group('QueueHistoryNotifier Undo / Redo Logic', () {
    late QueueHistoryNotifier notifier;

    setUp(() {
      notifier = QueueHistoryNotifier(maxHistory: 25);
    });

    test('initial state has no undo or redo', () {
      expect(notifier.canUndo, isFalse);
      expect(notifier.canRedo, isFalse);
      expect(notifier.state.current, isNull);
      expect(notifier.state.currentStep, 0);
      expect(notifier.state.totalSteps, 0);
      expect(notifier.state.stepCounterLabel, '0 / 0');
    });

    test('pushSnapshot sets initial current snapshot without past', () {
      final snap1 = QueueSnapshot(tracks: [t1], currentIndex: 0, description: 'Initial');
      notifier.pushSnapshot(snap1);

      expect(notifier.canUndo, isFalse);
      expect(notifier.canRedo, isFalse);
      expect(notifier.state.current, snap1);
      expect(notifier.state.past, isEmpty);
      expect(notifier.state.currentStep, 1);
      expect(notifier.state.totalSteps, 1);
      expect(notifier.state.stepCounterLabel, 'Step 1 / 1');
    });

    test('pushing second snapshot enables undo', () {
      final snap1 = QueueSnapshot(tracks: [t1], currentIndex: 0);
      final snap2 = QueueSnapshot(tracks: [t1, t2], currentIndex: 0);

      notifier.pushSnapshot(snap1);
      notifier.pushSnapshot(snap2);

      expect(notifier.canUndo, isTrue);
      expect(notifier.canRedo, isFalse);
      expect(notifier.state.past.length, 1);
      expect(notifier.state.past.first, snap1);
      expect(notifier.state.current, snap2);
      expect(notifier.state.currentStep, 2);
      expect(notifier.state.totalSteps, 2);
      expect(notifier.state.stepCounterLabel, 'Step 2 / 2');
    });

    test('undo restores previous snapshot and enables redo', () {
      final snap1 = QueueSnapshot(tracks: [t1], currentIndex: 0, description: 'Step 1');
      final snap2 = QueueSnapshot(tracks: [t1, t2], currentIndex: 0, description: 'Step 2');

      notifier.pushSnapshot(snap1);
      notifier.pushSnapshot(snap2);

      final restored = notifier.undo();

      expect(restored, equals(snap1));
      expect(notifier.state.current, equals(snap1));
      expect(notifier.canUndo, isFalse);
      expect(notifier.canRedo, isTrue);
      expect(notifier.state.future.length, 1);
      expect(notifier.state.future.first, equals(snap2));
      expect(notifier.state.currentStep, 1);
      expect(notifier.state.totalSteps, 2);
      expect(notifier.state.stepCounterLabel, 'Step 1 / 2');
    });

    test('redo restores forward snapshot', () {
      final snap1 = QueueSnapshot(tracks: [t1], currentIndex: 0);
      final snap2 = QueueSnapshot(tracks: [t1, t2], currentIndex: 0);

      notifier.pushSnapshot(snap1);
      notifier.pushSnapshot(snap2);
      notifier.undo();

      final redone = notifier.redo();

      expect(redone, equals(snap2));
      expect(notifier.state.current, equals(snap2));
      expect(notifier.canUndo, isTrue);
      expect(notifier.canRedo, isFalse);
      expect(notifier.state.future, isEmpty);
      expect(notifier.state.past.length, 1);
      expect(notifier.state.currentStep, 2);
      expect(notifier.state.totalSteps, 2);
    });

    test('undo when cannot undo returns null', () {
      expect(notifier.undo(), isNull);
    });

    test('redo when cannot redo returns null', () {
      expect(notifier.redo(), isNull);
    });

    test('pushSnapshot after undo clears redo future branch', () {
      final snap1 = QueueSnapshot(tracks: [t1], currentIndex: 0);
      final snap2 = QueueSnapshot(tracks: [t1, t2], currentIndex: 0);
      final snap3 = QueueSnapshot(tracks: [t3], currentIndex: 0);

      notifier.pushSnapshot(snap1);
      notifier.pushSnapshot(snap2);
      notifier.undo(); // now at snap1, future has snap2

      expect(notifier.canRedo, isTrue);

      notifier.pushSnapshot(snap3); // branch

      expect(notifier.canRedo, isFalse);
      expect(notifier.state.future, isEmpty);
      expect(notifier.state.current, equals(snap3));
      expect(notifier.state.past.length, 1);
      expect(notifier.state.past.first, equals(snap1));
    });

    test('pushSnapshot ignores consecutive duplicates when ignoreDuplicates is true', () {
      final snap = QueueSnapshot(tracks: [t1, t2], currentIndex: 0);

      notifier.pushSnapshot(snap);
      notifier.pushSnapshot(snap); // duplicate
      notifier.pushSnapshot(QueueSnapshot(tracks: [t1, t2], currentIndex: 0)); // equivalent duplicate

      expect(notifier.state.past, isEmpty);
      expect(notifier.state.totalSteps, 1);
    });

    test('pushTracks helper constructs and pushes snapshots correctly', () {
      notifier.pushTracks([t1], currentIndex: 0, description: 'Added 1');
      notifier.pushTracks([t1, t2], currentIndex: 1, description: 'Added 2');

      expect(notifier.canUndo, isTrue);
      expect(notifier.state.current!.tracks.length, 2);
      expect(notifier.state.current!.currentIndex, 1);
      expect(notifier.state.current!.description, 'Added 2');
    });

    test('clearHistory and reset methods', () {
      notifier.pushTracks([t1]);
      notifier.pushTracks([t1, t2]);
      notifier.undo();

      // Clear history while keeping current
      notifier.clearHistory(keepCurrent: true);
      expect(notifier.canUndo, isFalse);
      expect(notifier.canRedo, isFalse);
      expect(notifier.state.current, isNotNull);

      // Reset
      notifier.reset();
      expect(notifier.state.current, isNull);
      expect(notifier.state.totalSteps, 0);
    });
  });

  group('QueueHistoryNotifier 25 Steps Limit', () {
    test('enforces strict 25 snapshots cap and FIFO eviction', () {
      final notifier = QueueHistoryNotifier(maxHistory: 25);

      // Push 30 distinct snapshots
      for (int i = 0; i < 30; i++) {
        final track = makeTrack('$i', 'Track $i');
        notifier.pushSnapshot(
          QueueSnapshot(
            tracks: [track],
            currentIndex: 0,
            description: 'Step $i',
          ),
        );
      }

      // Total snapshots in stack must not exceed 25
      expect(notifier.state.totalSteps, 25);
      expect(notifier.state.past.length, 24);
      expect(notifier.state.current!.description, 'Step 29');

      // The oldest 5 snapshots (Step 0 to 4) should have been evicted
      expect(notifier.state.past.first.description, 'Step 5');

      // Can undo exactly 24 times back to Step 5
      int undoCount = 0;
      while (notifier.canUndo) {
        notifier.undo();
        undoCount++;
      }

      expect(undoCount, 24);
      expect(notifier.state.current!.description, 'Step 5');
      expect(notifier.canUndo, isFalse);
      expect(notifier.canRedo, isTrue);
      expect(notifier.state.future.length, 24);
    });
  });

  group('AudioHandler Integration (undoAndApply / redoAndApply)', () {
    test('undoAndApply applies restored queue to audio handler', () async {
      final fakeHandler = FakeAudioHandler();
      final notifier = QueueHistoryNotifier();

      final snap1 = QueueSnapshot(tracks: [t1, t2], currentIndex: 0);
      final snap2 = QueueSnapshot(tracks: [t1, t2, t3], currentIndex: 2);

      notifier.pushSnapshot(snap1);
      notifier.pushSnapshot(snap2);

      final restored = await notifier.undoAndApply(fakeHandler);

      expect(restored, equals(snap1));
      expect(fakeHandler.setQueueCalled, isTrue);
      expect(fakeHandler.queueTracks.length, 2);
      expect(fakeHandler.lastStartIndex, 0);
    });

    test('redoAndApply applies restored queue to audio handler', () async {
      final fakeHandler = FakeAudioHandler();
      final notifier = QueueHistoryNotifier();

      final snap1 = QueueSnapshot(tracks: [t1], currentIndex: 0);
      final snap2 = QueueSnapshot(tracks: [t1, t2, t4], currentIndex: 1);

      notifier.pushSnapshot(snap1);
      notifier.pushSnapshot(snap2);
      notifier.undo();

      fakeHandler.setQueueCalled = false;
      final restored = await notifier.redoAndApply(fakeHandler);

      expect(restored, equals(snap2));
      expect(fakeHandler.setQueueCalled, isTrue);
      expect(fakeHandler.queueTracks.length, 3);
      expect(fakeHandler.lastStartIndex, 1);
    });
  });

  group('QueueUndoRedoBar Widget Tests', () {
    testWidgets('renders undo, redo, and step counter in initial state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QueueUndoRedoBar(),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('queue_undo_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_redo_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_history_step_counter')), findsOneWidget);
      expect(find.text('0 / 0'), findsOneWidget);

      final undoButton = tester.widget<IconButton>(find.byKey(const Key('queue_undo_button')));
      final redoButton = tester.widget<IconButton>(find.byKey(const Key('queue_redo_button')));

      // Both buttons are disabled when no history
      expect(undoButton.onPressed, isNull);
      expect(redoButton.onPressed, isNull);
    });

    testWidgets('undo and redo buttons enable and trigger callbacks', (tester) async {
      bool customUndoCalled = false;
      bool customRedoCalled = false;

      final container = ProviderContainer();
      final notifier = container.read(queueHistoryProvider.notifier);

      notifier.pushTracks([t1], currentIndex: 0, description: 'Added T1');
      notifier.pushTracks([t1, t2], currentIndex: 1, description: 'Added T2');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: QueueUndoRedoBar(
                onUndo: () => customUndoCalled = true,
                onRedo: () => customRedoCalled = true,
                showSnapshotDescription: true,
              ),
            ),
          ),
        ),
      );

      // Verify step counter reads Step 2 / 2
      expect(find.text('Step 2 / 2'), findsOneWidget);

      // Undo button enabled, redo button disabled
      final undoButton = tester.widget<IconButton>(find.byKey(const Key('queue_undo_button')));
      final redoButton = tester.widget<IconButton>(find.byKey(const Key('queue_redo_button')));
      expect(undoButton.onPressed, isNotNull);
      expect(redoButton.onPressed, isNull);

      // Tap undo
      await tester.tap(find.byKey(const Key('queue_undo_button')));
      await tester.pump();
      expect(customUndoCalled, isTrue);

      // Simulate state update from notifier undo
      notifier.undo();
      await tester.pump();

      // Step counter now Step 1 / 2
      expect(find.text('Step 1 / 2'), findsOneWidget);

      // Now redo is enabled
      final redoButtonAfter = tester.widget<IconButton>(find.byKey(const Key('queue_redo_button')));
      expect(redoButtonAfter.onPressed, isNotNull);

      // Tap redo
      await tester.tap(find.byKey(const Key('queue_redo_button')));
      await tester.pump();
      expect(customRedoCalled, isTrue);

      container.dispose();
    });

    testWidgets('compact mode renders properly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QueueUndoRedoBar(compact: true),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('queue_undo_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_redo_button')), findsOneWidget);
    });

    testWidgets('standalone QueueHistoryStepCounter widget renders label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QueueHistoryStepCounter(stepLabel: 'Step 4 / 10'),
          ),
        ),
      );

      expect(find.text('Step 4 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });
  });
}
