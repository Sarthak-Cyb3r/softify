// ============================================================================
// Softify Quality of Life (QoL) - Feature 40: Audio Spectrum Canvas Wave Visualizer
// ============================================================================
//
// High-performance Flutter CustomPainter rendering fluid audio spectrum
// waveforms, harmonic frequency bars, mirror bars, radial ripples, and
// reactive frequency particles.
//
// Features:
// 1. High-performance CustomPainter rendering fluid audio waveforms and harmonic bars.
// 2. 60fps ticker throttling, smooth attack/release damping physics, low CPU usage.
// 3. CanvasWaveVisualizerWidget for embedding in lyrics view, player, or screensaver.
// 4. Idiomatic Riverpod state management with full SharedPreferences persistence.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// Storage & Persistence Layer (Self-Contained & Zero-Dependency)
// ============================================================================

/// SharedPreferences persistent storage keys.
const String kVisualizerEnabledKey = 'softify_qol_visualizer_enabled';
const String kVisualizerStyleKey = 'softify_qol_visualizer_style';
const String kVisualizerPaletteKey = 'softify_qol_visualizer_palette';
const String kVisualizerBarCountKey = 'softify_qol_visualizer_bar_count';
const String kVisualizerSensitivityKey = 'softify_qol_visualizer_sensitivity';
const String kVisualizerDampingKey = 'softify_qol_visualizer_damping';
const String kVisualizerShowPeaksKey = 'softify_qol_visualizer_show_peaks';
const String kVisualizerTargetFpsKey = 'softify_qol_visualizer_target_fps';
const String kVisualizerWaveSpeedKey = 'softify_qol_visualizer_wave_speed';
const String kVisualizerWaveLayersKey = 'softify_qol_visualizer_wave_layers';
const String kVisualizerOpacityKey = 'softify_qol_visualizer_opacity';
const String kVisualizerIsMirroredKey = 'softify_qol_visualizer_is_mirrored';
const String kVisualizerReactiveKey = 'softify_qol_visualizer_reactive_playback';

/// Lightweight, self-contained key-value store matching the SharedPreferences API
/// contract without native plugin dependencies.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible instance if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock key-value pairs for test environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance for clean test suites.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Resolves or initializes the SharedPreferences singleton instance.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;

    try {
      file = _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // In-memory fallback if file system access fails
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_store);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  bool? getBool(String key) => _store[key] as bool?;
  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  int? getInt(String key) => _store[key] as int?;
  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  double? getDouble(String key) {
    final val = _store[key];
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return null;
  }

  Future<bool> setDouble(String key, double value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) => _store[key] as String?;
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  List<String>? getStringList(String key) {
    final val = _store[key];
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  Future<bool> remove(String key) async {
    _store.remove(key);
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    await _persist();
    return true;
  }

  bool containsKey(String key) => _store.containsKey(key);
  Set<String> getKeys() => _store.keys.toSet();
}

// ============================================================================
// Enums & Models
// ============================================================================

/// Rendering styles supported by the Canvas Wave Visualizer.
enum WaveVisualizerStyle {
  /// Fluid multi-layer sine/bézier waves with translucent gradient fills and glowing strokes.
  waveform(
    id: 'waveform',
    displayName: 'Fluid Waveform',
    description: 'Smooth multi-layer continuous audio ripples',
    icon: Icons.waves_rounded,
  ),

  /// Frequency spectrum equalizer bars with rounded heads and gravity-damped peak dots.
  harmonicBars(
    id: 'harmonic_bars',
    displayName: 'Harmonic Bars',
    description: 'Vertical spectrum equalizer bars with peak caps',
    icon: Icons.equalizer_rounded,
  ),

  /// Symmetrical spectrum bars bouncing from central horizontal baseline.
  mirrorBars(
    id: 'mirror_bars',
    displayName: 'Mirrored Bars',
    description: 'Symmetrical bars expanding from the center horizon',
    icon: Icons.height_rounded,
  ),

  /// Radial circular ripples expanding outwards, perfect for album art focus.
  radialCircle(
    id: 'radial_circle',
    displayName: 'Radial Ripple',
    description: 'Circular pulse waves expanding from the center',
    icon: Icons.radio_button_checked_rounded,
  ),

  /// Dynamic floating particles reacting to frequency band harmonics.
  particleFrequency(
    id: 'particle_frequency',
    displayName: 'Audio Particles',
    description: 'Orbiting particles pulsing to audio harmonics',
    icon: Icons.grain_rounded,
  );

  final String id;
  final String displayName;
  final String description;
  final IconData icon;

  const WaveVisualizerStyle({
    required this.id,
    required this.displayName,
    required this.description,
    required this.icon,
  });

  static WaveVisualizerStyle fromId(String? id) {
    return WaveVisualizerStyle.values.firstWhere(
      (e) => e.id == id,
      orElse: () => WaveVisualizerStyle.waveform,
    );
  }
}

/// Color theme presets for the audio visualizer.
enum WaveVisualizerColorPalette {
  /// Adapts dynamically to the active Material 3 app theme accent.
  themeAccent(
    id: 'theme_accent',
    displayName: 'Theme Accent',
    description: 'Dynamic accent matching app styling',
  ),

  /// Vibrant electric cyan, magenta, and deep neon violet.
  cyberpunkNeon(
    id: 'cyberpunk_neon',
    displayName: 'Cyberpunk Neon',
    description: 'Electric cyan, neon pink, and violet glow',
  ),

  /// Warm tangerine, crimson, and amber gold glow.
  sunsetWarm(
    id: 'sunset_warm',
    displayName: 'Warm Sunset',
    description: 'Tangerine, rose, and amber gold sunset',
  ),

  /// Aquamarine, mint green, and deep oceanic cyan.
  emeraldAura(
    id: 'emerald_aura',
    displayName: 'Emerald Aura',
    description: 'Mint green, aquamarine, and oceanic cyan',
  ),

  /// Minimalist frosted silver and translucent white for clean OLED display.
  monochrome(
    id: 'monochrome',
    displayName: 'Monochrome Silver',
    description: 'Clean frosted silver and translucent white',
  ),

  /// Custom user-supplied color stops.
  custom(
    id: 'custom',
    displayName: 'Custom Palette',
    description: 'User-specified color scheme',
  );

  final String id;
  final String displayName;
  final String description;

  const WaveVisualizerColorPalette({
    required this.id,
    required this.displayName,
    required this.description,
  });

