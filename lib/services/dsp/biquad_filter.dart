import 'dart:math' as math;
import 'dart:typed_data';

/// Filter topologies defined in Robert Bristow-Johnson's Audio EQ Cookbook.
enum BiquadFilterType {
  /// Parametric peaking/bell filter with adjustable center frequency, gain, and Q.
  peaking,

  /// Low-shelf filter boosting or cutting frequencies below cutoff.
  lowShelf,

  /// High-shelf filter boosting or cutting frequencies above cutoff.
  highShelf,

  /// 2nd order Butterworth low-pass filter.
  lowPass,

  /// 2nd order Butterworth high-pass filter.
  highPass,

  /// Band-pass filter with constant 0 dB peak gain.
  bandPass,

  /// Notch/band-stop filter.
  notch,

  /// All-pass filter for phase manipulation.
  allPass,
}

/// Normalized biquad filter transfer function coefficients where a0 = 1.0.
///
/// Transfer function:
/// H(z) = (b0 + b1*z^-1 + b2*z^-2) / (1 + a1*z^-1 + a2*z^-2)
class BiquadCoefficients {
  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;

  const BiquadCoefficients({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  static const BiquadCoefficients identity = BiquadCoefficients(
    b0: 1.0,
    b1: 0.0,
    b2: 0.0,
    a1: 0.0,
    a2: 0.0,
  );
}

/// Software-defined Robert Bristow-Johnson Audio EQ Cookbook Biquad IIR Filter.
///
/// Operates on 32-bit floating point audio buffers preserving pure studio-grade
/// 320 kbps fidelity. Independent of hardware/vendor DSP limits.
class BiquadFilter {
  BiquadFilterType _type;
  double _frequency;
  double _gainDb;
  double _q;
  double _sampleRate;
  bool enabled;

  late BiquadCoefficients _coeffs;

  // Direct Form I delay state registers per channel
  // Channel 0: Left, Channel 1: Right (or mono)
  final int _channels;
  late Float64List _x1;
  late Float64List _x2;
  late Float64List _y1;
  late Float64List _y2;

  BiquadFilter({
    required BiquadFilterType type,
    required double frequency,
    double gainDb = 0.0,
    double q = 0.7071,
    double sampleRate = 44100.0,
    this.enabled = true,
    int channels = 2,
  })  : _type = type,
        _frequency = frequency,
        _gainDb = gainDb,
        _q = q,
        _sampleRate = sampleRate,
        _channels = channels.clamp(1, 8) {
    _initStates();
    _computeCoefficients();
  }

  void _initStates() {
    _x1 = Float64List(_channels);
    _x2 = Float64List(_channels);
    _y1 = Float64List(_channels);
    _y2 = Float64List(_channels);
  }

  BiquadFilterType get type => _type;
  double get frequency => _frequency;
  double get gainDb => _gainDb;
  double get q => _q;
  double get sampleRate => _sampleRate;
  BiquadCoefficients get coefficients => _coeffs;

  /// Recalculates normalized filter coefficients.
  void _computeCoefficients() {
    // Clamp parameters to physically realizable and numerically stable ranges
    final fs = _sampleRate.clamp(8000.0, 192000.0);
    final nyquist = fs * 0.499;
    final f0 = _frequency.clamp(10.0, nyquist);
    final clampedQ = _q.clamp(0.01, 100.0);

    // If gain is 0 dB for peaking or shelf filters, filter is unity pass-through
    if (_gainDb.abs() < 1e-9 &&
        (_type == BiquadFilterType.peaking ||
            _type == BiquadFilterType.lowShelf ||
            _type == BiquadFilterType.highShelf)) {
      _coeffs = BiquadCoefficients.identity;
      return;
    }

    // RBJ Cookbook intermediate variables
    // A = 10^(dBgain/40) = sqrt(10^(dBgain/20))
    final a = math.pow(10.0, _gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * f0 / fs;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final alpha = sinW0 / (2.0 * clampedQ);

    double b0 = 1.0;
    double b1 = 0.0;
    double b2 = 0.0;
    double a0 = 1.0;
    double a1 = 0.0;
    double a2 = 0.0;

    switch (_type) {
      case BiquadFilterType.peaking:
        b0 = 1.0 + alpha * a;
        b1 = -2.0 * cosW0;
        b2 = 1.0 - alpha * a;
        a0 = 1.0 + alpha / a;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha / a;
        break;

      case BiquadFilterType.lowShelf:
        final sqrtA = math.sqrt(a);
        final twoSqrtAAlpha = (sqrtA * sinW0) / clampedQ;

        b0 = a * ((a + 1.0) - (a - 1.0) * cosW0 + twoSqrtAAlpha);
        b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cosW0);
        b2 = a * ((a + 1.0) - (a - 1.0) * cosW0 - twoSqrtAAlpha);
        a0 = (a + 1.0) + (a - 1.0) * cosW0 + twoSqrtAAlpha;
        a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cosW0);
        a2 = (a + 1.0) + (a - 1.0) * cosW0 - twoSqrtAAlpha;
        break;

      case BiquadFilterType.highShelf:
        final sqrtA = math.sqrt(a);
        final twoSqrtAAlpha = (sqrtA * sinW0) / clampedQ;

        b0 = a * ((a + 1.0) + (a - 1.0) * cosW0 + twoSqrtAAlpha);
        b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosW0);
        b2 = a * ((a + 1.0) + (a - 1.0) * cosW0 - twoSqrtAAlpha);
        a0 = (a + 1.0) - (a - 1.0) * cosW0 + twoSqrtAAlpha;
        a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cosW0);
        a2 = (a + 1.0) - (a - 1.0) * cosW0 - twoSqrtAAlpha;
        break;

      case BiquadFilterType.lowPass:
        b0 = (1.0 - cosW0) / 2.0;
        b1 = 1.0 - cosW0;
        b2 = (1.0 - cosW0) / 2.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.highPass:
        b0 = (1.0 + cosW0) / 2.0;
        b1 = -(1.0 + cosW0);
        b2 = (1.0 + cosW0) / 2.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.bandPass:
        b0 = alpha;
        b1 = 0.0;
        b2 = -alpha;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.notch:
        b0 = 1.0;
        b1 = -2.0 * cosW0;
        b2 = 1.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.allPass:
        b0 = 1.0 - alpha;
        b1 = -2.0 * cosW0;
        b2 = 1.0 + alpha;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;
    }

