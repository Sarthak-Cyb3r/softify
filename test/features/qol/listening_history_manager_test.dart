import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/features/qol/listening_history_manager.dart';
import 'package:softify/presentation/providers/player_providers.dart';

class MockAudioHandler implements SoftifyAudioHandler {
  bool isPrivate = false;

  @override
  bool get isPrivateSession => isPrivate;

  @override
  set isPrivateSession(bool value) => isPrivate = value;

  @override
  void setPrivateSession(bool enabled) {
    isPrivate = enabled;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockLibraryRepository implements ILibraryRepository {
  bool clearHistoryCalled = false;

  @override
  Future<void> clearPlayHistory() async {
    clearHistoryCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivateListeningModeNotifier & Provider', () {
    test('defaults to false (not in private mode)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isPrivate = container.read(privateListeningModeProvider);
      expect(isPrivate, isFalse);
    });

    test('toggle() flips the state and syncs to SoftifyAudioHandler', () {
      final mockHandler = MockAudioHandler();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(mockHandler),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(privateListeningModeProvider.notifier);
      expect(container.read(privateListeningModeProvider), isFalse);
      expect(mockHandler.isPrivate, isFalse);

      final result1 = notifier.toggle();
      expect(result1, isTrue);
      expect(container.read(privateListeningModeProvider), isTrue);
      expect(mockHandler.isPrivate, isTrue);

      final result2 = notifier.toggle();
      expect(result2, isFalse);
      expect(container.read(privateListeningModeProvider), isFalse);
      expect(mockHandler.isPrivate, isFalse);
    });

    test('setEnabled, enable, disable explicitly control state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(privateListeningModeProvider.notifier);
      notifier.enable();
      expect(container.read(privateListeningModeProvider), isTrue);

      notifier.disable();
      expect(container.read(privateListeningModeProvider), isFalse);

      notifier.setEnabled(true);
      expect(container.read(privateListeningModeProvider), isTrue);
    });

    test('setter state allows direct assignment', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(privateListeningModeProvider.notifier).state = true;
      expect(container.read(privateListeningModeProvider), isTrue);

      container.read(privateListeningModeProvider.notifier).state = false;
      expect(container.read(privateListeningModeProvider), isFalse);
    });
  });

  group('ListeningHistoryManager', () {
    testWidgets('clearAllListeningHistory purges database history via repository',
        (tester) async {
      final mockRepo = MockLibraryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () => ListeningHistoryManager.clearAllListeningHistory(ref),
                  child: const Text('Clear'),
                );
              },
            ),
          ),
        ),
      );

      expect(mockRepo.clearHistoryCalled, isFalse);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(mockRepo.clearHistoryCalled, isTrue);
    });

    testWidgets('togglePrivateSession turns private mode on and off',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final isPrivate = ListeningHistoryManager.isPrivateSessionActive(ref);
                return Column(
                  children: [
                    Text('Status: ${isPrivate ? "Private" : "Public"}'),
                    ElevatedButton(
                      onPressed: () => ListeningHistoryManager.togglePrivateSession(ref),
                      child: const Text('Toggle'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Status: Public'), findsOneWidget);
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(find.text('Status: Private'), findsOneWidget);

      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(find.text('Status: Public'), findsOneWidget);
    });

    testWidgets('instance methods work identically to static methods',
        (tester) async {
      final mockRepo = MockLibraryRepository();
      const manager = ListeningHistoryManager();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final isPrivate = manager.isPrivateSessionActive(ref);
                return Column(
                  children: [
                    Text('Status: ${isPrivate ? "Private" : "Public"}'),
                    ElevatedButton(
                      onPressed: () {
                        manager.togglePrivateSession(ref);
                        manager.clearAllListeningHistory(ref);
                      },
                      child: const Text('Action'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Status: Public'), findsOneWidget);
      expect(mockRepo.clearHistoryCalled, isFalse);

      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();

      expect(find.text('Status: Private'), findsOneWidget);
      expect(mockRepo.clearHistoryCalled, isTrue);
    });
  });

  group('PrivateSessionBanner', () {
    testWidgets('is hidden (shrink) when private listening mode is inactive',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PrivateSessionBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Private Session'), findsNothing);
      expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    });

    testWidgets('displays discrete banner with End button when active',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privateListeningModeProvider.overrideWith((ref) {
              final notifier = PrivateListeningModeNotifier(ref: ref);
              notifier.enable();
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PrivateSessionBanner(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Private Session'), findsOneWidget);
      expect(find.text('Incognito'), findsOneWidget);
      expect(
        find.text('Playback history and taste profile recommendations are paused.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
    });

    testWidgets('tapping End button turns off private session',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privateListeningModeProvider.overrideWith((ref) {
              final notifier = PrivateListeningModeNotifier(ref: ref);
              notifier.enable();
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PrivateSessionBanner(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Private Session'), findsOneWidget);

      await tester.tap(find.text('End'));
      await tester.pumpAndSettle();

      // Once turned off, the banner collapses
      expect(find.text('Private Session'), findsNothing);
    });

    testWidgets('renders properly in compact mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privateListeningModeProvider.overrideWith((ref) {
              final notifier = PrivateListeningModeNotifier(ref: ref);
              notifier.enable();
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PrivateSessionBanner(compact: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Private Session Active'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tapping close in compact mode ends session
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Private Session Active'), findsNothing);
    });
  });

  group('PrivateSessionPillIndicator', () {
    testWidgets('hidden when public, visible when private, tapping toggles',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [
                  PrivateSessionPillIndicator(),
                ],
              ),
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => ListeningHistoryManager.togglePrivateSession(ref),
                    child: const Text('Toggle'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Private'), findsNothing);

      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      expect(find.text('Private'), findsOneWidget);

      // Tapping the pill indicator toggles off
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      expect(find.text('Private'), findsNothing);
    });
  });
}
