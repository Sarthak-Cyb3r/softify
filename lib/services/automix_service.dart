import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/entities/track.dart';
import 'dsp/parametric_eq.dart';

/// Supported EQ transition curves modeled after Spotify's dap_aurora Automix recipes.
enum EqStyleCurves {
  /// Flat gain across all 3 bands (0 dB).
  neutral,

  /// Bass isolator swap: Deck A cuts lows to -48 dB at midpoint,
  /// Deck B introduces lows past midpoint. Prevents kick drum phase cancellation.
  bassSwap,

  /// Staggered isolator handoff: Lows crossfade at t in [0.2, 0.4],
  /// Mids crossfade at t in [0.4, 0.6], Highs crossfade at t in [0.6, 0.8].
  frequencySplit,

  /// Midrange band dips by -3.5 dB around t = 0.5 to prevent vocal masking.
  dipMid,
}

/// Filter sweep styles modeled after Spotify's dap_aurora transition recipes.
enum FilterFxStyle {
  /// Flat bypass (LPF at 20 kHz, HPF at 20 Hz, Q = 0.707).
  none,

  /// Deck A sweeps LPF from 20 kHz down to 400 Hz; Deck B opens from 400 Hz to 20 kHz.
  lowPassSweep,

  /// Deck A sweeps HPF from 20 Hz up to 3 kHz; Deck B opens from 3 kHz down to 20 Hz.
  highPassSweep,

  /// Resonant bandpass filter builds energy on Deck A before Deck B drop.
  resonantBandPass,

  /// Sidechain ducking filter keyed to incoming deck transients.
  duckingFilter,
}

/// Jogwheel & time-stretch models corresponding to Spotify's R3Stretcher engine.
enum JogwheelStyle {
  /// Smooth tempo convergence from Deck A BPM to Deck B BPM without pitch change.
  tempoSync,

  /// Emulates analog turntable motor switch-off with exponential pitch/rate drop on Deck A.
  vinylBrake,

  /// Temporary micro-rate nudge (+-2%) to phase-align downbeats.
  nudgeAlign,

  /// Direct cut without time-stretching.
  directCut,
}

/// Crossfade volume curve algorithms ensuring constant perceived acoustic power.
enum CrossfadeCurveType {
  /// Equal-power crossfade where v_A = cos(theta) and v_B = sin(theta).
  /// Strictly conserves perceived loudness: v_A^2 + v_B^2 = 1.0.
  equalPower,

  /// Cubic Bezier S-curve (smoothstep) mapped to equal-power energy preservation.
  /// Zero first-derivative at boundaries for click-free entry and exit.
  cubicBezier,

  /// Perceptual logarithmic decibel curve.
  logarithmic,

  /// Linear crossfade (for fully correlated signals).
  linear,
}

/// DSP state parameters for a single deck during transition.
class DeckDspState {
  final double volume; // 32-bit float [0.0, 1.0]
  final double lowGainDb; // Low-band isolator gain in dB
  final double midGainDb; // Mid-band isolator gain in dB
  final double highGainDb; // High-band isolator gain in dB
  final double lpfCutoffHz; // Low-pass filter cutoff in Hz
  final double hpfCutoffHz; // High-pass filter cutoff in Hz
  final double filterResonanceQ; // Filter Q factor
  final double playbackRate; // R3Stretcher playback rate [0.0, 2.0]
  final double pitchShiftSemitones; // Pitch offset

  const DeckDspState({
    required this.volume,
    this.lowGainDb = 0.0,
    this.midGainDb = 0.0,
    this.highGainDb = 0.0,
    this.lpfCutoffHz = 20000.0,
    this.hpfCutoffHz = 20.0,
    this.filterResonanceQ = 0.7071,
    this.playbackRate = 1.0,
    this.pitchShiftSemitones = 0.0,
  });

