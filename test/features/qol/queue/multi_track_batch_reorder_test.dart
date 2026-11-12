import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/queue/multi_track_batch_reorder.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_tokens.dart';

// ============================================================================
// Test Doubles & Helpers
// ============================================================================

class FakeAudioHandler extends Fake implements SoftifyAudioHandler {
  List<Track> queueTracks = [];
  int currentIdx = 0;
  List<int> removedIndices = [];
  List<(int, int)> reorderCalls = [];
  bool setQueueCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  List<Track> get currentQueue => List.unmodifiable(queueTracks);

  @override
  int get currentIndex => currentIdx;

  @override
  Future<void> removeQueueItemAt(int index) async {
    removedIndices.add(index);
    if (index >= 0 && index < queueTracks.length) {
      queueTracks.removeAt(index);
      if (currentIdx >= queueTracks.length) {
        currentIdx = queueTracks.length - 1;
      }
    }
  }

  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    reorderCalls.add((oldIndex, newIndex));
    if (oldIndex >= 0 &&
        oldIndex < queueTracks.length &&
        newIndex >= 0 &&
        newIndex < queueTracks.length) {
      final item = queueTracks.removeAt(oldIndex);
      queueTracks.insert(newIndex, item);
    }
  }

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    setQueueCalled = true;
    queueTracks = List<Track>.from(tracks);
    currentIdx = startIndex;
  }
}

Track _makeTrack(String id, [String? title]) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title ?? 'Track $id',
    artist: 'Artist $id',
    duration: const Duration(minutes: 3, seconds: 30),
  );
}

