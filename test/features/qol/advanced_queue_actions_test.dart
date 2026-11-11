import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/advanced_queue_actions.dart';
import 'package:softify/presentation/providers/player_providers.dart';

class FakeAudioHandler implements SoftifyAudioHandler {
  List<Track> queue = [];
  int index = 0;
  bool playNextCalled = false;
  bool clearUpcomingCalled = false;
  bool shuffleUpcomingCalled = false;
  bool reverseUpcomingCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  List<Track> get currentQueue => List.unmodifiable(queue);

  @override
  int get currentIndex => index;

  @override
  Stream<List<Track>> get tracksQueueStream => Stream.value(queue);

  @override
  Future<void> playNext(Track track) async {
    playNextCalled = true;
    if (queue.isEmpty) {
      queue.add(track);
      index = 0;
    } else {
      queue.insert(index + 1, track);
    }
  }

  @override
  Future<void> clearUpcomingQueue() async {
    clearUpcomingCalled = true;
    if (index >= 0 && index < queue.length - 1) {
      queue.removeRange(index + 1, queue.length);
    } else if (index < 0) {
      queue.clear();
    }
  }

  @override
  Future<void> shuffleUpcomingOnly() async {
    shuffleUpcomingCalled = true;
    final startIndex = index >= 0 ? index + 1 : 0;
    if (startIndex < queue.length - 1) {
      final upcoming = queue.sublist(startIndex);
      upcoming.shuffle();
      queue.removeRange(startIndex, queue.length);
      queue.addAll(upcoming);
    }
  }

  @override
  Future<void> reverseUpcomingOnly() async {
    reverseUpcomingCalled = true;
    final startIndex = index >= 0 ? index + 1 : 0;
    if (startIndex < queue.length - 1) {
      final upcoming = queue.sublist(startIndex);
      queue.removeRange(startIndex, queue.length);
      queue.addAll(upcoming.reversed);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioHandler fakeHandler;

  const track1 = Track(
    id: 'track_1',
    sourceId: 'src_1',
    title: 'Track One',
    artist: 'Artist One',
    duration: Duration(minutes: 3),
  );

  const track2 = Track(
    id: 'track_2',
    sourceId: 'src_2',
    title: 'Track Two',
    artist: 'Artist Two',
    duration: Duration(minutes: 4),
  );

  const track3 = Track(
    id: 'track_3',
    sourceId: 'src_3',
    title: 'Track Three',
    artist: 'Artist Three',
    duration: Duration(minutes: 5),
  );

  const track4 = Track(
    id: 'track_4',
    sourceId: 'src_4',
    title: 'Track Four',
    artist: 'Artist Four',
    duration: Duration(minutes: 3, seconds: 30),
  );

  setUp(() {
    fakeHandler = FakeAudioHandler();
    fakeHandler.queue = [track1, track2, track3];
    fakeHandler.index = 0;
  });

  group('AdvancedQueueController', () {
    testWidgets('playNext inserts track immediately after currently playing song',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  AdvancedQueueController.playNext(ref, track4);
                },
                child: const Text('Play Next'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Play Next'));
      await tester.pumpAndSettle();

      expect(fakeHandler.playNextCalled, true);
      expect(fakeHandler.queue.length, 4);
      expect(fakeHandler.queue[0].id, 'track_1');
      expect(fakeHandler.queue[1].id, 'track_4'); // Inserted right after current track!
      expect(fakeHandler.queue[2].id, 'track_2');
      expect(fakeHandler.queue[3].id, 'track_3');
    });

    testWidgets('clearUpcomingQueue removes upcoming tracks while active song continues playing',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  AdvancedQueueController.clearUpcomingQueue(ref);
                },
                child: const Text('Clear Upcoming'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Clear Upcoming'));
      await tester.pumpAndSettle();

      expect(fakeHandler.clearUpcomingCalled, true);
      expect(fakeHandler.queue.length, 1);
      expect(fakeHandler.queue[0].id, 'track_1');
    });

    testWidgets('shuffleUpcomingOnly reorders upcoming tracks without touching active track',
        (tester) async {
      fakeHandler.queue = [track1, track2, track3, track4];
      fakeHandler.index = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  AdvancedQueueController.shuffleUpcomingOnly(ref);
                },
                child: const Text('Shuffle Upcoming'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Shuffle Upcoming'));
      await tester.pumpAndSettle();

      expect(fakeHandler.shuffleUpcomingCalled, true);
      expect(fakeHandler.queue.length, 4);
      expect(fakeHandler.queue[0].id, 'track_1'); // Active track MUST remain unchanged at index 0
      final upcomingIds = fakeHandler.queue.sublist(1).map((t) => t.id).toSet();
      expect(upcomingIds, {'track_2', 'track_3', 'track_4'});
    });

    testWidgets('reverseUpcomingOnly inverts upcoming songs sequence',
        (tester) async {
      fakeHandler.queue = [track1, track2, track3, track4];
      fakeHandler.index = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  AdvancedQueueController.reverseUpcomingOnly(ref);
                },
                child: const Text('Reverse Upcoming'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Reverse Upcoming'));
      await tester.pumpAndSettle();

      expect(fakeHandler.reverseUpcomingCalled, true);
      expect(fakeHandler.queue.length, 4);
      expect(fakeHandler.queue[0].id, 'track_1');
      expect(fakeHandler.queue[1].id, 'track_4');
      expect(fakeHandler.queue[2].id, 'track_3');
      expect(fakeHandler.queue[3].id, 'track_2');
    });

    testWidgets('instance methods and provider delegate properly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final controller = ref.read(advancedQueueControllerProvider);
              return ElevatedButton(
                onPressed: () {
                  controller.clearUpcomingQueue(ref);
                },
                child: const Text('Provider Clear'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Provider Clear'));
      await tester.pumpAndSettle();

      expect(fakeHandler.clearUpcomingCalled, true);
      expect(fakeHandler.queue.length, 1);
      expect(fakeHandler.queue.first.id, 'track_1');
    });
  });

  group('QueueQuickActionsBar Widget', () {
    testWidgets('renders Clear, Shuffle, and Reverse buttons correctly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
            queueProvider.overrideWith((ref) => Stream.value(fakeHandler.queue)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QueueQuickActionsBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(QueueQuickActionsBar), findsOneWidget);
      expect(find.text('Clear (2)'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Reverse'), findsOneWidget);
    });

    testWidgets('triggers Clear action and updates queue from widget',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
            queueProvider.overrideWith((ref) => Stream.value(fakeHandler.queue)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QueueQuickActionsBar(showFeedback: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear (2)'));
      await tester.pumpAndSettle();

      expect(fakeHandler.clearUpcomingCalled, true);
      expect(fakeHandler.queue.length, 1);
      expect(fakeHandler.queue[0].id, 'track_1');
    });

    testWidgets('triggers Reverse action from widget',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(fakeHandler),
            queueProvider.overrideWith((ref) => Stream.value(fakeHandler.queue)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QueueQuickActionsBar(showFeedback: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Reverse'));
      await tester.pumpAndSettle();

      expect(fakeHandler.reverseUpcomingCalled, true);
      expect(fakeHandler.queue[0].id, 'track_1');
      expect(fakeHandler.queue[1].id, 'track_3');
      expect(fakeHandler.queue[2].id, 'track_2');
    });
  });
}
