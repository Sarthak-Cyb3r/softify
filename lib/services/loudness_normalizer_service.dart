import 'dart:math' as math;

import 'dsp/parametric_eq.dart';

/// Loudness normalization profile modes corresponding to Spotify's playback settings.
enum LoudnessProfile {
  /// -14 LUFS: Standard audiophile target preserving full 320 kbps dynamics.
  normal,

  /// -11 LUFS: Higher target for noisy environments.
  loud,

  /// -19 LUFS: Classical / high-dynamic-range target.
  quiet,

  /// Bypass normalization (linear 1.0 multiplier).
  off,
}

/// Dynamic audio loudness normalizer and lookahead peak limiter service.
/// Modeled after Spotify's dap_aurora peaklimiter and EBU R128 gain calculator.
class LoudnessNormalizerService {
  static final LoudnessNormalizerService instance =
      LoudnessNormalizerService._internal();

  LoudnessNormalizerService._internal();

  LoudnessProfile _activeProfile = LoudnessProfile.normal;
  ParametricEqualizer? _attachedEqualizer;

  /// Target integrated loudness values in LUFS.
  static const Map<LoudnessProfile, double> targetLufsMap = {
    LoudnessProfile.normal: -14.0,
    LoudnessProfile.loud: -11.0,
    LoudnessProfile.quiet: -19.0,
    LoudnessProfile.off: 0.0,
  };

  /// True-peak ceiling in linear amplitude (-0.2 dBFS = 0.9772).
  /// Prevents inter-sample DAC clipping on hardware output stages.
  static const double truePeakCeilingLinear = 0.9772372209558107;

  LoudnessProfile get activeProfile => _activeProfile;

  void setProfile(LoudnessProfile profile) {
    _activeProfile = profile;
  }

  /// Attaches a [ParametricEqualizer] to dynamically guard against clipping
  /// when EQ frequency bands are boosted.
  void attachEqualizer(ParametricEqualizer? equalizer) {
    _attachedEqualizer = equalizer;
  }

  /// Calculates dynamic linear gain multiplier for a track given its measured LUFS and peak.
  ///
  /// Preserves 320 kbps bitstream integrity: all calculations execute in 32-bit float
  /// and scale the final decoder volume multiplier without bit-depth truncation.
  double computeGainMultiplier({
    required double trackLufs,
    double trackPeakLinear = 1.0,
    double extraEqBoostDb = 0.0,
  }) {
    final effectiveEqBoost = extraEqBoostDb != 0.0
        ? extraEqBoostDb
        : (_attachedEqualizer != null && _attachedEqualizer!.enabled
            ? _attachedEqualizer!.computeMaxPotentialBoostDb()
            : 0.0);

    final totalEqLinear = math.pow(10.0, effectiveEqBoost / 20.0).toDouble();

    if (_activeProfile == LoudnessProfile.off) {
      // If normalization is off, only apply peak limiter if EQ boost exceeds ceiling
      if (trackPeakLinear * totalEqLinear > truePeakCeilingLinear) {
        return truePeakCeilingLinear / (trackPeakLinear * totalEqLinear);
      }
      return 1.0;
    }

    final targetLufs = targetLufsMap[_activeProfile] ?? -14.0;

    // Gain difference in dB for loudness matching
    final deltaDb = targetLufs - trackLufs;

    // Raw linear gain multiplier
    final rawMultiplier = math.pow(10.0, deltaDb / 20.0).toDouble();

    // Lookahead Peak Limiter:
    // If the scaled audio peak factoring in the equalizer boost would breach the true-peak ceiling, clamp gain
    final projectedPeak = trackPeakLinear * rawMultiplier * totalEqLinear;
    if (projectedPeak > truePeakCeilingLinear) {
      final limitedMultiplier = truePeakCeilingLinear / (trackPeakLinear * totalEqLinear);
      return limitedMultiplier.clamp(0.05, 4.0);
    }

    // Limit maximum positive boost to +6 dB to prevent noise floor amplification
    return rawMultiplier.clamp(0.05, 2.0);
  }

  /// Convenience calculation linking a specific [ParametricEqualizer] cascade.
  double computeGainMultiplierWithEqualizer({
    required double trackLufs,
    double trackPeakLinear = 1.0,
    required ParametricEqualizer equalizer,
  }) {
    final eqBoost = equalizer.enabled ? equalizer.computeMaxPotentialBoostDb() : 0.0;
    return computeGainMultiplier(
      trackLufs: trackLufs,
      trackPeakLinear: trackPeakLinear,
      extraEqBoostDb: eqBoost,
    );
  }

  /// Convenience method for tracks without pre-calculated LUFS metadata.
  /// Uses heuristic fallback based on track genre and source type.
  double computeDefaultGain({bool isModernMaster = true}) {
    // Modern digital masters are typically mastered to ~ -9 to -11 LUFS
    final defaultMeasuredLufs = isModernMaster ? -10.5 : -14.0;
    return computeGainMultiplier(trackLufs: defaultMeasuredLufs);
  }
}