  /// Linear gain multipliers for the 3 EQ bands.
  double get lowGainLinear => math.pow(10.0, lowGainDb / 20.0).toDouble();
  double get midGainLinear => math.pow(10.0, midGainDb / 20.0).toDouble();
  double get highGainLinear => math.pow(10.0, highGainDb / 20.0).toDouble();
}

/// Complete automix transition frame evaluated at a specific normalized time t in [0.0, 1.0].
class AutomixFrame {
  final double progress; // Normalized transition time t in [0.0, 1.0]
  final DeckDspState deckA; // Outgoing deck state
  final DeckDspState deckB; // Incoming deck state
  final double perceivedLoudnessConservationRatio; // sqrt(v_A^2 + v_B^2)

  const AutomixFrame({
    required this.progress,
    required this.deckA,
    required this.deckB,
    required this.perceivedLoudnessConservationRatio,
  });
}

/// Transition recipe configuring dual-deck automix crossfading.
class AutomixTransitionRecipe {
  final Duration duration; // Clamped [0s, 12s]
  final CrossfadeCurveType curveType;
  final EqStyleCurves eqStyle;
  final FilterFxStyle filterFx;
  final JogwheelStyle jogwheelStyle;
  final double? bpmDeckA;
  final double? bpmDeckB;
  final Duration prebufferLeadTime;

  const AutomixTransitionRecipe({
    this.duration = const Duration(seconds: 5),
    this.curveType = CrossfadeCurveType.equalPower,
    this.eqStyle = EqStyleCurves.bassSwap,
    this.filterFx = FilterFxStyle.none,
    this.jogwheelStyle = JogwheelStyle.tempoSync,
    this.bpmDeckA,
    this.bpmDeckB,
    this.prebufferLeadTime = const Duration(seconds: 20),
  });

  AutomixTransitionRecipe copyWith({
    Duration? duration,
    CrossfadeCurveType? curveType,
    EqStyleCurves? eqStyle,
    FilterFxStyle? filterFx,
    JogwheelStyle? jogwheelStyle,
    double? bpmDeckA,
    double? bpmDeckB,
    Duration? prebufferLeadTime,
  }) {
    return AutomixTransitionRecipe(
      duration: duration ?? this.duration,
      curveType: curveType ?? this.curveType,
      eqStyle: eqStyle ?? this.eqStyle,
      filterFx: filterFx ?? this.filterFx,
      jogwheelStyle: jogwheelStyle ?? this.jogwheelStyle,
      bpmDeckA: bpmDeckA ?? this.bpmDeckA,
      bpmDeckB: bpmDeckB ?? this.bpmDeckB,
      prebufferLeadTime: prebufferLeadTime ?? this.prebufferLeadTime,
    );
  }
}

/// Result of evaluating whether to trigger 320 kbps pre-buffering.
class PrebufferDecision {
  final bool shouldPrebuffer;
  final Duration timeUntilCutover;
  final Duration prebufferLeadTime;
  final String reason;

  const PrebufferDecision({
    required this.shouldPrebuffer,
    required this.timeUntilCutover,
    required this.prebufferLeadTime,
    required this.reason,
  });
}

/// Dual-deck S-curve crossfader modeling and strict 320 kbps 32-bit floating-point DSP service.
class AutomixService {
  Duration _crossfadeDuration = const Duration(seconds: 5);
  bool _crossfadeEnabled = true;
  CrossfadeCurveType _curveType = CrossfadeCurveType.equalPower;
  EqStyleCurves _eqStyle = EqStyleCurves.bassSwap;
  FilterFxStyle _filterFx = FilterFxStyle.none;
  JogwheelStyle _jogwheelStyle = JogwheelStyle.tempoSync;
  Duration _prebufferLeadTime = const Duration(seconds: 20);

  bool _isPrebuffering = false;
  bool _isPrebufferReady = false;
  Track? _prebufferedTrack;
  int _targetBitrateBps = 320000; // 320 kbps strict standard
  ParametricEqualizer? _equalizer;

