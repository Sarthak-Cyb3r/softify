import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/features/qol/queue/desktop_lock_pause_listener.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/theme/app_tokens.dart';

// ============================================================================
// Test Doubles & Mocks
// ============================================================================

class FakeSoftifyAudioHandler extends Fake implements SoftifyAudioHandler {
  final BehaviorSubject<PlaybackState> _stateSubject =
      BehaviorSubject<PlaybackState>.seeded(
    PlaybackState(
      playing: true,
      processingState: AudioProcessingState.ready,
    ),
  );

  bool pauseCalled = false;
  bool playCalled = false;
  int pauseCallCount = 0;
  int playCallCount = 0;

  @override
  BehaviorSubject<PlaybackState> get playbackState => _stateSubject;

  void setPlaying(bool playing) {
    _stateSubject.add(_stateSubject.value.copyWith(playing: playing));
  }

  @override
  Future<void> pause() async {
    pauseCalled = true;
    pauseCallCount++;
    setPlaying(false);
  }

  @override
  Future<void> play() async {
    playCalled = true;
    playCallCount++;
    setPlaying(true);
  }

  void reset() {
    pauseCalled = false;
    playCalled = false;
    pauseCallCount = 0;
    playCallCount = 0;
    setPlaying(true);
  }
}

// ============================================================================
// Main Test Suite
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ==========================================================================
  // Group 1: SharedPreferences Persistence Engine
  // ==========================================================================
  group('DesktopLockPause: SharedPreferences Engine', () {
    test('stores and retrieves boolean values', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kDesktopAutoPauseOnLockPrefKey), isNull);

      await prefs.setBool(kDesktopAutoPauseOnLockPrefKey, true);
      expect(prefs.getBool(kDesktopAutoPauseOnLockPrefKey), isTrue);

      await prefs.setBool(kDesktopAutoPauseOnLockPrefKey, false);
      expect(prefs.getBool(kDesktopAutoPauseOnLockPrefKey), isFalse);

      await prefs.remove(kDesktopAutoPauseOnLockPrefKey);
      expect(prefs.getBool(kDesktopAutoPauseOnLockPrefKey), isNull);
    });

    test('initializes with mock values accurately', () async {
      SharedPreferences.setMockInitialValues({
        kDesktopAutoPauseOnLockPrefKey: false,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kDesktopAutoPauseOnLockPrefKey), isFalse);
    });
  });

  // ==========================================================================
  // Group 2: AutoPauseOnLockNotifier (Riverpod Preference)
  // ==========================================================================
  group('DesktopLockPause: AutoPauseOnLockNotifier', () {
    test('defaults to true when no preference is stored', () {
      final notifier = AutoPauseOnLockNotifier();
      expect(notifier.state, isTrue);
      expect(notifier.isEnabled, isTrue);
    });

    test('toggles preference between true and false', () async {
      final notifier = AutoPauseOnLockNotifier();
      expect(notifier.state, isTrue);

      await notifier.toggle();
      expect(notifier.state, isFalse);

      await notifier.toggle();
      expect(notifier.state, isTrue);
    });

    test('setEnabled persists value to SharedPreferences', () async {
      final notifier = AutoPauseOnLockNotifier();

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kDesktopAutoPauseOnLockPrefKey), isFalse);

      await notifier.setEnabled(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool(kDesktopAutoPauseOnLockPrefKey), isTrue);
    });

    test('loads stored preference on initialization', () async {
      SharedPreferences.setMockInitialValues({
        kDesktopAutoPauseOnLockPrefKey: false,
      });

      final notifier = AutoPauseOnLockNotifier();
      // Allow async _loadPreference microtask to resolve
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, isFalse);
    });
  });

  // ==========================================================================
  // Group 3: Models & State Objects
  // ==========================================================================
  group('DesktopLockPause: Models & State', () {
    test('DesktopSessionEvent holds correct values and properties', () {
      final now = DateTime.now();
      final event = DesktopSessionEvent(
        type: DesktopSessionEventType.lock,
        timestamp: now,
        source: 'org.freedesktop.ScreenSaver',
        metadata: {'active': true},
      );

      expect(event.type, equals(DesktopSessionEventType.lock));
      expect(event.source, equals('org.freedesktop.ScreenSaver'));
      expect(event.metadata['active'], isTrue);
      expect(event.type.isLockOrSleep, isTrue);
      expect(event.type.isUnlockOrResume, isFalse);
      expect(event.toString(), contains('lock'));
    });

    test('DesktopSessionEventType properties', () {
      expect(DesktopSessionEventType.lock.isLockOrSleep, isTrue);
      expect(DesktopSessionEventType.sleep.isLockOrSleep, isTrue);
      expect(DesktopSessionEventType.unlock.isUnlockOrResume, isTrue);
      expect(DesktopSessionEventType.resume.isUnlockOrResume, isTrue);
    });

    test('DesktopLockPauseReason labels and descriptions', () {
      expect(DesktopLockPauseReason.screenLocked.label, equals('Screen Locked'));
      expect(DesktopLockPauseReason.powerSleep.label, equals('System Sleep'));
      expect(DesktopLockPauseReason.sessionLocked.label, equals('Session Locked'));
      expect(DesktopLockPauseReason.manualSimulation.label, equals('Manual Simulation'));
    });

    test('DesktopLockPauseState defaults and copyWith', () {
      const state = DesktopLockPauseState();
      expect(state.autoPauseOnLock, isTrue);
      expect(state.autoResumeOnUnlock, isFalse);
      expect(state.isLocked, isFalse);
      expect(state.isSleeping, isFalse);
      expect(state.wasPlayingBeforePause, isFalse);
      expect(state.pauseTriggerCount, equals(0));
      expect(state.isSuspendedOrLocked, isFalse);

      final updated = state.copyWith(
        isLocked: true,
        pauseTriggerCount: 3,
        lastPauseReason: DesktopLockPauseReason.screenLocked,
      );

      expect(updated.isLocked, isTrue);
      expect(updated.pauseTriggerCount, equals(3));
      expect(updated.isSuspendedOrLocked, isTrue);
      expect(updated.lastPauseReason, equals(DesktopLockPauseReason.screenLocked));
    });

    test('DesktopLockPauseState equality and hashCode', () {
      const state1 = DesktopLockPauseState(autoPauseOnLock: true, isLocked: true);
      const state2 = DesktopLockPauseState(autoPauseOnLock: true, isLocked: true);
      const state3 = DesktopLockPauseState(autoPauseOnLock: false, isLocked: true);

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1, isNot(equals(state3)));
    });
  });

  // ==========================================================================
  // Group 4: DesktopLockPauseController
  // ==========================================================================
  group('DesktopLockPause: DesktopLockPauseController', () {
    test('updates state on session events', () {
      final controller = DesktopLockPauseController();

      controller.updateSessionEvent(
        DesktopSessionEvent(type: DesktopSessionEventType.lock),
      );
      expect(controller.state.isLocked, isTrue);
      expect(controller.state.isSuspendedOrLocked, isTrue);

      controller.updateSessionEvent(
        DesktopSessionEvent(type: DesktopSessionEventType.unlock),
      );
      expect(controller.state.isLocked, isFalse);

      controller.updateSessionEvent(
        DesktopSessionEvent(type: DesktopSessionEventType.sleep),
      );
      expect(controller.state.isSleeping, isTrue);
      expect(controller.state.isSuspendedOrLocked, isTrue);

      controller.updateSessionEvent(
        DesktopSessionEvent(type: DesktopSessionEventType.resume),
      );
      expect(controller.state.isSleeping, isFalse);
    });

    test('recordPauseTriggered updates count and wasPlaying flag', () {
      final controller = DesktopLockPauseController();
      expect(controller.state.pauseTriggerCount, equals(0));

      controller.recordPauseTriggered(
        reason: DesktopLockPauseReason.screenLocked,
        wasPlaying: true,
      );
      expect(controller.state.pauseTriggerCount, equals(1));
      expect(controller.state.wasPlayingBeforePause, isTrue);
      expect(controller.state.lastPauseReason, equals(DesktopLockPauseReason.screenLocked));

      controller.recordPlaybackResumed();
      expect(controller.state.wasPlayingBeforePause, isFalse);
    });

    test('resetCounters clears counts and errors', () {
      final controller = DesktopLockPauseController();
      controller.recordPauseTriggered(
        reason: DesktopLockPauseReason.powerSleep,
        wasPlaying: true,
      );
      controller.setListening(true, error: 'DBus transient fault');

      controller.resetCounters();
      expect(controller.state.pauseTriggerCount, equals(0));
      expect(controller.state.lastError, isNull);
    });
  });

  // ==========================================================================
  // Group 5: DesktopLockPauseListener Core Engine
  // ==========================================================================
  group('DesktopLockPause: DesktopLockPauseListener Logic', () {
    late FakeSoftifyAudioHandler fakeAudioHandler;
    late AutoPauseOnLockNotifier preferenceNotifier;
    late DesktopLockPauseController controller;
    late DesktopLockPauseListener listener;

    setUp(() {
      fakeAudioHandler = FakeSoftifyAudioHandler();
      preferenceNotifier = AutoPauseOnLockNotifier();
      controller = DesktopLockPauseController();

      listener = DesktopLockPauseListener(
        audioHandler: fakeAudioHandler,
        preferenceNotifier: preferenceNotifier,
        controller: controller,
      );
    });

    tearDown(() {
      listener.dispose();
    });

    test('pauses playback when screen is locked and music is playing', () async {
      expect(fakeAudioHandler.playbackState.value.playing, isTrue);
      expect(listener.pauseTriggerCount, equals(0));

      await listener.simulateLock();

      expect(fakeAudioHandler.pauseCalled, isTrue);
      expect(fakeAudioHandler.playbackState.value.playing, isFalse);
      expect(listener.pauseTriggerCount, equals(1));
      expect(listener.wasPlayingBeforePause, isTrue);
      expect(controller.state.isLocked, isTrue);
      expect(controller.state.lastPauseReason, equals(DesktopLockPauseReason.screenLocked));
    });

    test('pauses playback when system enters sleep/suspend', () async {
      expect(fakeAudioHandler.playbackState.value.playing, isTrue);

      await listener.simulateSleep();

      expect(fakeAudioHandler.pauseCalled, isTrue);
      expect(fakeAudioHandler.playbackState.value.playing, isFalse);
      expect(listener.pauseTriggerCount, equals(1));
      expect(controller.state.isSleeping, isTrue);
      expect(controller.state.lastPauseReason, equals(DesktopLockPauseReason.powerSleep));
    });

    test('does NOT pause playback when autoPauseOnLock is disabled', () async {
      await preferenceNotifier.setEnabled(false);

      await listener.simulateLock();

      expect(fakeAudioHandler.pauseCalled, isFalse);
      expect(fakeAudioHandler.playbackState.value.playing, isTrue);
      expect(listener.pauseTriggerCount, equals(0));
    });

    test('does NOT trigger pause if audio is already paused', () async {
      fakeAudioHandler.setPlaying(false);

      await listener.simulateLock();

      expect(fakeAudioHandler.pauseCalled, isFalse);
      expect(listener.wasPlayingBeforePause, isFalse);
      expect(listener.pauseTriggerCount, equals(0));
    });

    test('emits observed events to eventStream broadcast', () async {
      final events = <DesktopSessionEvent>[];
      final subscription = listener.eventStream.listen(events.add);

      await listener.simulateLock();
      await listener.simulateUnlock();
      await listener.simulateSleep();
      await listener.simulateResume();

      // Small tick for event loop delivery
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(events.length, equals(4));
      expect(events[0].type, equals(DesktopSessionEventType.lock));
      expect(events[1].type, equals(DesktopSessionEventType.unlock));
      expect(events[2].type, equals(DesktopSessionEventType.sleep));
      expect(events[3].type, equals(DesktopSessionEventType.resume));

      await subscription.cancel();
    });

    test('supports auto-resume on unlock when enabled', () async {
      await controller.setAutoResumeOnUnlock(true);

      // 1. Lock occurs while playing -> pauses
      await listener.simulateLock();
      expect(fakeAudioHandler.pauseCalled, isTrue);
      expect(fakeAudioHandler.playbackState.value.playing, isFalse);

      // 2. Unlock occurs -> automatically resumes
      await listener.simulateUnlock();
      expect(fakeAudioHandler.playCalled, isTrue);
      expect(fakeAudioHandler.playbackState.value.playing, isTrue);
    });

    test('custom callbacks hook functions without audioHandler', () async {
      bool customPauseFired = false;
      bool customResumeFired = false;

      final customListener = DesktopLockPauseListener(
        isPlayingQuery: () async => true,
        onPauseCallback: () async {
          customPauseFired = true;
        },
        onResumeCallback: () async {
          customResumeFired = true;
        },
      );

      await customListener.simulateLock();
      expect(customPauseFired, isTrue);

      customListener.dispose();
    });

    test('startListening returns true and starts simulation mode gracefully', () async {
      final result = await listener.startListening();
      expect(result, isTrue);
      expect(listener.isListening, isTrue);

      await listener.stopListening();
      expect(listener.isListening, isFalse);
    });
  });

  // ==========================================================================
  // Group 6: DesktopLockPauseToggleTile Widget Tests
  // ==========================================================================
  group('DesktopLockPause: DesktopLockPauseToggleTile Widget', () {
    testWidgets('renders with default labels and switch enabled', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopLockPauseToggleTile(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Auto-Pause on Lock / Sleep'), findsOneWidget);
      expect(
        find.text('Music pauses automatically when your computer locks or goes to sleep'),
        findsOneWidget,
      );

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('toggles switch and invokes onToggled callback when clicked', (tester) async {
      bool? toggledValue;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopLockPauseToggleTile(
                onToggled: (val) {
                  toggledValue = val;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(toggledValue, isFalse);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      expect(
        find.text('Music continues playing even when the desktop is locked or sleeping'),
        findsOneWidget,
      );
    });

    testWidgets('tapping entire tile toggles preference', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopLockPauseToggleTile(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the tile InkWell
      await tester.tap(find.text('Auto-Pause on Lock / Sleep'));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('renders custom title, subtitle, icon, and status badge', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopLockPauseToggleTile(
                title: 'Custom Session Pause',
                subtitle: 'Custom Subtitle Description',
                icon: Icons.power_settings_new_rounded,
                showStatusBadge: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Custom Session Pause'), findsOneWidget);
      expect(find.text('Custom Subtitle Description'), findsOneWidget);
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('respects overridden initial state in ProviderScope', (tester) async {
      final mockNotifier = AutoPauseOnLockNotifier(null, false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autoPauseOnLockProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DesktopLockPauseToggleTile(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });
  });
}
