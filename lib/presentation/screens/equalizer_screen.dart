// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/equalizer_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/equalizer_curve_visualizer.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Equalizer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            Text(
              'Acoustic Profile • Softify Smart EQ 2.0',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.surfaceHighlight, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Active Output: Softify Smart EQ 2.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.refresh, color: tokens.textSecondary),
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
            activeColor: tokens.accent,
            onChanged: (val) => eqNotifier.setEnabled(val),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 800;
                  if (isDesktop) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          children: [
                            _buildPresetsCarousel(tokens, eqState, eqNotifier),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Visualizer & Studio Master
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      EqualizerCurveVisualizer(
                                        bandGains: eqState.bandGains,
                                        bandFrequencies: eqState.bandFrequencies,
                                        bassBoost: eqState.bassBoost,
                                        isEnabled: eqState.enabled,
                                        isBypassed: eqState.isBypassed,
                                        minDecibels: eqState.minDecibels,
                                        maxDecibels: eqState.maxDecibels,
                                        accentColor: tokens.accent,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildStudioMasterCard(tokens),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Right Column: Enhancers
                                Expanded(
                                  flex: 6,
                                  child: _buildEnhancersCard(context, ref, tokens, eqState, eqNotifier),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Full width: 10-Band Sliders Console
                            _buildBandsCard(context, ref, tokens, eqState, eqNotifier),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  }

                  // Mobile Layout
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      EqualizerCurveVisualizer(
                        bandGains: eqState.bandGains,
                        bandFrequencies: eqState.bandFrequencies,
                        bassBoost: eqState.bassBoost,
                        isEnabled: eqState.enabled,
                        isBypassed: eqState.isBypassed,
                        minDecibels: eqState.minDecibels,
                        maxDecibels: eqState.maxDecibels,
                        accentColor: tokens.accent,
                      ),
                      const SizedBox(height: 16),
                      _buildPresetsCarousel(tokens, eqState, eqNotifier),
                      const SizedBox(height: 20),
                      _buildBandsCard(context, ref, tokens, eqState, eqNotifier),
                      const SizedBox(height: 16),
                      _buildEnhancersCard(context, ref, tokens, eqState, eqNotifier),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),

            // Instant A/B Compare Audition Bar
            _buildAbCompareBar(context, tokens, eqState, eqNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsCarousel(
    AppTokens tokens,
    EqualizerState eqState,
    EqualizerNotifier eqNotifier,
  ) {
    return SizedBox(
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
            selectedColor: tokens.accent,
            backgroundColor: tokens.surfaceElevated,
            labelStyle: TextStyle(
              color: isSelected
                  ? const Color(0xFF080F11)
                  : (eqState.enabled
                      ? tokens.textPrimary
                      : tokens.textSecondary),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? tokens.accent
                    : tokens.surfaceHighlight,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudioMasterCard(AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.surfaceHighlight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.surfaceHighlight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: tokens.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spatial Engine 24-BIT 96k',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            'Studio Master Pipeline Active',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.surfaceHighlight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HI-RES',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: tokens.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Direct bit-perfect streaming through OpenSL ES / ALSA audio pipelines with sub-1ms buffer jitter and zero resampling distortion.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandsCard(
    BuildContext context,
    WidgetRef ref,
    AppTokens tokens,
    EqualizerState eqState,
    EqualizerNotifier eqNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.surfaceHighlight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Frequency Bands',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Double-tap band to reset',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bandCount = eqState.bandGains.length;
                // If width is at least 38px per band, distribute directly via Expanded row
                final bool canFitDirectly = constraints.maxWidth >= (bandCount * 38);

                if (canFitDirectly) {
                  return Row(
                    children: [
                      for (int i = 0; i < bandCount; i++)
                        Expanded(
                          child: _buildVerticalBand(
                            tokens: tokens,
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
                        ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (int i = 0; i < bandCount; i++)
                        SizedBox(
                          width: 48,
                          child: _buildVerticalBand(
                            tokens: tokens,
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
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalBand({
    required AppTokens tokens,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            // Gain Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isBoosted && isEnabled
                    ? tokens.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                style: TextStyle(
                  color: !isEnabled
                      ? tokens.textSecondary
                      : isBoosted
                          ? tokens.accent
                          : (isCut ? tokens.textSecondary : tokens.textPrimary),
                  fontSize: 10.5,
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
                        ? tokens.accent
                        : tokens.textSecondary,
                    inactiveTrackColor: tokens.surfaceHighlight,
                    thumbColor: isEnabled ? tokens.accent : tokens.textSecondary,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                      elevation: 2,
                    ),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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
                color: isEnabled ? tokens.textSecondary : tokens.textSecondary.withValues(alpha: 0.6),
                fontSize: 10.5,
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
    AppTokens tokens,
    EqualizerState eqState,
    EqualizerNotifier eqNotifier,
  ) {
    final bool active = eqState.enabled && !eqState.isBypassed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.surfaceHighlight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Enhancers',
            style: TextStyle(
              color: tokens.textPrimary,
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
                    ? tokens.accent
                    : tokens.textSecondary,
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
                        Text(
                          'Bass Boost',
                          style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '+${(eqState.bassBoost * 5.0).toStringAsFixed(1)} dB (${(eqState.bassBoost * 100).round()}%)',
                          style: TextStyle(
                            color: active && eqState.bassBoost > 0
                                ? tokens.accent
                                : tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: active ? tokens.accent : tokens.textSecondary,
                        inactiveTrackColor: tokens.surfaceHighlight,
                        thumbColor: active ? tokens.accent : tokens.textSecondary,
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
                    ? tokens.accent
                    : tokens.textSecondary,
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
                        Text(
                          'Loudness Maximizer',
                          style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '+${(eqState.loudnessGain * 10.0).toStringAsFixed(1)} dB (${(eqState.loudnessGain * 100).round()}%)',
                          style: TextStyle(
                            color: active && eqState.loudnessGain > 0
                                ? tokens.accent
                                : tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: active ? tokens.accent : tokens.textSecondary,
                        inactiveTrackColor: tokens.surfaceHighlight,
                        thumbColor: active ? tokens.accent : tokens.textSecondary,
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

          const SizedBox(height: 12),
          Divider(color: tokens.surfaceHighlight, height: 1),
          const SizedBox(height: 8),

          // Loudness Normalization (EBU R128 / ReplayGain)
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                color: active && eqState.loudnessNormalization
                    ? tokens.accent
                    : tokens.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loudness Normalization (EBU R128)',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Balances playback volume across tracks to eliminate sudden jumps',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: eqState.loudnessNormalization,
                activeColor: tokens.accent,
                activeTrackColor: tokens.accent.withValues(alpha: 0.3),
                inactiveThumbColor: tokens.textSecondary,
                inactiveTrackColor: tokens.surfaceHighlight,
                onChanged: active
                    ? (v) => eqNotifier.toggleLoudnessNormalization(v)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbCompareBar(
    BuildContext context,
    AppTokens tokens,
    EqualizerState eqState,
    EqualizerNotifier eqNotifier,
  ) {
    final bool canCompare = eqState.enabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(
          top: BorderSide(color: tokens.surfaceHighlight, width: 1),
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
                ? tokens.accent.withValues(alpha: 0.25)
                : tokens.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: eqState.isBypassed
                  ? tokens.accent
                  : tokens.surfaceHighlight,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                eqState.isBypassed ? Icons.volume_off : Icons.compare_arrows,
                color: eqState.isBypassed ? tokens.accent : (canCompare ? tokens.textPrimary : tokens.textSecondary),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                eqState.isBypassed
                    ? 'Auditioning Raw Original (Flat)'
                    : 'Hold to A/B Audition Original Sound',
                style: TextStyle(
                  color: eqState.isBypassed
                      ? tokens.accent
                      : (canCompare ? tokens.textPrimary : tokens.textSecondary),
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