    // Normalize coefficients by dividing by a0
    final invA0 = 1.0 / a0;
    _coeffs = BiquadCoefficients(
      b0: b0 * invA0,
      b1: b1 * invA0,
      b2: b2 * invA0,
      a1: a1 * invA0,
      a2: a2 * invA0,
    );
  }

  /// Updates filter parameters dynamically and recalculates coefficients.
  void update({
    BiquadFilterType? type,
    double? frequency,
    double? gainDb,
    double? q,
    double? sampleRate,
    bool? enabled,
  }) {
    bool dirty = false;
    if (type != null && type != _type) {
      _type = type;
      dirty = true;
    }
    if (frequency != null && frequency != _frequency) {
      _frequency = frequency;
      dirty = true;
    }
    if (gainDb != null && gainDb != _gainDb) {
      _gainDb = gainDb;
      dirty = true;
    }
    if (q != null && q != _q) {
      _q = q;
      dirty = true;
    }
    if (sampleRate != null && sampleRate != _sampleRate) {
      _sampleRate = sampleRate;
      dirty = true;
    }
    if (enabled != null) {
      this.enabled = enabled;
    }

    if (dirty) {
      _computeCoefficients();
    }
  }

  /// Resets filter history/delay registers to zero (prevents audio pops on seek).
  void reset() {
    _x1.fillRange(0, _channels, 0.0);
    _x2.fillRange(0, _channels, 0.0);
    _y1.fillRange(0, _channels, 0.0);
    _y2.fillRange(0, _channels, 0.0);
  }

  /// Processes a single audio sample for the designated channel (0 = Left, 1 = Right).
  ///
  /// Uses Direct Form I difference equation:
  /// y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
  @pragma('vm:prefer-inline')
  double processSample(double input, {int channel = 0}) {
    if (!enabled) return input;

    final ch = channel % _channels;
    final b0 = _coeffs.b0;
    final b1 = _coeffs.b1;
    final b2 = _coeffs.b2;
    final a1 = _coeffs.a1;
    final a2 = _coeffs.a2;

    double y = b0 * input + b1 * _x1[ch] + b2 * _x2[ch] - a1 * _y1[ch] - a2 * _y2[ch];

    // Anti-denormal flush: prevent floating-point CPU performance penalties on near-zero values
    if (y.abs() < 1e-15) {
      y = 0.0;
    }

    _x2[ch] = _x1[ch];
    _x1[ch] = input;
    _y2[ch] = _y1[ch];
    _y1[ch] = y;

    return y;
  }

  /// In-place processing of an interleaved stereo or multi-channel Float32 buffer.
  /// Format: [L0, R0, L1, R1, L2, R2, ...]
  void processInterleaved(Float32List buffer, int channels) {
    if (!enabled) return;

    final length = buffer.length;
    final chCount = math.min(channels, _channels);

    for (int i = 0; i < length; i += channels) {
      for (int c = 0; c < chCount; c++) {
        final idx = i + c;
        if (idx < length) {
          buffer[idx] = processSample(buffer[idx], channel: c);
        }
      }
    }
  }

  /// In-place processing of planar stereo audio buffers (separate Left and Right).
  void processPlanar(Float32List left, Float32List right) {
    if (!enabled) return;

    final length = math.min(left.length, right.length);
    for (int i = 0; i < length; i++) {
      left[i] = processSample(left[i], channel: 0);
      right[i] = processSample(right[i], channel: 1);
    }
  }

  /// Computes theoretical frequency response magnitude in decibels (dB) at [freqHz].
  ///
  /// Evaluates transfer function H(e^jw):
  /// Gain(dB) = 20 * log10(|H(e^jw)|)
  double evaluateGainAt(double freqHz) {
    final w = 2.0 * math.pi * freqHz / _sampleRate;
    final cosW = math.cos(w);
    final sinW = math.sin(w);
    final cos2W = math.cos(2.0 * w);
    final sin2W = math.sin(2.0 * w);

    // Numerator: b0 + b1*e^-jw + b2*e^-j2w
    final numReal = _coeffs.b0 + _coeffs.b1 * cosW + _coeffs.b2 * cos2W;
    final numImag = -(_coeffs.b1 * sinW + _coeffs.b2 * sin2W);
    final numMagSq = numReal * numReal + numImag * numImag;

    // Denominator: 1 + a1*e^-jw + a2*e^-j2w
    final denReal = 1.0 + _coeffs.a1 * cosW + _coeffs.a2 * cos2W;
    final denImag = -(_coeffs.a1 * sinW + _coeffs.a2 * sin2W);
    final denMagSq = denReal * denReal + denImag * denImag;

    if (denMagSq < 1e-12) return 0.0;
    final ratio = numMagSq / denMagSq;
    if (ratio <= 0.0) return -100.0;

    return 10.0 * (math.log(ratio) / math.ln10);
  }
}
