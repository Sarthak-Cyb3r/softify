import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/providers/settings_providers.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';
import '../../presentation/widgets/shared/app_network_image.dart';

/// Diagnostics data model that parses and formats real-time stream parameters.
class AudioStreamDiagnostics {
  final String qualityLevel;
  final String qualityLevelShort;
  final String badgeText;
  final String codec;
  final String container;
  final String codecContainerDisplay;
  final String sampleRate;
  final String sampleRateDetail;
  final String sourceType;
  final String sourceDetail;
  final String channel;
  final String channelDetail;
  final int bitrateKbps;
  final String providerName;
  final Color badgeColor;
  final bool isLossless;
  final bool isHiRes;

  const AudioStreamDiagnostics({
    required this.qualityLevel,
    required this.qualityLevelShort,
    required this.badgeText,
    required this.codec,
    required this.container,
    required this.codecContainerDisplay,
    required this.sampleRate,
    required this.sampleRateDetail,
    required this.sourceType,
    required this.sourceDetail,
    required this.channel,
    required this.channelDetail,
    required this.bitrateKbps,
    required this.providerName,
    required this.badgeColor,
    required this.isLossless,
    required this.isHiRes,
  });

  factory AudioStreamDiagnostics.from({
    Track? track,
    StreamInfo? streamInfo,
    AudioQualityPreset qualityPreset = AudioQualityPreset.standard,
    Color accentColor = const Color(0xFFED5564),
  }) {
    // 1. Determine Source Type
    final String sourceType;
    final String sourceDetail;
    final isLocal = track != null &&
        (track.id.startsWith('local_') ||
            streamInfo?.providerName == 'local_audio' ||
            streamInfo?.url.scheme == 'file');
    final isCached = streamInfo?.providerName == 'offline_cached' ||
        streamInfo?.url.scheme == 'cache';

    if (isLocal) {
      sourceType = 'Local File';
      sourceDetail = 'Device Storage';
    } else if (isCached) {
      sourceType = 'Cached';
      sourceDetail = 'Offline Local Cache';
    } else {
      sourceType = 'Streamed';
      sourceDetail = 'Live CDN Stream';
    }

    // 2. Parse Codec & Container
    String rawCodec = streamInfo?.codec.toLowerCase() ?? '';
    String rawContainer = streamInfo?.container.toLowerCase() ?? '';

    String codec;
    if (rawCodec.contains('flac')) {
      codec = 'FLAC';
    } else if (rawCodec.contains('opus')) {
      codec = 'Opus';
    } else if (rawCodec.contains('mp4a') || rawCodec.contains('aac')) {
      codec = 'AAC';
    } else if (rawCodec.contains('mp3')) {
      codec = 'MP3';
    } else {
      if (rawCodec.isNotEmpty) {
        codec = streamInfo!.codec.toUpperCase();
      } else {
        codec = qualityPreset == AudioQualityPreset.low ? 'Opus' : 'AAC';
      }
    }

    String container;
    if (rawContainer.contains('flac')) {
      container = 'FLAC';
    } else if (rawContainer.contains('webm')) {
      container = 'WebM';
    } else if (rawContainer.contains('m4a')) {
      container = 'M4A';
    } else if (rawContainer.contains('mp4')) {
      container = 'MP4';
    } else if (rawContainer.contains('mp3')) {
      container = 'MP3';
    } else {
      if (rawContainer.isNotEmpty) {
        container = streamInfo!.container.toUpperCase();
      } else {
        container = qualityPreset == AudioQualityPreset.low ? 'WebM' : 'M4A';
      }
    }

    // 3. Bitrate estimation
    final int bitrateKbps;
    if (streamInfo != null && streamInfo.bitrate > 0) {
      bitrateKbps = streamInfo.bitrate ~/ 1000;
    } else {
      switch (qualityPreset) {
        case AudioQualityPreset.high:
          bitrateKbps = 320;
          break;
        case AudioQualityPreset.standard:
          bitrateKbps = 128;
          break;
        case AudioQualityPreset.low:
          bitrateKbps = 64;
          break;
      }
    }

    // 4. Quality Level & Badge Color
    final bool isLossless =
        codec == 'FLAC' || container == 'FLAC' || bitrateKbps >= 1000;
    final String qualityLevel;
    final String qualityLevelShort;
    final String badgeText;
    final Color badgeColor;
    final bool isHiRes;

    if (isLossless) {
      qualityLevel = 'Lossless (FLAC)';
      qualityLevelShort = 'Lossless';
      badgeText = 'LOSSLESS';
      badgeColor = const Color(0xFFD4AF37); // Studio Master Gold
      isHiRes = true;
    } else if (bitrateKbps >= 300 || qualityPreset == AudioQualityPreset.high) {
      qualityLevel = 'High (320kbps)';
      qualityLevelShort = 'High Quality';
      badgeText = 'HQ';
      badgeColor = accentColor;
      isHiRes = true;
    } else if (bitrateKbps >= 100 || qualityPreset == AudioQualityPreset.standard) {
      qualityLevel = 'Standard (128kbps)';
      qualityLevelShort = 'Standard';
      badgeText = 'STANDARD';
      badgeColor = const Color(0xFF60A5FA); // Cyan / Blue
      isHiRes = false;
    } else {
      qualityLevel = 'Standard (128kbps)';
      qualityLevelShort = 'Data Saver';
      badgeText = 'SAVER';
      badgeColor = const Color(0xFF938F99);
      isHiRes = false;
    }

    // 5. Estimated Sample Rate: 44.1 kHz / 48 kHz
    final String sampleRate;
    final String sampleRateDetail;
    if (codec == 'Opus' || container == 'WebM') {
      sampleRate = '48 kHz';
      sampleRateDetail = '48.0 kHz (Opus Studio HD)';
    } else {
      sampleRate = '44.1 kHz';
      sampleRateDetail = '44.1 kHz (CD Standard Fidelity)';
    }

    // 6. Audio Channel
    const channel = 'Stereo 2.0';
    const channelDetail = '2 Channels (L/R) • 32-bit Float Pipeline';

    // 7. Stream Provider Name
    final String provider;
    if (streamInfo != null && streamInfo.providerName.isNotEmpty) {
      final p = streamInfo.providerName.toLowerCase();
      if (p.contains('saavn')) {
        provider = 'JioSaavn Studio CDN Master';
      } else if (p.contains('youtube') || p.contains('explode')) {
        provider = 'YouTube Music Audio Stream';
      } else if (p.contains('piped')) {
        provider = 'Piped High-Fidelity API';
      } else if (p.contains('local')) {
        provider = 'Local File System Storage';
      } else if (p.contains('offline') || p.contains('cached')) {
        provider = 'Offline Local Storage Cache';
      } else {
        provider = streamInfo.providerName;
      }
    } else if (isLocal) {
      provider = 'Local Audio Storage';
    } else {
      provider = 'Softify JIT Audio Stream Engine';
    }

    final codecContainerDisplay =
        codec == container ? codec : '$codec / $container';

    return AudioStreamDiagnostics(
      qualityLevel: qualityLevel,
      qualityLevelShort: qualityLevelShort,
      badgeText: badgeText,
      codec: codec,
      container: container,
      codecContainerDisplay: codecContainerDisplay,
      sampleRate: sampleRate,
      sampleRateDetail: sampleRateDetail,
      sourceType: sourceType,
      sourceDetail: sourceDetail,
      channel: channel,
      channelDetail: channelDetail,
      bitrateKbps: bitrateKbps,
      providerName: provider,
      badgeColor: badgeColor,
      isLossless: isLossless,
      isHiRes: isHiRes,
    );
  }
}

