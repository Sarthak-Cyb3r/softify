class EqualizerPreset {
  final String name;
  final List<double> gains;

  const EqualizerPreset({
    required this.name,
    required this.gains,
  });

  static const List<EqualizerPreset> defaultPresets = [
    EqualizerPreset(name: 'Flat', gains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
    EqualizerPreset(name: 'Bass Booster', gains: [6.0, 5.0, 4.0, 2.5, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
    EqualizerPreset(name: 'Bass Reducer', gains: [-6.0, -5.0, -4.0, -2.5, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
    EqualizerPreset(name: 'Treble Booster', gains: [0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.5, 4.5, 5.5, 6.0]),
    EqualizerPreset(name: 'Treble Reducer', gains: [0.0, 0.0, 0.0, 0.0, -1.0, -2.0, -3.5, -4.5, -5.5, -6.0]),
    EqualizerPreset(name: 'Vocal Booster', gains: [-2.0, -1.0, 0.0, 1.5, 4.0, 4.5, 3.5, 2.0, 0.5, 0.0]),
    EqualizerPreset(name: 'Rock', gains: [4.5, 3.5, 2.5, 0.5, -1.0, 0.0, 2.0, 3.5, 4.5, 5.0]),
    EqualizerPreset(name: 'Pop', gains: [-1.0, 0.5, 2.0, 3.5, 4.0, 3.5, 2.5, 1.0, -0.5, -1.0]),
    EqualizerPreset(name: 'Hip Hop', gains: [6.0, 5.5, 4.0, 2.5, 0.0, 1.0, 2.0, 2.5, 3.0, 3.5]),
    EqualizerPreset(name: 'Electronic', gains: [5.0, 4.5, 3.5, 1.0, -0.5, 0.5, 2.5, 4.0, 4.5, 5.0]),
    EqualizerPreset(name: 'Jazz', gains: [3.0, 2.5, 1.5, 1.0, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]),
    EqualizerPreset(name: 'Classical', gains: [4.0, 3.5, 2.5, 0.5, -1.0, 0.0, 1.5, 2.5, 3.5, 4.0]),
    EqualizerPreset(name: 'Acoustic', gains: [3.0, 2.5, 2.0, 1.5, 1.0, 1.0, 2.0, 2.5, 3.0, 3.5]),
    EqualizerPreset(name: 'Deep', gains: [5.5, 4.5, 3.0, 1.5, 0.5, -0.5, -1.0, -1.5, -2.5, -3.0]),
  ];
}

class EqualizerState {
  final bool enabled;
  final String currentPreset;
  final List<double> bandGains;
  final List<double> bandFrequencies;
  final double bassBoost;
  final double loudnessGain;
  final bool loudnessNormalization;
  final bool isBypassed;
  final double minDecibels;
  final double maxDecibels;

  const EqualizerState({
    this.enabled = true,
    this.currentPreset = 'Flat',
    this.bandGains = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.bandFrequencies = const [
      31.0,
      62.0,
      125.0,
      250.0,
      500.0,
      1000.0,
      2000.0,
      4000.0,
      8000.0,
      16000.0
    ],
    this.bassBoost = 0.0,
    this.loudnessGain = 0.0,
    this.loudnessNormalization = false,
    this.isBypassed = false,
    this.minDecibels = -12.0,
    this.maxDecibels = 12.0,
  });

  EqualizerState copyWith({
    bool? enabled,
    String? currentPreset,
    List<double>? bandGains,
    List<double>? bandFrequencies,
    double? bassBoost,
    double? loudnessGain,
    bool? loudnessNormalization,
    bool? isBypassed,
    double? minDecibels,
    double? maxDecibels,
  }) {
    return EqualizerState(
      enabled: enabled ?? this.enabled,
      currentPreset: currentPreset ?? this.currentPreset,
      bandGains: bandGains ?? this.bandGains,
      bandFrequencies: bandFrequencies ?? this.bandFrequencies,
      bassBoost: bassBoost ?? this.bassBoost,
      loudnessGain: loudnessGain ?? this.loudnessGain,
      loudnessNormalization:
          loudnessNormalization ?? this.loudnessNormalization,
      isBypassed: isBypassed ?? this.isBypassed,
      minDecibels: minDecibels ?? this.minDecibels,
      maxDecibels: maxDecibels ?? this.maxDecibels,
    );
  }
}
