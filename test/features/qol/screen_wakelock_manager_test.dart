import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/screen_wakelock_manager.dart';

class MockWakelockPlatformHandler extends WakelockPlatformHandler {
  final List<bool> lockCalls = [];

  @override
  Future<bool> setKeepAwake(bool enable) async {
    lockCalls.add(enable);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenWakelockState logic', () {
    test('Default state has all modes enabled and no active locks', () {
      const state = ScreenWakelockState();
      expect(state.isMasterEnabled, isTrue);
      expect(state.keepAwakeFullscreen, isTrue);
      expect(state.keepAwakeLyrics, isTrue);
      expect(state.keepAwakeCarMode, isTrue);
      expect(state.activeModes, isEmpty);
      expect(state.shouldBeAwake, isFalse);
    });

    test('shouldBeAwake is true when an allowed mode is active', () {
      const state = ScreenWakelockState(
        isMasterEnabled: true,
        keepAwakeFullscreen: true,
        activeModes: {WakelockMode.fullscreenPlayer},
      );
      expect(state.shouldBeAwake, isTrue);
    });

    test('shouldBeAwake is false when master switch is disabled', () {
      const state = ScreenWakelockState(
        isMasterEnabled: false,
        keepAwakeFullscreen: true,
        activeModes: {WakelockMode.fullscreenPlayer},
      );
      expect(state.shouldBeAwake, isFalse);
    });

    test('shouldBeAwake is false when specific active mode is disabled', () {
      const state = ScreenWakelockState(
        isMasterEnabled: true,
        keepAwakeFullscreen: false,
        activeModes: {WakelockMode.fullscreenPlayer},
      );
      expect(state.shouldBeAwake, isFalse);
    });

    test('Multiple active modes evaluate correctly', () {
      const state = ScreenWakelockState(
        isMasterEnabled: true,
        keepAwakeFullscreen: false,
        keepAwakeLyrics: true,
        activeModes: {WakelockMode.fullscreenPlayer, WakelockMode.lyricsMode},
      );
      expect(state.shouldBeAwake, isTrue);
    });
  });

  group('ScreenWakelockManager operations', () {
    test('Acquire and release update state and sync with platform handler', () async {
      final mockPlatform = MockWakelockPlatformHandler();
      final manager = ScreenWakelockManager(null, mockPlatform);

      expect(manager.state.activeModes, isEmpty);
      expect(manager.state.isLocked, isFalse);

      manager.acquire(WakelockMode.fullscreenPlayer);
      expect(manager.state.activeModes.contains(WakelockMode.fullscreenPlayer), isTrue);
      expect(manager.state.isLocked, isTrue);
      expect(mockPlatform.lockCalls.last, isTrue);

      manager.acquire(WakelockMode.lyricsMode);
      expect(manager.state.activeModes.length, 2);
      expect(manager.state.isLocked, isTrue);

      manager.release(WakelockMode.fullscreenPlayer);
      expect(manager.state.activeModes.contains(WakelockMode.fullscreenPlayer), isFalse);
      expect(manager.state.activeModes.contains(WakelockMode.lyricsMode), isTrue);
      expect(manager.state.isLocked, isTrue);

      manager.release(WakelockMode.lyricsMode);
      expect(manager.state.activeModes, isEmpty);
      expect(manager.state.isLocked, isFalse);
      expect(mockPlatform.lockCalls.last, isFalse);

      manager.dispose();
    });

    test('Disabling master while modes active releases wake lock', () async {
      final mockPlatform = MockWakelockPlatformHandler();
      final manager = ScreenWakelockManager(null, mockPlatform);

      manager.acquire(WakelockMode.carMode);
      expect(manager.state.isLocked, isTrue);

      await manager.setMasterEnabled(false);
      expect(manager.state.isMasterEnabled, isFalse);
      expect(manager.state.isLocked, isFalse);
      expect(mockPlatform.lockCalls.last, isFalse);

      await manager.setMasterEnabled(true);
      expect(manager.state.isMasterEnabled, isTrue);
      expect(manager.state.isLocked, isTrue);
      expect(mockPlatform.lockCalls.last, isTrue);

      manager.dispose();
    });

    test('Disabling specific mode releases wake lock if it was the only active mode', () async {
      final mockPlatform = MockWakelockPlatformHandler();
      final manager = ScreenWakelockManager(null, mockPlatform);

      manager.acquire(WakelockMode.lyricsMode);
      expect(manager.state.isLocked, isTrue);

      await manager.setLyricsEnabled(false);
      expect(manager.state.keepAwakeLyrics, isFalse);
      expect(manager.state.isLocked, isFalse);
      expect(mockPlatform.lockCalls.last, isFalse);

      manager.dispose();
    });
  });

  group('ScreenWakelockScope widget', () {
    testWidgets('acquires lock on mount and releases on unmount', (tester) async {
      final mockPlatform = MockWakelockPlatformHandler();
      final manager = ScreenWakelockManager(null, mockPlatform);

      final container = ProviderContainer(
        overrides: [
          screenWakelockProvider.overrideWith((ref) => manager),
        ],
      );

      final showScope = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: showScope,
              builder: (context, show, _) {
                if (!show) return const SizedBox();
                return const ScreenWakelockScope(
                  mode: WakelockMode.fullscreenPlayer,
                  child: Text('In Fullscreen'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(manager.state.activeModes.contains(WakelockMode.fullscreenPlayer), isTrue);
      expect(manager.state.isLocked, isTrue);

      showScope.value = false;
      await tester.pump();

      expect(manager.state.activeModes.contains(WakelockMode.fullscreenPlayer), isFalse);
      expect(manager.state.isLocked, isFalse);

      container.dispose();
    });
  });

  group('ScreenWakelockTile widget', () {
    testWidgets('renders tile and toggles master switch', (tester) async {
      final mockPlatform = MockWakelockPlatformHandler();
      final manager = ScreenWakelockManager(null, mockPlatform);

      final container = ProviderContainer(
        overrides: [
          screenWakelockProvider.overrideWith((ref) => manager),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ScreenWakelockTile(isCard: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Keep Screen Awake'), findsOneWidget);

      // Find the master switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Toggle off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(manager.state.isMasterEnabled, isFalse);

      container.dispose();
    });
  });
}
