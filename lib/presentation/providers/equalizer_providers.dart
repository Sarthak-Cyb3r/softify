import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/player/softify_audio_handler.dart';
import '../../domain/entities/equalizer_preset.dart';
import 'player_providers.dart';

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
  final db = ref.watch(databaseProvider);
  final audioHandler = ref.watch(audioHandlerProvider);
  return EqualizerNotifier(db: db, audioHandler: audioHandler);
});

class EqualizerNotifier extends StateNotifier<EqualizerState> {
  final AppDatabase _db;
  final SoftifyAudioHandler _audioHandler;

  EqualizerNotifier({
    required AppDatabase db,
    required SoftifyAudioHandler audioHandler,
  })  : _db = db,
        _audioHandler = audioHandler,
        super(const EqualizerState()) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final rows = await (_db.select(_db.settings)
            ..where((t) => t.key.like('equalizer_%')))
          .get();

      final map = {for (final r in rows) r.key: r.value};

      final enabled = map['equalizer_enabled'] != 'false';
      final preset = map['equalizer_preset'] ?? 'Flat';
      final bassBoost = double.tryParse(map['equalizer_bass_boost'] ?? '') ?? 0.0;
      final loudnessGain = double.tryParse(map['equalizer_loudness'] ?? '') ?? 0.0;

      List<double> gains = const [0.0, 0.0, 0.0, 0.0, 0.0];
      if (map.containsKey('equalizer_gains')) {
        try {
          final decoded = jsonDecode(map['equalizer_gains']!) as List;
          gains = decoded.map((e) => (e as num).toDouble()).toList();
          if (gains.length < 5) {
            gains = [...gains, ...List.filled(5 - gains.length, 0.0)];
          }
        } catch (_) {}
      }

      final freqs = await _audioHandler.getBandFrequencies();

      state = state.copyWith(
        enabled: enabled,
        currentPreset: preset,
        bandGains: gains,
        bandFrequencies: freqs.isNotEmpty ? freqs : state.bandFrequencies,
        bassBoost: bassBoost,
        loudnessGain: loudnessGain,
      );

      // Apply initial state to hardware DSP
      await _audioHandler.setEqualizerEnabled(enabled);
      await _audioHandler.setEqualizerBands(gains);
      await _audioHandler.setBassBoost(bassBoost);
      await _audioHandler.setLoudnessEnhancerGain(loudnessGain);
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _audioHandler.setEqualizerEnabled(enabled);
    await _saveSetting('equalizer_enabled', enabled.toString());
  }

  Future<void> selectPreset(String presetName) async {
    final preset = EqualizerPreset.defaultPresets.firstWhere(
      (p) => p.name == presetName,
      orElse: () => const EqualizerPreset(name: 'Flat', gains: [0.0, 0.0, 0.0, 0.0, 0.0]),
    );

    state = state.copyWith(
      currentPreset: presetName,
      bandGains: List.from(preset.gains),
    );

    if (state.enabled && !state.isBypassed) {
      await _audioHandler.setEqualizerBands(preset.gains);
    }

    await _saveSetting('equalizer_preset', presetName);
    await _saveSetting('equalizer_gains', jsonEncode(preset.gains));
  }

  Future<void> setBandGain(int bandIndex, double gain) async {
    if (bandIndex < 0 || bandIndex >= state.bandGains.length) return;

    final clamped = gain.clamp(state.minDecibels, state.maxDecibels);
    final updatedGains = List<double>.from(state.bandGains);
    updatedGains[bandIndex] = double.parse(clamped.toStringAsFixed(1));

    // Check if matching any default preset
    String activePreset = 'Custom';
    for (final p in EqualizerPreset.defaultPresets) {
      bool matches = true;
      for (int i = 0; i < p.gains.length; i++) {
        if ((p.gains[i] - updatedGains[i]).abs() > 0.05) {
          matches = false;
          break;
        }
      }
      if (matches) {
        activePreset = p.name;
        break;
      }
    }

    state = state.copyWith(
      bandGains: updatedGains,
      currentPreset: activePreset,
    );

    if (state.enabled && !state.isBypassed) {
      await _audioHandler.setEqualizerBands(updatedGains);
    }

    await _saveSetting('equalizer_gains', jsonEncode(updatedGains));
    await _saveSetting('equalizer_preset', activePreset);
  }

  Future<void> setBassBoost(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(bassBoost: clamped);
    if (state.enabled && !state.isBypassed) {
      await _audioHandler.setBassBoost(clamped);
    }
    await _saveSetting('equalizer_bass_boost', clamped.toString());
  }

  Future<void> setLoudnessGain(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(loudnessGain: clamped);
    if (state.enabled && !state.isBypassed) {
      await _audioHandler.setLoudnessEnhancerGain(clamped);
    }
    await _saveSetting('equalizer_loudness', clamped.toString());
  }

  Future<void> setBypass(bool bypassed) async {
    state = state.copyWith(isBypassed: bypassed);
    if (bypassed) {
      // Temporarily bypass all processing
      await _audioHandler.setEqualizerEnabled(false);
      await _audioHandler.setLoudnessEnhancerGain(0.0);
    } else {
      // Re-enable and restore user's tuned DSP settings
      await _audioHandler.setEqualizerEnabled(state.enabled);
      await _audioHandler.setEqualizerBands(state.bandGains);
      await _audioHandler.setBassBoost(state.bassBoost);
      await _audioHandler.setLoudnessEnhancerGain(state.loudnessGain);
    }
  }

  Future<void> resetToFlat() async {
    const flatGains = [0.0, 0.0, 0.0, 0.0, 0.0];
    state = state.copyWith(
      currentPreset: 'Flat',
      bandGains: flatGains,
      bassBoost: 0.0,
      loudnessGain: 0.0,
      isBypassed: false,
    );

    if (state.enabled) {
      await _audioHandler.setEqualizerBands(flatGains);
      await _audioHandler.setBassBoost(0.0);
      await _audioHandler.setLoudnessEnhancerGain(0.0);
    }

    await _saveSetting('equalizer_preset', 'Flat');
    await _saveSetting('equalizer_gains', jsonEncode(flatGains));
    await _saveSetting('equalizer_bass_boost', '0.0');
    await _saveSetting('equalizer_loudness', '0.0');
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: key, value: value),
          );
    } catch (_) {}
  }
}
