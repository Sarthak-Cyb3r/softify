// ============================================================================
// Softify - Quality of Life (QoL) Features
// Feature 52: Configurable Audio Lookahead Buffer Tests
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/network/lookahead_buffer_slider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  // ==========================================================================
  // 1. Pure Calculator Tests
  // ==========================================================================
  group('LookaheadBufferCalculator Tests', () {
    test('clampSeconds bounds values between 10s and 60s', () {
      expect(LookaheadBufferCalculator.clampSeconds(5), 10);
      expect(LookaheadBufferCalculator.clampSeconds(-10), 10);
      expect(LookaheadBufferCalculator.clampSeconds(10), 10);
      expect(LookaheadBufferCalculator.clampSeconds(30), 30);
      expect(LookaheadBufferCalculator.clampSeconds(45), 45);
      expect(LookaheadBufferCalculator.clampSeconds(60), 60);
      expect(LookaheadBufferCalculator.clampSeconds(75), 60);
      expect(LookaheadBufferCalculator.clampSeconds(999), 60);
    });

    test('estimateBufferBytes and estimateBufferMb calculate accurate RAM sizes', () {
      // 320 kbps = 40,000 bytes/sec
      final bytes10 = LookaheadBufferCalculator.estimateBufferBytes(10, bitrateKbps: 320);
      expect(bytes10, 400000);
      final mb10 = LookaheadBufferCalculator.estimateBufferMb(10, bitrateKbps: 320);
      expect(mb10, closeTo(0.38, 0.02));

      final bytes30 = LookaheadBufferCalculator.estimateBufferBytes(30, bitrateKbps: 320);
      expect(bytes30, 1200000);
      final mb30 = LookaheadBufferCalculator.estimateBufferMb(30, bitrateKbps: 320);
      expect(mb30, closeTo(1.14, 0.05));

      final bytes60 = LookaheadBufferCalculator.estimateBufferBytes(60, bitrateKbps: 320);
      expect(bytes60, 2400000);
      final mb60 = LookaheadBufferCalculator.estimateBufferMb(60, bitrateKbps: 320);
      expect(mb60, closeTo(2.28, 0.05));
    });

    test('calculateCoverageRatio returns accurate ratio bounded between 0.0 and 1.0', () {
      const target = Duration(seconds: 30);

      // Current == Buffered (no cushion)
      final zeroRatio = LookaheadBufferCalculator.calculateCoverageRatio(
        currentPosition: const Duration(seconds: 10),
        bufferedPosition: const Duration(seconds: 10),
        targetBuffer: target,
      );
      expect(zeroRatio, 0.0);

      // Buffered is behind current (underflow)
      final underflow = LookaheadBufferCalculator.calculateCoverageRatio(
        currentPosition: const Duration(seconds: 20),
        bufferedPosition: const Duration(seconds: 15),
        targetBuffer: target,
      );
      expect(underflow, 0.0);

      // Halfway buffered (15s ahead of 30s target)
      final halfRatio = LookaheadBufferCalculator.calculateCoverageRatio(
        currentPosition: const Duration(seconds: 10),
        bufferedPosition: const Duration(seconds: 25),
        targetBuffer: target,
      );
      expect(halfRatio, closeTo(0.5, 0.001));

      // Fully buffered (30s ahead of 30s target)
      final fullRatio = LookaheadBufferCalculator.calculateCoverageRatio(
        currentPosition: const Duration(seconds: 10),
        bufferedPosition: const Duration(seconds: 40),
        targetBuffer: target,
      );
      expect(fullRatio, 1.0);

      // Exceeded target buffer (clamps to 1.0)
      final overRatio = LookaheadBufferCalculator.calculateCoverageRatio(
        currentPosition: const Duration(seconds: 10),
        bufferedPosition: const Duration(seconds: 60),
        targetBuffer: target,
      );
      expect(overRatio, 1.0);

      // Zero targetBuffer returns 1.0
      expect(
        LookaheadBufferCalculator.calculateCoverageRatio(
          currentPosition: const Duration(seconds: 5),
          bufferedPosition: const Duration(seconds: 10),
          targetBuffer: Duration.zero,
        ),
        1.0,
      );
    });

    test('calculateCushion returns non-negative Duration', () {
      expect(
        LookaheadBufferCalculator.calculateCushion(
          currentPosition: const Duration(seconds: 10),
          bufferedPosition: const Duration(seconds: 25),
        ),
        const Duration(seconds: 15),
      );

      expect(
        LookaheadBufferCalculator.calculateCushion(
          currentPosition: const Duration(seconds: 25),
          bufferedPosition: const Duration(seconds: 10),
        ),
        Duration.zero,
      );
    });

    test('isBufferSufficient accurately flags threshold fulfillment', () {
      const target = Duration(seconds: 30);

      expect(
        LookaheadBufferCalculator.isBufferSufficient(
          currentPosition: const Duration(seconds: 10),
          bufferedPosition: const Duration(seconds: 20),
          targetBuffer: target,
        ),
        isFalse,
      );

      expect(
        LookaheadBufferCalculator.isBufferSufficient(
          currentPosition: const Duration(seconds: 10),
          bufferedPosition: const Duration(seconds: 40),
          targetBuffer: target,
        ),
        isTrue,
      );
    });

    test('matchPreset recognizes exact presets', () {
      expect(LookaheadBufferCalculator.matchPreset(10), LookaheadPreset.minimal);
      expect(LookaheadBufferCalculator.matchPreset(30), LookaheadPreset.standard);
      expect(LookaheadBufferCalculator.matchPreset(45), LookaheadPreset.transit);
      expect(LookaheadBufferCalculator.matchPreset(60), LookaheadPreset.subway);
      expect(LookaheadBufferCalculator.matchPreset(25), isNull);
    });

    test('getRecommendation returns informative advice', () {
      expect(LookaheadBufferCalculator.getRecommendation(10), contains('Instant playback'));
      expect(LookaheadBufferCalculator.getRecommendation(30), contains('Standard balanced'));
      expect(LookaheadBufferCalculator.getRecommendation(45), contains('Extended buffer'));
      expect(LookaheadBufferCalculator.getRecommendation(60), contains('Maximum preloading'));
    });
  });

  // ==========================================================================
  // 2. State & Model Tests
  // ==========================================================================
  group('LookaheadBufferState Model Tests', () {
    test('default state values', () {
      const state = LookaheadBufferState();
      expect(state.bufferSeconds, 30);
      expect(state.bufferDuration, const Duration(seconds: 30));
      expect(state.isSubwayMode, isFalse);
      expect(state.isDefault, isTrue);
      expect(state.isMin, isFalse);
      expect(state.isMax, isFalse);
      expect(state.formattedDuration, '30s');
      expect(state.currentPreset, LookaheadPreset.standard);
    });

    test('isMin and isMax flags', () {
      const minState = LookaheadBufferState(bufferSeconds: 10);
      expect(minState.isMin, isTrue);
      expect(minState.isMax, isFalse);

      const maxState = LookaheadBufferState(bufferSeconds: 60);
      expect(maxState.isMin, isFalse);
      expect(maxState.isMax, isTrue);
    });

    test('copyWith works correctly', () {
      const initial = LookaheadBufferState(bufferSeconds: 30);
      final updated = initial.copyWith(
        bufferSeconds: 45,
        isSubwayMode: true,
        previousNonSubwaySeconds: 30,
      );

      expect(updated.bufferSeconds, 45);
      expect(updated.isSubwayMode, isTrue);
      expect(updated.previousNonSubwaySeconds, 30);
    });

    test('equality and hashCode contract', () {
      const state1 = LookaheadBufferState(bufferSeconds: 30, isSubwayMode: false);
      const state2 = LookaheadBufferState(bufferSeconds: 30, isSubwayMode: false);
      const state3 = LookaheadBufferState(bufferSeconds: 60, isSubwayMode: true);

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1, isNot(equals(state3)));
    });
  });

  // ==========================================================================
  // 3. Notifier & Provider Tests
  // ==========================================================================
  group('LookaheadBufferNotifier & Riverpod Providers Tests', () {
    test('initial state defaults to 30s', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(lookaheadBufferProvider);
      expect(state.bufferSeconds, 30);
      expect(state.isSubwayMode, isFalse);
      expect(container.read(lookaheadBufferSecondsProvider), 30);
      expect(container.read(lookaheadBufferDurationProvider), const Duration(seconds: 30));
      expect(container.read(isSubwayModeEnabledProvider), isFalse);
    });

    test('setBufferSeconds updates duration and clamps limits', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lookaheadBufferProvider.notifier);

      await notifier.setBufferSeconds(45);
      expect(container.read(lookaheadBufferSecondsProvider), 45);
      expect(container.read(lookaheadBufferDurationProvider), const Duration(seconds: 45));

      // Underflow clamped to 10
      await notifier.setBufferSeconds(2);
      expect(container.read(lookaheadBufferSecondsProvider), 10);

      // Overflow clamped to 60
      await notifier.setBufferSeconds(120);
      expect(container.read(lookaheadBufferSecondsProvider), 60);
    });

    test('setBufferDuration accepts Duration', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lookaheadBufferProvider.notifier);
      await notifier.setBufferDuration(const Duration(seconds: 25));
      expect(container.read(lookaheadBufferSecondsProvider), 25);
    });

    test('toggleSubwayMode switches between 60s and restores prior buffer', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lookaheadBufferProvider.notifier);
      await notifier.setBufferSeconds(20);
      expect(container.read(lookaheadBufferSecondsProvider), 20);

      // Enable subway mode
      await notifier.toggleSubwayMode();
      expect(container.read(lookaheadBufferSecondsProvider), 60);
      expect(container.read(isSubwayModeEnabledProvider), isTrue);

      // Disable subway mode restores 20s
      await notifier.toggleSubwayMode();
      expect(container.read(lookaheadBufferSecondsProvider), 20);
      expect(container.read(isSubwayModeEnabledProvider), isFalse);
    });

    test('applyPreset updates buffer accordingly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lookaheadBufferProvider.notifier);

      await notifier.applyPreset(LookaheadPreset.minimal);
      expect(container.read(lookaheadBufferSecondsProvider), 10);

      await notifier.applyPreset(LookaheadPreset.transit);
      expect(container.read(lookaheadBufferSecondsProvider), 45);

      await notifier.applyPreset(LookaheadPreset.subway);
      expect(container.read(lookaheadBufferSecondsProvider), 60);
      expect(container.read(isSubwayModeEnabledProvider), isTrue);
    });

    test('stepIncrease and stepDecrease modify buffer by step', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lookaheadBufferProvider.notifier);

      await notifier.stepIncrease(5);
      expect(container.read(lookaheadBufferSecondsProvider), 35);

      await notifier.stepDecrease(10);
      expect(container.read(lookaheadBufferSecondsProvider), 25);
    });

    test('resetToDefault restores 30s and clears subway mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lookaheadBufferProvider.notifier);
      await notifier.setSubwayMode(true);
      expect(container.read(lookaheadBufferSecondsProvider), 60);

      await notifier.resetToDefault();
      expect(container.read(lookaheadBufferSecondsProvider), 30);
      expect(container.read(isSubwayModeEnabledProvider), isFalse);
    });

    test('persists buffer settings to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lookaheadBufferProvider.notifier);
      await notifier.setBufferSeconds(50);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kLookaheadBufferPrefKey), 50);

      // New container restores persisted preference
      final newContainer = ProviderContainer();
      addTearDown(newContainer.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(newContainer.read(lookaheadBufferSecondsProvider), 50);
    });

    test('lookaheadCoverageProvider calculates live coverage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coverage = container.read(
        lookaheadCoverageProvider((
          current: const Duration(seconds: 10),
          buffered: const Duration(seconds: 25),
        )),
      );

      // Default target = 30s. Cushion = 15s. 15 / 30 = 0.5
      expect(coverage, closeTo(0.5, 0.001));
    });
  });

  // ==========================================================================
  // 4. Widget Tests: LookaheadBufferSlider
  // ==========================================================================
  group('LookaheadBufferSlider Widget Tests', () {
    testWidgets('renders slider, duration badge, indicators, and preset chips', (tester) async {
      SharedPreferences.setMockInitialValues({
        kLookaheadBufferPrefKey: 30,
      });

      int? changedValue;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LookaheadBufferSlider(
                showHeader: true,
                showPresets: true,
                showSecondIndicators: true,
                onChanged: (val) => changedValue = val,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verified presence of header, live badge, slider, track markers, and presets
      expect(find.text('Lookahead Duration'), findsOneWidget);
      expect(find.text('30s'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('10s (Min)'), findsOneWidget);
      expect(find.text('30s (Default)'), findsOneWidget);
      expect(find.text('60s (Subway)'), findsOneWidget);

      expect(find.text('10s Minimal'), findsOneWidget);
      expect(find.text('30s Default'), findsOneWidget);
      expect(find.text('45s Transit'), findsOneWidget);
      expect(find.text('60s Subway'), findsOneWidget);

      // Tap preset chip '45s Transit'
      await tester.tap(find.text('45s Transit'));
      await tester.pump();

      expect(changedValue, 45);
      expect(find.text('45s'), findsWidgets);
    });
  });

  // ==========================================================================
  // 5. Widget Tests: LookaheadBufferSliderCard
  // ==========================================================================
  group('LookaheadBufferSliderCard Widget Tests', () {
    testWidgets('renders card with header, subway mode switch, slider, and telemetry', (tester) async {
      SharedPreferences.setMockInitialValues({
        kLookaheadBufferPrefKey: 30,
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LookaheadBufferSliderCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Card Header
      expect(find.text('Audio Lookahead Buffer'), findsOneWidget);
      expect(
        find.text('Pre-buffer audio stream to prevent stuttering in low-connectivity areas & subways'),
        findsOneWidget,
      );

      // Subway Mode Quick Toggle Switch
      expect(find.text('Subway & Tunnel Mode (60s Max)'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Slider present
      expect(find.byType(Slider), findsOneWidget);

      // Telemetry & Info Box
      expect(find.text('Buffer Telemetry & Advice'), findsOneWidget);
      expect(find.textContaining('RAM @ 320k'), findsOneWidget);

      // Toggle Subway Mode
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Now subway mode is active (60s)
      expect(find.text('60s SUBWAY'), findsOneWidget);

      // Reset button should now be visible since buffer is 60s
      expect(find.text('Reset to default (30s)'), findsOneWidget);

      // Tap Reset button
      await tester.tap(find.text('Reset to default (30s)'));
      await tester.pump();

      expect(find.text('30s'), findsWidgets);
      expect(find.text('Reset to default (30s)'), findsNothing);
    });
  });

  // ==========================================================================
  // 6. Widget Tests: LookaheadBufferCoverageBar
  // ==========================================================================
  group('LookaheadBufferCoverageBar Widget Tests', () {
    testWidgets('renders cushion duration and coverage percentage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LookaheadBufferCoverageBar(
              currentPosition: Duration(seconds: 10),
              bufferedPosition: Duration(seconds: 25),
              targetBuffer: Duration(seconds: 30),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Buffered Cushion: 15s / 30s'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });
  });
}
