// ============================================================================
// Unit & Widget Tests: Pitch Transpose DSP (Independent of Tempo)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/dsp/pitch_shifter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  // ==========================================================================
  // Group 1: PitchShifterMath DSP Calculations
  // ==========================================================================
  group('PitchShifterMath DSP Calculations', () {
    test('ratioFromSemitones returns exact expected acoustic multipliers', () {
      // 0 semitones = unison (1.0x)
      expect(PitchShifterMath.ratioFromSemitones(0), closeTo(1.0, 0.0001));

      // +12 semitones = octave up (2.0x)
      expect(PitchShifterMath.ratioFromSemitones(12), closeTo(2.0, 0.0001));

      // -12 semitones = octave down (0.5x)
      expect(PitchShifterMath.ratioFromSemitones(-12), closeTo(0.5, 0.0001));

      // +1 semitone = 2^(1/12) ~ 1.05946
      expect(PitchShifterMath.ratioFromSemitones(1), closeTo(1.05946, 0.0001));

      // -1 semitone = 2^(-1/12) ~ 0.94387
      expect(PitchShifterMath.ratioFromSemitones(-1), closeTo(0.94387, 0.0001));

      // +7 semitones (perfect 5th) ~ 1.4983
      expect(PitchShifterMath.ratioFromSemitones(7), closeTo(1.4983, 0.001));
    });

    test('semitonesFromRatio converts ratio back to semitones with clamping', () {
      expect(PitchShifterMath.semitonesFromRatio(1.0), 0);
      expect(PitchShifterMath.semitonesFromRatio(2.0), 12);
      expect(PitchShifterMath.semitonesFromRatio(0.5), -12);
      expect(PitchShifterMath.semitonesFromRatio(1.05946), 1);
      expect(PitchShifterMath.semitonesFromRatio(0.94387), -1);

      // Extreme ratios clamp to -12 and +12
      expect(PitchShifterMath.semitonesFromRatio(10.0), 12);
      expect(PitchShifterMath.semitonesFromRatio(0.01), -12);
      expect(PitchShifterMath.semitonesFromRatio(-1.0), 0);
    });

    test('percentageChange computes relative frequency shift', () {
      expect(PitchShifterMath.percentageChange(0), closeTo(0.0, 0.001));
      expect(PitchShifterMath.percentageChange(12), closeTo(100.0, 0.001));
      expect(PitchShifterMath.percentageChange(-12), closeTo(-50.0, 0.001));
      expect(PitchShifterMath.percentageChange(1), closeTo(5.946, 0.01));
    });

    test('formatSemitones & formatChipLabel format correctly', () {
      expect(PitchShifterMath.formatSemitones(0), '0 st (Normal)');
      expect(PitchShifterMath.formatSemitones(3), '+3 st');
      expect(PitchShifterMath.formatSemitones(-5), '-5 st');

      expect(PitchShifterMath.formatChipLabel(0), '0');
      expect(PitchShifterMath.formatChipLabel(2), '+2');
      expect(PitchShifterMath.formatChipLabel(-2), '-2');
    });

    test('intervalName produces musical names', () {
      expect(PitchShifterMath.intervalName(0), 'Original / Unison (0)');
      expect(PitchShifterMath.intervalName(1), 'Minor 2nd Up (+1)');
      expect(PitchShifterMath.intervalName(7), 'Perfect 5th Up (+7)');
      expect(PitchShifterMath.intervalName(12), 'Octave Up (+12)');
      expect(PitchShifterMath.intervalName(-1), 'Minor 2nd Down (-1)');
      expect(PitchShifterMath.intervalName(-7), 'Perfect 5th Down (-7)');
      expect(PitchShifterMath.intervalName(-12), 'Octave Down (-12)');
    });
  });

  // ==========================================================================
  // Group 2: PitchShifterNotifier Unit Tests
  // ==========================================================================
  group('PitchShifterNotifier State Management', () {
    test('initial state defaults to 0 (normal unison)', () {
      final notifier = PitchShifterNotifier();
      expect(notifier.state, 0);
      expect(notifier.semitones, 0);
      expect(notifier.isNormal, isTrue);
      expect(notifier.isShifted, isFalse);
      expect(notifier.pitchRatio, closeTo(1.0, 0.0001));
      expect(notifier.formattedLabel, '0 st (Normal)');
      expect(notifier.intervalName, 'Original / Unison (0)');
      expect(notifier.percentageChange, closeTo(0.0, 0.001));
    });

    test('updates semitones and reflects shifted state', () async {
      final notifier = PitchShifterNotifier();
      await notifier.setSemitones(4);

      expect(notifier.state, 4);
      expect(notifier.semitones, 4);
      expect(notifier.isNormal, isFalse);
      expect(notifier.isShifted, isTrue);
      expect(notifier.pitchRatio, closeTo(1.2599, 0.001));
      expect(notifier.formattedLabel, '+4 st');
    });

    test('clamps semitones strictly to range [-12, +12]', () async {
      final notifier = PitchShifterNotifier();

      // Above upper bound
      await notifier.setSemitones(18);
      expect(notifier.state, 12);
      expect(notifier.pitchRatio, closeTo(2.0, 0.0001));

      // Below lower bound
      await notifier.setSemitones(-30);
      expect(notifier.state, -12);
      expect(notifier.pitchRatio, closeTo(0.5, 0.0001));
    });

    test('increment, decrement and transpose work within clamped bounds', () async {
      final notifier = PitchShifterNotifier();

      await notifier.increment();
      expect(notifier.state, 1);

      await notifier.increment();
      expect(notifier.state, 2);

      await notifier.decrement();
      expect(notifier.state, 1);

      await notifier.transpose(4);
      expect(notifier.state, 5);

      await notifier.transpose(-10);
      expect(notifier.state, -5);

      // Clamp upper via increment
      await notifier.setSemitones(12);
      await notifier.increment();
      expect(notifier.state, 12);

      // Clamp lower via decrement
      await notifier.setSemitones(-12);
      await notifier.decrement();
      expect(notifier.state, -12);
    });

    test('reset action sets state back to 0', () async {
      final notifier = PitchShifterNotifier();
      await notifier.setSemitones(7);
      expect(notifier.state, 7);
      expect(notifier.isShifted, isTrue);

      await notifier.reset();
      expect(notifier.state, 0);
      expect(notifier.isNormal, isTrue);
      expect(notifier.isShifted, isFalse);
      expect(notifier.pitchRatio, closeTo(1.0, 0.0001));
    });

    test('persists semitones to SharedPreferences and restores on init', () async {
      // 1. Initialized with stored preference
      SharedPreferences.setMockInitialValues({
        kPitchTransposePrefKey: 3,
      });

      final notifier = PitchShifterNotifier();
      // Allow async persistence load
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state, 3);
      expect(notifier.pitchRatio, closeTo(1.1892, 0.001));

      // 2. Change value and verify SharedPreferences updated
      await notifier.setSemitones(-2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kPitchTransposePrefKey), -2);

      // 3. Reset and verify SharedPreferences updated
      await notifier.reset();
      expect(prefs.getInt(kPitchTransposePrefKey), 0);
    });

    test('clamps persisted values if out-of-range in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        kPitchTransposePrefKey: 99,
      });

      final notifier = PitchShifterNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state, 12);
    });
  });

  // ==========================================================================
  // Group 3: Riverpod Providers Integration
  // ==========================================================================
  group('Riverpod Providers Integration', () {
    test('providers expose consistent values and update reactively', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pitchShifterProvider), 0);
      expect(container.read(pitchRatioProvider), closeTo(1.0, 0.0001));
      expect(container.read(isPitchShiftedProvider), isFalse);
      expect(container.read(pitchFormattedLabelProvider), '0 st (Normal)');
      expect(container.read(pitchIntervalNameProvider), 'Original / Unison (0)');

      final notifier = container.read(pitchShifterProvider.notifier);
      await notifier.setSemitones(2);

      expect(container.read(pitchShifterProvider), 2);
      expect(container.read(pitchRatioProvider), closeTo(1.12246, 0.001));
      expect(container.read(isPitchShiftedProvider), isTrue);
      expect(container.read(pitchFormattedLabelProvider), '+2 st');
      expect(container.read(pitchIntervalNameProvider), 'Major 2nd Up (+2)');
    });
  });

  // ==========================================================================
  // Group 4: PitchShifterControl Widget Tests
  // ==========================================================================
  group('PitchShifterControl Widget', () {
    testWidgets('renders all core UI elements: header, slider, chips, details',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PitchShifterControl(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Pitch Transpose'), findsOneWidget);
      expect(find.text('Shift musical key independent of tempo'), findsOneWidget);

      // Slider and nudge buttons
      expect(find.byKey(const Key('pitch_shifter_slider')), findsOneWidget);
      expect(find.byKey(const Key('pitch_step_down_button')), findsOneWidget);
      expect(find.byKey(const Key('pitch_step_up_button')), findsOneWidget);

      // Semitone chip indicators
      expect(find.byKey(const Key('pitch_chip_0')), findsOneWidget);
      expect(find.byKey(const Key('pitch_chip_2')), findsOneWidget);
      expect(find.byKey(const Key('pitch_chip_12')), findsOneWidget);
      expect(find.byKey(const Key('pitch_chip_-12')), findsOneWidget);

      // Reset button in header
      expect(find.byKey(const Key('pitch_reset_button')), findsOneWidget);

      // Acoustic interval details
      expect(find.text('Original / Unison (0)'), findsOneWidget);
    });

    testWidgets('tapping a semitone chip updates state and ratio',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      int? callbackValue;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PitchShifterControl(
                  onPitchChanged: (val) => callbackValue = val,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap chip for +2 semitones
      final chip2 = find.byKey(const Key('pitch_chip_2'));
      expect(chip2, findsOneWidget);
      await tester.tap(chip2);
      await tester.pumpAndSettle();

      expect(container.read(pitchShifterProvider), 2);
      expect(callbackValue, 2);
      expect(find.text('+2 st'), findsOneWidget);
      expect(find.text('Major 2nd Up (+2)'), findsOneWidget);
    });

    testWidgets('reset button resets pitch back to 0', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool resetCalled = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PitchShifterControl(
                  onReset: () => resetCalled = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select +5 semitones first
      await tester.tap(find.byKey(const Key('pitch_chip_5')));
      await tester.pumpAndSettle();

      expect(container.read(pitchShifterProvider), 5);

      // Tap header reset button
      final resetButton = find.byKey(const Key('pitch_reset_button'));
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(container.read(pitchShifterProvider), 0);
      expect(resetCalled, isTrue);
      expect(find.text('0 st (Normal)'), findsOneWidget);
    });

    testWidgets('step up and step down nudge buttons adjust pitch by 1 semitone',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PitchShifterControl(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap step up button (+1)
      await tester.tap(find.byKey(const Key('pitch_step_up_button')));
      await tester.pumpAndSettle();
      expect(container.read(pitchShifterProvider), 1);

      // Tap step up button again (+2)
      await tester.tap(find.byKey(const Key('pitch_step_up_button')));
      await tester.pumpAndSettle();
      expect(container.read(pitchShifterProvider), 2);

      // Tap step down button (-1 -> +1)
      await tester.tap(find.byKey(const Key('pitch_step_down_button')));
      await tester.pumpAndSettle();
      expect(container.read(pitchShifterProvider), 1);
    });

    testWidgets('explicit text reset button resets pitch', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PitchShifterControl(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shift to -5 semitones
      await tester.tap(find.byKey(const Key('pitch_chip_-5')));
      await tester.pumpAndSettle();
      expect(container.read(pitchShifterProvider), -5);

      // The text button 'Reset to Normal (0 st)' is now visible
      final textResetBtn = find.byKey(const Key('pitch_reset_text_button'));
      expect(textResetBtn, findsOneWidget);
      await tester.tap(textResetBtn);
      await tester.pumpAndSettle();

      expect(container.read(pitchShifterProvider), 0);
    });

    testWidgets('modal bottom sheet helper displays PitchShifterControl',
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
                  onPressed: () => showPitchShifterSheet(context),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(PitchShifterControl), findsOneWidget);
      expect(find.text('Pitch Transpose'), findsOneWidget);
    });
  });
}