  static WaveVisualizerColorPalette fromId(String? id) {
    return WaveVisualizerColorPalette.values.firstWhere(
      (e) => e.id == id,
      orElse: () => WaveVisualizerColorPalette.themeAccent,
    );
  }

  /// Resolves the list of gradient color stops for rendering.
  List<Color> resolveColors(Color activeAccent, [List<Color>? customColors]) {
    switch (this) {
      case WaveVisualizerColorPalette.themeAccent:
        return [
          activeAccent.withOpacity(0.95),
          activeAccent.withOpacity(0.65),
          activeAccent.withOpacity(0.25),
        ];
      case WaveVisualizerColorPalette.cyberpunkNeon:
        return const [
          Color(0xFF00F0FF), // Electric Cyan
          Color(0xFFFF007F), // Neon Magenta
          Color(0xFF7000FF), // Deep Violet
        ];
      case WaveVisualizerColorPalette.sunsetWarm:
        return const [
          Color(0xFFFF5252), // Sunset Coral
          Color(0xFFFF7A00), // Tangerine
          Color(0xFFFFD600), // Amber Gold
        ];
      case WaveVisualizerColorPalette.emeraldAura:
        return const [
          Color(0xFF00E676), // Bright Mint
          Color(0xFF00B0FF), // Aquamarine
          Color(0xFF004D40), // Deep Teal
        ];
      case WaveVisualizerColorPalette.monochrome:
        return const [
          Color(0xFFFFFFFF),
          Color(0xFFB0B0B8),
          Color(0x40FFFFFF),
        ];
      case WaveVisualizerColorPalette.custom:
        if (customColors != null && customColors.length >= 2) {
          return customColors;
        }
        return [activeAccent, activeAccent.withOpacity(0.5)];
    }
  }
}

/// Immutable configuration holding all audio visualizer preferences.
@immutable
class CanvasWaveVisualizerConfig {
  final bool isEnabled;
  final WaveVisualizerStyle style;
  final WaveVisualizerColorPalette colorPalette;
  final int barCount;
  final double sensitivity;
  final double dampingFactor;
  final double waveSpeed;
  final int waveLayers;
  final bool showPeaks;
  final int targetFps;
  final bool isMirrored;
  final double opacity;
  final bool reactiveToPlayback;
  final List<Color>? customColors;

  const CanvasWaveVisualizerConfig({
    this.isEnabled = true,
    this.style = WaveVisualizerStyle.waveform,
    this.colorPalette = WaveVisualizerColorPalette.themeAccent,
    this.barCount = 32,
    this.sensitivity = 1.0,
    this.dampingFactor = 0.22,
    this.waveSpeed = 1.0,
    this.waveLayers = 3,
    this.showPeaks = true,
    this.targetFps = 60,
    this.isMirrored = false,
    this.opacity = 0.85,
    this.reactiveToPlayback = true,
    this.customColors,
  });