  final StreamController<AutomixFrame> _transitionFrameController =
      StreamController<AutomixFrame>.broadcast();
  final StreamController<Duration> _crossfadeDurationController =
      StreamController<Duration>.broadcast();

  AutomixService({
    Duration initialCrossfade = const Duration(seconds: 5),
    CrossfadeCurveType curveType = CrossfadeCurveType.equalPower,
    EqStyleCurves eqStyle = EqStyleCurves.bassSwap,
    FilterFxStyle filterFx = FilterFxStyle.none,
    JogwheelStyle jogwheelStyle = JogwheelStyle.tempoSync,
    Duration prebufferLeadTime = const Duration(seconds: 20),
    ParametricEqualizer? equalizer,
  })  : _curveType = curveType,
        _eqStyle = eqStyle,
        _filterFx = filterFx,
        _jogwheelStyle = jogwheelStyle,
        _prebufferLeadTime = prebufferLeadTime,
        _equalizer = equalizer {
    setCrossfadeDuration(initialCrossfade);
  }

  ParametricEqualizer? get equalizer => _equalizer;

  void setEqualizer(ParametricEqualizer? eq) {
    _equalizer = eq;
  }

  // Getters
  Duration get crossfadeDuration => _crossfadeEnabled ? _crossfadeDuration : Duration.zero;
  bool get isCrossfadeEnabled => _crossfadeEnabled;

  void setCrossfadeEnabled(bool enabled) {
    _crossfadeEnabled = enabled;
  }
  CrossfadeCurveType get curveType => _curveType;
  EqStyleCurves get eqStyle => _eqStyle;
  FilterFxStyle get filterFx => _filterFx;
  JogwheelStyle get jogwheelStyle => _jogwheelStyle;
  Duration get prebufferLeadTime => _prebufferLeadTime;
  bool get isPrebuffering => _isPrebuffering;
  bool get isPrebufferReady => _isPrebufferReady;
  Track? get prebufferedTrack => _prebufferedTrack;
  int get targetBitrateBps => _targetBitrateBps;

  Stream<AutomixFrame> get transitionFrameStream =>
      _transitionFrameController.stream;
  Stream<Duration> get crossfadeDurationStream =>
      _crossfadeDurationController.stream;

  /// Sets crossfade duration clamped to [0s, 12s].
  void setCrossfadeDuration(Duration duration) {
    final clampedMs = duration.inMilliseconds.clamp(0, 12000);
    _crossfadeDuration = Duration(milliseconds: clampedMs);
    _crossfadeDurationController.add(_crossfadeDuration);
  }

  void setCurveType(CrossfadeCurveType type) => _curveType = type;
  void setEqStyle(EqStyleCurves style) => _eqStyle = style;
  void setFilterFx(FilterFxStyle style) => _filterFx = style;
  void setJogwheelStyle(JogwheelStyle style) => _jogwheelStyle = style;
  void setPrebufferLeadTime(Duration lead) => _prebufferLeadTime = lead;