/// Interactive micro-badge widget that can be placed in player headers or toolbars.
/// Tapping it launches [AudioQualityDetailDialog].
class AudioQualityBadge extends ConsumerWidget {
  final Track? track;
  final StreamInfo? streamInfo;
  final bool compact;
  final VoidCallback? onTap;

  const AudioQualityBadge({
    super.key,
    this.track,
    this.streamInfo,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final currentTrack = track ?? ref.watch(currentTrackProvider).value;
    final currentStream = streamInfo ?? ref.watch(currentStreamInfoProvider).value;
    final preset = ref.watch(audioQualityPresetProvider);

    final diagnostics = AudioStreamDiagnostics.from(
      track: currentTrack,
      streamInfo: currentStream,
      qualityPreset: preset,
      accentColor: tokens.accent,
    );

    return BouncingScaleButton(
      scaleFactor: 0.94,
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          AudioQualityDetailDialog.show(
            context,
            track: currentTrack,
            streamInfo: currentStream,
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: diagnostics.badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(tokens.radiusFull),
          border: Border.all(
            color: diagnostics.badgeColor.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: diagnostics.badgeColor,
                boxShadow: diagnostics.isHiRes
                    ? [
                        BoxShadow(
                          color: diagnostics.badgeColor.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              diagnostics.badgeText,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: compact ? 9.5 : 11.0,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: diagnostics.badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alias for [AudioQualityBadge] for explicit QoL module naming.
typedef AudioQualityBadgeDetail = AudioQualityBadge;

/// Audio Quality & Stream Format Inspector Dialog.
/// Triggered by tapping the audio quality badge ("HQ", "Lossless", etc.).
/// Displays detailed live stream stats, an audiophile badges explanation guide,
/// and a button to jump directly to Audio Quality Settings.
class AudioQualityDetailDialog extends ConsumerStatefulWidget {
  final Track? track;
  final StreamInfo? streamInfo;

  const AudioQualityDetailDialog({
    super.key,
    this.track,
    this.streamInfo,
  });

  /// Displays the [AudioQualityDetailDialog] modally.
  static Future<void> show(
    BuildContext context, {
    Track? track,
    StreamInfo? streamInfo,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => AudioQualityDetailDialog(
        track: track,
        streamInfo: streamInfo,
      ),
    );
  }

  @override
  ConsumerState<AudioQualityDetailDialog> createState() =>
      _AudioQualityDetailDialogState();
}

class _AudioQualityDetailDialogState
    extends ConsumerState<AudioQualityDetailDialog> {
  bool _showBadgesGuide = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentTrack = widget.track ?? ref.watch(currentTrackProvider).value;
    final currentStream =
        widget.streamInfo ?? ref.watch(currentStreamInfoProvider).value;
    final activePreset = ref.watch(audioQualityPresetProvider);

    final diagnostics = AudioStreamDiagnostics.from(
      track: currentTrack,
      streamInfo: currentStream,
      qualityPreset: activePreset,
      accentColor: tokens.accent,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: const Color(0xFF141619),
            borderRadius: BorderRadius.circular(tokens.radiusXl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 36,
                spreadRadius: 6,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusXl),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Bar with Inspector Title & Dismiss
                  _buildHeader(context, diagnostics),
                  const SizedBox(height: 16),

                  // 2. Currently Playing Track Micro-Card (if track available)
                  if (currentTrack != null) ...[
                    _buildTrackCard(currentTrack, diagnostics),
                    const SizedBox(height: 16),
                  ],

                  // 3. Formatted Stream Info Matrix
                  _buildSectionLabel('STREAM FORMAT & DIAGNOSTICS'),
                  const SizedBox(height: 8),
                  _buildDiagnosticsCard(diagnostics),
                  const SizedBox(height: 16),

                  // 4. Quick Quality Preset Switcher
                  _buildSectionLabel('STREAMING FIDELITY PRESET'),
                  const SizedBox(height: 8),
                  _buildPresetSwitcher(activePreset),
                  const SizedBox(height: 16),

                  // 5. Audiophile Badges Explanation Guide
                  _buildBadgesGuideSection(diagnostics),
                  const SizedBox(height: 20),

                  // 6. Action Button: Jump to Audio Quality Settings
                  _buildSettingsButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, AudioStreamDiagnostics diagnostics) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: diagnostics.badgeColor.withValues(alpha: 0.15),
            border: Border.all(
              color: diagnostics.badgeColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: diagnostics.badgeColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stream Format Inspector',
                style: TextStyle(
                  fontFamily: AppTheme.fontPageTitle,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Real-time DAC pipeline & stream telemetry',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          color: Colors.white60,
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTrackCard(Track track, AudioStreamDiagnostics diagnostics) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppNetworkImage(
              imageUrl: track.coverUrl,
              width: 42,
              height: 42,
              fallbackIcon: Icons.music_note_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Active Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: diagnostics.badgeColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: diagnostics.badgeColor.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: diagnostics.badgeColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  diagnostics.badgeText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: diagnostics.badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.fontUi,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildDiagnosticsCard(AudioStreamDiagnostics d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // 1. Audio Quality Level
          _buildDiagRow(
            icon: Icons.speed_rounded,
            label: 'Audio Quality Level',
            value: d.qualityLevel,
            valueColor: d.badgeColor,
            isMonospace: true,
          ),
          const Divider(color: Colors.white10, height: 16),

          // 2. Codec / Container
          _buildDiagRow(
            icon: Icons.layers_outlined,
            label: 'Codec / Container',
            value: d.codecContainerDisplay,
            valueColor: Colors.white,
            isMonospace: true,
          ),
          const Divider(color: Colors.white10, height: 16),

          // 3. Estimated Sample Rate
          _buildDiagRow(
            icon: Icons.waves_rounded,
            label: 'Estimated Sample Rate',
            value: d.sampleRateDetail,
            valueColor: Colors.white,
            isMonospace: true,
          ),
          const Divider(color: Colors.white10, height: 16),

          // 4. Source Type
          _buildDiagRow(
            icon: d.sourceType == 'Local File'
                ? Icons.folder_outlined
                : (d.sourceType == 'Cached'
                    ? Icons.offline_pin_outlined
                    : Icons.cloud_outlined),
            label: 'Source Type',
            value: '${d.sourceType} (${d.sourceDetail})',
            valueColor: d.sourceType == 'Local File'
                ? const Color(0xFF60A5FA)
                : (d.sourceType == 'Cached'
                    ? const Color(0xFF34D399)
                    : Colors.white),
          ),
          const Divider(color: Colors.white10, height: 16),

          // 5. Audio Channel
          _buildDiagRow(
            icon: Icons.headphones_outlined,
            label: 'Audio Channel',
            value: d.channel,
            valueColor: Colors.white,
            subtitle: d.channelDetail,
          ),
          const Divider(color: Colors.white10, height: 16),

          // 6. Provider & Stream Engine
          _buildDiagRow(
            icon: Icons.dns_outlined,
            label: 'Audio Stream Provider',
            value: d.providerName,
            valueColor: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    String? subtitle,
    bool isMonospace = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: Colors.white38),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E959E),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: isMonospace ? 'monospace' : AppTheme.fontUi,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetSwitcher(AudioQualityPreset activePreset) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          _buildPresetButton(
            title: 'Data Saver',
            sub: '64 kbps',
            isSelected: activePreset == AudioQualityPreset.low,
            onTap: () {
              HapticFeedback.selectionClick();
              ref
                  .read(audioQualityPresetProvider.notifier)
                  .setQuality(AudioQualityPreset.low);
            },
          ),
          _buildPresetButton(
            title: 'Standard',
            sub: '128 kbps',
            isSelected: activePreset == AudioQualityPreset.standard,
            onTap: () {
              HapticFeedback.selectionClick();
              ref
                  .read(audioQualityPresetProvider.notifier)
                  .setQuality(AudioQualityPreset.standard);
            },
          ),
          _buildPresetButton(
            title: 'High Quality',
            sub: '320 kbps',
            isSelected: activePreset == AudioQualityPreset.high,
            onTap: () {
              HapticFeedback.selectionClick();
              ref
                  .read(audioQualityPresetProvider.notifier)
                  .setQuality(AudioQualityPreset.high);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String title,
    required String sub,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accent.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? tokens.accent.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: isSelected ? tokens.accent : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesGuideSection(AudioStreamDiagnostics current) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // Collapsible Header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _showBadgesGuide = !_showBadgesGuide;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Audiophile Badges Explanation',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    _showBadgesGuide
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.white60,
                  ),
                ],
              ),
            ),
          ),

          if (_showBadgesGuide) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  _buildBadgeExplanationRow(
                    badge: 'LOSSLESS',
                    badgeColor: const Color(0xFFD4AF37),
                    title: 'Lossless (FLAC • ~1,411 kbps)',
                    desc:
                        'Bit-perfect studio audio. Preserves dynamic range without psychoacoustic compression.',
                  ),
                  const SizedBox(height: 10),
                  _buildBadgeExplanationRow(
                    badge: 'HQ',
                    badgeColor: const Color(0xFF1DB954),
                    title: 'High Quality (320 kbps AAC / Opus)',
                    desc:
                        'Studio-grade acoustic transparency with crisp high frequencies up to 20 kHz.',
                  ),
                  const SizedBox(height: 10),
                  _buildBadgeExplanationRow(
                    badge: 'STANDARD',
                    badgeColor: const Color(0xFF60A5FA),
                    title: 'Standard (128 kbps AAC)',
                    desc:
                        'Balanced fidelity engineered for rapid buffering and optimized data usage.',
                  ),
                  const SizedBox(height: 10),
                  _buildBadgeExplanationRow(
                    badge: 'SAVER',
                    badgeColor: const Color(0xFF938F99),
                    title: 'Data Saver (64 kbps Opus)',
                    desc:
                        'Resilient low-bandwidth audio optimized for metered mobile networks.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgeExplanationRow({
    required String badge,
    required Color badgeColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              badge,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    final tokens = context.tokens;
    return BouncingScaleButton(
      scaleFactor: 0.96,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: tokens.accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: tokens.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Audio Quality Settings',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
