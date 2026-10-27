import 'dart:math' as math;
import 'dart:typed_data';

import 'biquad_filter.dart';

/// Single parametric equalizer frequency band specification.
class EqBand {
  final int index;
  final bool enabled;
  final BiquadFilterType type;
  final double frequency; // Hz
  final double gainDb; // dB [-24.0, +24.0]
  final double q; // Quality factor (0.1 to 20.0)

  const EqBand({
    required this.index,
    this.enabled = true,
    required this.type,
    required this.frequency,
    required this.gainDb,
    this.q = 1.0,
  });

  EqBand copyWith({
    int? index,
    bool? enabled,
    BiquadFilterType? type,
    double? frequency,
    double? gainDb,
    double? q,
  }) {
    return EqBand(
      index: index ?? this.index,
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      gainDb: gainDb ?? this.gainDb,
      q: q ?? this.q,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'enabled': enabled,
        'type': type.name,
        'frequency': frequency,
        'gainDb': gainDb,
        'q': q,
      };

  factory EqBand.fromJson(Map<String, dynamic> json) {
    return EqBand(
      index: json['index'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      type: BiquadFilterType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BiquadFilterType.peaking,
      ),
      frequency: (json['frequency'] as num?)?.toDouble() ?? 1000.0,
      gainDb: (json['gainDb'] as num?)?.toDouble() ?? 0.0,
      q: (json['q'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() =>
      'EqBand(#$index: ${enabled ? "ON" : "OFF"} ${type.name} Fc=${frequency.toStringAsFixed(1)}Hz Gain=${gainDb.toStringAsFixed(1)}dB Q=${q.toStringAsFixed(2)})';
}

/// Software-defined cascaded Parametric Equalizer.
///
/// Implements n-band cascaded Robert Bristow-Johnson biquad IIR filters with
/// pre-amplification scaling. Preserves 32-bit floating-point StudioMaster audio
/// fidelity without lossy quantization or truncation.
class ParametricEqualizer {
  static final ParametricEqualizer instance = ParametricEqualizer();

  bool enabled;
  double _preampDb;
  double _sampleRate;
  final int _channels;

  final List<EqBand> _bands = [];
  final List<BiquadFilter> _filters = [];

  ParametricEqualizer({
    this.enabled = true,
    double preampDb = 0.0,
    double sampleRate = 44100.0,
    int channels = 2,
    List<EqBand>? initialBands,
  })  : _preampDb = preampDb,
        _sampleRate = sampleRate,
        _channels = channels.clamp(1, 8) {
    if (initialBands != null && initialBands.isNotEmpty) {
      setBands(initialBands, preampDb: preampDb);
    } else {
      _loadDefaultFlatBands();
    }
  }

  double get preampDb => _preampDb;
  double get sampleRate => _sampleRate;
  List<EqBand> get bands => List.unmodifiable(_bands);
  List<BiquadFilter> get filters => List.unmodifiable(_filters);

  /// Linear preamp multiplier: 10^(preampDb / 20).
  double get linearPreamp => math.pow(10.0, _preampDb / 20.0).toDouble();

  void _loadDefaultFlatBands() {
    // Standard ISO 10-band octave frequencies
    const defaultFrequencies = [
      31.25,
      62.5,
      125.0,
      250.0,
      500.0,
      1000.0,
      2000.0,
      4000.0,
      8000.0,
      16000.0,
    ];

    final bands = <EqBand>[];
    for (int i = 0; i < defaultFrequencies.length; i++) {
      final BiquadFilterType type;
      if (i == 0) {
        type = BiquadFilterType.lowShelf;
      } else if (i == defaultFrequencies.length - 1) {
        type = BiquadFilterType.highShelf;
      } else {
        type = BiquadFilterType.peaking;
      }

      bands.add(EqBand(
        index: i,
        enabled: true,
        type: type,
        frequency: defaultFrequencies[i],
        gainDb: 0.0,
        q: 1.414,
      ));
    }

    setBands(bands, preampDb: _preampDb);
  }

  /// Sets or replaces all equalizer bands and updates preamp attenuation.
  void setBands(List<EqBand> newBands, {double? preampDb}) {
    if (preampDb != null) {
      _preampDb = preampDb;
    }

    _bands.clear();
    _filters.clear();

    for (int i = 0; i < newBands.length; i++) {
      final band = newBands[i];
      _bands.add(band);

      _filters.add(BiquadFilter(
        type: band.type,
        frequency: band.frequency,
        gainDb: band.gainDb,
        q: band.q,
        sampleRate: _sampleRate,
        enabled: band.enabled,
        channels: _channels,
      ));
    }
  }

  /// Updates a specific EQ band by index.
  void updateBand(
    int index, {
    double? frequency,
    double? gainDb,
    double? q,
    bool? enabled,
    BiquadFilterType? type,
  }) {
    if (index < 0 || index >= _bands.length) return;

    final oldBand = _bands[index];
    final updatedBand = oldBand.copyWith(
      frequency: frequency,
      gainDb: gainDb,
      q: q,
      enabled: enabled,
      type: type,
    );

    _bands[index] = updatedBand;
    _filters[index].update(
      frequency: updatedBand.frequency,
      gainDb: updatedBand.gainDb,
      q: updatedBand.q,
      enabled: updatedBand.enabled,
      type: updatedBand.type,
    );
  }

  /// Sets global preamp gain in dB (e.g. -6.0 dB for AutoEq headroom).
  void setPreampDb(double db) {
    _preampDb = db;
  }

  /// Updates sample rate and recalibrates all filter coefficients.
  void setSampleRate(double fs) {
    if ((fs - _sampleRate).abs() < 1e-3) return;
    _sampleRate = fs;
    for (final filter in _filters) {
      filter.update(sampleRate: fs);
    }
  }

  /// Resets delay states across all cascaded filters to prevent clicks/thumps on seeks.
  void reset() {
    for (final filter in _filters) {
      filter.reset();
    }
  }

  /// Processes a single audio sample through the preamp and cascaded biquad filters.
  @pragma('vm:prefer-inline')
  double processSample(double sample, {int channel = 0}) {
    if (!enabled) return sample;

    double out = sample * linearPreamp;
    for (int i = 0; i < _filters.length; i++) {
      out = _filters[i].processSample(out, channel: channel);
    }
    return out;
  }

  /// In-place processing of 32-bit floating-point interleaved stereo PCM audio.
  /// Format: [L0, R0, L1, R1, ...]
  ///
  /// Strictly operates in 32-bit float vector arithmetic without downsampling.
  void processInterleaved(Float32List buffer, int channels) {
    if (!enabled) return;

    final length = buffer.length;
    final pPreamp = linearPreamp;

    // Apply preamp gain
    if ((pPreamp - 1.0).abs() > 1e-6) {
      for (int i = 0; i < length; i++) {
        buffer[i] *= pPreamp;
      }
    }

    // Cascade through each active biquad filter stage
    for (int f = 0; f < _filters.length; f++) {
      final filter = _filters[f];
      if (filter.enabled) {
        filter.processInterleaved(buffer, channels);
      }
    }
  }

  /// In-place processing of planar stereo audio buffers (separate Left and Right).
  void processPlanar(Float32List left, Float32List right) {
    if (!enabled) return;

    final length = math.min(left.length, right.length);
    final pPreamp = linearPreamp;

    if ((pPreamp - 1.0).abs() > 1e-6) {
      for (int i = 0; i < length; i++) {
        left[i] *= pPreamp;
        right[i] *= pPreamp;
      }
    }

    for (int f = 0; f < _filters.length; f++) {
      final filter = _filters[f];
      if (filter.enabled) {
        filter.processPlanar(left, right);
      }
    }
  }

  /// Evaluates composite frequency response in dB at [freqHz] including preamp.
  double evaluateGainAt(double freqHz) {
    if (!enabled) return 0.0;

    double totalDb = _preampDb;
    for (int i = 0; i < _filters.length; i++) {
      if (_filters[i].enabled) {
        totalDb += _filters[i].evaluateGainAt(freqHz);
      }
    }
    return totalDb;
  }

  /// Computes the maximum potential positive boost across the audible spectrum (20Hz to 20kHz).
  /// Used by LoudnessNormalizerService lookahead limiter to prevent inter-sample DAC clipping.
  double computeMaxPotentialBoostDb() {
    if (!enabled) return 0.0;

    double maxBoost = _preampDb;

    // Sample across 30 log-spaced test points across the audible spectrum
    for (int i = 0; i <= 30; i++) {
      final freq = 20.0 * math.pow(1000.0, i / 30.0);
      final gain = evaluateGainAt(freq);
      if (gain > maxBoost) {
        maxBoost = gain;
      }
    }

    return math.max(0.0, maxBoost);
  }

  /// Preset factory configurations
  void loadPreset(String name) {
    switch (name.toLowerCase()) {
      case 'bass_boost':
      case 'bassboost':
        setBands([
          const EqBand(index: 0, type: BiquadFilterType.lowShelf, frequency: 80.0, gainDb: 5.5, q: 0.707),
          const EqBand(index: 1, type: BiquadFilterType.peaking, frequency: 160.0, gainDb: 3.0, q: 1.2),
          const EqBand(index: 2, type: BiquadFilterType.peaking, frequency: 500.0, gainDb: 0.0, q: 1.0),
          const EqBand(index: 3, type: BiquadFilterType.peaking, frequency: 2000.0, gainDb: 0.0, q: 1.0),
          const EqBand(index: 4, type: BiquadFilterType.highShelf, frequency: 8000.0, gainDb: 0.0, q: 0.707),
        ], preampDb: -3.0);
        break;

      case 'vocal_boost':
      case 'vocalboost':
        setBands([
          const EqBand(index: 0, type: BiquadFilterType.lowShelf, frequency: 100.0, gainDb: -2.0, q: 0.707),
          const EqBand(index: 1, type: BiquadFilterType.peaking, frequency: 1000.0, gainDb: 3.5, q: 1.5),
          const EqBand(index: 2, type: BiquadFilterType.peaking, frequency: 3000.0, gainDb: 4.0, q: 1.8),
          const EqBand(index: 3, type: BiquadFilterType.highShelf, frequency: 8000.0, gainDb: 1.0, q: 0.707),
        ], preampDb: -2.5);
        break;

      case 'treble_boost':
      case 'trebleboost':
        setBands([
          const EqBand(index: 0, type: BiquadFilterType.lowShelf, frequency: 200.0, gainDb: 0.0, q: 0.707),
          const EqBand(index: 1, type: BiquadFilterType.peaking, frequency: 4000.0, gainDb: 3.0, q: 1.4),
          const EqBand(index: 2, type: BiquadFilterType.highShelf, frequency: 10000.0, gainDb: 5.0, q: 0.707),
        ], preampDb: -3.0);
        break;

      case 'electronic':
      case 'edm':
        setBands([
          const EqBand(index: 0, type: BiquadFilterType.lowShelf, frequency: 60.0, gainDb: 4.5, q: 0.707),
          const EqBand(index: 1, type: BiquadFilterType.peaking, frequency: 250.0, gainDb: 1.5, q: 1.0),
          const EqBand(index: 2, type: BiquadFilterType.peaking, frequency: 1000.0, gainDb: -1.0, q: 1.2),
          const EqBand(index: 3, type: BiquadFilterType.peaking, frequency: 4000.0, gainDb: 2.5, q: 1.5),
          const EqBand(index: 4, type: BiquadFilterType.highShelf, frequency: 12000.0, gainDb: 4.0, q: 0.707),
        ], preampDb: -3.5);
        break;

      case 'flat':
      default:
        _preampDb = 0.0;
        _loadDefaultFlatBands();
        break;
    }
  }
}