Widget _wrapWithTokens({required Widget child, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [AppTokens.standardTokens],
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tA = _makeTrack('a', 'Alpha');
  final tB = _makeTrack('b', 'Bravo');
  final tC = _makeTrack('c', 'Charlie');
  final tD = _makeTrack('d', 'Delta');
  final tE = _makeTrack('e', 'Echo');

  setUp(() {
    QueueBatchReorderPrefsStorage.setMockInitialValues({});
  });

  tearDown(() {
    QueueBatchReorderPrefsStorage.reset();
  });

  // ==========================================================================
  // 1. QueueMultiSelectState Unit Tests
  // ==========================================================================
  group('QueueMultiSelectState', () {
    test('default state is empty', () {
      const state = QueueMultiSelectState();
      expect(state.selectedIndices, isEmpty);
      expect(state.selectedCount, 0);
      expect(state.hasSelection, isFalse);
      expect(state.isSelectionModeActive, isFalse);
      expect(state.lastToggledIndex, isNull);
      expect(state.sortedIndices, isEmpty);
      expect(state.isAllSelected(5), isFalse);
    });

    test('isSelected correctly tests presence of index', () {
      const state = QueueMultiSelectState(selectedIndices: {1, 3});
      expect(state.isSelected(0), isFalse);
      expect(state.isSelected(1), isTrue);
      expect(state.isSelected(2), isFalse);
      expect(state.isSelected(3), isTrue);
      expect(state.selectedCount, 2);
      expect(state.hasSelection, isTrue);
    });

    test('isAllSelected checks matching count', () {
      const state = QueueMultiSelectState(selectedIndices: {0, 1, 2});
      expect(state.isAllSelected(3), isTrue);
      expect(state.isAllSelected(4), isFalse);
      expect(state.isAllSelected(0), isFalse);
    });

    test('sortedIndices returns sorted copy', () {
      const state = QueueMultiSelectState(selectedIndices: {4, 1, 3});
      expect(state.sortedIndices, equals([1, 3, 4]));
    });

    test('copyWith properly updates or preserves values', () {
      const state = QueueMultiSelectState(
        selectedIndices: {1},
        lastToggledIndex: 1,
        totalItems: 5,
      );

      final updated = state.copyWith(
        selectedIndices: {1, 2},
        lastToggledIndex: 2,
      );

      expect(updated.selectedIndices, equals({1, 2}));
      expect(updated.lastToggledIndex, 2);
      expect(updated.totalItems, 5);

      final clearedLast = updated.copyWith(clearLastToggledIndex: true);
      expect(clearedLast.lastToggledIndex, isNull);
      expect(clearedLast.selectedIndices, equals({1, 2}));
    });

    test('value equality and hashCode behave correctly', () {
      const s1 = QueueMultiSelectState(
        selectedIndices: {1, 2},
        lastToggledIndex: 2,
        totalItems: 4,
      );
      const s2 = QueueMultiSelectState(
        selectedIndices: {2, 1},
        lastToggledIndex: 2,
        totalItems: 4,
      );
      const sDiff = QueueMultiSelectState(
        selectedIndices: {1, 3},
        lastToggledIndex: 2,
        totalItems: 4,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(sDiff)));
    });
  });

  // ==========================================================================
  // 2. QueueBatchReorderPrefsStorage Unit Tests
  // ==========================================================================
  group('QueueBatchReorderPrefsStorage', () {
    test('getBool returns null when unset', () async {
      final storage = QueueBatchReorderPrefsStorage();
      final val = await storage.getBool(kBatchReorderPreserveCurrentKey);
      expect(val, isNull);
    });

    test('setBool and getBool roundtrip', () async {
      final storage = QueueBatchReorderPrefsStorage();
      await storage.setBool(kBatchReorderPreserveCurrentKey, false);
      final val = await storage.getBool(kBatchReorderPreserveCurrentKey);
      expect(val, isFalse);

      await storage.setBool(kBatchReorderConfirmDeleteKey, true);
      final confirm = await storage.getBool(kBatchReorderConfirmDeleteKey);
      expect(confirm, isTrue);
    });
  });

  // ==========================================================================
  // 3. QueueBatchReorderHelper Pure Algorithmic Tests
  // ==========================================================================
  group('QueueBatchReorderHelper: removeSelected', () {
    test('empty queue or selection returns unchanged', () {
      final res1 = QueueBatchReorderHelper.removeSelected([], {0});
      expect(res1.hasChanged, isFalse);
      expect(res1.updatedQueue, isEmpty);

      final res2 = QueueBatchReorderHelper.removeSelected([tA, tB], {});
      expect(res2.hasChanged, isFalse);
      expect(res2.updatedQueue.length, 2);
    });

    test('removes selected non-contiguous items cleanly', () {
      final queue = [tA, tB, tC, tD, tE];
      final res = QueueBatchReorderHelper.removeSelected(
        queue,
        {1, 3}, // Remove Bravo and Delta
        currentIndex: 4, // Current is Echo
      );

      expect(res.hasChanged, isTrue);
      expect(res.updatedQueue, equals([tA, tC, tE]));
      expect(res.affectedTracks, equals([tB, tD]));
      expect(res.newSelectedIndices, isEmpty);
      // Echo was at index 4, two items before it were removed, so now index 2
      expect(res.newCurrentIndex, 2);
    });

    test('removes currently playing track and adjusts currentIndex to next', () {
      final queue = [tA, tB, tC];
      final res = QueueBatchReorderHelper.removeSelected(
        queue,
        {1}, // Remove Bravo (current track)
        currentIndex: 1,
      );

      expect(res.hasChanged, isTrue);
      expect(res.updatedQueue, equals([tA, tC]));
      expect(res.newCurrentIndex, 1); // Points to Charlie
    });

    test('removes all items leaving empty queue', () {
      final queue = [tA, tB];
      final res = QueueBatchReorderHelper.removeSelected(
        queue,
        {0, 1},
        currentIndex: 0,
      );

      expect(res.hasChanged, isTrue);
      expect(res.updatedQueue, isEmpty);
      expect(res.newCurrentIndex, -1);
    });

    test('ignores out-of-range indices gracefully', () {
      final queue = [tA, tB];
      final res = QueueBatchReorderHelper.removeSelected(
        queue,
        {-1, 10},
        currentIndex: 0,
      );

      expect(res.hasChanged, isFalse);
      expect(res.updatedQueue, equals(queue));
      expect(res.newCurrentIndex, 0);
    });
  });

  group('QueueBatchReorderHelper: moveSelectedToTop', () {
    test('moves selected items to absolute index 0 (preserveCurrentTrack: false)', () {
      final queue = [tA, tB, tC, tD, tE];
      final res = QueueBatchReorderHelper.moveSelectedToTop(
        queue,
        {1, 3}, // Bravo, Delta
        currentIndex: 0, // Alpha was playing
        preserveCurrentTrack: false,
      );

      expect(res.hasChanged, isTrue);
      expect(res.updatedQueue, equals([tB, tD, tA, tC, tE]));
      expect(res.newSelectedIndices, equals({0, 1}));
      // Alpha is now at index 2
      expect(res.newCurrentIndex, 2);
    });

    test('noop when selected items are already at top', () {
      final queue = [tA, tB, tC, tD];
      final res = QueueBatchReorderHelper.moveSelectedToTop(
        queue,
        {0, 1},
        currentIndex: 0,
        preserveCurrentTrack: false,
      );

      expect(res.hasChanged, isFalse);
      expect(res.updatedQueue, equals(queue));
      expect(res.newSelectedIndices, equals({0, 1}));
    });

    test('moves selected upcoming items right after current track (preserveCurrentTrack: true)', () {
      final queue = [tA, tB, tC, tD, tE];
      final res = QueueBatchReorderHelper.moveSelectedToTop(
        queue,
        {2, 4}, // Charlie, Echo
        currentIndex: 0, // Alpha is now playing
        preserveCurrentTrack: true,
      );

      expect(res.hasChanged, isTrue);
      // Alpha remains at 0, followed by Charlie and Echo, then Bravo and Delta
      expect(res.updatedQueue, equals([tA, tC, tE, tB, tD]));
      expect(res.newSelectedIndices, equals({1, 2}));
      expect(res.newCurrentIndex, 0);
    });
  });

  group('QueueBatchReorderHelper: moveSelectedToBottom', () {
    test('moves selected items to the bottom preserving relative order', () {
      final queue = [tA, tB, tC, tD, tE];
      final res = QueueBatchReorderHelper.moveSelectedToBottom(
        queue,
        {1, 3}, // Bravo, Delta
        currentIndex: 0, // Alpha was playing
      );

      expect(res.hasChanged, isTrue);
      expect(res.updatedQueue, equals([tA, tC, tE, tB, tD]));
      expect(res.newSelectedIndices, equals({3, 4}));
      expect(res.newCurrentIndex, 0);
    });

    test('noop when selected items are already at bottom', () {
      final queue = [tA, tB, tC, tD];
      final res = QueueBatchReorderHelper.moveSelectedToBottom(
        queue,
        {2, 3},
        currentIndex: 0,
      );

      expect(res.hasChanged, isFalse);
      expect(res.updatedQueue, equals(queue));
      expect(res.newSelectedIndices, equals({2, 3}));
    });
  });

  group('QueueBatchReorderHelper: moveSelectedUp & moveSelectedDown', () {
    test('moveSelectedUp shifts items up by 1 position', () {
      final queue = [tA, tB, tC, tD];
      final res = QueueBatchReorderHelper.moveSelectedUp(queue, {2}); // Charlie at 2

      expect(res.hasChanged, isTrue);
      expect(res.updatedQueue, equals([tA, tC, tB, tD]));
      expect(res.newSelectedIndices, equals({1}));
    });

    test('moveSelectedUp at top boundary is noop', () {
      final queue = [tA, tB, tC];
      final res = QueueBatchReorderHelper.moveSelectedUp(queue, {0});

      expect(res.hasChanged, isFalse);
      expect(res.updatedQueue, equals(queue));
    });

    test('moveSelectedDown shifts items down by 1 position', () {
      final queue = [tA, tB, tC, tD];
      final res = QueueBatchReorderHelper.moveSelectedDown(queue, {1}); // Bravo at 1

      expect(res.hasChanged, isTrue);
      expect(res.updatedQueue, equals([tA, tC, tB, tD]));
      expect(res.newSelectedIndices, equals({2}));
    });

    test('moveSelectedDown at bottom boundary is noop', () {
      final queue = [tA, tB, tC];
      final res = QueueBatchReorderHelper.moveSelectedDown(queue, {2});

      expect(res.hasChanged, isFalse);
      expect(res.updatedQueue, equals(queue));
    });
  });

  // ==========================================================================
  // 4. QueueMultiSelectNotifier Unit Tests
  // ==========================================================================
  group('QueueMultiSelectNotifier', () {
    late QueueMultiSelectNotifier notifier;

    setUp(() {
      notifier = QueueMultiSelectNotifier();
    });

    test('toggleItem selects unselected item and deselects selected item', () {
      notifier.toggleItem(1);
      expect(notifier.state.selectedIndices, equals({1}));
      expect(notifier.state.lastToggledIndex, 1);

      notifier.toggleItem(3);
      expect(notifier.state.selectedIndices, equals({1, 3}));
      expect(notifier.state.lastToggledIndex, 3);

      notifier.toggleItem(1);
      expect(notifier.state.selectedIndices, equals({3}));
      expect(notifier.state.lastToggledIndex, 1);
    });

    test('Shift range select selects all items between last toggled and target', () {
      // First click index 1
      notifier.toggleItem(1);
      expect(notifier.state.selectedIndices, equals({1}));

      // Shift click index 4
      notifier.toggleItem(4, isShiftPressed: true, totalCount: 6);
      expect(notifier.state.selectedIndices, equals({1, 2, 3, 4}));
      expect(notifier.state.lastToggledIndex, 4);

      // Shift click backward to 2
      notifier.toggleItem(2, isShiftPressed: true, totalCount: 6);
      expect(notifier.state.selectedIndices, equals({1, 2, 3, 4}));
      expect(notifier.state.lastToggledIndex, 2);
    });

    test('selectItem and deselectItem explicitly update selection', () {
      notifier.selectItem(2);
      expect(notifier.state.isSelected(2), isTrue);

      notifier.deselectItem(2);
      expect(notifier.state.isSelected(2), isFalse);
    });

    test('selectRange selects forward and backward bounds', () {
      notifier.selectRange(1, 3);
      expect(notifier.state.selectedIndices, equals({1, 2, 3}));

      notifier.clearSelection();
      notifier.selectRange(4, 2);
      expect(notifier.state.selectedIndices, equals({2, 3, 4}));
    });

    test('selectAll selects all items up to total count', () {
      notifier.selectAll(5);
      expect(notifier.state.selectedIndices, equals({0, 1, 2, 3, 4}));
      expect(notifier.state.selectedCount, 5);

      notifier.selectAll(0);
      expect(notifier.state.selectedIndices, isEmpty);
    });

    test('invertSelection flips selected and unselected sets', () {
      notifier.selectItem(1);
      notifier.selectItem(3);

      notifier.invertSelection(5);
      expect(notifier.state.selectedIndices, equals({0, 2, 4}));

      // Inverting again returns to original
      notifier.invertSelection(5);
      expect(notifier.state.selectedIndices, equals({1, 3}));
    });

    test('clearSelection resets all selection state', () {
      notifier.selectRange(0, 4);
      expect(notifier.state.hasSelection, isTrue);

      notifier.clearSelection();
      expect(notifier.state.hasSelection, isFalse);
      expect(notifier.state.selectedIndices, isEmpty);
      expect(notifier.state.lastToggledIndex, isNull);
    });

    test('prune discards indices out of new queue bounds', () {
      notifier.selectRange(0, 5);
      expect(notifier.state.selectedIndices.length, 6);

      notifier.prune(3); // Queue shrunk to 3 items
      expect(notifier.state.selectedIndices, equals({0, 1, 2}));
    });
  });

  // ==========================================================================
  // 5. AudioHandler Integration Tests
  // ==========================================================================
  group('QueueMultiSelectNotifier AudioHandler Actions', () {
    late FakeAudioHandler fakeHandler;
    late QueueMultiSelectNotifier notifier;

    setUp(() {
      fakeHandler = FakeAudioHandler();
      fakeHandler.queueTracks = [tA, tB, tC, tD, tE];
      fakeHandler.currentIdx = 0;
      notifier = QueueMultiSelectNotifier();
    });

    test('removeSelected deletes items from fakeHandler in descending order', () async {
      notifier.selectItem(1); // Bravo
      notifier.selectItem(3); // Delta

      final result = await notifier.removeSelected(handler: fakeHandler);

      expect(result, isNotNull);
      expect(result!.hasChanged, isTrue);
      // Must be removed from highest index to lowest index so indices stay valid
      expect(fakeHandler.removedIndices, equals([3, 1]));
      expect(fakeHandler.queueTracks, equals([tA, tC, tE]));
      expect(notifier.state.hasSelection, isFalse);
    });

    test('moveSelectedToTop applies reorders to fakeHandler and updates selection', () async {
      notifier.selectItem(1); // Bravo
      notifier.selectItem(3); // Delta

      final result = await notifier.moveSelectedToTop(
        handler: fakeHandler,
        preserveCurrentTrack: false,
      );

      expect(result, isNotNull);
      expect(result!.hasChanged, isTrue);
      expect(fakeHandler.queueTracks, equals([tB, tD, tA, tC, tE]));
      expect(notifier.state.selectedIndices, equals({0, 1}));
    });

    test('moveSelectedToBottom applies reorders to fakeHandler and updates selection', () async {
      notifier.selectItem(1); // Bravo
      notifier.selectItem(3); // Delta

      final result = await notifier.moveSelectedToBottom(handler: fakeHandler);

      expect(result, isNotNull);
      expect(result!.hasChanged, isTrue);
      expect(fakeHandler.queueTracks, equals([tA, tC, tE, tB, tD]));
      expect(notifier.state.selectedIndices, equals({3, 4}));
    });
  });

  // ==========================================================================
  // 6. QueueBatchActionBar Widget Tests
  // ==========================================================================
  group('QueueBatchActionBar Widget', () {
    testWidgets('renders nothing when selection is empty and alwaysVisible is false', (tester) async {
      await tester.pumpWidget(
        _wrapWithTokens(
          child: const QueueBatchActionBar(alwaysVisible: false),
        ),
      );

      expect(find.byKey(const Key('queue_batch_action_bar')), findsNothing);
    });

    testWidgets('renders count and action buttons when selection > 0', (tester) async {
      final notifier = QueueMultiSelectNotifier(
        initialState: const QueueMultiSelectState(selectedIndices: {1, 3}),
      );

      await tester.pumpWidget(
        _wrapWithTokens(
          overrides: [
            queueMultiSelectProvider.overrideWith((ref) => notifier),
          ],
          child: const QueueBatchActionBar(),
        ),
      );

      expect(find.byKey(const Key('queue_batch_action_bar')), findsOneWidget);
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byKey(const Key('queue_batch_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_batch_move_top_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_batch_move_bottom_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_batch_select_all_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_batch_invert_button')), findsOneWidget);
      expect(find.byKey(const Key('queue_batch_remove_button')), findsOneWidget);
    });

    testWidgets('action buttons trigger corresponding callbacks', (tester) async {
      bool clearTapped = false;
      bool moveTopTapped = false;
      bool moveBottomTapped = false;
      bool selectAllTapped = false;
      bool invertTapped = false;
      bool removeTapped = false;

      await tester.pumpWidget(
        _wrapWithTokens(
          child: QueueBatchActionBar(
            alwaysVisible: true,
            onClearSelection: () => clearTapped = true,
            onMoveSelectedToTop: () => moveTopTapped = true,
            onMoveSelectedToBottom: () => moveBottomTapped = true,
            onSelectAll: () => selectAllTapped = true,
            onInvertSelection: () => invertTapped = true,
            onRemoveSelected: () => removeTapped = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('queue_batch_clear_button')));
      await tester.pump();
      expect(clearTapped, isTrue);

      await tester.tap(find.byKey(const Key('queue_batch_move_top_button')));
      await tester.pump();
      expect(moveTopTapped, isTrue);

      await tester.tap(find.byKey(const Key('queue_batch_move_bottom_button')));
      await tester.pump();
      expect(moveBottomTapped, isTrue);

      await tester.tap(find.byKey(const Key('queue_batch_select_all_button')));
      await tester.pump();
      expect(selectAllTapped, isTrue);

      await tester.tap(find.byKey(const Key('queue_batch_invert_button')));
      await tester.pump();
      expect(invertTapped, isTrue);

      await tester.tap(find.byKey(const Key('queue_batch_remove_button')));
      await tester.pump();
      expect(removeTapped, isTrue);
    });
  });

  // ==========================================================================
  // 7. QueueSelectableItem Widget Tests
  // ==========================================================================
  group('QueueSelectableItem Widget', () {
    testWidgets('renders track title, artist and checkbox indicator', (tester) async {
      final notifier = QueueMultiSelectNotifier();

      await tester.pumpWidget(
        _wrapWithTokens(
          overrides: [
            queueMultiSelectProvider.overrideWith((ref) => notifier),
          ],
          child: QueueSelectableItem(
            index: 0,
            track: tA,
            totalCount: 3,
          ),
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Artist a'), findsOneWidget);
      expect(find.byKey(const Key('queue_item_checkbox_0')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Tap to select item
      await tester.tap(find.byKey(const Key('queue_selectable_item_0')));
      await tester.pump();

      expect(notifier.state.isSelected(0), isTrue);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