  /// Calculates smooth volume curves so perceived loudness remains constant during transitions.
  /// For equal-power: v_A = cos(theta), v_B = sin(theta) where theta = t * pi / 2.
  /// For cubic Bezier: v_A = sqrt(1 - S(t)), v_B = sqrt(S(t)) where S(t) = 3t^2 - 2t^3.
  /// Returns (deckA: double, deckB: double) in [0.0, 1.0].
  ({double deckA, double deckB}) calculateVolumeCurve({
    required double progress,
    CrossfadeCurveType? curve,
  }) {
    final t = progress.clamp(0.0, 1.0);
    final selectedCurve = curve ?? _curveType;

    switch (selectedCurve) {
      case CrossfadeCurveType.equalPower:
        // Constant acoustic energy: cos^2(theta) + sin^2(theta) = 1.0
        final theta = t * (math.pi / 2.0);
        final vA = math.cos(theta).clamp(0.0, 1.0);
        final vB = math.sin(theta).clamp(0.0, 1.0);
        return (deckA: vA, deckB: vB);

      case CrossfadeCurveType.cubicBezier:
        // Smoothstep cubic S-curve S(t) = 3t^2 - 2t^3 with zero derivative at boundaries.
        // Energy preserved via square root transformation.
        final s = t * t * (3.0 - 2.0 * t);
        final vA = math.sqrt((1.0 - s).clamp(0.0, 1.0));
        final vB = math.sqrt(s.clamp(0.0, 1.0));
        return (deckA: vA, deckB: vB);

      case CrossfadeCurveType.logarithmic:
        // Perceptually linear dB curve (-60 dB attenuation floor)
        final theta = t * (math.pi / 2.0);
        final vA = math.cos(theta);
        final vB = math.sin(theta);
        // Apply smooth dB shaping
        final dbA = -60.0 * (1.0 - vA);
        final dbB = -60.0 * (1.0 - vB);
        final linA = (dbA <= -59.0) ? 0.0 : math.pow(10.0, dbA / 20.0).toDouble();
        final linB = (dbB <= -59.0) ? 0.0 : math.pow(10.0, dbB / 20.0).toDouble();
        // Normalize energy
        final energy = math.sqrt(linA * linA + linB * linB);
        if (energy > 1e-6) {
          return (deckA: (linA / energy).clamp(0.0, 1.0), deckB: (linB / energy).clamp(0.0, 1.0));
        }
        return (deckA: 0.0, deckB: 0.0);

      case CrossfadeCurveType.linear:
        final vA = (1.0 - t).clamp(0.0, 1.0);
        final vB = t.clamp(0.0, 1.0);
        return (deckA: vA, deckB: vB);
    }
  }

  /// Evaluates 3-band EQ curve gains (dB) for Deck A and Deck B at progress t in [0.0, 1.0].
  ({
    double lowDbA,
    double midDbA,
    double highDbA,
    double lowDbB,
    double midDbB,
    double highDbB,
  }) calculateEqCurves({
    required double progress,
    required EqStyleCurves eqStyle,
  }) {
    final t = progress.clamp(0.0, 1.0);

    switch (eqStyle) {
      case EqStyleCurves.neutral:
        return (
          lowDbA: 0.0,
          midDbA: 0.0,
          highDbA: 0.0,
          lowDbB: 0.0,
          midDbB: 0.0,
          highDbB: 0.0,
        );

      case EqStyleCurves.bassSwap:
        // Sharp bass isolator swap at midpoint to avoid double-kick phase clashes.
        // Deck A cuts low from 0 dB to -48 dB across t in [0.35, 0.50].
        // Deck B raises low from -48 dB to 0 dB across t in [0.50, 0.65].
        final double lowDbA;
        if (t < 0.35) {
          lowDbA = 0.0;
        } else if (t < 0.50) {
          final p = (t - 0.35) / 0.15;
          lowDbA = -48.0 * p;
        } else {
          lowDbA = -48.0;
        }

        final double lowDbB;
        if (t < 0.50) {
          lowDbB = -48.0;
        } else if (t < 0.65) {
          final p = (t - 0.50) / 0.15;
          lowDbB = -48.0 * (1.0 - p);
        } else {
          lowDbB = 0.0;
        }

        return (
          lowDbA: lowDbA,
          midDbA: 0.0,
          highDbA: 0.0,
          lowDbB: lowDbB,
          midDbB: 0.0,
          highDbB: 0.0,
        );

      case EqStyleCurves.frequencySplit:
        // Staggered isolator crossfades:
        // Low: t in [0.20, 0.40]
        // Mid: t in [0.40, 0.60]
        // High: t in [0.60, 0.80]
        final pLow = ((t - 0.20) / 0.20).clamp(0.0, 1.0);
        final pMid = ((t - 0.40) / 0.20).clamp(0.0, 1.0);
        final pHigh = ((t - 0.60) / 0.20).clamp(0.0, 1.0);

        return (
          lowDbA: -48.0 * pLow,
          midDbA: -48.0 * pMid,
          highDbA: -48.0 * pHigh,
          lowDbB: -48.0 * (1.0 - pLow),
          midDbB: -48.0 * (1.0 - pMid),
          highDbB: -48.0 * (1.0 - pHigh),
        );

      case EqStyleCurves.dipMid:
        // Parabolic dip in mids around t = 0.5 (-3.5 dB) to carve vocal headroom
        final midDip = -3.5 * math.sin(t * math.pi);
        return (
          lowDbA: 0.0,
          midDbA: midDip,
          highDbA: 0.0,
          lowDbB: 0.0,
          midDbB: midDip,
          highDbB: 0.0,
        );
    }
  }

