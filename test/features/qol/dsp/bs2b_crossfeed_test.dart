// ============================================================================
// Unit & Widget Tests: Headphone Crossfeed (Bauer BS2B DSP)
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/features/qol/dsp/bs2b_crossfeed_service.dart';

/// In-memory mock storage for deterministic unit testing.
class FakeBs2bPrefsStorage implements Bs2bPrefsStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

void main() {
  setUp(() {
    Bs2bCrossfeedNotifier.resetForTesting();
  });

  tearDown(() {
    Bs2bCrossfeedNotifier.resetForTesting();
  });

  // ==========================================================================
  // Group 1: Bs2bPreset Model & Domain Logic
  // ==========================================================================
  group('Bs2bPreset Enum & Domain Logic', () {
    test('contains all 4 required presets with authentic specifications', () {
      expect(Bs2bPreset.values.length, 4);

      // 1. Off preset
      expect(Bs2bPreset.off.id, 'off');
      expect(Bs2bPreset.off.isEnabled, false);
      expect(Bs2bPreset.off.cutoffHz, isNull);
      expect(Bs2bPreset.off.feedDb, 0.0);
      expect(Bs2bPreset.off.subtitle, 'Bypass');

      // 2. Default Bauer preset (700 Hz, 4.5 dB)
      expect(Bs2bPreset.defaultPreset.id, 'default');
      expect(Bs2bPreset.defaultPreset.isEnabled, true);
      expect(Bs2bPreset.defaultPreset.cutoffHz, 700);
      expect(Bs2bPreset.defaultPreset.feedDb, 4.5);
      expect(Bs2bPreset.defaultPreset.label, 'Default (700Hz, 4.5dB)');
      expect(Bs2bPreset.defaultPreset.subtitle, contains('700 Hz'));

      // 3. Chu Moy preset (700 Hz, 6.0 dB)
      expect(Bs2bPreset.chuMoy.id, 'chu_moy');
      expect(Bs2bPreset.chuMoy.isEnabled, true);
      expect(Bs2bPreset.chuMoy.cutoffHz, 700);
      expect(Bs2bPreset.chuMoy.feedDb, 6.0);
      expect(Bs2bPreset.chuMoy.label, 'Chu Moy (700Hz, 6dB)');
      expect(Bs2bPreset.chuMoy.subtitle, contains('6.0 dB'));

      // 4. Jan Meier preset (650 Hz, 9.5 dB)
      expect(Bs2bPreset.janMeier.id, 'jan_meier');
      expect(Bs2bPreset.janMeier.isEnabled, true);
      expect(Bs2bPreset.janMeier.cutoffHz, 650);
      expect(Bs2bPreset.janMeier.feedDb, 9.5);
      expect(Bs2bPreset.janMeier.label, 'Jan Meier (650Hz, 9.5dB)');
      expect(Bs2bPreset.janMeier.subtitle, contains('650 Hz'));
    });

    test('Bs2bPreset.fromId parses IDs and names correctly with safe fallback', () {
      expect(Bs2bPreset.fromId('off'), Bs2bPreset.off);
      expect(Bs2bPreset.fromId('default'), Bs2bPreset.defaultPreset);
      expect(Bs2bPreset.fromId('Default'), Bs2bPreset.defaultPreset);
      expect(Bs2bPreset.fromId('chu_moy'), Bs2bPreset.chuMoy);
      expect(Bs2bPreset.fromId('Chu Moy'), Bs2bPreset.chuMoy);
      expect(Bs2bPreset.fromId('jan_meier'), Bs2bPreset.janMeier);
      expect(Bs2bPreset.fromId('Jan Meier'), Bs2bPreset.janMeier);

      // Fallback
      expect(Bs2bPreset.fromId(null), Bs2bPreset.off);
      expect(Bs2bPreset.fromId('unknown_preset'), Bs2bPreset.off);
      expect(Bs2bPreset.fromId(''), Bs2bPreset.off);
    });
  });

  // ==========================================================================
  // Group 2: Pure Dart BS2B DSP Engine Calculations
  // ==========================================================================
  group('Bs2bCrossfeedEngine Pure Dart DSP', () {
    test('Off preset passes audio samples through unmodified', () {
      final engine = Bs2bCrossfeedEngine(preset: Bs2bPreset.off);
      expect(engine.isEnabled, false);

      final (outL, outR) = engine.processSample(0.8, -0.4);
      expect(outL, 0.8);
      expect(outR, -0.4);

      final buffer = Float32List.fromList([1.0, 0.0, -0.5, 0.5]);
      engine.processInterleaved(buffer);
      expect(buffer[0], 1.0);
      expect(buffer[1], 0.0);
      expect(buffer[2], -0.5);
      expect(buffer[3], 0.5);
    });

    test('Computes valid IIR filter coefficients for active presets', () {
      final engine = Bs2bCrossfeedEngine(
        preset: Bs2bPreset.defaultPreset,
        sampleRate: 44100,
      );

      expect(engine.isEnabled, true);
      expect(engine.a0Lo, isPositive);
      expect(engine.b1Lo, inInclusiveRange(0.0, 1.0));
      expect(engine.a0Hi, isPositive);
      expect(engine.a1Hi, isNegative);
      expect(engine.b1Hi, inInclusiveRange(0.0, 1.0));
      expect(engine.gain, greaterThan(1.0));
    });

    test('Chu Moy 6dB preset exhibits ~2:1 acoustic energy ratio at DC', () {
      final engine = Bs2bCrossfeedEngine(
        preset: Bs2bPreset.chuMoy,
        sampleRate: 44100,
      );

      // Feed 500 samples of hard-panned DC step [1.0, 0.0]
      double outL = 0.0;
      double outR = 0.0;
      for (int i = 0; i < 500; i++) {
        final pair = engine.processSample(1.0, 0.0);
        outL = pair.$1;
        outR = pair.$2;
      }

      // Chu Moy 6.0 dB level: Left ear ~ 0.666, Right ear ~ 0.334
      // Ratio: 0.666 / 0.334 ~= 2.0 (factor of 2 = 6 dB voltage ratio)
      expect(outL, closeTo(0.666, 0.01));
      expect(outR, closeTo(0.334, 0.01));
      expect(outL + outR, closeTo(1.0, 0.01));
    });

    test('Jan Meier 9.5dB preset exhibits ~3:1 acoustic energy ratio at DC', () {
      final engine = Bs2bCrossfeedEngine(
        preset: Bs2bPreset.janMeier,
        sampleRate: 44100,
      );

      double outL = 0.0;
      double outR = 0.0;
      for (int i = 0; i < 500; i++) {
        final pair = engine.processSample(1.0, 0.0);
        outL = pair.$1;
        outR = pair.$2;
      }

      // Jan Meier 9.5 dB level: Left ear ~ 0.749, Right ear ~ 0.251
      // Ratio: 0.749 / 0.251 ~= 2.984 (20*log10(2.984) = 9.5 dB)
      expect(outL, closeTo(0.749, 0.01));
      expect(outR, closeTo(0.251, 0.01));
      expect(outL + outR, closeTo(1.0, 0.01));
    });

    test('Default 4.5dB preset exhibits ~0.627 / 0.373 acoustic energy ratio at DC', () {
      final engine = Bs2bCrossfeedEngine(
        preset: Bs2bPreset.defaultPreset,
        sampleRate: 44100,
      );

      double outL = 0.0;
      double outR = 0.0;
      for (int i = 0; i < 500; i++) {
        final pair = engine.processSample(1.0, 0.0);
        outL = pair.$1;
        outR = pair.$2;
      }

      expect(outL, closeTo(0.627, 0.01));
      expect(outR, closeTo(0.373, 0.01));
      expect(outL + outR, closeTo(1.0, 0.01));
    });

    test('High frequencies are shadowed and remain isolated to direct channel', () {
      final engine = Bs2bCrossfeedEngine(
        preset: Bs2bPreset.defaultPreset,
        sampleRate: 44100,
      );

      double lastOutL = 0.0;
      double lastOutR = 0.0;

      // Feed Nyquist frequency alternating signal (+1, -1) on Left only
      for (int i = 0; i < 500; i++) {
        final inL = (i % 2 == 0) ? 1.0 : -1.0;
        final pair = engine.processSample(inL, 0.0);
        lastOutL = pair.$1;
        lastOutR = pair.$2;
      }

      // High frequency should not bleed significantly into Right channel
      expect(lastOutL.abs(), greaterThan(0.7));
      expect(lastOutR.abs(), lessThan(0.05));
    });

    test('processInterleaved processes Float32List in place', () {
      final engine = Bs2bCrossfeedEngine(preset: Bs2bPreset.defaultPreset);
      final buffer = Float32List.fromList([1.0, 0.0, 0.0, 1.0]);

      engine.processInterleaved(buffer);

      // Lowpass and highboost should alter values
      expect(buffer[0], isNot(1.0));
      expect(buffer[1], isNot(0.0));
    });

    test('processPlanar processes separate channels in place', () {
      final engine = Bs2bCrossfeedEngine(preset: Bs2bPreset.defaultPreset);
      final left = Float32List.fromList([1.0, 1.0, 1.0]);
      final right = Float32List.fromList([0.0, 0.0, 0.0]);

      engine.processPlanar(left, right);

      expect(left[0], isNot(1.0));
      expect(right[0], isNot(0.0));
    });

    test('processInterleavedCopy creates modified copy leaving original untouched', () {
      final engine = Bs2bCrossfeedEngine(preset: Bs2bPreset.defaultPreset);
      final original = Float32List.fromList([1.0, 0.0, -1.0, 0.0]);
      final copy = engine.processInterleavedCopy(original);

      expect(original[0], 1.0);
      expect(original[1], 0.0);
      expect(copy[0], isNot(1.0));
      expect(copy[1], isNot(0.0));
    });

    test('processInt16Interleaved processes and clamps 16-bit integer PCM', () {
      final engine = Bs2bCrossfeedEngine(preset: Bs2bPreset.defaultPreset);
      final buffer = Int16List.fromList([32767, 0, -32768, 0]);

      engine.processInt16Interleaved(buffer);

      expect(buffer[0], inInclusiveRange(-32768, 32767));
      expect(buffer[1], inInclusiveRange(-32768, 32767));
      expect(buffer[1], isNot(0)); // Crossfeed introduced
    });

    test('setSampleRate adjusts coefficients across hi-res sample rates', () {
      final engine = Bs2bCrossfeedEngine(preset: Bs2bPreset.defaultPreset);
      final b1_44k = engine.b1Lo;

      engine.setSampleRate(96000);
      expect(engine.sampleRate, 96000);
      expect(engine.b1Lo, isNot(b1_44k));

      engine.setSampleRate(192000);
      expect(engine.sampleRate, 192000);
    });

    test('reset clears internal filter memory', () {
      final engine = Bs2bCrossfeedEngine(preset: Bs2bPreset.defaultPreset);
      engine.processSample(1.0, 0.5);

      engine.reset();
      // After reset, single sample should produce fresh initial step
      final (freshL, freshR) = engine.processSample(0.0, 0.0);
      expect(freshL, 0.0);
      expect(freshR, 0.0);
    });
  });

  // ==========================================================================
  // Group 3: Riverpod StateNotifier & Persistence
  // ==========================================================================
  group('Bs2bCrossfeedNotifier State & Persistence', () {
    test('initial state defaults to Off', () {
      final storage = FakeBs2bPrefsStorage();
      final notifier = Bs2bCrossfeedNotifier(storage: storage);

      expect(notifier.state.preset, Bs2bPreset.off);
      expect(notifier.state.isEnabled, false);
      expect(notifier.state.sampleRate, 44100);
      expect(notifier.state.lastActivePreset, Bs2bPreset.defaultPreset);

      notifier.dispose();
    });

    test('setPreset updates state, engine, and persistent storage', () async {
      final storage = FakeBs2bPrefsStorage();
      final engine = Bs2bCrossfeedEngine();
      final notifier = Bs2bCrossfeedNotifier(storage: storage, engine: engine);

      await notifier.setPreset(Bs2bPreset.chuMoy);

      expect(notifier.state.preset, Bs2bPreset.chuMoy);
      expect(notifier.state.isEnabled, true);
      expect(engine.preset, Bs2bPreset.chuMoy);
      expect(storage.values[kBs2bCrossfeedPresetPrefKey], 'chu_moy');

      notifier.dispose();
    });

    test('toggle switches between Off and previous active preset', () async {
      final storage = FakeBs2bPrefsStorage();
      final notifier = Bs2bCrossfeedNotifier(storage: storage);

      // Off -> Default
      await notifier.toggle();
      expect(notifier.state.preset, Bs2bPreset.defaultPreset);
      expect(notifier.state.isEnabled, true);

      // Change to Jan Meier
      await notifier.setPreset(Bs2bPreset.janMeier);
      expect(notifier.state.preset, Bs2bPreset.janMeier);

      // Toggle off
      await notifier.toggle();
      expect(notifier.state.preset, Bs2bPreset.off);
      expect(notifier.state.isEnabled, false);

      // Toggle back on should restore Jan Meier
      await notifier.toggle();
      expect(notifier.state.preset, Bs2bPreset.janMeier);

      notifier.dispose();
    });

    test('cycleNextPreset iterates through all presets cyclically', () async {
      final storage = FakeBs2bPrefsStorage();
      final notifier = Bs2bCrossfeedNotifier(storage: storage);

      expect(notifier.state.preset, Bs2bPreset.off);

      await notifier.cycleNextPreset();
      expect(notifier.state.preset, Bs2bPreset.defaultPreset);

      await notifier.cycleNextPreset();
      expect(notifier.state.preset, Bs2bPreset.chuMoy);

      await notifier.cycleNextPreset();
      expect(notifier.state.preset, Bs2bPreset.janMeier);

      await notifier.cycleNextPreset();
      expect(notifier.state.preset, Bs2bPreset.off);

      notifier.dispose();
    });

    test('setSampleRate and resetDspState function properly', () {
      final engine = Bs2bCrossfeedEngine();
      final notifier = Bs2bCrossfeedNotifier(
        storage: FakeBs2bPrefsStorage(),
        engine: engine,
      );

      notifier.setSampleRate(48000);
      expect(notifier.state.sampleRate, 48000);
      expect(engine.sampleRate, 48000);

      notifier.resetDspState();

      notifier.dispose();
    });

    test('loads previously persisted preset asynchronously on init', () async {
      final storage = FakeBs2bPrefsStorage();
      storage.values[kBs2bCrossfeedPresetPrefKey] = 'jan_meier';

      final notifier = Bs2bCrossfeedNotifier(storage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.preset, Bs2bPreset.janMeier);
      expect(notifier.state.isEnabled, true);

      notifier.dispose();
    });
  });

  // ==========================================================================
  // Group 4: Bs2bCrossfeedSelector Widget Tests
  // ==========================================================================
  group('Bs2bCrossfeedSelector Widget Tests', () {
    testWidgets('renders all preset choice chips and header elements', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Bs2bCrossfeedSelector(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Header
      expect(find.text('Headphone Crossfeed'), findsOneWidget);
      expect(find.byKey(const Key('bs2b_selector_card')), findsOneWidget);
      expect(find.byKey(const Key('bs2b_switch')), findsOneWidget);

      // All 4 chips
      expect(find.byKey(const Key('bs2b_chip_off')), findsOneWidget);
      expect(find.byKey(const Key('bs2b_chip_default')), findsOneWidget);
      expect(find.byKey(const Key('bs2b_chip_chu_moy')), findsOneWidget);
      expect(find.byKey(const Key('bs2b_chip_jan_meier')), findsOneWidget);

      // Info card showing Off status
      expect(find.byKey(const Key('bs2b_info_card')), findsOneWidget);
      expect(find.text('Bypass'), findsOneWidget);
    });

    testWidgets('tapping preset chip updates selection and calls onPresetChanged', (
      tester,
    ) async {
      Bs2bPreset? selectedPreset;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Bs2bCrossfeedSelector(
                onPresetChanged: (preset) {
                  selectedPreset = preset;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Default preset chip
      await tester.tap(find.byKey(const Key('bs2b_chip_default')));
      await tester.pumpAndSettle();

      expect(selectedPreset, Bs2bPreset.defaultPreset);
      expect(find.text('BS2B Active'), findsOneWidget);
      expect(find.text('700 Hz Cutoff'), findsOneWidget);
      expect(find.text('4.5 dB Level'), findsOneWidget);

      // Tap Chu Moy chip
      await tester.tap(find.byKey(const Key('bs2b_chip_chu_moy')));
      await tester.pumpAndSettle();

      expect(selectedPreset, Bs2bPreset.chuMoy);
      expect(find.text('6.0 dB Level'), findsOneWidget);

      // Tap Jan Meier chip
      await tester.tap(find.byKey(const Key('bs2b_chip_jan_meier')));
      await tester.pumpAndSettle();

      expect(selectedPreset, Bs2bPreset.janMeier);
      expect(find.text('650 Hz Cutoff'), findsOneWidget);
      expect(find.text('9.5 dB Level'), findsOneWidget);
    });

    testWidgets('switch toggle turns crossfeed on and off', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Bs2bCrossfeedSelector(),
            ),
          ),
        ),
      );
      await tester.pump();

      final switchFinder = find.byKey(const Key('bs2b_switch'));
      expect(switchFinder, findsOneWidget);

      // Turn on switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('BS2B Active'), findsOneWidget);

      // Turn off switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('BS2B Active'), findsNothing);
      expect(find.text('Bypass'), findsOneWidget);
    });

    testWidgets('compact mode suppresses the detailed info card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Bs2bCrossfeedSelector(compact: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('bs2b_selector_card')), findsOneWidget);
      expect(find.byKey(const Key('bs2b_chip_default')), findsOneWidget);
      expect(find.byKey(const Key('bs2b_info_card')), findsNothing);
    });
  });
}
