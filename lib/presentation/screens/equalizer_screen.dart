// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/equalizer_preset.dart';
import '../providers/equalizer_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/equalizer_curve_visualizer.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            tooltip: 'Reset to Flat',
            onPressed: () {
              eqNotifier.resetToFlat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Equalizer reset to Flat'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          Switch(
            value: eqState.enabled,
            activeColor: AppTheme.primary,
            onChanged: (val) => eqNotifier.setEnabled(val),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // 1. Interactive Spline Curve Visualizer
                  EqualizerCurveVisualizer(
                    bandGains: eqState.bandGains,
                    bandFrequencies: eqState.bandFrequencies,
                    bassBoost: eqState.bassBoost,
                    isEnabled: eqState.enabled,
                    isBypassed: eqState.isBypassed,
                    minDecibels: eqState.minDecibels,
                    maxDecibels: eqState.maxDecibels,
                  ),

                  const SizedBox(height: 20),

                  // 2. Presets Selector Carousel
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: EqualizerPreset.defaultPresets.length +
                          (eqState.currentPreset == 'Custom' ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isCustom = index == EqualizerPreset.defaultPresets.length;
                        final name = isCustom
                            ? 'Custom'
                            : EqualizerPreset.defaultPresets[index].name;
                        final isSelected = eqState.currentPreset == name;

                        return ChoiceChip(
                          label: Text(name),
                          selected: isSelected,
                          onSelected: eqState.enabled
                              ? (selected) {
                                  if (selected && !isCustom) {
                                    eqNotifier.selectPreset(name);
                                  }
                                }
                              : null,
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceElevated,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : (eqState.enabled
                                    ? Colors.white
                                    : AppTheme.textMuted),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.surfaceHighlight,
                              width: 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Multi-band Sliders Card
                  _buildBandsCard(context, ref, eqState, eqNotifier),

                  const SizedBox(height: 20),

                  // 4. Sound Enhancers: Bass Boost & Loudness Maximizer
                  _buildEnhancersCard(context, ref, eqState, eqNotifier),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 5. Instant A/B Compare Audition Bar
            _buildAbCompareBar(context, eqState, eqNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildBandsCard(
    BuildContext context,
    WidgetRef ref,
    EqualizerState eqState,
    EqualizerNotifier eqNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Frequency Bands',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Double-tap band to reset',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < eqState.bandGains.length; i++)
                  _buildVerticalBand(
                    index: i,
                    gain: eqState.bandGains[i],
                    freq: i < eqState.bandFrequencies.length
                        ? eqState.bandFrequencies[i]
                        : 0.0,
                    isEnabled: eqState.enabled && !eqState.isBypassed,
                    minDb: eqState.minDecibels,
                    maxDb: eqState.maxDecibels,
                    onChanged: (newGain) => eqNotifier.setBandGain(i, newGain),
                    onReset: () => eqNotifier.setBandGain(i, 0.0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalBand({
    required int index,
    required double gain,
    required double freq,
    required bool isEnabled,
    required double minDb,
    required double maxDb,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    final bool isBoosted = gain > 0.05;
    final bool isCut = gain < -0.05;

    return GestureDetector(
      onDoubleTap: isEnabled ? onReset : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            // Gain Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isBoosted && isEnabled
                    ? AppTheme.primary.withOpacity(0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                style: TextStyle(
                  color: !isEnabled
                      ? AppTheme.textMuted
                      : isBoosted
                          ? AppTheme.primary
                          : (isCut ? AppTheme.textSecondary : Colors.white),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Vertical Slider
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3.5,
                    activeTrackColor: isEnabled
                        ? (isBoosted ? AppTheme.primary : AppTheme.primaryLight)
                        : AppTheme.textMuted,
                    inactiveTrackColor: AppTheme.surfaceHighlight,
                    thumbColor: isEnabled ? AppTheme.primary : AppTheme.textMuted,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                      elevation: 2,
                    ),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: gain.clamp(minDb, maxDb),
                    min: minDb,
                    max: maxDb,
                    onChanged: isEnabled ? onChanged : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Frequency Label
            Text(
              _formatFreq(freq),
              style: TextStyle(
                color: isEnabled ? AppTheme.textSecondary : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancersCard(
    BuildContext context,
    WidgetRef ref,
    EqualizerState eqState,
    EqualizerNotifier eqNotifier,
  ) {
    final bool active = eqState.enabled && !eqState.isBypassed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Enhancers',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),

          // Bass Boost Slider
          Row(
            children: [
              Icon(
                Icons.surround_sound,
                color: active && eqState.bassBoost > 0
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bass Boost',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '+${(eqState.bassBoost * 5.0).toStringAsFixed(1)} dB (${(eqState.bassBoost * 100).round()}%)',
                          style: TextStyle(
                            color: active && eqState.bassBoost > 0
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: active ? AppTheme.primary : AppTheme.textMuted,
                        inactiveTrackColor: AppTheme.surfaceHighlight,
                        thumbColor: active ? AppTheme.primary : AppTheme.textMuted,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: eqState.bassBoost,
                        min: 0.0,
                        max: 1.0,
                        onChanged: active ? (v) => eqNotifier.setBassBoost(v) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Loudness Enhancer / Headroom Maximizer
          Row(
            children: [
              Icon(
                Icons.equalizer,
                color: active && eqState.loudnessGain > 0
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Loudness Maximizer',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '+${(eqState.loudnessGain * 10.0).toStringAsFixed(1)} dB (${(eqState.loudnessGain * 100).round()}%)',
                          style: TextStyle(
                            color: active && eqState.loudnessGain > 0
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: active ? AppTheme.primary : AppTheme.textMuted,
                        inactiveTrackColor: AppTheme.surfaceHighlight,
                        thumbColor: active ? AppTheme.primary : AppTheme.textMuted,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: eqState.loudnessGain,
                        min: 0.0,
                        max: 1.0,
                        onChanged: active ? (v) => eqNotifier.setLoudnessGain(v) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbCompareBar(
    BuildContext context,
    EqualizerState eqState,
    EqualizerNotifier eqNotifier,
  ) {
    final bool canCompare = eqState.enabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.surfaceHighlight, width: 1),
        ),
      ),
      child: GestureDetector(
        onTapDown: canCompare ? (_) => eqNotifier.setBypass(true) : null,
        onTapUp: canCompare ? (_) => eqNotifier.setBypass(false) : null,
        onTapCancel: canCompare ? () => eqNotifier.setBypass(false) : null,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: eqState.isBypassed
                ? Colors.amber.withOpacity(0.25)
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: eqState.isBypassed
                  ? Colors.amber
                  : AppTheme.surfaceHighlight,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                eqState.isBypassed ? Icons.volume_off : Icons.compare_arrows,
                color: eqState.isBypassed ? Colors.amber : (canCompare ? Colors.white : AppTheme.textMuted),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                eqState.isBypassed
                    ? 'Auditioning Raw Original (Flat)'
                    : 'Hold to A/B Audition Original Sound',
                style: TextStyle(
                  color: eqState.isBypassed
                      ? Colors.amber
                      : (canCompare ? Colors.white : AppTheme.textMuted),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFreq(double hz) {
    if (hz >= 1000) {
      final khz = hz / 1000;
      return khz == khz.roundToDouble()
          ? '${khz.toInt()}kHz'
          : '${khz.toStringAsFixed(1)}kHz';
    }
    return '${hz.round()}Hz';
  }
}