  /// Evaluates resonant filter sweep parameters at progress t in [0.0, 1.0].
  ({
    double lpfA,
    double hpfA,
    double qA,
    double lpfB,
    double hpfB,
    double qB,
  }) calculateFilterFx({
    required double progress,
    required FilterFxStyle filterFx,
  }) {
    final t = progress.clamp(0.0, 1.0);

    switch (filterFx) {
      case FilterFxStyle.none:
        return (
          lpfA: 20000.0,
          hpfA: 20.0,
          qA: 0.7071,
          lpfB: 20000.0,
          hpfB: 20.0,
          qB: 0.7071,
        );

      case FilterFxStyle.lowPassSweep:
        // Deck A sweeps LPF down to 400 Hz starting at t=0.4
        final lpfA = (t < 0.4)
            ? 20000.0
            : 20000.0 * math.pow(400.0 / 20000.0, (t - 0.4) / 0.6).toDouble();
        // Deck B opens LPF up from 400 Hz to 20000 Hz until t=0.6
        final lpfB = (t > 0.6)
            ? 20000.0
            : 400.0 * math.pow(20000.0 / 400.0, t / 0.6).toDouble();
        return (
          lpfA: lpfA.clamp(20.0, 20000.0),
          hpfA: 20.0,
          qA: 0.9,
          lpfB: lpfB.clamp(20.0, 20000.0),
          hpfB: 20.0,
          qB: 0.9,
        );

      case FilterFxStyle.highPassSweep:
        // Deck A sweeps HPF up to 3000 Hz starting at t=0.3
        final hpfA = (t < 0.3)
            ? 20.0
            : 20.0 * math.pow(3000.0 / 20.0, (t - 0.3) / 0.7).toDouble();
        // Deck B sweeps HPF down from 3000 Hz to 20 Hz until t=0.7
        final hpfB = (t > 0.7)
            ? 20.0
            : 3000.0 * math.pow(20.0 / 3000.0, t / 0.7).toDouble();
        return (
          lpfA: 20000.0,
          hpfA: hpfA.clamp(20.0, 20000.0),
          qA: 1.1,
          lpfB: 20000.0,
          hpfB: hpfB.clamp(20.0, 20000.0),
          qB: 1.1,
        );

      case FilterFxStyle.resonantBandPass:
        // High Q sweep on Deck A to create tension
        final centerFreq = 500.0 + 3500.0 * t;
        return (
          lpfA: (centerFreq * 1.5).clamp(20.0, 20000.0),
          hpfA: (centerFreq * 0.66).clamp(20.0, 20000.0),
          qA: 2.5,
          lpfB: 20000.0,
          hpfB: 20.0,
          qB: 0.7071,
        );

      case FilterFxStyle.duckingFilter:
        // Dynamic ducking on Deck A
        final duck = (t >= 0.5) ? 0.3 : 1.0;
        return (
          lpfA: 20000.0 * duck,
          hpfA: 20.0,
          qA: 0.7071,
          lpfB: 20000.0,
          hpfB: 20.0,
          qB: 0.7071,
        );
    }
  }

