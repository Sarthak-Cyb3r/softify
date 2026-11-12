// ============================================================================
// Unit & Widget Tests: Feature 8 - True Dual-Engine Overlapping Crossfade
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/features/qol/dsp/true_crossfade_engine.dart';

void main() {
  setUp(() {
    TrueCrossfadePrefs.setMockInitialValues({});
  });

  tearDown(() {
    TrueCrossfadePrefs.resetForTesting();
  });

  // ==========================================================================
  // Group 1: Mathematical DSP Foundations & Constant Power Preservation
  // ==========================================================================
  group('CrossfadeMath Equal-Power DSP Tests', () {
    test('at progress 0.0: V_out = 1.0, V_in = 0.0, totalPower = 1.0', () {
      final vOut = CrossfadeMath.equalPowerOut(0.0);
      final vIn = CrossfadeMath.equalPowerIn(0.0);
      final power = CrossfadeMath.computeTotalPower(vOut, vIn);

      expect(vOut, closeTo(1.0, 1e-9));
      expect(vIn, closeTo(0.0, 1e-9));
      expect(power, closeTo(1.0, 1e-9));
    });

    test('at progress 0.5 (exact midpoint): V_out = sqrt(2)/2, V_in = sqrt(2)/2', () {
      final vOut = CrossfadeMath.equalPowerOut(0.5);
      final vIn = CrossfadeMath.equalPowerIn(0.5);
      final expectedSqrt2Over2 = math.sqrt(2) / 2; // ~0.70710678

      expect(vOut, closeTo(expectedSqrt2Over2, 1e-6));
      expect(vIn, closeTo(expectedSqrt2Over2, 1e-6));

      // Constant acoustic energy: cos^2(pi/4) + sin^2(pi/4) == 0.5 + 0.5 == 1.0
      final power = CrossfadeMath.computeTotalPower(vOut, vIn);
      expect(power, closeTo(1.0, 1e-6));

      // Decibel drop per channel is exactly -3.01 dB
      final dbOut = CrossfadeMath.toDecibels(vOut);
      final dbIn = CrossfadeMath.toDecibels(vIn);
      expect(dbOut, closeTo(-3.0103, 1e-2));
      expect(dbIn, closeTo(-3.0103, 1e-2));

      // Overall acoustic power fluctuation is 0.0 dB
      expect(CrossfadeMath.powerFluxDb(power), closeTo(0.0, 1e-4));
    });

    test('at progress 1.0: V_out = 0.0, V_in = 1.0, totalPower = 1.0', () {
      final vOut = CrossfadeMath.equalPowerOut(1.0);
      final vIn = CrossfadeMath.equalPowerIn(1.0);
      final power = CrossfadeMath.computeTotalPower(vOut, vIn);

      expect(vOut, closeTo(0.0, 1e-9));
      expect(vIn, closeTo(1.0, 1e-9));
      expect(power, closeTo(1.0, 1e-9));
    });

    test('constant-power preservation: P_tot == 1.0 across all 21 sampled points', () {
      // Validates V_out^2 + V_in^2 = 1.00000 across entire transition range
      for (int i = 0; i <= 20; i++) {
        final progress = i / 20.0;
        final vOut = CrossfadeMath.equalPowerOut(progress);
        final vIn = CrossfadeMath.equalPowerIn(progress);
        final totalPower = CrossfadeMath.computeTotalPower(vOut, vIn);

        expect(
          totalPower,
          closeTo(1.0, 1e-6),
          reason: 'Failed equal-power conservation at progress: $progress',
        );
        expect(CrossfadeMath.powerFluxDb(totalPower), closeTo(0.0, 1e-4));
      }
    });

    test('linear crossfade demonstrates ~3dB power dip at center (P = 0.50)', () {
      final vOut = CrossfadeMath.linearOut(0.5);
      final vIn = CrossfadeMath.linearIn(0.5);
      final power = CrossfadeMath.computeTotalPower(vOut, vIn);

      expect(vOut, closeTo(0.5, 1e-9));
      expect(vIn, closeTo(0.5, 1e-9));
      // Linear midpoint has only 50% power (-3.01 dB dip!)
      expect(power, closeTo(0.5, 1e-9));
      expect(CrossfadeMath.powerFluxDb(power), closeTo(-3.0103, 1e-2));
    });

    test('smoothstep S-curve endpoints and midpoint behavior', () {
      expect(CrossfadeMath.sCurveOut(0.0), closeTo(1.0, 1e-9));
      expect(CrossfadeMath.sCurveIn(0.0), closeTo(0.0, 1e-9));

      expect(CrossfadeMath.sCurveOut(0.5), closeTo(0.5, 1e-9));
      expect(CrossfadeMath.sCurveIn(0.5), closeTo(0.5, 1e-9));

      expect(CrossfadeMath.sCurveOut(1.0), closeTo(0.0, 1e-9));
      expect(CrossfadeMath.sCurveIn(1.0), closeTo(1.0, 1e-9));
    });

    test('toDecibels and fromDecibels conversion accuracy', () {
      expect(CrossfadeMath.toDecibels(1.0), closeTo(0.0, 1e-6));
      expect(CrossfadeMath.toDecibels(0.1), closeTo(-20.0, 1e-2));
      expect(CrossfadeMath.toDecibels(0.01), closeTo(-40.0, 1e-2));
      expect(CrossfadeMath.toDecibels(0.0), equals(-60.0)); // floor

      expect(CrossfadeMath.fromDecibels(0.0), closeTo(1.0, 1e-6));
      expect(CrossfadeMath.fromDecibels(-20.0), closeTo(0.1, 1e-4));
    });

    test('clamping guards against out-of-bounds input', () {
      expect(CrossfadeMath.equalPowerOut(-0.5), closeTo(1.0, 1e-6));
      expect(CrossfadeMath.equalPowerIn(-0.5), closeTo(0.0, 1e-6));
      expect(CrossfadeMath.equalPowerOut(1.5), closeTo(0.0, 1e-6));
      expect(CrossfadeMath.equalPowerIn(1.5), closeTo(1.0, 1e-6));
    });
  });

  // ==========================================================================
  // Group 2: TrueCrossfadeState Model Tests
  // ==========================================================================
  group('TrueCrossfadeState Model Tests', () {
    test('initial state defaults', () {
      final state = TrueCrossfadeState.initial();

      expect(state.isActive, isFalse);
      expect(state.phase, CrossfadePhase.idle);
      expect(state.progress, 0.0);
      expect(state.outgoingVolume, 1.0);
      expect(state.incomingVolume, 0.0);
      expect(state.totalPower, 1.0);
      expect(state.duration, const Duration(seconds: kTrueCrossfadeDefaultSeconds));
      expect(state.elapsed, Duration.zero);
      expect(state.outgoingEngineId, 'Engine-A');
      expect(state.incomingEngineId, 'Engine-B');
      expect(state.curveMode, CrossfadeCurveMode.equalPower);
      expect(state.isDualEngineActive, isFalse);
      expect(state.isFading, isFalse);
      expect(state.isCompleted, isFalse);
      expect(state.formattedProgress, '0.0%');
    });

    test('copyWith updates fields correctly', () {
      final initial = TrueCrossfadeState.initial();
      final updated = initial.copyWith(
        phase: CrossfadePhase.fading,
        progress: 0.5,
        outgoingVolume: 0.707,
        incomingVolume: 0.707,
        isDualEngineActive: true,
      );

      expect(updated.phase, CrossfadePhase.fading);
      expect(updated.progress, 0.5);
      expect(updated.outgoingVolume, 0.707);
      expect(updated.incomingVolume, 0.707);
      expect(updated.isDualEngineActive, isTrue);
      expect(updated.isFading, isTrue);
      expect(updated.formattedProgress, '50.0%');
    });

    test('remaining duration computation', () {
      const duration = Duration(seconds: 4);
      final state = TrueCrossfadeState.initial(duration: duration).copyWith(
        elapsed: const Duration(seconds: 1),
      );

      expect(state.remaining, const Duration(seconds: 3));
    });
  });

  // ==========================================================================
  // Group 3: TrueCrossfadeEngineNotifier Unit Tests
  // ==========================================================================
  group('TrueCrossfadeEngineNotifier Controller Tests', () {
    late SimulatedDualEngineAudioPort audioPort;
    late TrueCrossfadeEngineNotifier notifier;

    setUp(() {
      audioPort = SimulatedDualEngineAudioPort();
      notifier = TrueCrossfadeEngineNotifier(audioPort: audioPort);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('startCrossfade arms dual engines and enters fading phase', () async {
      await notifier.startCrossfade(
        outgoingTrack: 'Song 1',
        incomingTrack: 'Song 2',
        duration: const Duration(seconds: 4),
      );

      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.phase, CrossfadePhase.fading);
      expect(notifier.state.isDualEngineActive, isTrue);
      expect(notifier.state.progress, 0.0);
      expect(notifier.state.outgoingVolume, closeTo(1.0, 1e-4));
      expect(notifier.state.incomingVolume, closeTo(0.0, 1e-4));
      expect(notifier.state.outgoingTrackTitle, 'Song 1');
      expect(notifier.state.incomingTrackTitle, 'Song 2');

      // Verify audio port logged play and setVolume for both engines
      expect(audioPort.playing['Engine-B'], isTrue);
      expect(audioPort.volumes['Engine-A'], closeTo(1.0, 1e-4));
      expect(audioPort.volumes['Engine-B'], closeTo(0.0, 1e-4));
    });

    test('stepProgress modifies progress and computes live cos/sin curves', () {
      notifier.stepProgress(0.5);

      final state = notifier.state;
      expect(state.progress, 0.5);
      expect(state.phase, CrossfadePhase.fading);
      expect(state.isDualEngineActive, isTrue);

      final expectedVol = math.sqrt(2) / 2;
      expect(state.outgoingVolume, closeTo(expectedVol, 1e-4));
      expect(state.incomingVolume, closeTo(expectedVol, 1e-4));
      expect(state.totalPower, closeTo(1.0, 1e-4));

      // Check audio port volumes
      expect(audioPort.volumes['Engine-A'], closeTo(expectedVol, 1e-4));
      expect(audioPort.volumes['Engine-B'], closeTo(expectedVol, 1e-4));
    });

    test('stepProgress near completion engages finishing phase', () {
      notifier.stepProgress(0.96);

      expect(notifier.state.phase, CrossfadePhase.finishing);
      expect(notifier.state.isDualEngineActive, isTrue);
    });

    test('stepProgress 1.0 triggers completion and swaps engine dominance', () {
      notifier.stepProgress(1.0);

      final state = notifier.state;
      expect(state.isActive, isFalse);
      expect(state.phase, CrossfadePhase.completed);
      expect(state.progress, 1.0);
      expect(state.outgoingVolume, closeTo(0.0, 1e-4));
      expect(state.incomingVolume, closeTo(1.0, 1e-4));
      expect(state.isDualEngineActive, isFalse);

      // Outgoing engine stopped and incoming engine at max volume
      expect(audioPort.volumes['Engine-A'], closeTo(0.0, 1e-4));
      expect(audioPort.playing['Engine-A'], isFalse);
      expect(audioPort.volumes['Engine-B'], closeTo(1.0, 1e-4));
    });

    test('tick deterministically advances crossfade elapsed time and progress', () {
      notifier.startCrossfade(duration: const Duration(seconds: 4));

      // Advance by 1 second (25% progress)
      notifier.tick(const Duration(seconds: 1));
      expect(notifier.state.progress, closeTo(0.25, 1e-3));
      expect(notifier.state.elapsed, const Duration(seconds: 1));

      // Advance by another second (50% progress)
      notifier.tick(const Duration(seconds: 1));
      expect(notifier.state.progress, closeTo(0.50, 1e-3));
      expect(notifier.state.outgoingVolume, closeTo(math.sqrt(2) / 2, 1e-3));
      expect(notifier.state.incomingVolume, closeTo(math.sqrt(2) / 2, 1e-3));

      // Advance by 2 seconds (100% progress -> completes)
      notifier.tick(const Duration(seconds: 2));
      expect(notifier.state.phase, CrossfadePhase.completed);
      expect(notifier.state.progress, 1.0);
    });

    test('pauseCrossfade and resumeCrossfade freeze and resume progress ticks', () {
      notifier.startCrossfade(duration: const Duration(seconds: 4));
      notifier.tick(const Duration(seconds: 1));
      expect(notifier.state.progress, closeTo(0.25, 1e-3));

      notifier.pauseCrossfade();
      expect(notifier.state.isPaused, isTrue);

      // Ticks should be ignored while paused
      notifier.tick(const Duration(seconds: 1));
      expect(notifier.state.progress, closeTo(0.25, 1e-3));

      notifier.resumeCrossfade();
      expect(notifier.state.isPaused, isFalse);

      // Ticks should now advance
      notifier.tick(const Duration(seconds: 1));
      expect(notifier.state.progress, closeTo(0.50, 1e-3));
    });

    test('cancelCrossfade restores primary engine and stops secondary engine', () async {
      await notifier.startCrossfade(duration: const Duration(seconds: 4));
      notifier.stepProgress(0.5);

      await notifier.cancelCrossfade();

      expect(notifier.state.isActive, isFalse);
      expect(notifier.state.phase, CrossfadePhase.idle);
      expect(notifier.state.progress, 0.0);
      expect(notifier.state.outgoingVolume, closeTo(1.0, 1e-4));
      expect(notifier.state.incomingVolume, closeTo(0.0, 1e-4));

      expect(audioPort.volumes['Engine-A'], closeTo(1.0, 1e-4));
      expect(audioPort.volumes['Engine-B'], closeTo(0.0, 1e-4));
      expect(audioPort.playing['Engine-B'], isFalse);
    });

    test('swapEngines updates identities and resets playback position', () {
      notifier.swapEngines();

      expect(notifier.state.outgoingEngineId, 'Engine-B');
      expect(notifier.state.incomingEngineId, 'Engine-A');
      expect(notifier.state.phase, CrossfadePhase.idle);
      expect(notifier.state.outgoingVolume, 1.0);
      expect(notifier.state.incomingVolume, 0.0);
    });

    test('setDuration clamps to 1s..12s and persists', () async {
      await notifier.setDuration(const Duration(seconds: 6));
      expect(notifier.state.duration, const Duration(seconds: 6));

      final prefs = await TrueCrossfadePrefs.getInstance();
      expect(prefs.getInt(kTrueCrossfadeDurationPrefKey), 6000);

      // Underflow clamp
      await notifier.setDuration(const Duration(seconds: 0));
      expect(notifier.state.duration, const Duration(seconds: 1));

      // Overflow clamp
      await notifier.setDuration(const Duration(seconds: 30));
      expect(notifier.state.duration, const Duration(seconds: 12));
    });

    test('setCurveMode switches curve type and recalculates volumes live', () async {
      notifier.stepProgress(0.5);

      // Default equal-power midpoint: sqrt(2)/2 ~= 0.707
      expect(notifier.state.outgoingVolume, closeTo(0.7071, 1e-3));

      // Switch to linear mode -> midpoint: 0.500
      await notifier.setCurveMode(CrossfadeCurveMode.linear);
      expect(notifier.state.curveMode, CrossfadeCurveMode.linear);
      expect(notifier.state.outgoingVolume, closeTo(0.500, 1e-3));
      expect(notifier.state.incomingVolume, closeTo(0.500, 1e-3));
      expect(notifier.state.totalPower, closeTo(0.500, 1e-3)); // -3dB dip
    });
  });

  // ==========================================================================
  // Group 4: Riverpod Provider Integration Tests
  // ==========================================================================
  group('Riverpod Provider Tests', () {
    test('providers read correctly from container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(crossfadeProgressProvider), 0.0);
      expect(container.read(crossfadePhaseProvider), CrossfadePhase.idle);
      expect(container.read(crossfadeOutgoingVolumeProvider), 1.0);
      expect(container.read(crossfadeIncomingVolumeProvider), 0.0);
      expect(container.read(crossfadeTotalPowerProvider), 1.0);
      expect(container.read(crossfadeIsDualActiveProvider), isFalse);

      final notifier = container.read(trueCrossfadeNotifierProvider.notifier);
      notifier.stepProgress(0.5);

      expect(container.read(crossfadeProgressProvider), 0.5);
      expect(container.read(crossfadePhaseProvider), CrossfadePhase.fading);
      expect(container.read(crossfadeOutgoingVolumeProvider), closeTo(0.7071, 1e-3));
      expect(container.read(crossfadeIncomingVolumeProvider), closeTo(0.7071, 1e-3));
      expect(container.read(crossfadeTotalPowerProvider), closeTo(1.0, 1e-4));
      expect(container.read(crossfadeIsDualActiveProvider), isTrue);
    });
  });

  // ==========================================================================
  // Group 5: CrossfadeLiveVisualizer Widget Tests
  // ==========================================================================
  group('CrossfadeLiveVisualizer Widget Tests', () {
    testWidgets('renders header, curves painter canvas, metric cards and controls',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CrossfadeLiveVisualizer(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Header & Badges
      expect(find.text('Dual-Engine Crossfade Visualizer'), findsOneWidget);
      expect(find.text('Constant-Power Overlap (Equal-Power DSP)'), findsOneWidget);
      expect(find.text('IDLE'), findsOneWidget);

      // Canvas formulas & legends
      expect(find.text('V_out = cos(theta)'), findsOneWidget);
      expect(find.text('V_in = sin(theta)'), findsOneWidget);
      expect(find.text('Midpoint: sqrt(2)/2 ~= 0.707 (-3dB)'), findsOneWidget);

      // Engine metric cards
      expect(find.text('OUTGOING'), findsOneWidget);
      expect(find.text('INCOMING'), findsOneWidget);
      expect(find.text('Engine-A'), findsOneWidget);
      expect(find.text('Engine-B'), findsOneWidget);

      // Combined Acoustic Power Gauge
      expect(
        find.text('Combined Acoustic Power (V_out² + V_in²)'),
        findsOneWidget,
      );
      expect(find.text('1.0000'), findsOneWidget);

      // Controls
      expect(find.text('Simulate Crossfade'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Swap Engines'), findsOneWidget);
      expect(find.text('4s'), findsWidgets);
      expect(find.text('8s'), findsWidgets);
    });

    testWidgets('scrubbing slider updates progress and live volumes in UI',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CrossfadeLiveVisualizer(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Locate the slider widget
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Slide to midpoint (~0.5)
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Phase changes to FADING and gain values update
      expect(find.text('FADING'), findsOneWidget);
    });

    testWidgets('tapping duration preset chip updates duration setting',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CrossfadeLiveVisualizer(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap 6s chip
      final chipFinder = find.widgetWithText(ChoiceChip, '6s');
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      final chipWidget = tester.widget<ChoiceChip>(chipFinder);
      expect(chipWidget.selected, isTrue);
    });

    testWidgets('tapping Simulate Crossfade triggers crossfade and changes phase',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CrossfadeLiveVisualizer(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final simulateButton = find.widgetWithText(ElevatedButton, 'Simulate Crossfade');
      expect(simulateButton, findsOneWidget);

      await tester.tap(simulateButton);
      await tester.pump();

      // Phase transitions to FADING
      expect(find.text('FADING'), findsOneWidget);

      // Reset button restores to IDLE
      final resetButton = find.widgetWithText(OutlinedButton, 'Reset');
      await tester.tap(resetButton);
      await tester.pump();

      expect(find.text('IDLE'), findsOneWidget);
    });
  });
}
