// ============================================================================
// Unit & Widget Tests: Stereo Left/Right Balance Slider & DSP Panner
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/dsp/stereo_balance_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  // ==========================================================================
  // Group 1: StereoBalanceMath & Attenuation Curve Calculations
  // ==========================================================================
  group('StereoBalanceMath & Linear Attenuation Curve', () {
    test('neutral center (0.0) yields full 100% gain on both channels', () {
      final left = StereoBalanceMath.calculateLeftGain(0.0);
      final right = StereoBalanceMath.calculateRightGain(0.0);

      expect(left, closeTo(1.0, 1e-5));
      expect(right, closeTo(1.0, 1e-5));
    });

    test('full left (-1.0) yields 100% Left gain and 0% Right gain (muted)', () {
      final left = StereoBalanceMath.calculateLeftGain(-1.0);
      final right = StereoBalanceMath.calculateRightGain(-1.0);

      expect(left, closeTo(1.0, 1e-5));
      expect(right, closeTo(0.0, 1e-5));
    });

    test('full right (+1.0) yields 0% Left gain (muted) and 100% Right gain', () {
      final left = StereoBalanceMath.calculateLeftGain(1.0);
      final right = StereoBalanceMath.calculateRightGain(1.0);

      expect(left, closeTo(0.0, 1e-5));
      expect(right, closeTo(1.0, 1e-5));
    });

    test('intermediate balance positions attenuate the opposite channel linearly', () {
      // Half Left (-0.5): Left is 1.0, Right is attenuated to 0.5
      expect(StereoBalanceMath.calculateLeftGain(-0.5), closeTo(1.0, 1e-5));
      expect(StereoBalanceMath.calculateRightGain(-0.5), closeTo(0.5, 1e-5));

      // Half Right (+0.5): Left is attenuated to 0.5, Right is 1.0
      expect(StereoBalanceMath.calculateLeftGain(0.5), closeTo(0.5, 1e-5));
      expect(StereoBalanceMath.calculateRightGain(0.5), closeTo(1.0, 1e-5));

      // Quarter Left (-0.25): Left is 1.0, Right is 0.75
      expect(StereoBalanceMath.calculateLeftGain(-0.25), closeTo(1.0, 1e-5));
      expect(StereoBalanceMath.calculateRightGain(-0.25), closeTo(0.75, 1e-5));

      // Quarter Right (+0.25): Left is 0.75, Right is 1.0
      expect(StereoBalanceMath.calculateLeftGain(0.25), closeTo(0.75, 1e-5));
      expect(StereoBalanceMath.calculateRightGain(0.25), closeTo(1.0, 1e-5));
    });

    test('out of bounds values are clamped strictly within [-1.0, 1.0]', () {
      expect(StereoBalanceMath.calculateLeftGain(-2.5), closeTo(1.0, 1e-5));
      expect(StereoBalanceMath.calculateRightGain(-2.5), closeTo(0.0, 1e-5));

      expect(StereoBalanceMath.calculateLeftGain(3.0), closeTo(0.0, 1e-5));
      expect(StereoBalanceMath.calculateRightGain(3.0), closeTo(1.0, 1e-5));
    });

    test('StereoGains.fromBalance constructs accurate model & decibels', () {
      final center = StereoGains.fromBalance(0.0);
      expect(center.leftGain, closeTo(1.0, 1e-5));
      expect(center.rightGain, closeTo(1.0, 1e-5));
      expect(center.leftPercent, 100);
      expect(center.rightPercent, 100);
      expect(center.leftDecibels, closeTo(0.0, 0.01));
      expect(center.rightDecibels, closeTo(0.0, 0.01));
      expect(center.isBalanced, isTrue);
      expect(center.isFullLeft, isFalse);
      expect(center.isFullRight, isFalse);

      final fullLeft = StereoGains.fromBalance(-1.0);
      expect(fullLeft.leftPercent, 100);
      expect(fullLeft.rightPercent, 0);
      expect(fullLeft.leftDecibels, closeTo(0.0, 0.01));
      expect(fullLeft.rightDecibels, lessThanOrEqualTo(-90.0));
      expect(fullLeft.isFullLeft, isTrue);
      expect(fullLeft.isFullRight, isFalse);

      final fullRight = StereoGains.fromBalance(1.0);
      expect(fullRight.leftPercent, 0);
      expect(fullRight.rightPercent, 100);
      expect(fullRight.isFullRight, isTrue);
      expect(fullRight.isFullLeft, isFalse);

      final halfLeft = StereoGains.fromBalance(-0.5);
      // 20 * log10(0.5) ~ -6.02 dB
      expect(halfLeft.rightDecibels, closeTo(-6.02, 0.1));
      expect(halfLeft.leftDecibels, closeTo(0.0, 0.01));
    });

    test('formatReadout generates concise percentage strings', () {
      expect(StereoBalanceMath.formatReadout(0.0), 'Center');
      expect(StereoBalanceMath.formatReadout(0.002), 'Center');
      expect(StereoBalanceMath.formatReadout(-0.002), 'Center');
      expect(StereoBalanceMath.formatReadout(-0.5), 'L 50%');
      expect(StereoBalanceMath.formatReadout(-1.0), 'L 100%');
      expect(StereoBalanceMath.formatReadout(0.5), 'R 50%');
      expect(StereoBalanceMath.formatReadout(1.0), 'R 100%');
      expect(StereoBalanceMath.formatReadout(-0.25), 'L 25%');
      expect(StereoBalanceMath.formatReadout(0.75), 'R 75%');
    });

    test('formatPercentageOnly returns unsigned percentage', () {
      expect(StereoBalanceMath.formatPercentageOnly(0.0), '0%');
      expect(StereoBalanceMath.formatPercentageOnly(-0.4), '40%');
      expect(StereoBalanceMath.formatPercentageOnly(0.85), '85%');
    });

    test('formatDetailedReadout provides comprehensive channel overview', () {
      expect(StereoBalanceMath.formatDetailedReadout(0.0), contains('Centered'));
      expect(StereoBalanceMath.formatDetailedReadout(-0.6), contains('Biased Left'));
      expect(StereoBalanceMath.formatDetailedReadout(0.6), contains('Biased Right'));
    });

    test('applyBalanceToStereoBuffer modifies interleaved Float32 audio samples correctly', () {
      // Buffer format: [L0, R0, L1, R1]
      final buffer = Float32List.fromList([1.0, 1.0, 0.8, 0.8]);

      // 1. Center (0.0) -> unchanged
      StereoBalanceMath.applyBalanceToStereoBuffer(buffer, 0.0);
      expect(buffer[0], closeTo(1.0, 1e-5));
      expect(buffer[1], closeTo(1.0, 1e-5));
      expect(buffer[2], closeTo(0.8, 1e-5));
      expect(buffer[3], closeTo(0.8, 1e-5));

      // 2. Full Left (-1.0) -> Right channel zeroed
      StereoBalanceMath.applyBalanceToStereoBuffer(buffer, -1.0);
      expect(buffer[0], closeTo(1.0, 1e-5));
      expect(buffer[1], closeTo(0.0, 1e-5));
      expect(buffer[2], closeTo(0.8, 1e-5));
      expect(buffer[3], closeTo(0.0, 1e-5));

      // 3. Half Right (+0.5) on fresh buffer
      final buffer2 = Float32List.fromList([1.0, 1.0, 0.8, 0.8]);
      StereoBalanceMath.applyBalanceToStereoBuffer(buffer2, 0.5);
      expect(buffer2[0], closeTo(0.5, 1e-5)); // Left scaled by 0.5
      expect(buffer2[1], closeTo(1.0, 1e-5)); // Right at 1.0
      expect(buffer2[2], closeTo(0.4, 1e-5)); // Left 0.8 * 0.5
      expect(buffer2[3], closeTo(0.8, 1e-5)); // Right 0.8 * 1.0
    });

    test('applyBalanceToPcm16Buffer modifies Int16 samples correctly', () {
      final pcm = Int16List.fromList([10000, 10000, 20000, 20000]);

      // Full Right (+1.0) -> Left channel zeroed
      StereoBalanceMath.applyBalanceToPcm16Buffer(pcm, 1.0);
      expect(pcm[0], 0);
      expect(pcm[1], 10000);
      expect(pcm[2], 0);
      expect(pcm[3], 20000);
    });
  });

  // ==========================================================================
  // Group 2: StereoBalanceController StateNotifier & Persistence
  // ==========================================================================
  group('StereoBalanceController State Management & Persistence', () {
    test('initial state defaults to 0.0 Center with equal gains', () {
      final controller = StereoBalanceController();
      expect(controller.state, 0.0);
      expect(controller.balance, 0.0);
      expect(controller.leftGain, 1.0);
      expect(controller.rightGain, 1.0);
      expect(controller.isCenter, isTrue);
      expect(controller.isLeftBiased, isFalse);
      expect(controller.isRightBiased, isFalse);
      expect(controller.readout, 'Center');
    });

    test('explicit initialBalance sets custom initial state', () {
      final controller = StereoBalanceController(initialBalance: -0.4);
      expect(controller.state, -0.4);
      expect(controller.balance, -0.4);
      expect(controller.isCenter, isFalse);
      expect(controller.isLeftBiased, isTrue);
      expect(controller.readout, 'L 40%');
    });

    test('setBalance updates state, gains, and readouts', () async {
      final controller = StereoBalanceController();

      await controller.setBalance(0.6);
      expect(controller.state, 0.6);
      expect(controller.leftGain, closeTo(0.4, 1e-4));
      expect(controller.rightGain, closeTo(1.0, 1e-4));
      expect(controller.isRightBiased, isTrue);
      expect(controller.readout, 'R 60%');

      await controller.setBalance(-0.75);
      expect(controller.state, -0.75);
      expect(controller.leftGain, closeTo(1.0, 1e-4));
      expect(controller.rightGain, closeTo(0.25, 1e-4));
      expect(controller.isLeftBiased, isTrue);
      expect(controller.readout, 'L 75%');
    });

    test('setBalance clamps values exceeding [-1.0, 1.0]', () async {
      final controller = StereoBalanceController();

      await controller.setBalance(-3.5);
      expect(controller.state, -1.0);
      expect(controller.leftGain, 1.0);
      expect(controller.rightGain, 0.0);

      await controller.setBalance(2.8);
      expect(controller.state, 1.0);
      expect(controller.leftGain, 0.0);
      expect(controller.rightGain, 1.0);
    });

    test('snapNearCenter snaps values close to 0.0 back to Center', () async {
      final controller = StereoBalanceController();

      await controller.setBalance(0.02, snapNearCenter: true);
      expect(controller.state, 0.0);
      expect(controller.isCenter, isTrue);

      await controller.setBalance(-0.02, snapNearCenter: true);
      expect(controller.state, 0.0);
      expect(controller.isCenter, isTrue);

      // Outside snap deadband remains intact
      await controller.setBalance(0.08, snapNearCenter: true);
      expect(controller.state, 0.08);
    });

    test('snapToCenter and reset restore balance back to 0.0', () async {
      final controller = StereoBalanceController();

      await controller.setBalance(0.8);
      expect(controller.state, 0.8);

      await controller.snapToCenter();
      expect(controller.state, 0.0);
      expect(controller.isCenter, isTrue);
      expect(controller.readout, 'Center');

      await controller.setBalance(-0.5);
      await controller.reset();
      expect(controller.state, 0.0);
      expect(controller.isCenter, isTrue);
    });

    test('nudgeLeft and nudgeRight step balance incrementally', () async {
      final controller = StereoBalanceController();

      await controller.nudgeLeft(0.1);
      expect(controller.state, -0.1);

      await controller.nudgeLeft(0.2);
      expect(controller.state, -0.3);

      await controller.nudgeRight(0.5);
      expect(controller.state, closeTo(0.2, 1e-4));

      // Stepping past bounds is clamped
      await controller.nudgeRight(2.0);
      expect(controller.state, 1.0);

      await controller.nudgeLeft(3.0);
      expect(controller.state, -1.0);
    });

    test('setFullLeft and setFullRight jump to extremes', () async {
      final controller = StereoBalanceController();

      await controller.setFullLeft();
      expect(controller.state, -1.0);
      expect(controller.gains.isFullLeft, isTrue);

      await controller.setFullRight();
      expect(controller.state, 1.0);
      expect(controller.gains.isFullRight, isTrue);
    });

    test('persists state changes to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = StereoBalanceController(prefs: prefs);

      await controller.setBalance(0.45);
      final stored = prefs.getDouble(kStereoBalancePrefKey);
      expect(stored, 0.45);
    });

    test('loads persisted preference on initialization', () async {
      SharedPreferences.setMockInitialValues({
        kStereoBalancePrefKey: -0.65,
      });

      final controller = StereoBalanceController();
      // Allow async persistence initialization to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.state, -0.65);
      expect(controller.readout, 'L 65%');
    });
  });

  // ==========================================================================
  // Group 3: Riverpod Providers
  // ==========================================================================
  group('Riverpod Providers Integration', () {
    test('providers emit synchronous reactive state updates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(stereoBalanceProvider), 0.0);
      expect(container.read(isStereoCenterProvider), isTrue);
      expect(container.read(stereoBalanceReadoutProvider), 'Center');
      expect(container.read(stereoGainsProvider).leftGain, 1.0);
      expect(container.read(stereoGainsProvider).rightGain, 1.0);

      // Mutate state through controller
      await container
          .read(stereoBalanceProvider.notifier)
          .setBalance(0.5);

      expect(container.read(stereoBalanceProvider), 0.5);
      expect(container.read(isStereoCenterProvider), isFalse);
      expect(container.read(stereoBalanceReadoutProvider), 'R 50%');
      expect(container.read(stereoGainsProvider).leftGain, closeTo(0.5, 1e-4));
      expect(container.read(stereoGainsProvider).rightGain, closeTo(1.0, 1e-4));
    });
  });

  // ==========================================================================
  // Group 4: StereoBalanceSlider Material 3 Widget Tests
  // ==========================================================================
  group('StereoBalanceSlider Widget Tests', () {
    testWidgets('renders all visual elements and initial neutral center state',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header components
      expect(find.text('Stereo Balance'), findsOneWidget);
      expect(find.text('Pan audio between Left and Right channels'), findsOneWidget);
      expect(find.byKey(const Key('stereo_balance_readout')), findsOneWidget);
      expect(find.text('Center'), findsWidgets);
      expect(find.byKey(const Key('stereo_balance_reset_button')), findsOneWidget);

      // L / R Visual Indicators
      expect(find.byKey(const Key('stereo_balance_indicator_left')), findsOneWidget);
      expect(find.byKey(const Key('stereo_balance_indicator_right')), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('100%'), findsWidgets);

      // Slider & Center Snap Tick
      expect(find.byKey(const Key('stereo_balance_slider')), findsOneWidget);
      expect(find.byKey(const Key('stereo_balance_center_tick')), findsOneWidget);

      // Nudge buttons
      expect(find.byKey(const Key('stereo_balance_nudge_left')), findsOneWidget);
      expect(find.byKey(const Key('stereo_balance_nudge_right')), findsOneWidget);
      expect(find.text('Double-tap to center'), findsOneWidget);
    });

    testWidgets('dragging slider updates balance value and readout',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      double? callbackVal;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(
                  onBalanceChanged: (val) => callbackVal = val,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const Key('stereo_balance_slider'));
      expect(sliderFinder, findsOneWidget);

      // Drag slider towards Right (positive)
      await tester.drag(sliderFinder, const Offset(60, 0));
      await tester.pumpAndSettle();

      final currentBalance = container.read(stereoBalanceProvider);
      expect(currentBalance, greaterThan(0.0));
      expect(callbackVal, isNotNull);
      expect(container.read(isStereoCenterProvider), isFalse);
    });

    testWidgets('tapping reset button snaps balance back to Center (0.0)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool centerSnapped = false;

      // Seed state at -0.6 (Left biased)
      await container
          .read(stereoBalanceProvider.notifier)
          .setBalance(-0.6);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(
                  onSnapToCenter: () => centerSnapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(stereoBalanceProvider), -0.6);
      expect(find.text('L 60%'), findsOneWidget);

      // Tap reset button
      final resetBtn = find.byKey(const Key('stereo_balance_reset_button'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(container.read(stereoBalanceProvider), 0.0);
      expect(container.read(isStereoCenterProvider), isTrue);
      expect(centerSnapped, isTrue);
      expect(find.text('Center'), findsWidgets);
    });

    testWidgets('tapping center snap tick snaps balance back to Center (0.0)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool centerSnapped = false;

      // Seed state at +0.7 (Right biased)
      await container
          .read(stereoBalanceProvider.notifier)
          .setBalance(0.7);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(
                  onSnapToCenter: () => centerSnapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(stereoBalanceProvider), 0.7);

      // Tap center snap tick
      final centerTick = find.byKey(const Key('stereo_balance_center_tick'));
      expect(centerTick, findsOneWidget);
      await tester.tap(centerTick);
      await tester.pumpAndSettle();

      expect(container.read(stereoBalanceProvider), 0.0);
      expect(centerSnapped, isTrue);
    });

    testWidgets('double-tap gesture snaps balance back to Center (0.0)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool centerSnapped = false;

      // Seed state at -0.5
      await container
          .read(stereoBalanceProvider.notifier)
          .setBalance(-0.5);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(
                  onSnapToCenter: () => centerSnapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(stereoBalanceProvider), -0.5);

      // Double-tap on the double-tap detector area
      final doubleTapArea =
          find.byKey(const Key('stereo_balance_double_tap_detector'));
      expect(doubleTapArea, findsOneWidget);

      await tester.tap(doubleTapArea);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(doubleTapArea);
      await tester.pumpAndSettle();

      expect(container.read(stereoBalanceProvider), 0.0);
      expect(centerSnapped, isTrue);
    });

    testWidgets('nudge buttons adjust balance by step delta',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(stereoBalanceProvider), 0.0);

      // Tap nudge right button
      final rightNudge = find.byKey(const Key('stereo_balance_nudge_right'));
      await tester.tap(rightNudge);
      await tester.pumpAndSettle();
      expect(container.read(stereoBalanceProvider), closeTo(0.05, 1e-4));

      // Tap nudge right again
      await tester.tap(rightNudge);
      await tester.pumpAndSettle();
      expect(container.read(stereoBalanceProvider), closeTo(0.10, 1e-4));

      // Tap nudge left button
      final leftNudge = find.byKey(const Key('stereo_balance_nudge_left'));
      await tester.tap(leftNudge);
      await tester.pumpAndSettle();
      expect(container.read(stereoBalanceProvider), closeTo(0.05, 1e-4));
    });

    testWidgets('tapping channel gauges nudges balance towards respective channel',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final leftGauge = find.byKey(const Key('stereo_balance_indicator_left'));
      await tester.tap(leftGauge);
      await tester.pumpAndSettle();
      expect(container.read(stereoBalanceProvider), lessThan(0.0));

      final rightGauge = find.byKey(const Key('stereo_balance_indicator_right'));
      await tester.tap(rightGauge);
      await tester.pumpAndSettle();
      // Returns closer to center
      expect(container.read(stereoBalanceProvider), closeTo(0.0, 1e-4));
    });

    testWidgets('custom visibility flags cleanly omit disabled components',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StereoBalanceSlider(
                  showHeader: false,
                  showIndicators: false,
                  showCenterTick: false,
                  showNudgeButtons: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stereo Balance'), findsNothing);
      expect(find.byKey(const Key('stereo_balance_indicator_left')), findsNothing);
      expect(find.byKey(const Key('stereo_balance_center_tick')), findsNothing);
      expect(find.byKey(const Key('stereo_balance_nudge_left')), findsNothing);
      // Slider remains visible
      expect(find.byKey(const Key('stereo_balance_slider')), findsOneWidget);
    });

    testWidgets('showStereoBalanceSheet displays bottom sheet with slider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showStereoBalanceSheet(context),
                  child: const Text('Open Balance Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Balance Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(StereoBalanceSlider), findsOneWidget);
      expect(find.text('Stereo Balance'), findsOneWidget);
    });
  });
}