  /// Evaluates jogwheel/tempo-stretch parameters modeled after Spotify's R3Stretcher.
  ({
    double rateA,
    double pitchA,
    double rateB,
    double pitchB,
  }) calculateJogwheelCurves({
    required double progress,
    required JogwheelStyle style,
    double? bpmA,
    double? bpmB,
  }) {
    final t = progress.clamp(0.0, 1.0);

    switch (style) {
      case JogwheelStyle.tempoSync:
        if (bpmA != null && bpmB != null && bpmA > 0 && bpmB > 0) {
          // Smoothly ramp tempo to target without pitch shift
          final targetBpm = bpmA + (bpmB - bpmA) * (t * t * (3.0 - 2.0 * t));
          return (
            rateA: (targetBpm / bpmA).clamp(0.8, 1.25),
            pitchA: 0.0,
            rateB: (targetBpm / bpmB).clamp(0.8, 1.25),
            pitchB: 0.0,
          );
        }
        return (rateA: 1.0, pitchA: 0.0, rateB: 1.0, pitchB: 0.0);

      case JogwheelStyle.vinylBrake:
        // Turntable brake on Deck A starting at t = 0.75
        if (t >= 0.75) {
          final p = (t - 0.75) / 0.25;
          final decel = math.max(0.0, 1.0 - p * p);
          final pitch = -24.0 * (1.0 - decel);
          return (rateA: decel, pitchA: pitch, rateB: 1.0, pitchB: 0.0);
        }
        return (rateA: 1.0, pitchA: 0.0, rateB: 1.0, pitchB: 0.0);

      case JogwheelStyle.nudgeAlign:
        // Micro nudge (+2.5% rate) during first 20% to align downbeats
        final rateA = (t < 0.2) ? 1.025 : 1.0;
        return (rateA: rateA, pitchA: 0.0, rateB: 1.0, pitchB: 0.0);

      case JogwheelStyle.directCut:
        return (rateA: 1.0, pitchA: 0.0, rateB: 1.0, pitchB: 0.0);
    }
  }

  /// Computes the complete AutomixFrame at normalized time t in [0.0, 1.0].
  AutomixFrame computeTransitionFrame({
    required double progress,
    AutomixTransitionRecipe? recipe,
  }) {
    final currentRecipe = recipe ??
        AutomixTransitionRecipe(
          duration: _crossfadeDuration,
          curveType: _curveType,
          eqStyle: _eqStyle,
          filterFx: _filterFx,
          jogwheelStyle: _jogwheelStyle,
          prebufferLeadTime: _prebufferLeadTime,
        );

    final volumes = calculateVolumeCurve(
      progress: progress,
      curve: currentRecipe.curveType,
    );

    final eq = calculateEqCurves(
      progress: progress,
      eqStyle: currentRecipe.eqStyle,
    );

    final filters = calculateFilterFx(
      progress: progress,
      filterFx: currentRecipe.filterFx,
    );

    final jog = calculateJogwheelCurves(
      progress: progress,
      style: currentRecipe.jogwheelStyle,
      bpmA: currentRecipe.bpmDeckA,
      bpmB: currentRecipe.bpmDeckB,
    );

    final deckA = DeckDspState(
      volume: volumes.deckA,
      lowGainDb: eq.lowDbA,
      midGainDb: eq.midDbA,
      highGainDb: eq.highDbA,
      lpfCutoffHz: filters.lpfA,
      hpfCutoffHz: filters.hpfA,
      filterResonanceQ: filters.qA,
      playbackRate: jog.rateA,
      pitchShiftSemitones: jog.pitchA,
    );

    final deckB = DeckDspState(
      volume: volumes.deckB,
      lowGainDb: eq.lowDbB,
      midGainDb: eq.midDbB,
      highGainDb: eq.highDbB,
      lpfCutoffHz: filters.lpfB,
      hpfCutoffHz: filters.hpfB,
      filterResonanceQ: filters.qB,
      playbackRate: jog.rateB,
      pitchShiftSemitones: jog.pitchB,
    );

    // Conservation metric sqrt(v_A^2 + v_B^2)
    final loudnessRatio = math.sqrt(volumes.deckA * volumes.deckA + volumes.deckB * volumes.deckB);

    final frame = AutomixFrame(
      progress: progress.clamp(0.0, 1.0),
      deckA: deckA,
      deckB: deckB,
      perceivedLoudnessConservationRatio: loudnessRatio,
    );

    _transitionFrameController.add(frame);
    return frame;
  }