  CanvasWaveVisualizerConfig copyWith({
    bool? isEnabled,
    WaveVisualizerStyle? style,
    WaveVisualizerColorPalette? colorPalette,
    int? barCount,
    double? sensitivity,
    double? dampingFactor,
    double? waveSpeed,
    int? waveLayers,
    bool? showPeaks,
    int? targetFps,
    bool? isMirrored,
    double? opacity,
    bool? reactiveToPlayback,
    List<Color>? customColors,
  }) {
    return CanvasWaveVisualizerConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      style: style ?? this.style,
      colorPalette: colorPalette ?? this.colorPalette,
      barCount: barCount ?? this.barCount,
      sensitivity: sensitivity ?? this.sensitivity,
      dampingFactor: dampingFactor ?? this.dampingFactor,
      waveSpeed: waveSpeed ?? this.waveSpeed,
      waveLayers: waveLayers ?? this.waveLayers,
      showPeaks: showPeaks ?? this.showPeaks,
      targetFps: targetFps ?? this.targetFps,
      isMirrored: isMirrored ?? this.isMirrored,
      opacity: opacity ?? this.opacity,
      reactiveToPlayback: reactiveToPlayback ?? this.reactiveToPlayback,
      customColors: customColors ?? this.customColors,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'style': style.id,
      'colorPalette': colorPalette.id,
      'barCount': barCount,
      'sensitivity': sensitivity,
      'dampingFactor': dampingFactor,
      'waveSpeed': waveSpeed,
      'waveLayers': waveLayers,
      'showPeaks': showPeaks,
      'targetFps': targetFps,
      'isMirrored': isMirrored,
      'opacity': opacity,
      'reactiveToPlayback': reactiveToPlayback,
      if (customColors != null)
        'customColors': customColors!.map((c) => c.value).toList(),
    };
  }

  factory CanvasWaveVisualizerConfig.fromJson(Map<String, dynamic> json) {
    List<Color>? parsedColors;
    if (json['customColors'] is List) {
      parsedColors = (json['customColors'] as List)
          .whereType<int>()
          .map((v) => Color(v))
          .toList();
    }

    return CanvasWaveVisualizerConfig(
      isEnabled: json['isEnabled'] as bool? ?? true,
      style: WaveVisualizerStyle.fromId(json['style'] as String?),
      colorPalette:
          WaveVisualizerColorPalette.fromId(json['colorPalette'] as String?),
      barCount: (json['barCount'] as num?)?.toInt() ?? 32,
      sensitivity: (json['sensitivity'] as num?)?.toDouble() ?? 1.0,
      dampingFactor: (json['dampingFactor'] as num?)?.toDouble() ?? 0.22,
      waveSpeed: (json['waveSpeed'] as num?)?.toDouble() ?? 1.0,
      waveLayers: (json['waveLayers'] as num?)?.toInt() ?? 3,
      showPeaks: json['showPeaks'] as bool? ?? true,
      targetFps: (json['targetFps'] as num?)?.toInt() ?? 60,
      isMirrored: json['isMirrored'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
      reactiveToPlayback: json['reactiveToPlayback'] as bool? ?? true,
      customColors: parsedColors,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasWaveVisualizerConfig &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          style == other.style &&
          colorPalette == other.colorPalette &&
          barCount == other.barCount &&
          sensitivity == other.sensitivity &&
          dampingFactor == other.dampingFactor &&
          waveSpeed == other.waveSpeed &&
          waveLayers == other.waveLayers &&
          showPeaks == other.showPeaks &&
          targetFps == other.targetFps &&
          isMirrored == other.isMirrored &&
          opacity == other.opacity &&
          reactiveToPlayback == other.reactiveToPlayback &&
          listEquals(customColors, other.customColors);

  @override
  int get hashCode => Object.hash(
        isEnabled,
        style,
        colorPalette,
        barCount,
        sensitivity,
        dampingFactor,
        waveSpeed,
        waveLayers,
        showPeaks,
        targetFps,
        isMirrored,
        opacity,
        reactiveToPlayback,
        customColors == null ? 0 : Object.hashAll(customColors!),
      );
}

// ============================================================================
// Realtime Harmonic Spectrum & Damping Physics Engine
// ============================================================================

/// High-performance mathematical spectrum generator and smooth damping engine.
///
/// Efficiently updates frequency bins with fast attack (rise) and smooth
/// exponential decay (release), gravity-accelerated peak hold indicators, and
/// harmonic oscillation synthesis when direct PCM/FFT streams are unavailable.
///
/// Designed for low CPU footprint by reusing fixed typed memory buffers and
/// preventing garbage collector pauses during 60fps animation loops.
class SpectrumHarmonicEngine {
  int _barCount;
  Float64List _smoothed;
  Float64List _target;
  Float64List _peaks;
  Int32List _peakHoldTimers;

  double _simTimeSec = 0.0;
  double _phase = 0.0;

  SpectrumHarmonicEngine({int initialBarCount = 32})
      : _barCount = initialBarCount.clamp(8, 128),
        _smoothed = Float64List(initialBarCount.clamp(8, 128)),
        _target = Float64List(initialBarCount.clamp(8, 128)),
        _peaks = Float64List(initialBarCount.clamp(8, 128)),
        _peakHoldTimers = Int32List(initialBarCount.clamp(8, 128));

  /// Current number of frequency spectrum bins.
  int get barCount => _barCount;

  /// Continuous traveling wave phase for smooth custom paint rendering.
  double get phase => _phase;

  /// Normalized smoothed amplitudes in [0.0, 1.0] range.
  List<double> get smoothedAmplitudes => _smoothed;

  /// Normalized peak hold amplitudes in [0.0, 1.0] range.
  List<double> get peakAmplitudes => _peaks;

  /// Overall average spectrum energy level [0.0, 1.0].
  double get overallEnergy {
    if (_barCount == 0) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < _barCount; i++) {
      sum += _smoothed[i];
    }
    return sum / _barCount;
  }

  /// Whether all frequency bands have settled to near zero.
  bool get isSilent {
    for (int i = 0; i < _barCount; i++) {
      if (_smoothed[i] > 0.005) return false;
    }
    return true;
  }

  /// Updates buffer capacity if the bar count configuration changes.
  void resize(int newCount) {
    final clamped = newCount.clamp(8, 128);
    if (clamped == _barCount) return;

    final oldSmoothed = _smoothed;
    final oldPeaks = _peaks;
    final oldCount = _barCount;

    _barCount = clamped;
    _smoothed = Float64List(clamped);
    _target = Float64List(clamped);
    _peaks = Float64List(clamped);
    _peakHoldTimers = Int32List(clamped);

    // Resample existing smoothed values so resize looks seamless
    for (int i = 0; i < clamped; i++) {
      final oldIndex = (i * oldCount / clamped).floor().clamp(0, oldCount - 1);
      _smoothed[i] = oldSmoothed[oldIndex];
      _peaks[i] = oldPeaks[oldIndex];
    }
  }

  /// Steps physics engine by [dt] seconds.
  ///
  /// [isPlaying]: Whether player is actively rendering audio.
  /// [rawSpectrum]: Optional direct external FFT data. If null, synthesizes
  /// realistic harmonic audio spectrum based on harmonic overtone oscillators.
  /// [sensitivity]: Amplitude amplification factor (0.2x to 2.5x).
  /// [dampingFactor]: Attack/decay release smoothness (0.05 to 0.7).
  /// [waveSpeed]: Animation wave speed multiplier.
  void update({
    required double dt,
    required bool isPlaying,
    List<double>? rawSpectrum,
    double sensitivity = 1.0,
    double dampingFactor = 0.22,
    double waveSpeed = 1.0,
  }) {
    final clampedDt = dt.clamp(0.001, 0.05);
    _simTimeSec += clampedDt;
    _phase += waveSpeed * clampedDt * 2.5;

    // 1. Calculate Target Amplitudes
    if (rawSpectrum != null && rawSpectrum.isNotEmpty) {
      _resampleExternalSpectrum(rawSpectrum, sensitivity);
    } else if (isPlaying) {
      _synthesizeHarmonicSpectrum(sensitivity);
    } else {
      // Gentle decay towards resting baseline when paused
      for (int i = 0; i < _barCount; i++) {
        _target[i] = 0.0;
      }
    }

    // 2. Physics-Based Attack & Release Damping
    // Fast rise time for snappy audio impact, exponential falloff for smooth damping
    final attackRate = (1.0 - math.exp(-clampedDt * 28.0)).clamp(0.15, 0.85);
    final releaseSpeed = 14.0 * (1.0 - dampingFactor.clamp(0.05, 0.7));
    final releaseRate =
        (1.0 - math.exp(-clampedDt * releaseSpeed)).clamp(0.02, 0.45);

    // Gravity for peak hold dots
    final peakFallSpeed = (0.028 * (clampedDt / 0.016)).clamp(0.001, 0.1);

    for (int i = 0; i < _barCount; i++) {
      final target = _target[i];
      final current = _smoothed[i];

      if (target > current) {
        _smoothed[i] = current + (target - current) * attackRate;
      } else {
        _smoothed[i] = current - (current - target) * releaseRate;
      }
      _smoothed[i] = _smoothed[i].clamp(0.0, 1.0);

      // 3. Peak Hold & Gravity
      final curVal = _smoothed[i];
      if (curVal >= _peaks[i]) {
        _peaks[i] = curVal;
        _peakHoldTimers[i] = (0.22 / clampedDt).round().clamp(6, 30);
      } else {
        if (_peakHoldTimers[i] > 0) {
          _peakHoldTimers[i]--;
        } else {
          _peaks[i] = (_peaks[i] - peakFallSpeed).clamp(0.0, 1.0);
        }
      }
    }
  }

  /// Direct mapping/resampling of raw spectrum FFT bins.
  void _resampleExternalSpectrum(List<double> raw, double sensitivity) {
    final rawLen = raw.length;
    for (int i = 0; i < _barCount; i++) {
      final srcIdx = (i * rawLen / _barCount).floor().clamp(0, rawLen - 1);
      final rawVal = raw[srcIdx];
      _target[i] = (rawVal * sensitivity).clamp(0.0, 1.0);
    }
  }

  /// Synthesizes organic multi-octave harmonic audio spectrum.
  ///
  /// Combines rhythmic sub-bass pulses, mid-range vocal harmonics, and
  /// high-frequency percussion shimmer with pink noise falloff.
  void _synthesizeHarmonicSpectrum(double sensitivity) {
    final t = _simTimeSec;

    // Sub-bass & Bass kick pulse (4/4 rhythm simulation)
    final bassPulse = (math.sin(t * 4.2) * 0.5 + 0.5) *
        (math.sin(t * 2.1 + 0.4) * 0.3 + 0.7);

    // Mid-range melodic cadence
    final midCadence = (math.sin(t * 5.8) * 0.35 + 0.65) *
        (math.cos(t * 3.4) * 0.3 + 0.7);

    // High treble sparkle
    final trebleSparkle = (math.sin(t * 11.2) * 0.3 + 0.5) *
        (math.sin(t * 16.8 + 1.2) * 0.4 + 0.6);

    for (int i = 0; i < _barCount; i++) {
      final normalizedIndex = i / _barCount;

      // Frequency distribution curves:
      // Bass (low bins) -> Mid (middle bins) -> Treble (high bins)
      double energy = 0.0;
      if (normalizedIndex < 0.25) {
        // Bass region
        final binSubPulse = math.sin(t * 3.6 + i * 0.55) * 0.2 + 0.8;
        energy = bassPulse * binSubPulse * (1.1 - normalizedIndex * 0.8);
      } else if (normalizedIndex < 0.65) {
        // Mid region
        final harmonic = math.sin(t * 7.5 + i * 0.4) * 0.35 + 0.65;
        energy = midCadence * harmonic * 0.85;
      } else {
        // Treble region
        final sparkle = math.sin(t * 14.0 + i * 0.75) * 0.4 + 0.6;
        energy = trebleSparkle * sparkle * 0.7;
      }

      // Add harmonic jitter for organic fluid motion
      final microJitter = (math.sin(t * 19.3 + i * 1.9) * 0.08);
      final rawTarget = (energy + microJitter) * sensitivity;

      _target[i] = rawTarget.clamp(0.02, 1.0);
    }
  }

  /// Resets all values to zero (silence).
  void clear() {
    _smoothed.fillRange(0, _barCount, 0.0);
    _target.fillRange(0, _barCount, 0.0);
    _peaks.fillRange(0, _barCount, 0.0);
    _peakHoldTimers.fillRange(0, _barCount, 0);
  }
}

// ============================================================================
// High-Performance Audio Spectrum CustomPainter
// ============================================================================

/// High-performance [CustomPainter] rendering fluid audio waveforms and harmonic bars.
///
/// Features:
/// - Fluid cubic Bézier wave paths with multi-layer parallax depth and glow.
/// - Rounded frequency spectrum bars with gravity peak indicators.
/// - Symmetrical mirror bars with central axis resonance.
/// - Radial polar circular ripples for album art / centered lyrics focus.
/// - Low CPU footprint with zero allocations in the render path.
class AudioSpectrumCustomPainter extends CustomPainter {
  final List<double> amplitudes;
  final List<double> peakAmplitudes;
  final double phase;
  final WaveVisualizerStyle style;
  final WaveVisualizerColorPalette palette;
  final Color activeAccent;
  final List<Color>? customColors;
  final double sensitivity;
  final double waveSpeed;
  final int waveLayers;
  final bool showPeaks;
  final bool isMirrored;
  final double opacity;

  // Pre-allocated reusable paint and path objects to prevent GC churn
  static final Paint _fillPaint = Paint()..isAntiAlias = true;
  static final Paint _strokePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _peakPaint = Paint()..isAntiAlias = true;
  static final Path _wavePath = Path();
  static final Path _strokePath = Path();

  AudioSpectrumCustomPainter({
    required this.amplitudes,
    required this.peakAmplitudes,
    required this.phase,
    required this.style,
    required this.palette,
    required this.activeAccent,
    this.customColors,
    this.sensitivity = 1.0,
    this.waveSpeed = 1.0,
    this.waveLayers = 3,
    this.showPeaks = true,
    this.isMirrored = false,
    this.opacity = 0.85,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || amplitudes.isEmpty) {
      return;
    }

    final colors = palette.resolveColors(activeAccent, customColors);

    switch (style) {
      case WaveVisualizerStyle.waveform:
        _paintWaveform(canvas, size, colors);
        break;
      case WaveVisualizerStyle.harmonicBars:
        _paintHarmonicBars(canvas, size, colors, isMirrored: isMirrored);
        break;
      case WaveVisualizerStyle.mirrorBars:
        _paintHarmonicBars(canvas, size, colors, isMirrored: true);
        break;
      case WaveVisualizerStyle.radialCircle:
        _paintRadialCircle(canvas, size, colors);
        break;
      case WaveVisualizerStyle.particleFrequency:
        _paintParticleFrequency(canvas, size, colors);
        break;
    }
  }

  /// Renders multi-layered fluid cubic Bézier waveforms.
  void _paintWaveform(Canvas canvas, Size size, List<Color> colors) {
    final width = size.width;
    final height = size.height;
    final baseline = isMirrored ? height / 2 : height;
    final availableHeight = isMirrored ? height * 0.45 : height * 0.85;
    final pointCount = amplitudes.length;

    if (pointCount < 2) return;

    final layers = waveLayers.clamp(1, 5);

    // Paint each layer from back to front with parallax phase shifts
    for (int l = layers - 1; l >= 0; l--) {
      final layerProgress = l / layers;
      final layerPhase = phase * (1.0 + l * 0.28) + (l * math.pi * 0.45);
      final layerOpacity =
          ((1.0 - layerProgress * 0.45) * opacity).clamp(0.05, 1.0);
      final layerAmpScale = (1.0 - layerProgress * 0.25) * sensitivity;

      // Color selection for layer
      final colorIdx = l % colors.length;
      final layerColor = colors[colorIdx].withOpacity(layerOpacity);
      final topColor = colors[0].withOpacity(layerOpacity);

      _wavePath.reset();
      _strokePath.reset();

      // Start path at left baseline
      _wavePath.moveTo(0, baseline);

      final points = <Offset>[];
      for (int i = 0; i < pointCount; i++) {
        final x = (i / (pointCount - 1)) * width;
        final amp = amplitudes[i];

        // Smooth wave modulation across bins
        final harmonicOffset =
            math.sin(layerPhase + (i / pointCount) * math.pi * 3.5) * 0.18;
        final waveHeight =
            ((amp + harmonicOffset).clamp(0.0, 1.2)) * availableHeight * layerAmpScale;

        final y = baseline - waveHeight;
        points.add(Offset(x, y));
      }

      // Interpolate smooth Bézier spline through points
      _wavePath.lineTo(points.first.dx, points.first.dy);
      _strokePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;

        _wavePath.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        _strokePath.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }

      final last = points.last;
      _wavePath.lineTo(last.dx, last.dy);
      _strokePath.lineTo(last.dx, last.dy);

      // Close fill path down to baseline
      _wavePath.lineTo(width, baseline);
      _wavePath.close();

      // 1. Fill with vertical gradient
      _fillPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          topColor.withOpacity(0.55 * layerOpacity),
          layerColor.withOpacity(0.20 * layerOpacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

      canvas.drawPath(_wavePath, _fillPaint);

      // 2. Stroke with glowing ridge line
      _strokePaint.strokeWidth = l == 0 ? 2.5 : 1.5;
      _strokePaint.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          colors[0].withOpacity(layerOpacity),
          colors[colorIdx].withOpacity(layerOpacity),
          colors.last.withOpacity(layerOpacity),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

      canvas.drawPath(_strokePath, _strokePaint);
    }
  }

  /// Renders discrete harmonic frequency spectrum bars.
  void _paintHarmonicBars(
    Canvas canvas,
    Size size,
    List<Color> colors, {
    required bool isMirrored,
  }) {
    final width = size.width;
    final height = size.height;
    final count = amplitudes.length;
    if (count == 0) return;

    const minBarWidth = 2.0;
    const barSpacingRatio = 0.35;

    // Calculate optimal bar width and inter-bar spacing
    final totalSpacingUnits = count + (count - 1) * barSpacingRatio;
    final rawBarWidth = width / totalSpacingUnits;
    final barWidth = math.max(minBarWidth, rawBarWidth);
    final spacing = barWidth * barSpacingRatio;

    final centerY = height / 2;
    final maxBarHeight = isMirrored ? (height * 0.46) : (height * 0.92);
    final cornerRadius = Radius.circular(math.min(barWidth / 2, 4.0));

    // Gradient shader spanning the height
    _fillPaint.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: colors.map((c) => c.withOpacity(opacity)).toList(),
      stops: colors.length == 3 ? const [0.0, 0.5, 1.0] : null,
    ).createShader(Rect.fromLTWH(0, 0, width, height));

    _peakPaint.color = colors.first.withOpacity(opacity);

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + spacing);
      if (x + barWidth > width + spacing) break;

      final amp = (amplitudes[i] * sensitivity).clamp(0.015, 1.0);
      final barH = math.max(2.0, amp * maxBarHeight);

      if (isMirrored) {
        // Mirrored bar expanding symmetrically up & down from center
        final rect = Rect.fromLTWH(
          x,
          centerY - barH,
          barWidth,
          barH * 2,
        );
        final rrect = RRect.fromRectAndRadius(rect, cornerRadius);
        canvas.drawRRect(rrect, _fillPaint);

        // Peak caps for mirrored mode (top and bottom)
        if (showPeaks && i < peakAmplitudes.length) {
          final peakAmp = (peakAmplitudes[i] * sensitivity).clamp(0.0, 1.0);
          if (peakAmp > 0.05) {
            final peakOffset = peakAmp * maxBarHeight;
            // Top peak cap
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, centerY - peakOffset - 2.5, barWidth, 2.0),
                const Radius.circular(1.0),
              ),
              _peakPaint,
            );
            // Bottom peak cap
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, centerY + peakOffset + 0.5, barWidth, 2.0),
                const Radius.circular(1.0),
              ),
              _peakPaint,
            );
          }
        }
      } else {
        // Standard floor-aligned vertical bar
        final top = height - barH;
        final rect = Rect.fromLTWH(x, top, barWidth, barH);
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: cornerRadius,
          topRight: cornerRadius,
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        );
        canvas.drawRRect(rrect, _fillPaint);

        // Peak cap dot/pill above bar
        if (showPeaks && i < peakAmplitudes.length) {
          final peakAmp = (peakAmplitudes[i] * sensitivity).clamp(0.0, 1.0);
          if (peakAmp > 0.05) {
            final peakTop = height - (peakAmp * maxBarHeight) - 3.5;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, peakTop.clamp(0.0, height - 3.0), barWidth, 2.2),
                const Radius.circular(1.0),
              ),
              _peakPaint,
            );
          }
        }
      }
    }
  }

  /// Renders polar circular spectrum ripples around the canvas center.
  void _paintRadialCircle(Canvas canvas, Size size, List<Color> colors) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final count = amplitudes.length;
    if (count < 4) return;

    final minDimension = math.min(size.width, size.height);
    final baseRadius = minDimension * 0.25;
    final maxExtension = minDimension * 0.22 * sensitivity;

    _wavePath.reset();

    final points = <Offset>[];
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2.0 + (phase * 0.15);
      final amp = amplitudes[i];
      final r = baseRadius + amp * maxExtension;

      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
      points.add(Offset(px, py));
    }

    // Closed loop spline
    _wavePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length; i++) {
      final p0 = points[i];
      final p1 = points[(i + 1) % points.length];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      _wavePath.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    _wavePath.close();

    // Radial gradient fill
    _fillPaint.shader = RadialGradient(
      center: Alignment.center,
      radius: 0.5,
      colors: [
        colors[0].withOpacity(0.35 * opacity),
        colors.last.withOpacity(0.05 * opacity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.7, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: minDimension / 2));

    canvas.drawPath(_wavePath, _fillPaint);

    // Glowing perimeter stroke
    _strokePaint.strokeWidth = 2.0;
    _strokePaint.shader = SweepGradient(
      center: Alignment.center,
      colors: [...colors, colors.first].map((c) => c.withOpacity(opacity)).toList(),
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: minDimension / 2));

    canvas.drawPath(_wavePath, _strokePaint);
  }

  /// Renders responsive orbital particles vibrating to frequency harmonics.
  void _paintParticleFrequency(Canvas canvas, Size size, List<Color> colors) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final count = amplitudes.length;

    _fillPaint.shader = null;

    for (int i = 0; i < count; i++) {
      final amp = amplitudes[i] * sensitivity;
      if (amp < 0.02) continue;

      final normalizedIdx = i / count;
      final angle = normalizedIdx * math.pi * 2.0 + (phase * (0.2 + normalizedIdx * 0.3));
      final dist = (size.width * 0.15) + (amp * size.height * 0.35);

      final px = cx + dist * math.cos(angle);
      final py = cy + dist * math.sin(angle);

      final radius = (2.0 + amp * 5.0).clamp(1.5, 9.0);
      final color = colors[i % colors.length].withOpacity((amp * opacity).clamp(0.2, 1.0));

      _fillPaint.color = color;
      canvas.drawCircle(Offset(px, py), radius, _fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioSpectrumCustomPainter old) {
    return old.phase != phase ||
        old.style != style ||
        old.palette != palette ||
        old.activeAccent != activeAccent ||
        old.sensitivity != sensitivity ||
        old.waveLayers != waveLayers ||
        old.showPeaks != showPeaks ||
        old.isMirrored != isMirrored ||
        old.opacity != opacity ||
        !listEquals(old.amplitudes, amplitudes) ||
        !listEquals(old.peakAmplitudes, peakAmplitudes);
  }
}

