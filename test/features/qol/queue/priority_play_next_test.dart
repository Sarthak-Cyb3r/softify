import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/queue/priority_play_next.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test Track Fixtures
  const trackA = Track(
    id: 'track_a',
    sourceId: 'src_a',
    title: 'Track Alpha',
    artist: 'Artist One',
    album: 'Album X',
    duration: Duration(minutes: 3, seconds: 20),
  );

  const trackB = Track(
    id: 'track_b',
    sourceId: 'src_b',
    title: 'Track Bravo',
    artist: 'Artist Two',
    album: 'Album Y',
    duration: Duration(minutes: 4, seconds: 5),
  );

  const trackC = Track(
    id: 'track_c',
    sourceId: 'src_c',
    title: 'Track Charlie',
    artist: 'Artist Three',
    album: 'Album Z',
    duration: Duration(minutes: 2, seconds: 45),
  );

  const trackD = Track(
    id: 'track_d',
    sourceId: 'src_d',
    title: 'Track Delta',
    artist: 'Artist Four',
    album: 'Album W',
    duration: Duration(minutes: 5, seconds: 10),
  );

  setUp(() {
    PriorityQueuePreferences.setMockInitialValues({});
  });

  tearDown(() {
    PriorityQueuePreferences.reset();
  });

  // ==========================================================================
  // Group 1: PriorityQueueState Model & Resolvers
  // ==========================================================================
  group('PriorityQueueState Model', () {
    test('initializes with expected default values', () {
      final state = PriorityQueueState();
      expect(state.currentTrack, isNull);
      expect(state.priorityStack, isEmpty);
      expect(state.playlistQueue, isEmpty);
      expect(state.history, isEmpty);
      expect(state.isLifoMode, isTrue);
      expect(state.priorityCount, equals(0));
      expect(state.playlistCount, equals(0));
      expect(state.totalUpcomingCount, equals(0));
      expect(state.hasPriorityTracks, isFalse);
      expect(state.hasPlaylistTracks, isFalse);
      expect(state.hasUpcoming, isFalse);
      expect(state.nextUpTrack, isNull);
      expect(state.isEmpty, isTrue);
      expect(state.unifiedUpcomingQueue, isEmpty);
      expect(state.fullQueue, isEmpty);
    });

    test('resolves nextUpTrack with priority stack taking precedence', () {
      // 1. Only playlist items
      var state = PriorityQueueState(
        playlistQueue: [trackA, trackB],
      );
      expect(state.nextUpTrack, equals(trackA));
      expect(state.totalUpcomingCount, equals(2));

      // 2. Both priority and playlist items -> priority item returned
      state = state.copyWith(
        priorityStack: [trackC],
      );
      expect(state.nextUpTrack, equals(trackC));
      expect(state.totalUpcomingCount, equals(3));
    });

    test('constructs unifiedUpcomingQueue with priority before playlist', () {
      final state = PriorityQueueState(
        priorityStack: [trackA, trackB],
        playlistQueue: [trackC, trackD],
      );

      final unified = state.unifiedUpcomingQueue;
      expect(unified.length, equals(4));
      expect(unified[0], equals(trackA));
      expect(unified[1], equals(trackB));
      expect(unified[2], equals(trackC));
      expect(unified[3], equals(trackD));
    });

    test('constructs fullQueue including current track at position 0', () {
      final state = PriorityQueueState(
        currentTrack: trackA,
        priorityStack: [trackB],
        playlistQueue: [trackC],
      );

      final full = state.fullQueue;
      expect(full.length, equals(3));
      expect(full[0], equals(trackA));
      expect(full[1], equals(trackB));
      expect(full[2], equals(trackC));
    });

    test('serializes to and from Map and JSON faithfully', () {
      final state = PriorityQueueState(
        currentTrack: trackA,
        priorityStack: [trackB],
        playlistQueue: [trackC, trackD],
        history: [trackA],
        isLifoMode: false,
      );

      final map = state.toMap();
      final reconstituted = PriorityQueueState.fromMap(map);

      expect(reconstituted.currentTrack?.id, equals(trackA.id));
      expect(reconstituted.priorityStack.length, equals(1));
      expect(reconstituted.priorityStack[0].id, equals(trackB.id));
      expect(reconstituted.playlistQueue.length, equals(2));
      expect(reconstituted.playlistQueue[0].id, equals(trackC.id));
      expect(reconstituted.playlistQueue[1].id, equals(trackD.id));
      expect(reconstituted.isLifoMode, isFalse);

      final jsonStr = state.toJson();
      final fromJson = PriorityQueueState.fromJson(jsonStr);
      expect(fromJson.currentTrack?.id, equals(trackA.id));
      expect(fromJson.priorityStack.length, equals(1));
    });

    test('supports value equality and copyWith', () {
      final state1 = PriorityQueueState(
        priorityStack: [trackA],
        playlistQueue: [trackB],
      );

      final state2 = PriorityQueueState(
        priorityStack: [trackA],
        playlistQueue: [trackB],
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      final state3 = state1.copyWith(isLifoMode: false);
      expect(state3.isLifoMode, isFalse);
      expect(state1 == state3, isFalse);
    });
  });

  // ==========================================================================
  // Group 2: PriorityQueueManager - Play Next & LIFO Queue Operations
  // ==========================================================================
  group('PriorityQueueManager - Play Next & LIFO Stack', () {
    late PriorityQueueManager manager;

    setUp(() {
      manager = PriorityQueueManager();
    });

    test('playNext inserts at index 0 of priority stack in default LIFO mode', () {
      manager.playNext(trackA);
      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack[0], equals(trackA));

      // Push trackB -> sits at top (index 0), shifting trackA to index 1
      manager.playNext(trackB);
      expect(manager.priorityStack.length, equals(2));
      expect(manager.priorityStack[0], equals(trackB));
      expect(manager.priorityStack[1], equals(trackA));

      // Push trackC -> sits at top (index 0)
      manager.playNext(trackC);
      expect(manager.priorityStack.length, equals(3));
      expect(manager.priorityStack[0], equals(trackC));
      expect(manager.priorityStack[1], equals(trackB));
      expect(manager.priorityStack[2], equals(trackA));
    });

    test('playNext with playImmediatelyIfIdle sets currentTrack when idle', () {
      manager.playNext(trackA, playImmediatelyIfIdle: true);
      expect(manager.currentTrack, equals(trackA));
      expect(manager.priorityStack, isEmpty);

      // Subsequent playNext with playImmediatelyIfIdle does NOT overwrite currentTrack
      manager.playNext(trackB, playImmediatelyIfIdle: true);
      expect(manager.currentTrack, equals(trackA));
      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackB));
    });

    test('playNextBatch with preserveOrder maintains batch order at top of stack', () {
      manager.playNext(trackA); // Existing item
      manager.playNextBatch([trackB, trackC], preserveOrder: true);

      // Expect [trackB, trackC, trackA]
      expect(manager.priorityStack.length, equals(3));
      expect(manager.priorityStack[0], equals(trackB));
      expect(manager.priorityStack[1], equals(trackC));
      expect(manager.priorityStack[2], equals(trackA));
    });

    test('playNext in non-LIFO mode appends to end of priority queue', () {
      manager.setLifoMode(false);
      manager.playNext(trackA);
      manager.playNext(trackB);

      expect(manager.priorityStack[0], equals(trackA));
      expect(manager.priorityStack[1], equals(trackB));
    });
  });

  // ==========================================================================
  // Group 3: PriorityQueueManager - Add to End & FIFO Queue Operations
  // ==========================================================================
  group('PriorityQueueManager - Add to End & FIFO Queue', () {
    late PriorityQueueManager manager;

    setUp(() {
      manager = PriorityQueueManager();
    });

    test('addToEnd appends to playlist queue in FIFO order', () {
      manager.addToEnd(trackA);
      manager.addToEnd(trackB);
      manager.addToEnd(trackC);

      expect(manager.playlistQueue.length, equals(3));
      expect(manager.playlistQueue[0], equals(trackA));
      expect(manager.playlistQueue[1], equals(trackB));
      expect(manager.playlistQueue[2], equals(trackC));
    });

    test('addToEndBatch appends multiple tracks sequentially', () {
      manager.addToEndBatch([trackA, trackB]);
      manager.addToEndBatch([trackC, trackD]);

      expect(manager.playlistQueue.length, equals(4));
      expect(manager.playlistQueue, equals([trackA, trackB, trackC, trackD]));
    });

    test('setPlaylistQueue replaces playlist queue while preserving priority stack', () {
      manager.playNext(trackA);
      manager.addToEnd(trackB);

      manager.setPlaylistQueue([trackC, trackD]);

      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackA));

      expect(manager.playlistQueue.length, equals(2));
      expect(manager.playlistQueue[0], equals(trackC));
      expect(manager.playlistQueue[1], equals(trackD));
    });
  });

  // ==========================================================================
  // Group 4: PriorityQueueManager - Playback Advancement (Priority Resolution)
  // ==========================================================================
  group('PriorityQueueManager - advanceNext & skipPrevious', () {
    late PriorityQueueManager manager;

    setUp(() {
      manager = PriorityQueueManager();
    });

    test('advanceNext exhausts priority stack before consuming playlist queue', () {
      manager.setCurrentTrack(trackA);
      manager.playNext(trackB); // Priority stack: [trackB]
      manager.addToEnd(trackC); // Playlist queue: [trackC]
      manager.addToEnd(trackD); // Playlist queue: [trackC, trackD]

      // 1st advance: pops trackB from priority stack
      final firstAdvance = manager.advanceNext();
      expect(firstAdvance, equals(trackB));
      expect(manager.currentTrack, equals(trackB));
      expect(manager.priorityStack, isEmpty);
      expect(manager.playlistQueue.length, equals(2));
      expect(manager.history.length, equals(1));
      expect(manager.history.first, equals(trackA));

      // 2nd advance: priority stack is now empty, pops trackC from playlist queue
      final secondAdvance = manager.advanceNext();
      expect(secondAdvance, equals(trackC));
      expect(manager.currentTrack, equals(trackC));
      expect(manager.playlistQueue.length, equals(1));
      expect(manager.playlistQueue.first, equals(trackD));

      // 3rd advance: pops trackD from playlist queue
      final thirdAdvance = manager.advanceNext();
      expect(thirdAdvance, equals(trackD));
      expect(manager.playlistQueue, isEmpty);

      // 4th advance: both queues empty -> returns null
      final fourthAdvance = manager.advanceNext();
      expect(fourthAdvance, isNull);
    });

    test('skipPrevious rewinds to previous track and preserves current track at top of priority stack', () {
      manager.setCurrentTrack(trackA);
      manager.playNext(trackB);

      // Advance to trackB, archiving trackA in history
      manager.advanceNext();
      expect(manager.currentTrack, equals(trackB));
      expect(manager.history.first, equals(trackA));

      // Skip previous
      final rewound = manager.skipPrevious();
      expect(rewound, equals(trackA));
      expect(manager.currentTrack, equals(trackA));
      expect(manager.history, isEmpty);

      // trackB was pushed back to the front of priority stack
      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackB));
    });

    test('skipPrevious returns null when history is empty', () {
      manager.setCurrentTrack(trackA);
      expect(manager.skipPrevious(), isNull);
      expect(manager.currentTrack, equals(trackA));
    });
  });

  // ==========================================================================
  // Group 5: PriorityQueueManager - Promotion, Demotion, Removal & Reordering
  // ==========================================================================
  group('PriorityQueueManager - Item Manipulation', () {
    late PriorityQueueManager manager;

    setUp(() {
      manager = PriorityQueueManager();
    });

    test('promoteToPriority moves item from playlist queue to priority stack', () {
      manager.addToEnd(trackA);
      manager.addToEnd(trackB);
      manager.addToEnd(trackC);

      // Promote trackB (index 1) to top of priority stack
      final success = manager.promoteToPriority(1);
      expect(success, isTrue);

      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackB));

      expect(manager.playlistQueue.length, equals(2));
      expect(manager.playlistQueue[0], equals(trackA));
      expect(manager.playlistQueue[1], equals(trackC));

      // Invalid index fails safely
      expect(manager.promoteToPriority(99), isFalse);
    });

    test('demoteToPlaylist moves item from priority stack to playlist queue', () {
      manager.playNext(trackA);
      manager.playNext(trackB); // Priority: [trackB, trackA]

      final success = manager.demoteToPlaylist(0); // Demote trackB
      expect(success, isTrue);

      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackA));

      expect(manager.playlistQueue.length, equals(1));
      expect(manager.playlistQueue.first, equals(trackB));

      // Invalid index fails safely
      expect(manager.demoteToPlaylist(-1), isFalse);
    });

    test('removePriorityTrackAt removes item correctly', () {
      manager.playNext(trackA);
      manager.playNext(trackB); // [trackB, trackA]

      expect(manager.removePriorityTrackAt(0), isTrue);
      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackA));

      expect(manager.removePriorityTrackAt(5), isFalse);
    });

    test('removePlaylistTrackAt removes item correctly', () {
      manager.addToEnd(trackA);
      manager.addToEnd(trackB);

      expect(manager.removePlaylistTrackAt(1), isTrue);
      expect(manager.playlistQueue.length, equals(1));
      expect(manager.playlistQueue.first, equals(trackA));

      expect(manager.removePlaylistTrackAt(-1), isFalse);
    });

    test('removeTrackById removes from both queues by default', () {
      manager.playNext(trackA);
      manager.addToEnd(trackA);
      manager.addToEnd(trackB);

      final removed = manager.removeTrackById(trackA.id);
      expect(removed, equals(2));
      expect(manager.priorityStack, isEmpty);
      expect(manager.playlistQueue.length, equals(1));
      expect(manager.playlistQueue.first, equals(trackB));
    });

    test('reorderPriorityQueue correctly reorders items', () {
      manager.playNext(trackA);
      manager.playNext(trackB);
      manager.playNext(trackC); // [trackC, trackB, trackA]

      // Move trackC (index 0) to after trackB (target index 2 in Flutter Reorderable format)
      final success = manager.reorderPriorityQueue(0, 2);
      expect(success, isTrue);

      expect(manager.priorityStack[0], equals(trackB));
      expect(manager.priorityStack[1], equals(trackC));
      expect(manager.priorityStack[2], equals(trackA));
    });

    test('reorderPlaylistQueue correctly reorders items', () {
      manager.addToEnd(trackA);
      manager.addToEnd(trackB);
      manager.addToEnd(trackC); // [trackA, trackB, trackC]

      // Move trackA (0) to end (target 3)
      final success = manager.reorderPlaylistQueue(0, 3);
      expect(success, isTrue);

      expect(manager.playlistQueue[0], equals(trackB));
      expect(manager.playlistQueue[1], equals(trackC));
      expect(manager.playlistQueue[2], equals(trackA));
    });
  });

  // ==========================================================================
  // Group 6: PriorityQueueManager - Bulk Operations & Clear
  // ==========================================================================
  group('PriorityQueueManager - Bulk Operations', () {
    late PriorityQueueManager manager;

    setUp(() {
      manager = PriorityQueueManager();
    });

    test('clearPriorityQueue wipes priority stack without touching playlist', () {
      manager.playNext(trackA);
      manager.addToEnd(trackB);

      manager.clearPriorityQueue();
      expect(manager.priorityStack, isEmpty);
      expect(manager.playlistQueue.length, equals(1));
    });

    test('clearPlaylistQueue wipes playlist queue without touching priority', () {
      manager.playNext(trackA);
      manager.addToEnd(trackB);

      manager.clearPlaylistQueue();
      expect(manager.priorityStack.length, equals(1));
      expect(manager.playlistQueue, isEmpty);
    });

    test('clearAllUpcoming wipes both upcoming queues', () {
      manager.setCurrentTrack(trackA);
      manager.playNext(trackB);
      manager.addToEnd(trackC);

      manager.clearAllUpcoming();
      expect(manager.currentTrack, equals(trackA));
      expect(manager.priorityStack, isEmpty);
      expect(manager.playlistQueue, isEmpty);
    });

    test('shufflePlaylistQueue randomizes playlist without altering priority stack', () {
      manager.playNext(trackA);
      manager.addToEnd(trackB);
      manager.addToEnd(trackC);
      manager.addToEnd(trackD);

      manager.shufflePlaylistQueue(random: Random(42));
      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackA));
      expect(manager.playlistQueue.length, equals(3));
    });

    test('reversePriorityQueue inverts priority order', () {
      manager.playNext(trackA);
      manager.playNext(trackB);
      manager.playNext(trackC); // [trackC, trackB, trackA]

      manager.reversePriorityQueue();
      expect(manager.priorityStack[0], equals(trackA));
      expect(manager.priorityStack[1], equals(trackB));
      expect(manager.priorityStack[2], equals(trackC));
    });

    test('toggleLifoMode switches mode correctly', () {
      expect(manager.isLifoMode, isTrue);
      manager.toggleLifoMode();
      expect(manager.isLifoMode, isFalse);
      manager.toggleLifoMode();
      expect(manager.isLifoMode, isTrue);
    });
  });

  // ==========================================================================
  // Group 7: Persistence with PriorityQueuePreferences
  // ==========================================================================
  group('PriorityQueueManager - Persistence', () {
    test('saves priority stack and restores state successfully', () async {
      final prefs = await PriorityQueuePreferences.getInstance();
      final manager = PriorityQueueManager(preferences: prefs);

      manager.playNext(trackA);
      manager.playNext(trackB);
      manager.setLifoMode(true);

      await manager.saveToPreferences(prefs);

      // Create new manager and restore
      final newManager = PriorityQueueManager(preferences: prefs);
      final restored = await newManager.loadFromPreferences(prefs);

      expect(restored, isTrue);
      expect(newManager.priorityStack.length, equals(2));
      expect(newManager.priorityStack[0].id, equals(trackB.id));
      expect(newManager.priorityStack[1].id, equals(trackA.id));
      expect(newManager.isLifoMode, isTrue);
    });
  });

  // ==========================================================================
  // Group 8: QueueSectionDivider Widget Tests
  // ==========================================================================
  group('QueueSectionDivider Widget', () {
    testWidgets('renders priority divider with title, count, badge, and triggers clear', (tester) async {
      bool clearCalled = false;
      bool actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTokens.standardTokens],
          ),
          home: Scaffold(
            body: QueueSectionDivider.priority(
              count: 4,
              onClear: () => clearCalled = true,
              onReverse: () => actionCalled = true,
            ),
          ),
        ),
      );

      // Verify title, badge, and count text
      expect(find.text('Play Next Stack'), findsOneWidget);
      expect(find.text('LIFO STACK'), findsOneWidget);
      expect(find.text('4 tracks'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      // Tap clear
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(clearCalled, isTrue);

      // Tap action (reverse)
      await tester.tap(find.byIcon(Icons.swap_vert_rounded));
      await tester.pump();
      expect(actionCalled, isTrue);
    });

    testWidgets('renders playlist divider with subtitle and triggers shuffle', (tester) async {
      bool shuffleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTokens.standardTokens],
          ),
          home: Scaffold(
            body: QueueSectionDivider.playlist(
              count: 12,
              playlistTitle: 'Daily Mix 1',
              onShuffle: () => shuffleCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Upcoming from Playlist'), findsOneWidget);
      expect(find.text('From: Daily Mix 1'), findsOneWidget);
      expect(find.text('PLAYLIST'), findsOneWidget);
      expect(find.text('12 tracks'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play_rounded), findsOneWidget);

      // Tap shuffle
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      await tester.pump();
      expect(shuffleCalled, isTrue);
    });

    testWidgets('renders nowPlaying divider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTokens.standardTokens],
          ),
          home: Scaffold(
            body: QueueSectionDivider.nowPlaying(),
          ),
        ),
      );

      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('CURRENT'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Group 9: PriorityQueueView Widget Integration Tests
  // ==========================================================================
  group('PriorityQueueView Widget', () {
    testWidgets('displays empty state when queue is completely empty', (tester) async {
      final manager = PriorityQueueManager();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priorityQueueManagerProvider.overrideWith((ref) => manager),
            isPlayingProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: Scaffold(
              body: PriorityQueueView(manager: manager),
            ),
          ),
        ),
      );

      expect(find.text('Playback Queue is Empty'), findsOneWidget);
    });

    testWidgets('displays now playing, priority stack, and playlist sections', (tester) async {
      final manager = PriorityQueueManager();
      manager.setCurrentTrack(trackA);
      manager.playNext(trackB);
      manager.addToEnd(trackC);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priorityQueueManagerProvider.overrideWith((ref) => manager),
            isPlayingProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: Scaffold(
              body: PriorityQueueView(manager: manager),
            ),
          ),
        ),
      );

      // Now Playing
      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('Track Alpha'), findsOneWidget);

      // Priority Stack section
      expect(find.text('Play Next Stack'), findsOneWidget);
      expect(find.text('Track Bravo'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);

      // Upcoming Playlist section
      expect(find.text('Upcoming from Playlist'), findsOneWidget);
      expect(find.text('Track Charlie'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('quick promotes playlist item to priority stack when tapping bolt icon', (tester) async {
      final manager = PriorityQueueManager();
      manager.addToEnd(trackA);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priorityQueueManagerProvider.overrideWith((ref) => manager),
            isPlayingProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: Scaffold(
              body: PriorityQueueView(manager: manager),
            ),
          ),
        ),
      );

      expect(manager.priorityStack, isEmpty);
      expect(manager.playlistQueue.length, equals(1));

      // Find and tap the promote button (bolt icon in playlist tile)
      final promoteBtn = find.byTooltip('Promote to Play Next priority stack');
      expect(promoteBtn, findsOneWidget);
      await tester.tap(promoteBtn);
      await tester.pump();

      // Track promoted to priority stack
      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackA));
      expect(manager.playlistQueue, isEmpty);
    });
  });

  // ==========================================================================
  // Group 10: Action Button Helpers
  // ==========================================================================
  group('Action Button Helpers', () {
    testWidgets('PlayNextActionButton adds track to priority stack', (tester) async {
      final manager = PriorityQueueManager();
      bool completeCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priorityQueueManagerProvider.overrideWith((ref) => manager),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: Scaffold(
              body: PlayNextActionButton(
                track: trackA,
                onComplete: () => completeCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(manager.priorityStack.length, equals(1));
      expect(manager.priorityStack.first, equals(trackA));
      expect(completeCalled, isTrue);
    });

    testWidgets('AddToEndActionButton adds track to playlist queue', (tester) async {
      final manager = PriorityQueueManager();
      bool completeCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priorityQueueManagerProvider.overrideWith((ref) => manager),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppTokens.standardTokens],
            ),
            home: Scaffold(
              body: AddToEndActionButton(
                track: trackB,
                onComplete: () => completeCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(manager.playlistQueue.length, equals(1));
      expect(manager.playlistQueue.first, equals(trackB));
      expect(completeCalled, isTrue);
    });
  });
}
