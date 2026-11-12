// ============================================================================
// Softify Quality of Life (QoL): Silence Trimmer Unit & Widget Tests
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/dsp/silence_trimmer_service.dart';

/// In-memory mock storage implementation conforming to [SilenceTrimmerPrefsStorage].
class MockSilenceTrimmerStorage implements SilenceTrimmerPrefsStorage {
  final Map<String, dynamic> store = {};

  @override
  Future<bool?> getBool(String key) async {
    final v = store[key];
    if (v is bool) return v;
    return null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    store[key] = value;
    return true;
  }

  @override
  Future<int?> getInt(String key) async {
    final v = store[key];
    if (v is int) return v;
    return null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    store[key] = value;
    return true;
  }

  @override
  Future<double?> getDouble(String key) async {
    final v = store[key];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    store[key] = value;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSilenceTrimmerStorage mockStorage;

  setUp(() {
    SilenceTrimmerNotifier.resetForTesting();
    mockStorage = MockSilenceTrimmerStorage();
    SilenceTrimmerNotifier.customStorage = mockStorage;
  });

  tearDown(() {
    SilenceTrimmerNotifier.resetForTesting();
  });

  // ==========================================================================
  // 1. SilenceTrimmerState Model Tests
  // ==========================================================================
  group('SilenceTrimmerState Tests', () {
    test('default state initialized with correct specs', () {
      const state = SilenceTrimmerState();
      expect(state.isEnabled, isFalse);
      expect(state.thresholdMs, 500);
      expect(state.trimLeading, isTrue);
      expect(state.trimTrailing, isTrue);
      expect(state.noiseFloorDb, -60.0);
      expect(state.totalTracksTrimmed, 0);
      expect(state.totalSilenceSaved, Duration.zero);
      expect(state.formattedThreshold, '500 ms');
      expect(state.formattedSavedTime, '0s saved');
    });

    test('formattedThreshold formats milliseconds and seconds cleanly', () {
      const state200 = SilenceTrimmerState(thresholdMs: 200);
      expect(state200.formattedThreshold, '200 ms');

      const state750 = SilenceTrimmerState(thresholdMs: 750);
      expect(state750.formattedThreshold, '750 ms');

      const state1000 = SilenceTrimmerState(thresholdMs: 1000);
      expect(state1000.formattedThreshold, '1 s');

      const state1500 = SilenceTrimmerState(thresholdMs: 1500);
      expect(state1500.formattedThreshold, '1.5 s');

      const state2000 = SilenceTrimmerState(thresholdMs: 2000);
      expect(state2000.formattedThreshold, '2 s');
    });

    test('formattedSavedTime formats minutes, seconds, and milliseconds', () {
      const stateMs = SilenceTrimmerState(
        totalSilenceSaved: Duration(milliseconds: 650),
      );
      expect(stateMs.formattedSavedTime, '650ms saved');

      const stateSec = SilenceTrimmerState(
        totalSilenceSaved: Duration(seconds: 42),
      );
      expect(stateSec.formattedSavedTime, '42s saved');

      const stateMin = SilenceTrimmerState(
        totalSilenceSaved: Duration(minutes: 3, seconds: 15),
      );
      expect(stateMin.formattedSavedTime, '3m 15s saved');
    });

    test('copyWith clamps thresholdMs between 200ms and 2000ms', () {
      const state = SilenceTrimmerState();

      final underClamped = state.copyWith(thresholdMs: 50);
      expect(underClamped.thresholdMs, 200);

      final overClamped = state.copyWith(thresholdMs: 5000);
      expect(overClamped.thresholdMs, 2000);

      final valid = state.copyWith(thresholdMs: 800);
      expect(valid.thresholdMs, 800);
    });

    test('equality and hashcode contracts', () {
      const stateA = SilenceTrimmerState(thresholdMs: 600, isEnabled: true);
      const stateB = SilenceTrimmerState(thresholdMs: 600, isEnabled: true);
      const stateC = SilenceTrimmerState(thresholdMs: 800, isEnabled: true);

      expect(stateA, equals(stateB));
      expect(stateA.hashCode, equals(stateB.hashCode));
      expect(stateA == stateC, isFalse);
      expect(stateA.toString(), contains('threshold: 600ms'));
    });
  });

  // ==========================================================================
  // 2. SilenceTrimResult Model Tests
  // ==========================================================================
  group('SilenceTrimResult Tests', () {
    test('computes trimmedDuration and savedDuration accurately', () {
      const result = SilenceTrimResult(
        leadingSilenceDuration: Duration(milliseconds: 800),
        trailingSilenceDuration: Duration(milliseconds: 1200),
        originalDuration: Duration(seconds: 180),
        startOffset: Duration(milliseconds: 800),
        endCutoff: Duration(milliseconds: 178800), // 180s - 1.2s
        leadingTrimmed: true,
        trailingTrimmed: true,
      );

      expect(result.trimmedDuration, const Duration(milliseconds: 178000));
      expect(result.savedDuration, const Duration(milliseconds: 2000));
      expect(result.hasAnyTrim, isTrue);
    });

    test('untrimmed factory sets zero offsets and full duration', () {
      final untrimmed = SilenceTrimResult.untrimmed(const Duration(seconds: 210));
      expect(untrimmed.startOffset, Duration.zero);
      expect(untrimmed.endCutoff, const Duration(seconds: 210));
      expect(untrimmed.savedDuration, Duration.zero);
      expect(untrimmed.hasAnyTrim, isFalse);
    });
  });

  // ==========================================================================
  // 3. SilenceTrimmerEngine Mathematical & DSP Tests
  // ==========================================================================
  group('SilenceTrimmerEngine Math & DSP Tests', () {
    const engine = SilenceTrimmerEngine(
      thresholdMs: 500,
      noiseFloorDb: -60.0,
      trimLeading: true,
      trimTrailing: true,
    );

    test('dbToLinear and linearToDb decibel transformations', () {
      expect(SilenceTrimmerEngine.dbToLinear(0.0), closeTo(1.0, 1e-4));
      expect(SilenceTrimmerEngine.dbToLinear(-20.0), closeTo(0.1, 1e-4));
      expect(SilenceTrimmerEngine.dbToLinear(-60.0), closeTo(0.001, 1e-4));
      expect(SilenceTrimmerEngine.dbToLinear(-130.0), 0.0);

      expect(SilenceTrimmerEngine.linearToDb(1.0), closeTo(0.0, 1e-4));
      expect(SilenceTrimmerEngine.linearToDb(0.1), closeTo(-20.0, 1e-4));
      expect(SilenceTrimmerEngine.linearToDb(0.001), closeTo(-60.0, 1e-4));
      expect(SilenceTrimmerEngine.linearToDb(0.0), -100.0);
    });

    test('computeRmsFloat32 on pure silence, DC, and alternating samples', () {
      final empty = Float32List(0);
      expect(SilenceTrimmerEngine.computeRmsFloat32(empty), 0.0);

      final silence = Float32List(100);
      expect(SilenceTrimmerEngine.computeRmsFloat32(silence), 0.0);

      final fullScaleDc = Float32List(100)..fillRange(0, 100, 1.0);
      expect(SilenceTrimmerEngine.computeRmsFloat32(fullScaleDc), closeTo(1.0, 1e-5));

      final squareWave = Float32List.fromList([1.0, -1.0, 1.0, -1.0]);
      expect(SilenceTrimmerEngine.computeRmsFloat32(squareWave), closeTo(1.0, 1e-5));

      final halfAmp = Float32List(50)..fillRange(0, 50, 0.5);
      expect(SilenceTrimmerEngine.computeRmsFloat32(halfAmp), closeTo(0.5, 1e-5));
    });

    test('computeRmsInt16 on integer PCM samples', () {
      final silence = Int16List(100);
      expect(SilenceTrimmerEngine.computeRmsInt16(silence), 0.0);

      final fullScale = Int16List(100)..fillRange(0, 100, 32767);
      expect(SilenceTrimmerEngine.computeRmsInt16(fullScale), closeTo(1.0, 1e-3));
    });

    test('detectLeadingSilence identifies dead air at buffer beginning', () {
      const sampleRate = 44100;
      const channels = 2;
      // 500ms silence = 0.5 * 44100 * 2 = 44100 samples
      const silentSamples = 44100;
      // 500ms audio
      const audioSamples = 44100;

      final buffer = Float32List(silentSamples + audioSamples);
      buffer.fillRange(silentSamples, buffer.length, 0.5); // audible portion

      final leading = engine.detectLeadingSilence(
        buffer,
        sampleRate: sampleRate,
        channels: channels,
        frameSizeMs: 10,
      );

      // Should be approximately 500ms
      expect(leading.inMilliseconds, inInclusiveRange(490, 510));
    });

    test('detectLeadingSilence returns 0ms when audio starts immediately', () {
      final buffer = Float32List(1000)..fillRange(0, 1000, 0.8);
      final leading = engine.detectLeadingSilence(
        buffer,
        sampleRate: 44100,
        channels: 2,
      );
      expect(leading, Duration.zero);
    });

    test('detectLeadingSilence returns full buffer duration for silent stream', () {
      final buffer = Float32List(44100 * 2); // 1 second of silence
      final leading = engine.detectLeadingSilence(
        buffer,
        sampleRate: 44100,
        channels: 2,
      );
      expect(leading.inMilliseconds, inInclusiveRange(990, 1000));
    });

    test('detectTrailingSilence identifies dead air at buffer end', () {
      const sampleRate = 44100;
      const channels = 2;
      // 600ms audio followed by 400ms silence
      const audioSamples = (44100 * 6 ~/ 10) * 2;
      const silentSamples = (44100 * 4 ~/ 10) * 2;

      final buffer = Float32List(audioSamples + silentSamples);
      buffer.fillRange(0, audioSamples, 0.6); // audible portion

      final trailing = engine.detectTrailingSilence(
        buffer,
        sampleRate: sampleRate,
        channels: channels,
        frameSizeMs: 10,
      );

      expect(trailing.inMilliseconds, inInclusiveRange(390, 410));
    });

    test('detectLeadingSilenceInt16 and detectTrailingSilenceInt16', () {
      const sampleRate = 44100;
      const channels = 1;
      final buffer = Int16List(44100);
      // First 22050 samples (500ms) silence, second 22050 samples audio
      buffer.fillRange(22050, 44100, 20000);

      final leading = engine.detectLeadingSilenceInt16(
        buffer,
        sampleRate: sampleRate,
        channels: channels,
      );
      expect(leading.inMilliseconds, inInclusiveRange(490, 510));

      final trailing = engine.detectTrailingSilenceInt16(
        buffer,
        sampleRate: sampleRate,
        channels: channels,
      );
      expect(trailing.inMilliseconds, 0);
    });

    test('evaluateTrack trims silence exceeding 500ms threshold', () {
      final result = engine.evaluateTrack(
        totalDuration: const Duration(seconds: 200),
        leadingSilence: const Duration(milliseconds: 750), // > 500ms -> trimmed
        trailingSilence: const Duration(milliseconds: 1200), // > 500ms -> trimmed
      );

      expect(result.leadingTrimmed, isTrue);
      expect(result.trailingTrimmed, isTrue);
      expect(result.startOffset, const Duration(milliseconds: 750));
      expect(result.endCutoff, const Duration(milliseconds: 198800));
      expect(result.savedDuration, const Duration(milliseconds: 1950));
    });

    test('evaluateTrack preserves silence shorter than threshold (<500ms)', () {
      final result = engine.evaluateTrack(
        totalDuration: const Duration(seconds: 180),
        leadingSilence: const Duration(milliseconds: 300), // < 500ms -> preserved
        trailingSilence: const Duration(milliseconds: 450), // < 500ms -> preserved
      );

      expect(result.leadingTrimmed, isFalse);
      expect(result.trailingTrimmed, isFalse);
      expect(result.startOffset, Duration.zero);
      expect(result.endCutoff, const Duration(seconds: 180));
      expect(result.savedDuration, Duration.zero);
    });

    test('evaluateTrack respects trimLeading and trimTrailing flags', () {
      const leadingOnlyEngine = SilenceTrimmerEngine(
        thresholdMs: 500,
        trimLeading: true,
        trimTrailing: false,
      );

      final result = leadingOnlyEngine.evaluateTrack(
        totalDuration: const Duration(seconds: 100),
        leadingSilence: const Duration(milliseconds: 800),
        trailingSilence: const Duration(milliseconds: 900),
      );

      expect(result.leadingTrimmed, isTrue);
      expect(result.trailingTrimmed, isFalse);
      expect(result.startOffset, const Duration(milliseconds: 800));
      expect(result.endCutoff, const Duration(seconds: 100));
    });

    test('trimFloat32Buffer exscinds leading and trailing silence', () {
      const sampleRate = 44100;
      const channels = 2;
      // 1000ms silence + 1000ms audio + 1000ms silence
      const oneSecSamples = 44100 * 2;
      final buffer = Float32List(oneSecSamples * 3);
      buffer.fillRange(oneSecSamples, oneSecSamples * 2, 0.7);

      final trimmed = engine.trimFloat32Buffer(
        buffer,
        sampleRate: sampleRate,
        channels: channels,
      );

      // Trimmed buffer should only contain approximately the middle 1 second
      expect(trimmed.length, inInclusiveRange(oneSecSamples - 2000, oneSecSamples + 2000));
    });

    test('playhead jump and advance decision helpers', () {
      // shouldSkipLeading
      expect(
        engine.shouldSkipLeading(
          currentPosition: const Duration(milliseconds: 200),
          leadingSilence: const Duration(milliseconds: 800),
        ),
        isTrue,
      );

      expect(
        engine.shouldSkipLeading(
          currentPosition: const Duration(milliseconds: 900),
          leadingSilence: const Duration(milliseconds: 800),
        ),
        isFalse,
      );

      expect(
        engine.shouldSkipLeading(
          currentPosition: const Duration(milliseconds: 100),
          leadingSilence: const Duration(milliseconds: 300), // Below 500ms threshold
        ),
        isFalse,
      );

      // shouldAdvanceTrailing
      expect(
        engine.shouldAdvanceTrailing(
          currentPosition: const Duration(milliseconds: 99200),
          totalDuration: const Duration(seconds: 100),
          trailingSilence: const Duration(milliseconds: 1000), // Cutoff at 99.0s
        ),
        isTrue,
      );

      expect(
        engine.shouldAdvanceTrailing(
          currentPosition: const Duration(milliseconds: 98000),
          totalDuration: const Duration(seconds: 100),
          trailingSilence: const Duration(milliseconds: 1000), // Cutoff at 99.0s
        ),
        isFalse,
      );

      // Target offsets
      expect(
        engine.getPlayheadStartOffset(const Duration(milliseconds: 700)),
        const Duration(milliseconds: 700),
      );
      expect(
        engine.getPlayheadStartOffset(const Duration(milliseconds: 300)),
        Duration.zero,
      );
      expect(
        engine.getPlayheadEndCutoff(
          const Duration(seconds: 60),
          const Duration(milliseconds: 800),
        ),
        const Duration(milliseconds: 59200),
      );
    });
  });

  // ==========================================================================
  // 4. SilenceTrimmerNotifier & Riverpod State Tests
  // ==========================================================================
  group('SilenceTrimmerNotifier Tests', () {
    test('initializes with defaults when store is empty', () {
      final notifier = SilenceTrimmerNotifier();
      expect(notifier.state.isEnabled, isFalse);
      expect(notifier.state.thresholdMs, 500);
      expect(notifier.state.trimLeading, isTrue);
      expect(notifier.state.trimTrailing, isTrue);
    });

    test('toggle flips enabled and writes to persistent storage', () async {
      final notifier = SilenceTrimmerNotifier();
      expect(notifier.state.isEnabled, isFalse);

      await notifier.toggle();
      expect(notifier.state.isEnabled, isTrue);
      expect(mockStorage.store[kSilenceTrimmerEnabledKey], isTrue);

      await notifier.toggle();
      expect(notifier.state.isEnabled, isFalse);
      expect(mockStorage.store[kSilenceTrimmerEnabledKey], isFalse);
    });

    test('setThresholdMs clamps to 200..2000 and persists', () async {
      final notifier = SilenceTrimmerNotifier();

      await notifier.setThresholdMs(750);
      expect(notifier.state.thresholdMs, 750);
      expect(mockStorage.store[kSilenceTrimmerThresholdMsKey], 750);

      await notifier.setThresholdMs(50);
      expect(notifier.state.thresholdMs, 200);

      await notifier.setThresholdMs(3000);
      expect(notifier.state.thresholdMs, 2000);
    });

    test('setTrimLeading and setTrimTrailing update and persist', () async {
      final notifier = SilenceTrimmerNotifier();

      await notifier.setTrimLeading(false);
      expect(notifier.state.trimLeading, isFalse);
      expect(mockStorage.store[kSilenceTrimmerTrimLeadingKey], isFalse);

      await notifier.setTrimTrailing(false);
      expect(notifier.state.trimTrailing, isFalse);
      expect(mockStorage.store[kSilenceTrimmerTrimTrailingKey], isFalse);
    });

    test('setNoiseFloorDb updates and persists', () async {
      final notifier = SilenceTrimmerNotifier();

      await notifier.setNoiseFloorDb(-50.0);
      expect(notifier.state.noiseFloorDb, -50.0);
      expect(mockStorage.store[kSilenceTrimmerNoiseFloorDbKey], -50.0);
    });

    test('recordTrimEvent accumulates tracks and saved silence', () {
      final notifier = SilenceTrimmerNotifier();
      expect(notifier.state.totalTracksTrimmed, 0);

      notifier.recordTrimEvent(
        leadingTrimmed: const Duration(milliseconds: 600),
        trailingTrimmed: const Duration(milliseconds: 800),
      );

      expect(notifier.state.totalTracksTrimmed, 1);
      expect(notifier.state.totalSilenceSaved, const Duration(milliseconds: 1400));

      notifier.recordTrimEvent(
        leadingTrimmed: const Duration(seconds: 1),
        trailingTrimmed: Duration.zero,
      );

      expect(notifier.state.totalTracksTrimmed, 2);
      expect(notifier.state.totalSilenceSaved, const Duration(milliseconds: 2400));
    });

    test('resetToDefaults resets state and clears storage', () async {
      final notifier = SilenceTrimmerNotifier();
      await notifier.setEnabled(true);
      await notifier.setThresholdMs(1200);
      await notifier.setTrimLeading(false);

      expect(notifier.state.isEnabled, isTrue);
      expect(notifier.state.thresholdMs, 1200);

      await notifier.resetToDefaults();

      expect(notifier.state.isEnabled, isFalse);
      expect(notifier.state.thresholdMs, 500);
      expect(notifier.state.trimLeading, isTrue);
      expect(notifier.state.trimTrailing, isTrue);
      expect(mockStorage.store[kSilenceTrimmerEnabledKey], isFalse);
      expect(mockStorage.store[kSilenceTrimmerThresholdMsKey], 500);
    });

    test('loads persisted settings on construction', () async {
      mockStorage.store[kSilenceTrimmerEnabledKey] = true;
      mockStorage.store[kSilenceTrimmerThresholdMsKey] = 800;
      mockStorage.store[kSilenceTrimmerTrimLeadingKey] = false;

      final notifier = SilenceTrimmerNotifier();
      // Allow async load to complete
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(notifier.state.isEnabled, isTrue);
      expect(notifier.state.thresholdMs, 800);
      expect(notifier.state.trimLeading, isFalse);
      expect(notifier.state.trimTrailing, isTrue);
    });

    test('evaluateTrack returns untrimmed when isEnabled is false', () {
      final notifier = SilenceTrimmerNotifier();
      expect(notifier.state.isEnabled, isFalse);

      final result = notifier.evaluateTrack(
        totalDuration: const Duration(seconds: 120),
        leadingSilence: const Duration(seconds: 2),
        trailingSilence: const Duration(seconds: 3),
      );

      expect(result.hasAnyTrim, isFalse);
      expect(result.startOffset, Duration.zero);
      expect(result.endCutoff, const Duration(seconds: 120));
    });

    test('evaluateTrack auto-skips when isEnabled is true', () async {
      final notifier = SilenceTrimmerNotifier();
      await notifier.setEnabled(true);

      final result = notifier.evaluateTrack(
        totalDuration: const Duration(seconds: 120),
        leadingSilence: const Duration(seconds: 1),
        trailingSilence: const Duration(seconds: 2),
      );

      expect(result.hasAnyTrim, isTrue);
      expect(result.startOffset, const Duration(seconds: 1));
      expect(result.endCutoff, const Duration(seconds: 118));
      expect(result.savedDuration, const Duration(seconds: 3));
    });
  });

  // ==========================================================================
  // 5. Riverpod Providers Tests
  // ==========================================================================
  group('Riverpod Providers Tests', () {
    test('providers expose consistent reactive slices', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isSilenceTrimmerEnabledProvider), isFalse);
      expect(container.read(silenceThresholdMsProvider), 500);
      expect(container.read(silenceTrimLeadingProvider), isTrue);
      expect(container.read(silenceTrimTrailingProvider), isTrue);

      final notifier = container.read(silenceTrimmerProvider.notifier);
      await notifier.setEnabled(true);
      await notifier.setThresholdMs(1000);

      expect(container.read(isSilenceTrimmerEnabledProvider), isTrue);
      expect(container.read(silenceThresholdMsProvider), 1000);

      final engine = container.read(silenceTrimmerEngineProvider);
      expect(engine.thresholdMs, 1000);
    });
  });

  // ==========================================================================
  // 6. SilenceTrimmerSettingsCard Widget Tests
  // ==========================================================================
  group('SilenceTrimmerSettingsCard Widget Tests', () {
    testWidgets('renders header, title, badge, and toggle switch', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SilenceTrimmerSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Silence Trimmer'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      // Detail controls hidden when off
      expect(find.text('Silence Threshold'), findsNothing);
    });

    testWidgets('toggling switch reveals slider, presets, and checkboxes', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool? toggledValue;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SilenceTrimmerSettingsCard(
                onToggled: (v) => toggledValue = v,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(toggledValue, isTrue);
      expect(find.text('Active (500 ms)'), findsOneWidget);
      expect(find.text('Silence Threshold'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('500ms (Def)'), findsOneWidget);
      expect(find.text('Trim intro silence'), findsOneWidget);
      expect(find.text('Trim outro silence'), findsOneWidget);
    });

    testWidgets('tapping preset chip updates threshold and slider', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-enable trimmer
      container.read(silenceTrimmerProvider.notifier).setEnabled(true);

      int? changedThreshold;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SilenceTrimmerSettingsCard(
                onThresholdChanged: (ms) => changedThreshold = ms,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the '200ms' preset chip
      final chip200 = find.text('200ms');
      expect(chip200, findsOneWidget);
      await tester.tap(chip200);
      await tester.pumpAndSettle();

      expect(changedThreshold, 200);
      expect(container.read(silenceThresholdMsProvider), 200);
      expect(find.text('Active (200 ms)'), findsOneWidget);
    });

    testWidgets('checkboxes toggle leading and trailing intro/outro flags', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(silenceTrimmerProvider.notifier).setEnabled(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SilenceTrimmerSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(silenceTrimLeadingProvider), isTrue);

      // Tap 'Trim intro silence'
      await tester.tap(find.text('Trim intro silence'));
      await tester.pumpAndSettle();

      expect(container.read(silenceTrimLeadingProvider), isFalse);

      // Tap 'Trim outro silence'
      expect(container.read(silenceTrimTrailingProvider), isTrue);
      await tester.tap(find.text('Trim outro silence'));
      await tester.pumpAndSettle();

      expect(container.read(silenceTrimTrailingProvider), isFalse);
    });

    testWidgets('shows cumulative saved time banner when stats available', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(silenceTrimmerProvider.notifier);
      await notifier.setEnabled(true);
      notifier.recordTrimEvent(
        leadingTrimmed: const Duration(seconds: 15),
        trailingTrimmed: const Duration(seconds: 30),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SilenceTrimmerSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      expect(find.textContaining('Eliminated 45s saved of dead air'), findsOneWidget);
    });
  });
}