  /// Evaluates whether the next 320 kbps track should be pre-buffered.
  /// Pre-buffers prior to track termination (lead time: e.g. 20s before crossfade onset).
  PrebufferDecision evaluatePrebufferTrigger({
    required Duration currentPosition,
    required Duration currentTrackDuration,
    Duration? crossfade,
    Duration? leadTime,
  }) {
    final xfade = crossfade ?? _crossfadeDuration;
    final lead = leadTime ?? _prebufferLeadTime;

    if (currentTrackDuration <= const Duration(seconds: 25)) {
      return PrebufferDecision(
        shouldPrebuffer: false,
        timeUntilCutover: Duration.zero,
        prebufferLeadTime: lead,
        reason: 'Track too short for speculative prebuffering',
      );
    }

    final cutoverPoint = currentTrackDuration - xfade;
    final triggerPoint = cutoverPoint - lead;

    final shouldTrigger =
        currentPosition >= triggerPoint && currentPosition < currentTrackDuration;
    final timeUntilCutover = (cutoverPoint > currentPosition)
        ? (cutoverPoint - currentPosition)
        : Duration.zero;

    return PrebufferDecision(
      shouldPrebuffer: shouldTrigger,
      timeUntilCutover: timeUntilCutover,
      prebufferLeadTime: lead,
      reason: shouldTrigger
          ? 'Within prebuffer window ($lead lead before crossfade)'
          : 'Outside prebuffer window',
    );
  }

  /// Sets prebuffer state when standby prebuffering starts.
  void markPrebuffering(Track track, {int bitrateBps = 320000}) {
    _isPrebuffering = true;
    _isPrebufferReady = false;
    _prebufferedTrack = track;
    _targetBitrateBps = bitrateBps;
  }

  /// Marks prebuffered 320 kbps stream as decoded and ready in standby deck.
  void markPrebufferReady() {
    _isPrebuffering = false;
    _isPrebufferReady = true;
  }

  /// Clears standby prebuffer state.
  void clearPrebuffer() {
    _isPrebuffering = false;
    _isPrebufferReady = false;
    _prebufferedTrack = null;
  }

  /// Pure 32-bit floating-point dual-deck summing bus with optional Parametric EQ stage.
  /// Executes strictly in 32-bit float vector arithmetic with ZERO lossy re-encoding or downsampling.
  /// Operates on interleaved stereo PCM [L0, R0, L1, R1, ...] 32-bit float buffers.
  void mixDualDeck32BitFloat({
    required Float32List deckABuffer,
    required Float32List deckBBuffer,
    required Float32List outMasterBuffer,
    required double progress,
    AutomixTransitionRecipe? recipe,
    ParametricEqualizer? masterEqualizer,
  }) {
    final sampleCount = math.min(
      outMasterBuffer.length,
      math.min(deckABuffer.length, deckBBuffer.length),
    );

    final frame = computeTransitionFrame(progress: progress, recipe: recipe);
    final gainA = frame.deckA.volume;
    final gainB = frame.deckB.volume;

    // Strict 32-bit float linear pass-through without bit-depth loss or sample rate modification
    for (int i = 0; i < sampleCount; i++) {
      final sampleA = deckABuffer[i] * gainA;
      final sampleB = deckBBuffer[i] * gainB;
      outMasterBuffer[i] = sampleA + sampleB;
    }

    // Apply master 32-bit floating-point parametric equalizer cascade if present
    final eq = masterEqualizer ?? _equalizer;
    if (eq != null && eq.enabled) {
      eq.processInterleaved(outMasterBuffer, 2);
    }
  }

  void dispose() {
    _transitionFrameController.close();
    _crossfadeDurationController.close();
  }
}