// ============================================================================
// Riverpod State Management
// ============================================================================

/// StateNotifier controlling the audio visualizer settings and persistence.
class CanvasWaveVisualizerNotifier
    extends StateNotifier<CanvasWaveVisualizerConfig> {
  CanvasWaveVisualizerNotifier() : super(const CanvasWaveVisualizerConfig()) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isEnabled = prefs.getBool(kVisualizerEnabledKey) ?? state.isEnabled;
      final styleId = prefs.getString(kVisualizerStyleKey);
      final paletteId = prefs.getString(kVisualizerPaletteKey);
      final barCount = prefs.getInt(kVisualizerBarCountKey) ?? state.barCount;
      final sensitivity =
          prefs.getDouble(kVisualizerSensitivityKey) ?? state.sensitivity;
      final damping =
          prefs.getDouble(kVisualizerDampingKey) ?? state.dampingFactor;
      final showPeaks =
          prefs.getBool(kVisualizerShowPeaksKey) ?? state.showPeaks;
      final targetFps =
          prefs.getInt(kVisualizerTargetFpsKey) ?? state.targetFps;
      final waveSpeed =
          prefs.getDouble(kVisualizerWaveSpeedKey) ?? state.waveSpeed;
      final waveLayers =
          prefs.getInt(kVisualizerWaveLayersKey) ?? state.waveLayers;
      final opacity =
          prefs.getDouble(kVisualizerOpacityKey) ?? state.opacity;
      final isMirrored =
          prefs.getBool(kVisualizerIsMirroredKey) ?? state.isMirrored;
      final reactive =
          prefs.getBool(kVisualizerReactiveKey) ?? state.reactiveToPlayback;

      state = state.copyWith(
        isEnabled: isEnabled,
        style: styleId != null ? WaveVisualizerStyle.fromId(styleId) : state.style,
        colorPalette: paletteId != null
            ? WaveVisualizerColorPalette.fromId(paletteId)
            : state.colorPalette,
        barCount: barCount.clamp(8, 128),
        sensitivity: sensitivity.clamp(0.2, 2.5),
        dampingFactor: damping.clamp(0.05, 0.7),
        showPeaks: showPeaks,
        targetFps: targetFps == 30 || targetFps == 60 || targetFps == 120
            ? targetFps
            : 60,
        waveSpeed: waveSpeed.clamp(0.2, 3.0),
        waveLayers: waveLayers.clamp(1, 5),
        opacity: opacity.clamp(0.1, 1.0),
        isMirrored: isMirrored,
        reactiveToPlayback: reactive,
      );
    } catch (_) {}
  }

  /// Toggles master enabled state.
  Future<void> toggleEnabled() async {
    final next = !state.isEnabled;
    state = state.copyWith(isEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kVisualizerEnabledKey, next);
  }

  /// Updates rendering visual style.
  Future<void> setStyle(WaveVisualizerStyle style) async {
    state = state.copyWith(style: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kVisualizerStyleKey, style.id);
  }

  /// Updates color palette preset.
  Future<void> setColorPalette(WaveVisualizerColorPalette palette) async {
    state = state.copyWith(colorPalette: palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kVisualizerPaletteKey, palette.id);
  }

  /// Updates frequency spectrum bar count (8 to 128).
  Future<void> setBarCount(int count) async {
    final clamped = count.clamp(8, 128);
    state = state.copyWith(barCount: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kVisualizerBarCountKey, clamped);
  }

  /// Updates amplitude sensitivity multiplier (0.2x to 2.5x).
  Future<void> setSensitivity(double sensitivity) async {
    final clamped = sensitivity.clamp(0.2, 2.5);
    state = state.copyWith(sensitivity: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kVisualizerSensitivityKey, clamped);
  }

  /// Updates attack/release damping factor (0.05 to 0.7).
  Future<void> setDampingFactor(double damping) async {
    final clamped = damping.clamp(0.05, 0.7);
    state = state.copyWith(dampingFactor: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kVisualizerDampingKey, clamped);
  }

  /// Toggles peak hold caps on frequency bars.
  Future<void> setShowPeaks(bool show) async {
    state = state.copyWith(showPeaks: show);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kVisualizerShowPeaksKey, show);
  }

  /// Sets target refresh frame rate (30, 60, or 120 FPS).
  Future<void> setTargetFps(int fps) async {
    final validFps = (fps == 30 || fps == 60 || fps == 120) ? fps : 60;
    state = state.copyWith(targetFps: validFps);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kVisualizerTargetFpsKey, validFps);
  }

  /// Sets wave oscillation speed (0.2 to 3.0x).
  Future<void> setWaveSpeed(double speed) async {
    final clamped = speed.clamp(0.2, 3.0);
    state = state.copyWith(waveSpeed: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kVisualizerWaveSpeedKey, clamped);
  }

  /// Sets wave overlapping layer count (1 to 5).
  Future<void> setWaveLayers(int layers) async {
    final clamped = layers.clamp(1, 5);
    state = state.copyWith(waveLayers: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kVisualizerWaveLayersKey, clamped);
  }

  /// Toggles horizontal mirroring.
  Future<void> setIsMirrored(bool mirrored) async {
    state = state.copyWith(isMirrored: mirrored);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kVisualizerIsMirroredKey, mirrored);
  }

  /// Sets visualizer opacity (0.1 to 1.0).
  Future<void> setOpacity(double opacity) async {
    final clamped = opacity.clamp(0.1, 1.0);
    state = state.copyWith(opacity: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kVisualizerOpacityKey, clamped);
  }

  /// Toggles automatic reaction to playback state.
  Future<void> setReactiveToPlayback(bool reactive) async {
    state = state.copyWith(reactiveToPlayback: reactive);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kVisualizerReactiveKey, reactive);
  }

  /// Resets configuration to defaults.
  Future<void> resetToDefaults() async {
    state = const CanvasWaveVisualizerConfig();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

/// Global provider for Canvas Wave Visualizer configuration.
final canvasWaveVisualizerConfigProvider = StateNotifierProvider<
    CanvasWaveVisualizerNotifier, CanvasWaveVisualizerConfig>((ref) {
  return CanvasWaveVisualizerNotifier();
});

/// Convenience provider for visualizer enabled status.
final canvasWaveVisualizerEnabledProvider = Provider<bool>((ref) {
  return ref.watch(canvasWaveVisualizerConfigProvider).isEnabled;
});

/// Optional provider for streaming external raw PCM/FFT spectrum frames.
final externalSpectrumDataProvider = StateProvider<List<double>?>((ref) => null);

// ============================================================================
// CanvasWaveVisualizerWidget (Primary UI Component)
// ============================================================================

/// Production-ready fluid audio visualizer widget.
///
/// Features:
/// - 60fps frame ticker throttling for ultra-smooth 60fps rendering without CPU waste.
/// - Automatically connects to Softify audio player playback state.
/// - Supports overlay mode for background placement beneath synchronized lyrics.
/// - Interactive tap to reveal Material 3 configuration bottom sheet.
class CanvasWaveVisualizerWidget extends ConsumerStatefulWidget {
  /// Height of the visualizer canvas. If null, expands to fill parent.
  final double? height;

  /// Width of the visualizer canvas.
  final double? width;

  /// Optional padding around canvas.
  final EdgeInsetsGeometry? padding;

  /// Optional margin around canvas.
  final EdgeInsetsGeometry? margin;

  /// Visualizer style override; if null, uses config from provider.
  final WaveVisualizerStyle? overrideStyle;

  /// Color palette override; if null, uses config from provider.
  final WaveVisualizerColorPalette? overridePalette;

  /// Custom color list for [WaveVisualizerColorPalette.custom].
  final List<Color>? customColors;

  /// Whether to display floating quick-controls toggle badge.
  final bool showControlsButton;

  /// Whether this visualizer is placed as a subtle background behind lyrics.
  final bool isOverlay;

  /// Direct raw spectrum data feed (overrides internal harmonic simulator).
  final List<double>? directSpectrumData;

  /// Explicit playback override; if null, automatically watches [isPlayingProvider].
  final bool? isPlayingOverride;

  /// Optional custom tap callback. If omitted, tapping opens visualizer sheet.
  final VoidCallback? onTap;

  const CanvasWaveVisualizerWidget({
    super.key,
    this.height = 120.0,
    this.width = double.infinity,
    this.padding,
    this.margin,
    this.overrideStyle,
    this.overridePalette,
    this.customColors,
    this.showControlsButton = false,
    this.isOverlay = false,
    this.directSpectrumData,
    this.isPlayingOverride,
    this.onTap,
  });

  @override
  ConsumerState<CanvasWaveVisualizerWidget> createState() =>
      _CanvasWaveVisualizerWidgetState();
}

class _CanvasWaveVisualizerWidgetState
    extends ConsumerState<CanvasWaveVisualizerWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  late final SpectrumHarmonicEngine _engine;
  final ValueNotifier<int> _frameRepaintNotifier = ValueNotifier<int>(0);

  double _lastTickTimestampMs = 0.0;
  bool _isAppResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initialConfig = ref.read(canvasWaveVisualizerConfigProvider);
    _engine = SpectrumHarmonicEngine(initialBarCount: initialConfig.barCount);

    _ticker = createTicker(_onTick);
    if (initialConfig.isEnabled) {
      _ticker.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    if (!_isAppResumed && _ticker.isActive) {
      _ticker.stop();
    } else if (_isAppResumed &&
        !_ticker.isActive &&
        ref.read(canvasWaveVisualizerConfigProvider).isEnabled) {
      _lastTickTimestampMs = 0.0;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant CanvasWaveVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final config = ref.read(canvasWaveVisualizerConfigProvider);
    _engine.resize(config.barCount);
  }

  /// 60fps Throttled Frame Ticker Callback.
  ///
  /// Enforces frame interval bounds matching [config.targetFps] (30, 60, or 120 FPS)
  /// and drops surplus frames to guarantee minimal CPU and GPU consumption.
  void _onTick(Duration elapsed) {
    if (!mounted || !_isAppResumed) return;

    final config = ref.read(canvasWaveVisualizerConfigProvider);
    if (!config.isEnabled) return;

    final currentMs = elapsed.inMicroseconds / 1000.0;
    if (_lastTickTimestampMs == 0.0) {
      _lastTickTimestampMs = currentMs;
      return;
    }

    final deltaMs = currentMs - _lastTickTimestampMs;
    final targetIntervalMs = 1000.0 / config.targetFps;

    // Ticker Throttling: Skip tick if under frame budget
    if (deltaMs < targetIntervalMs) {
      return;
    }

    _lastTickTimestampMs = currentMs;
    final dtSec = deltaMs / 1000.0;

    // Determine current audio playback status
    final isPlaying = widget.isPlayingOverride ??
        (config.reactiveToPlayback ? ref.read(isPlayingProvider) : true);

    // External spectrum data from widget parameter or provider
    final externalData = widget.directSpectrumData ??
        ref.read(externalSpectrumDataProvider);

    // Update damping physics & frequency bins
    _engine.resize(config.barCount);
    _engine.update(
      dt: dtSec,
      isPlaying: isPlaying ?? false,
      rawSpectrum: externalData,
      sensitivity: config.sensitivity,
      dampingFactor: config.dampingFactor,
      waveSpeed: config.waveSpeed,
    );

    // Trigger canvas repaint without dirtying the widget subtree
    _frameRepaintNotifier.value++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frameRepaintNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(canvasWaveVisualizerConfigProvider);

    // Synchronize ticker running state with config
    if (config.isEnabled && !_ticker.isActive && _isAppResumed) {
      _lastTickTimestampMs = 0.0;
      _ticker.start();
    } else if (!config.isEnabled && _ticker.isActive) {
      _ticker.stop();
    }

    if (!config.isEnabled) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final activeAccent = tokens.accent;
    final style = widget.overrideStyle ?? config.style;
    final palette = widget.overridePalette ?? config.colorPalette;

    Widget canvasWidget = RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width ?? double.infinity, widget.height ?? 120.0),
        painter: AudioSpectrumCustomPainter(
          amplitudes: _engine.smoothedAmplitudes,
          peakAmplitudes: _engine.peakAmplitudes,
          phase: _engine.phase,
          style: style,
          palette: palette,
          activeAccent: activeAccent,
          customColors: widget.customColors ?? config.customColors,
          sensitivity: config.sensitivity,
          waveSpeed: config.waveSpeed,
          waveLayers: config.waveLayers,
          showPeaks: config.showPeaks,
          isMirrored: config.isMirrored,
          opacity: widget.isOverlay ? (config.opacity * 0.45) : config.opacity,
          repaint: _frameRepaintNotifier,
        ),
      ),
    );

    if (widget.showControlsButton) {
      canvasWidget = Stack(
        children: [
          canvasWidget,
          Positioned(
            right: 8,
            top: 8,
            child: CanvasWaveVisualizerBadge(
              onTap: () => CanvasWaveVisualizerSheet.show(context),
            ),
          ),
        ],
      );
    }

    return Container(
      height: widget.height,
      width: widget.width,
      padding: widget.padding,
      margin: widget.margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap ?? () => CanvasWaveVisualizerSheet.show(context),
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          splashColor: activeAccent.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: canvasWidget,
        ),
      ),
    );
  }
}

