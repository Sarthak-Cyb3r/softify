// ============================================================================
// Unit & Widget Tests: Feature 40 Audio Spectrum Canvas Wave Visualizer
// ============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/features/qol/lyrics/canvas_wave_visualizer.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  // ==========================================================================
  // 1. CanvasWaveVisualizerConfig Model & Serialization Tests
  // ==========================================================================
  group('CanvasWaveVisualizerConfig Model Tests', () {
    test('default configuration has correct initial values', () {
      const config = CanvasWaveVisualizerConfig();

      expect(config.isEnabled, isTrue);
      expect(config.style, WaveVisualizerStyle.waveform);
      expect(config.colorPalette, WaveVisualizerColorPalette.themeAccent);
      expect(config.barCount, 32);
      expect(config.sensitivity, 1.0);
      expect(config.dampingFactor, 0.22);
      expect(config.waveSpeed, 1.0);
      expect(config.waveLayers, 3);
      expect(config.showPeaks, isTrue);
      expect(config.targetFps, 60);
      expect(config.isMirrored, isFalse);
      expect(config.opacity, 0.85);
      expect(config.reactiveToPlayback, isTrue);
      expect(config.customColors, isNull);
    });

    test('copyWith creates modified copy while preserving other attributes', () {
      const original = CanvasWaveVisualizerConfig();
      final modified = original.copyWith(
        isEnabled: false,
        style: WaveVisualizerStyle.harmonicBars,
        colorPalette: WaveVisualizerColorPalette.cyberpunkNeon,
        barCount: 48,
        sensitivity: 1.5,
        targetFps: 30,
        isMirrored: true,
      );

      expect(modified.isEnabled, isFalse);
      expect(modified.style, WaveVisualizerStyle.harmonicBars);
      expect(modified.colorPalette, WaveVisualizerColorPalette.cyberpunkNeon);
      expect(modified.barCount, 48);
      expect(modified.sensitivity, 1.5);
      expect(modified.targetFps, 30);
      expect(modified.isMirrored, isTrue);
      // Preserved attributes
      expect(modified.dampingFactor, original.dampingFactor);
      expect(modified.waveSpeed, original.waveSpeed);
      expect(modified.waveLayers, original.waveLayers);
    });

    test('toJson and fromJson serialize and deserialize correctly', () {
      const config = CanvasWaveVisualizerConfig(
        isEnabled: true,
        style: WaveVisualizerStyle.radialCircle,
        colorPalette: WaveVisualizerColorPalette.sunsetWarm,
        barCount: 64,
        sensitivity: 1.8,
        dampingFactor: 0.35,
        waveSpeed: 1.5,
        waveLayers: 4,
        showPeaks: false,
        targetFps: 120,
        isMirrored: true,
        opacity: 0.75,
        reactiveToPlayback: false,
        customColors: [Color(0xFFFF0000), Color(0xFF00FF00)],
      );

      final jsonMap = config.toJson();
      final restored = CanvasWaveVisualizerConfig.fromJson(jsonMap);

      expect(restored.isEnabled, config.isEnabled);
      expect(restored.style, config.style);
      expect(restored.colorPalette, config.colorPalette);
      expect(restored.barCount, config.barCount);
      expect(restored.sensitivity, config.sensitivity);
      expect(restored.dampingFactor, config.dampingFactor);
      expect(restored.waveSpeed, config.waveSpeed);
      expect(restored.waveLayers, config.waveLayers);
      expect(restored.showPeaks, config.showPeaks);
      expect(restored.targetFps, config.targetFps);
      expect(restored.isMirrored, config.isMirrored);
      expect(restored.opacity, config.opacity);
      expect(restored.reactiveToPlayback, config.reactiveToPlayback);
      expect(restored.customColors?.length, 2);
      expect(restored.customColors?.first.value, const Color(0xFFFF0000).value);
    });

    test('operator == and hashCode compare by value', () {
      const config1 = CanvasWaveVisualizerConfig(
        barCount: 24,
        sensitivity: 1.2,
      );
      const config2 = CanvasWaveVisualizerConfig(
        barCount: 24,
        sensitivity: 1.2,
      );
      const config3 = CanvasWaveVisualizerConfig(
        barCount: 48,
        sensitivity: 1.2,
      );

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });
  });

  // ==========================================================================
  // 2. WaveVisualizerStyle & WaveVisualizerColorPalette Tests
  // ==========================================================================
  group('WaveVisualizerStyle & Palette Tests', () {
    test('WaveVisualizerStyle fromId returns correct enum value', () {
      expect(WaveVisualizerStyle.fromId('waveform'), WaveVisualizerStyle.waveform);
      expect(
        WaveVisualizerStyle.fromId('harmonic_bars'),
        WaveVisualizerStyle.harmonicBars,
      );
      expect(
        WaveVisualizerStyle.fromId('mirror_bars'),
        WaveVisualizerStyle.mirrorBars,
      );
      expect(
        WaveVisualizerStyle.fromId('radial_circle'),
        WaveVisualizerStyle.radialCircle,
      );
      expect(
        WaveVisualizerStyle.fromId('particle_frequency'),
        WaveVisualizerStyle.particleFrequency,
      );
      expect(
        WaveVisualizerStyle.fromId('unknown_id'),
        WaveVisualizerStyle.waveform,
      );
    });

    test('WaveVisualizerColorPalette fromId returns correct enum value', () {
      expect(
        WaveVisualizerColorPalette.fromId('theme_accent'),
        WaveVisualizerColorPalette.themeAccent,
      );
      expect(
        WaveVisualizerColorPalette.fromId('cyberpunk_neon'),
        WaveVisualizerColorPalette.cyberpunkNeon,
      );
      expect(
        WaveVisualizerColorPalette.fromId('sunset_warm'),
        WaveVisualizerColorPalette.sunsetWarm,
      );
      expect(
        WaveVisualizerColorPalette.fromId('emerald_aura'),
        WaveVisualizerColorPalette.emeraldAura,
      );
      expect(
        WaveVisualizerColorPalette.fromId('monochrome'),
        WaveVisualizerColorPalette.monochrome,
      );
      expect(
        WaveVisualizerColorPalette.fromId('non_existent'),
        WaveVisualizerColorPalette.themeAccent,
      );
    });

    test('resolveColors generates expected palettes for each preset', () {
      const accent = Color(0xFFED5564);

      final themeColors =
          WaveVisualizerColorPalette.themeAccent.resolveColors(accent);
      expect(themeColors.length, greaterThanOrEqualTo(2));
      expect(themeColors.first.alpha, greaterThan(0));

      final cyberColors =
          WaveVisualizerColorPalette.cyberpunkNeon.resolveColors(accent);
      expect(cyberColors.length, 3);
      expect(cyberColors[0], const Color(0xFF00F0FF));

      final sunsetColors =
          WaveVisualizerColorPalette.sunsetWarm.resolveColors(accent);
      expect(sunsetColors.length, 3);

      final emeraldColors =
          WaveVisualizerColorPalette.emeraldAura.resolveColors(accent);
      expect(emeraldColors.length, 3);

      final monoColors =
          WaveVisualizerColorPalette.monochrome.resolveColors(accent);
      expect(monoColors.length, 3);

      final customPalette = [Colors.yellow, Colors.blue];
      final customColors =
          WaveVisualizerColorPalette.custom.resolveColors(accent, customPalette);
      expect(customColors, equals(customPalette));
    });
  });

  // ==========================================================================
  // 3. SpectrumHarmonicEngine Damping Physics & Math Tests
  // ==========================================================================
  group('SpectrumHarmonicEngine Physics & Damping Tests', () {
    test('initializes with clamped buffer capacities', () {
      final engine = SpectrumHarmonicEngine(initialBarCount: 32);

      expect(engine.barCount, 32);
      expect(engine.smoothedAmplitudes.length, 32);
      expect(engine.peakAmplitudes.length, 32);
      expect(engine.isSilent, isTrue);
      expect(engine.overallEnergy, 0.0);
    });

    test('clamps barCount between 8 and 128', () {
      final engineMin = SpectrumHarmonicEngine(initialBarCount: 2);
      expect(engineMin.barCount, 8);

      final engineMax = SpectrumHarmonicEngine(initialBarCount: 500);
      expect(engineMax.barCount, 128);
    });

    test('resize reallocates buffers while maintaining consistency', () {
      final engine = SpectrumHarmonicEngine(initialBarCount: 16);
      engine.update(dt: 0.016, isPlaying: true);

      engine.resize(32);
      expect(engine.barCount, 32);
      expect(engine.smoothedAmplitudes.length, 32);
      expect(engine.peakAmplitudes.length, 32);
    });

    test('harmonic spectrum generates non-zero energy when isPlaying is true', () {
      final engine = SpectrumHarmonicEngine(initialBarCount: 32);

      // Advance physics simulation
      for (int i = 0; i < 10; i++) {
        engine.update(dt: 0.016, isPlaying: true);
      }

      expect(engine.isSilent, isFalse);
      expect(engine.overallEnergy, greaterThan(0.0));
      for (final amp in engine.smoothedAmplitudes) {
        expect(amp, inInclusiveRange(0.0, 1.0));
      }
    });

    test('damping smoothly decays to silent when playback stops', () {
      final engine = SpectrumHarmonicEngine(initialBarCount: 16);

      // First run with playback active
      for (int i = 0; i < 20; i++) {
        engine.update(dt: 0.016, isPlaying: true);
      }
      expect(engine.overallEnergy, greaterThan(0.05));

      // Now pause playback and step through decay frames
      for (int i = 0; i < 150; i++) {
        engine.update(dt: 0.016, isPlaying: false, dampingFactor: 0.1);
      }

      // Amplitudes must decay down toward rest baseline
      expect(engine.overallEnergy, lessThan(0.02));
    });

    test('peaks capture maximum amplitudes and fall under gravity', () {
      final engine = SpectrumHarmonicEngine(initialBarCount: 16);

      // Run with strong signal
      for (int i = 0; i < 15; i++) {
        engine.update(dt: 0.016, isPlaying: true, sensitivity: 2.0);
      }

      final recordedPeaks = List<double>.from(engine.peakAmplitudes);
      for (int i = 0; i < engine.barCount; i++) {
        expect(recordedPeaks[i], greaterThanOrEqualTo(engine.smoothedAmplitudes[i]));
      }

      // Allow hold time to expire and decay under gravity
      for (int i = 0; i < 100; i++) {
        engine.update(dt: 0.016, isPlaying: false);
      }

      for (int i = 0; i < engine.barCount; i++) {
        expect(engine.peakAmplitudes[i], lessThanOrEqualTo(recordedPeaks[i]));
      }
    });

    test('resamples external raw spectrum data correctly', () {
      final engine = SpectrumHarmonicEngine(initialBarCount: 16);
      final rawFft = List<double>.generate(64, (i) => i / 64.0);

      for (int i = 0; i < 10; i++) {
        engine.update(dt: 0.016, isPlaying: true, rawSpectrum: rawFft);
      }

      expect(engine.smoothedAmplitudes.length, 16);
      expect(engine.overallEnergy, greaterThan(0.0));
    });

    test('clear resets all values to zero', () {
      final engine = SpectrumHarmonicEngine(initialBarCount: 16);
      engine.update(dt: 0.016, isPlaying: true);
      expect(engine.isSilent, isFalse);

      engine.clear();
      expect(engine.isSilent, isTrue);
      expect(engine.overallEnergy, 0.0);
    });
  });

  // ==========================================================================
  // 4. AudioSpectrumCustomPainter Unit Tests
  // ==========================================================================
  group('AudioSpectrumCustomPainter Paint & Repaint Tests', () {
    test('paints all visualizer styles without throwing exceptions', () {
      final amplitudes = List<double>.generate(32, (i) => (i % 8) / 8.0);
      final peaks = List<double>.generate(32, (i) => 0.9);

      for (final style in WaveVisualizerStyle.values) {
        final painter = AudioSpectrumCustomPainter(
          amplitudes: amplitudes,
          peakAmplitudes: peaks,
          phase: 1.5,
          style: style,
          palette: WaveVisualizerColorPalette.themeAccent,
          activeAccent: const Color(0xFFED5564),
          sensitivity: 1.0,
          waveLayers: 3,
          showPeaks: true,
          isMirrored: false,
          opacity: 0.85,
        );

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(300, 120);

        expect(() => painter.paint(canvas, size), returnsNormally);
        final picture = recorder.endRecording();
        picture.dispose();
      }
    });

    test('handles zero size and empty amplitudes safely without errors', () {
      final painter = AudioSpectrumCustomPainter(
        amplitudes: const [],
        peakAmplitudes: const [],
        phase: 0.0,
        style: WaveVisualizerStyle.waveform,
        palette: WaveVisualizerColorPalette.themeAccent,
        activeAccent: const Color(0xFFED5564),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      expect(() => painter.paint(canvas, const Size(-10, -10)), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('shouldRepaint returns true on state changes and false when identical', () {
      final amps1 = [0.1, 0.2, 0.3];
      final amps2 = [0.1, 0.5, 0.3];
      final peaks = [0.8, 0.8, 0.8];

      final p1 = AudioSpectrumCustomPainter(
        amplitudes: amps1,
        peakAmplitudes: peaks,
        phase: 0.0,
        style: WaveVisualizerStyle.waveform,
        palette: WaveVisualizerColorPalette.themeAccent,
        activeAccent: Colors.blue,
      );

      final p1Identical = AudioSpectrumCustomPainter(
        amplitudes: amps1,
        peakAmplitudes: peaks,
        phase: 0.0,
        style: WaveVisualizerStyle.waveform,
        palette: WaveVisualizerColorPalette.themeAccent,
        activeAccent: Colors.blue,
      );

      final p2DifferentPhase = AudioSpectrumCustomPainter(
        amplitudes: amps1,
        peakAmplitudes: peaks,
        phase: 0.5,
        style: WaveVisualizerStyle.waveform,
        palette: WaveVisualizerColorPalette.themeAccent,
        activeAccent: Colors.blue,
      );

      final p3DifferentAmps = AudioSpectrumCustomPainter(
        amplitudes: amps2,
        peakAmplitudes: peaks,
        phase: 0.0,
        style: WaveVisualizerStyle.waveform,
        palette: WaveVisualizerColorPalette.themeAccent,
        activeAccent: Colors.blue,
      );

      expect(p1.shouldRepaint(p1Identical), isFalse);
      expect(p1.shouldRepaint(p2DifferentPhase), isTrue);
      expect(p1.shouldRepaint(p3DifferentAmps), isTrue);
    });
  });

  // ==========================================================================
  // 5. CanvasWaveVisualizerNotifier Riverpod State Management Tests
  // ==========================================================================
  group('CanvasWaveVisualizerNotifier Riverpod Tests', () {
    test('loads default values on fresh launch', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(canvasWaveVisualizerConfigProvider);
      expect(config.isEnabled, isTrue);
      expect(config.style, WaveVisualizerStyle.waveform);
      expect(config.barCount, 32);
    });

    test('toggleEnabled persists value to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(canvasWaveVisualizerConfigProvider.notifier);
      await notifier.toggleEnabled();

      expect(container.read(canvasWaveVisualizerConfigProvider).isEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kVisualizerEnabledKey), isFalse);

      await notifier.toggleEnabled();
      expect(container.read(canvasWaveVisualizerConfigProvider).isEnabled, isTrue);
      expect(prefs.getBool(kVisualizerEnabledKey), isTrue);
    });

    test('mutations update state and persist correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(canvasWaveVisualizerConfigProvider.notifier);

      await notifier.setStyle(WaveVisualizerStyle.mirrorBars);
      await notifier.setColorPalette(WaveVisualizerColorPalette.emeraldAura);
      await notifier.setBarCount(48);
      await notifier.setSensitivity(1.6);
      await notifier.setDampingFactor(0.35);
      await notifier.setShowPeaks(false);
      await notifier.setTargetFps(30);
      await notifier.setWaveSpeed(1.8);
      await notifier.setWaveLayers(4);
      await notifier.setIsMirrored(true);
      await notifier.setOpacity(0.9);
      await notifier.setReactiveToPlayback(false);

      final state = container.read(canvasWaveVisualizerConfigProvider);
      expect(state.style, WaveVisualizerStyle.mirrorBars);
      expect(state.colorPalette, WaveVisualizerColorPalette.emeraldAura);
      expect(state.barCount, 48);
      expect(state.sensitivity, 1.6);
      expect(state.dampingFactor, 0.35);
      expect(state.showPeaks, isFalse);
      expect(state.targetFps, 30);
      expect(state.waveSpeed, 1.8);
      expect(state.waveLayers, 4);
      expect(state.isMirrored, isTrue);
      expect(state.opacity, 0.9);
      expect(state.reactiveToPlayback, isFalse);

      // Verify persistent store
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kVisualizerStyleKey), 'mirror_bars');
      expect(prefs.getString(kVisualizerPaletteKey), 'emerald_aura');
      expect(prefs.getInt(kVisualizerBarCountKey), 48);
    });

    test('resetToDefaults resets state to factory defaults', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(canvasWaveVisualizerConfigProvider.notifier);
      await notifier.setBarCount(64);
      await notifier.setSensitivity(2.2);

      expect(container.read(canvasWaveVisualizerConfigProvider).barCount, 64);

      await notifier.resetToDefaults();
      final resetState = container.read(canvasWaveVisualizerConfigProvider);
      expect(resetState.barCount, 32);
      expect(resetState.sensitivity, 1.0);
    });
  });

  // ==========================================================================
  // 6. CanvasWaveVisualizerWidget Flutter Widget Tests
  // ==========================================================================
  group('CanvasWaveVisualizerWidget Tests', () {
    testWidgets('renders CustomPaint widget when visualizer is enabled',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CanvasWaveVisualizerWidget(
                height: 120,
                width: 300,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CanvasWaveVisualizerWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CanvasWaveVisualizerWidget),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders SizedBox.shrink when visualizer is disabled',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Disable visualizer
      await container
          .read(canvasWaveVisualizerConfigProvider.notifier)
          .toggleEnabled();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CanvasWaveVisualizerWidget(
                height: 120,
                width: 300,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // CustomPaint inside CanvasWaveVisualizerWidget should not be rendered
      expect(
        find.descendant(
          of: find.byType(CanvasWaveVisualizerWidget),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('renders badge button when showControlsButton is true',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CanvasWaveVisualizerWidget(
                height: 120,
                width: 300,
                showControlsButton: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CanvasWaveVisualizerBadge), findsOneWidget);
    });

    testWidgets('tapping visualizer opens CanvasWaveVisualizerSheet modal',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CanvasWaveVisualizerWidget(
                height: 120,
                width: 300,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on visualizer
      await tester.tap(find.byType(CanvasWaveVisualizerWidget));
      await tester.pumpAndSettle();

      // Modal bottom sheet should now be visible
      expect(find.byType(CanvasWaveVisualizerSheet), findsOneWidget);
      expect(find.text('Spectrum Wave Visualizer'), findsOneWidget);
      expect(find.text('Visualizer Style'), findsOneWidget);
      expect(find.text('Color Palette'), findsOneWidget);
      expect(find.text('Frame Rate Throttling'), findsOneWidget);
    });

    testWidgets('CanvasWaveVisualizerBadge toggles visualizer on tap',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CanvasWaveVisualizerBadge(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Fluid Waveform'), findsOneWidget);

      // Tap badge to toggle off
      await tester.tap(find.byType(CanvasWaveVisualizerBadge));
      await tester.pumpAndSettle();

      expect(container.read(canvasWaveVisualizerConfigProvider).isEnabled, isFalse);
      expect(find.text('Visualizer Off'), findsOneWidget);
    });
  });
}
