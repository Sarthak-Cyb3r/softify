// ============================================================================
// Unit & Widget Tests: Target LUFS Loudness Normalization Selector
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/dsp/target_lufs_selector.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LufsPreset standard presets', () {
    test('standard presets define correct reference LUFS targets', () {
      expect(LufsPreset.spotify.targetLufs, -14.0);
      expect(LufsPreset.spotify.label, 'Spotify Standard');
      expect(LufsPreset.spotify.shortLabel, 'Spotify');

      expect(LufsPreset.apple.targetLufs, -16.0);
      expect(LufsPreset.apple.label, 'Apple Music');
      expect(LufsPreset.apple.shortLabel, 'Apple Music');

      expect(LufsPreset.ebuR128.targetLufs, -23.0);
      expect(LufsPreset.ebuR128.label, 'EBU R128');
      expect(LufsPreset.ebuR128.shortLabel, 'EBU R128');

      expect(LufsPreset.custom.targetLufs, isNull);
      expect(LufsPreset.custom.label, 'Custom');
    });

    test('LufsPreset.fromLufs correctly identifies standard presets', () {
      expect(LufsPreset.fromLufs(-14.0), LufsPreset.spotify);
      expect(LufsPreset.fromLufs(-14.02), LufsPreset.spotify);
      expect(LufsPreset.fromLufs(-16.0), LufsPreset.apple);
      expect(LufsPreset.fromLufs(-15.98), LufsPreset.apple);
      expect(LufsPreset.fromLufs(-23.0), LufsPreset.ebuR128);
      expect(LufsPreset.fromLufs(-18.5), LufsPreset.custom);
      expect(LufsPreset.fromLufs(-11.0), LufsPreset.custom);
      expect(LufsPreset.fromLufs(-24.0), LufsPreset.custom);
    });
  });

  group('TargetLufsState model', () {
    test('default state has Spotify Standard (-14 LUFS) and is enabled', () {
      const state = TargetLufsState();
      expect(state.isEnabled, isTrue);
      expect(state.targetLufs, -14.0);
      expect(state.preset, LufsPreset.spotify);
      expect(state.preventClipping, isTrue);
      expect(state.peakCeilingDb, -1.0);
      expect(state.formattedTarget, '-14.0 LUFS');
      expect(state.formattedTargetDb, '-14.0 dB');
    });

    test('calculateGainDb computes accurate decibel adjustments', () {
      const state = TargetLufsState(targetLufs: -14.0);

      // Louder track (-10 LUFS) should be attenuated by -4 dB
      expect(state.calculateGainDb(-10.0), closeTo(-4.0, 0.001));

      // Quieter track (-18 LUFS) should be boosted by +4 dB
      expect(state.calculateGainDb(-18.0), closeTo(4.0, 0.001));

      // Same loudness track (-14 LUFS) should have 0 dB adjustment
      expect(state.calculateGainDb(-14.0), closeTo(0.0, 0.001));

      // Disabled state should return unity 0.0 dB
      final disabledState = state.copyWith(isEnabled: false);
      expect(disabledState.calculateGainDb(-10.0), 0.0);
      expect(disabledState.calculateGainDb(-18.0), 0.0);
    });

    test('calculateLinearGain converts decibels to linear multipliers', () {
      const state = TargetLufsState(targetLufs: -14.0);

      // 0 dB gain -> linear 1.0
      expect(state.calculateLinearGain(-14.0), closeTo(1.0, 0.001));

      // -6.02 dB gain -> linear ~0.5
      expect(state.calculateLinearGain(-7.98), closeTo(0.50, 0.01));

      // Disabled -> linear 1.0
      final disabled = state.copyWith(isEnabled: false);
      expect(disabled.calculateLinearGain(-10.0), 1.0);
    });

    test('copyWith updates fields selectively', () {
      const state = TargetLufsState();
      final updated = state.copyWith(
        isEnabled: false,
        targetLufs: -16.0,
        preset: LufsPreset.apple,
        preventClipping: false,
        peakCeilingDb: -0.5,
      );

      expect(updated.isEnabled, isFalse);
      expect(updated.targetLufs, -16.0);
      expect(updated.preset, LufsPreset.apple);
      expect(updated.preventClipping, isFalse);
      expect(updated.peakCeilingDb, -0.5);
    });

    test('serialization round-trip with toJson and fromJson', () {
      const state = TargetLufsState(
        isEnabled: true,
        targetLufs: -23.0,
        preset: LufsPreset.ebuR128,
        preventClipping: true,
        peakCeilingDb: -1.5,
      );

      final json = state.toJson();
      final revived = TargetLufsState.fromJson(json);

      expect(revived, equals(state));
      expect(revived.targetLufs, -23.0);
      expect(revived.preset, LufsPreset.ebuR128);
    });

    test('equality and hashCode support', () {
      const a = TargetLufsState(targetLufs: -14.0, preset: LufsPreset.spotify);
      const b = TargetLufsState(targetLufs: -14.0, preset: LufsPreset.spotify);
      const c = TargetLufsState(targetLufs: -16.0, preset: LufsPreset.apple);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('LufsGainCalculator pure DSP calculations', () {
    test('computeGainDb clamps to max limits', () {
      final normalGain = LufsGainCalculator.computeGainDb(
        sourceTrackLufs: -10.0,
        targetLufs: -14.0,
      );
      expect(normalGain, closeTo(-4.0, 0.001));

      // Max boost clamping
      final extremeQuietGain = LufsGainCalculator.computeGainDb(
        sourceTrackLufs: -50.0,
        targetLufs: -14.0,
        maxBoostDb: 12.0,
      );
      expect(extremeQuietGain, 12.0);

      // Max cut clamping
      final extremeLoudGain = LufsGainCalculator.computeGainDb(
        sourceTrackLufs: 10.0,
        targetLufs: -24.0,
        maxCutDb: 30.0,
      );
      expect(extremeLoudGain, -30.0);
    });

    test('dbToLinear and linearToDb round-trip accurately', () {
      const testDbs = [-24.0, -14.0, -6.0, 0.0, 6.0, 12.0];
      for (final db in testDbs) {
        final linear = LufsGainCalculator.dbToLinear(db);
        final backToDb = LufsGainCalculator.linearToDb(linear);
        expect(backToDb, closeTo(db, 0.0001));
      }

      expect(LufsGainCalculator.linearToDb(0.0), -120.0);
    });

    test('computePeak finds absolute maximum amplitude', () {
      final buffer = Float32List.fromList([-0.2, 0.5, -0.85, 0.4, 0.1]);
      expect(LufsGainCalculator.computePeak(buffer), closeTo(0.85, 0.0001));

      final empty = Float32List(0);
      expect(LufsGainCalculator.computePeak(empty), 0.0);
    });

    test('applyGainToBuffer scales samples and respects peak limit', () {
      final buffer = Float32List.fromList([0.1, -0.2, 0.3, -0.4]);
      final effective = LufsGainCalculator.applyGainToBuffer(
        buffer,
        2.0,
        preventClipping: true,
        peakLimit: 0.99,
      );

      expect(effective, closeTo(2.0, 0.001));
      expect(buffer[0], closeTo(0.2, 0.001));
      expect(buffer[3], closeTo(-0.8, 0.001));

      // Test clipping prevention attenuation: 0.8 * 2.0 = 1.6 > 0.99
      final hotBuffer = Float32List.fromList([0.2, -0.8]);
      final attenuatedGain = LufsGainCalculator.applyGainToBuffer(
        hotBuffer,
        2.0,
        preventClipping: true,
        peakLimit: 0.99,
      );

      expect(attenuatedGain, closeTo(0.99 / 0.8, 0.001));
      expect(hotBuffer[1].abs(), lessThanOrEqualTo(0.9901));
    });

    test('estimateBufferRmsLufs computes unweighted signal level', () {
      final silence = Float32List.fromList([0.0, 0.0, 0.0]);
      expect(LufsGainCalculator.estimateBufferRmsLufs(silence), -120.0);

      // Full-scale square wave (+1.0, -1.0) has RMS = 1.0 (0 dBFS)
      final fullScale = Float32List.fromList([1.0, -1.0, 1.0, -1.0]);
      expect(LufsGainCalculator.estimateBufferRmsLufs(fullScale), closeTo(0.0, 0.001));
    });
  });

  group('TargetLufsNotifier StateNotifier tests', () {
    test('initial state matches defaults', () {
      final notifier = TargetLufsNotifier();
      expect(notifier.state.isEnabled, isTrue);
      expect(notifier.state.targetLufs, -14.0);
      expect(notifier.state.preset, LufsPreset.spotify);
    });

    test('setPreset updates preset and targetLufs for standard presets', () async {
      final notifier = TargetLufsNotifier();

      await notifier.setPreset(LufsPreset.apple);
      expect(notifier.state.preset, LufsPreset.apple);
      expect(notifier.state.targetLufs, -16.0);

      await notifier.setPreset(LufsPreset.ebuR128);
      expect(notifier.state.preset, LufsPreset.ebuR128);
      expect(notifier.state.targetLufs, -23.0);

      await notifier.setPreset(LufsPreset.spotify);
      expect(notifier.state.preset, LufsPreset.spotify);
      expect(notifier.state.targetLufs, -14.0);
    });

    test('setTargetLufs adjusts value and identifies matching or custom preset', () async {
      final notifier = TargetLufsNotifier();

      // Non-standard target becomes custom
      await notifier.setTargetLufs(-18.5);
      expect(notifier.state.targetLufs, -18.5);
      expect(notifier.state.preset, LufsPreset.custom);

      // Target matching Apple (-16.0) automatically maps to Apple preset
      await notifier.setTargetLufs(-16.0);
      expect(notifier.state.targetLufs, -16.0);
      expect(notifier.state.preset, LufsPreset.apple);
    });

    test('setTargetLufs clamps within -24.0 to -10.0 LUFS boundary', () async {
      final notifier = TargetLufsNotifier();

      // Lower bound clamp
      await notifier.setTargetLufs(-30.0);
      expect(notifier.state.targetLufs, kLufsMin);

      // Upper bound clamp
      await notifier.setTargetLufs(-4.0);
      expect(notifier.state.targetLufs, kLufsMax);
    });

    test('setEnabled and toggleEnabled change normalization state', () async {
      final notifier = TargetLufsNotifier();
      expect(notifier.state.isEnabled, isTrue);

      await notifier.setEnabled(false);
      expect(notifier.state.isEnabled, isFalse);

      await notifier.toggleEnabled();
      expect(notifier.state.isEnabled, isTrue);
    });

    test('setPreventClipping and setPeakCeilingDb update limiter options', () async {
      final notifier = TargetLufsNotifier();

      await notifier.setPreventClipping(false);
      expect(notifier.state.preventClipping, isFalse);

      await notifier.setPeakCeilingDb(-2.0);
      expect(notifier.state.peakCeilingDb, -2.0);
    });

    test('resetToDefault restores standard Spotify reference', () async {
      final notifier = TargetLufsNotifier();

      await notifier.setPreset(LufsPreset.ebuR128);
      await notifier.setEnabled(false);
      expect(notifier.state.targetLufs, -23.0);
      expect(notifier.state.isEnabled, isFalse);

      await notifier.resetToDefault();
      expect(notifier.state.targetLufs, -14.0);
      expect(notifier.state.preset, LufsPreset.spotify);
      expect(notifier.state.isEnabled, isTrue);
    });

    test('persists state to SharedPreferences and restores across instances', () async {
      SharedPreferences.setMockInitialValues({
        kTargetLufsValueKey: -16.0,
        kTargetLufsPresetKey: LufsPreset.apple.name,
        kTargetLufsEnabledKey: true,
      });

      final notifier = TargetLufsNotifier();
      // Allow async load to complete
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(notifier.state.targetLufs, -16.0);
      expect(notifier.state.preset, LufsPreset.apple);

      // Now change setting and verify written to preferences
      await notifier.setPreset(LufsPreset.ebuR128);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(kTargetLufsValueKey), -23.0);
      expect(prefs.getString(kTargetLufsPresetKey), LufsPreset.ebuR128.name);
    });
  });

  group('TargetLufsSelectorCard widget tests', () {
    testWidgets('renders card with title, presets, switch, and target slider', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TargetLufsSelectorCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header title and active target badge
      expect(find.text('Target LUFS Loudness Normalization'), findsOneWidget);
      expect(find.text('-14.0 LUFS'), findsWidgets);

      // Presets
      expect(find.text('Spotify Standard'), findsOneWidget);
      expect(find.text('Apple Music'), findsOneWidget);
      expect(find.text('EBU R128'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Slider and Switch
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('tapping Apple Music preset updates target to -16.0 LUFS', (tester) async {
      SharedPreferences.setMockInitialValues({});
      LufsPreset? selectedPreset;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TargetLufsSelectorCard(
                  onPresetChanged: (p) => selectedPreset = p,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Apple Music preset button
      await tester.tap(find.text('Apple Music'));
      await tester.pumpAndSettle();

      expect(selectedPreset, LufsPreset.apple);
      expect(find.text('-16.0 LUFS'), findsWidgets);
    });

    testWidgets('tapping EBU R128 preset updates target to -23.0 LUFS', (tester) async {
      SharedPreferences.setMockInitialValues({});
      LufsPreset? selectedPreset;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TargetLufsSelectorCard(
                  onPresetChanged: (p) => selectedPreset = p,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap EBU R128 preset button
      await tester.tap(find.text('EBU R128'));
      await tester.pumpAndSettle();

      expect(selectedPreset, LufsPreset.ebuR128);
      expect(find.text('-23.0 LUFS'), findsWidgets);
    });

    testWidgets('toggling switch disables normalization and invokes callback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool? toggledValue;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TargetLufsSelectorCard(
                  onToggleChanged: (val) => toggledValue = val,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(toggledValue, isFalse);
      expect(
        find.text('Loudness normalization disabled (tracks play at original mastering level)'),
        findsOneWidget,
      );
    });

    testWidgets('moving slider triggers onTargetChanged callback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      double? changedTarget;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TargetLufsSelectorCard(
                  onTargetChanged: (val) => changedTarget = val,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Drag slider slightly to the left
      await tester.drag(sliderFinder, const Offset(-50, 0));
      await tester.pumpAndSettle();

      expect(changedTarget, isNotNull);
      expect(changedTarget!, lessThan(-14.0));
      expect(changedTarget!, greaterThanOrEqualTo(kLufsMin));
    });
  });
}