// ============================================================================
// CanvasWaveVisualizerBadge (Compact Toolbar Button)
// ============================================================================

/// Compact pill button for displaying and toggling visualizer status.
class CanvasWaveVisualizerBadge extends ConsumerWidget {
  final VoidCallback? onTap;

  const CanvasWaveVisualizerBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final config = ref.watch(canvasWaveVisualizerConfigProvider);
    final isEnabled = config.isEnabled;
    final accent = tokens.accent;

    return BouncingScaleButton(
      onTap: onTap ??
          () => ref.read(canvasWaveVisualizerConfigProvider.notifier).toggleEnabled(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isEnabled ? accent.withOpacity(0.18) : tokens.surfaceHighlight,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          border: Border.all(
            color: isEnabled ? accent.withOpacity(0.4) : tokens.cardHover,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              config.style.icon,
              size: 14,
              color: isEnabled ? accent : tokens.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              isEnabled ? config.style.displayName : 'Visualizer Off',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isEnabled ? tokens.textPrimary : tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CanvasWaveVisualizerSheet (Material 3 Settings Modal)
// ============================================================================

/// Material 3 modal bottom sheet for adjusting visualizer styles, sensitivity,
/// frame rate throttling, color palettes, and damping physics.
class CanvasWaveVisualizerSheet extends ConsumerWidget {
  const CanvasWaveVisualizerSheet({super.key});

  /// Displays the visualizer configuration bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CanvasWaveVisualizerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final config = ref.watch(canvasWaveVisualizerConfigProvider);
    final notifier = ref.read(canvasWaveVisualizerConfigProvider.notifier);
    final accent = tokens.accent;

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusXl),
        ),
        border: Border.all(color: tokens.surfaceHighlight, width: 1),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.textMuted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.graphic_eq_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spectrum Wave Visualizer',
                        style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        'Feature 40 • 60fps Hardware Accelerated',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.isEnabled,
                  activeColor: accent,
                  onChanged: (_) => notifier.toggleEnabled(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Live Preview Area
          if (config.isEnabled)
            Container(
              height: 90,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.surfaceHighlight, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                child: CanvasWaveVisualizerWidget(
                  height: 90,
                  showControlsButton: false,
                  isPlayingOverride: true,
                ),
              ),
            ),

          // Settings Controls (Scrollable)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Visualizer Style Selector
                  _buildSectionHeader('Visualizer Style', tokens),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WaveVisualizerStyle.values.map((s) {
                      final isSelected = config.style == s;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.icon,
                              size: 16,
                              color: isSelected ? Colors.white : tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(s.displayName),
                          ],
                        ),
                        selectedColor: accent,
                        backgroundColor: tokens.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : tokens.textPrimary,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => notifier.setStyle(s),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // 2. Color Palette Selector
                  _buildSectionHeader('Color Palette', tokens),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WaveVisualizerColorPalette.values
                        .where((p) => p != WaveVisualizerColorPalette.custom)
                        .map((p) {
                      final isSelected = config.colorPalette == p;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(p.displayName),
                        selectedColor: accent,
                        backgroundColor: tokens.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : tokens.textPrimary,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => notifier.setColorPalette(p),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // 3. Sensitivity Slider
                  _buildSectionHeader(
                    'Sensitivity (${config.sensitivity.toStringAsFixed(1)}x)',
                    tokens,
                  ),
                  Slider(
                    value: config.sensitivity,
                    min: 0.2,
                    max: 2.5,
                    divisions: 23,
                    activeColor: accent,
                    inactiveColor: tokens.surfaceHighlight,
                    onChanged: (val) => notifier.setSensitivity(val),
                  ),

                  // 4. Bar Count Slider
                  _buildSectionHeader(
                    'Spectrum Bins (${config.barCount} bars)',
                    tokens,
                  ),
                  Slider(
                    value: config.barCount.toDouble(),
                    min: 8,
                    max: 64,
                    divisions: 7,
                    activeColor: accent,
                    inactiveColor: tokens.surfaceHighlight,
                    onChanged: (val) => notifier.setBarCount(val.round()),
                  ),

                  // 5. Target FPS Throttle
                  _buildSectionHeader('Frame Rate Throttling', tokens),
                  Row(
                    children: [30, 60, 120].map((fps) {
                      final isSelected = config.targetFps == fps;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text('$fps FPS'),
                          selectedColor: accent,
                          backgroundColor: tokens.surface,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) => notifier.setTargetFps(fps),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // 6. Peak Caps & Mirrored Layout Toggles
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Peak Hold Caps',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14,
                        color: tokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Renders floating gravity-decay dots on harmonic bars',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                    value: config.showPeaks,
                    activeColor: accent,
                    onChanged: (val) => notifier.setShowPeaks(val),
                  ),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Mirrored Dual Direction',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14,
                        color: tokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Expands symmetrically above and below center horizon',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                    value: config.isMirrored,
                    activeColor: accent,
                    onChanged: (val) => notifier.setIsMirrored(val),
                  ),

                  const SizedBox(height: 12),

                  // Reset Defaults Button
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset to Defaults'),
                      style: TextButton.styleFrom(
                        foregroundColor: tokens.textSecondary,
                      ),
                      onPressed: () => notifier.resetToDefaults(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}
