import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/audio_quality_preset.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/providers/settings_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// Enums: StreamHealthStatus
// ============================================================================

/// Represents the health status of an active audio stream buffer and network connection.
enum StreamHealthStatus {
  /// Optimal health: buffer ahead is ample (>= 15s) and latency is low (< 200ms).
  green,

  /// Warning status: buffer ahead is moderate (5s - 14s) or latency is elevated (200ms - 400ms).
  yellow,

  /// Critical status: buffer ahead is critically low (< 5s), stream is stalling, or connection degraded.
  red;

  /// Status indicator primary color.
  Color get color {
    switch (this) {
      case StreamHealthStatus.green:
        return const Color(0xFF22C55E); // Green / Emerald
      case StreamHealthStatus.yellow:
        return const Color(0xFFEAB308); // Yellow / Amber
      case StreamHealthStatus.red:
        return const Color(0xFFEF4444); // Red
    }
  }

  /// Human-readable label for the status.
  String get label {
    switch (this) {
      case StreamHealthStatus.green:
        return 'Healthy';
      case StreamHealthStatus.yellow:
        return 'Warning';
      case StreamHealthStatus.red:
        return 'Critical';
    }
  }

  /// Longer descriptive text explaining current stream conditions.
  String get description {
    switch (this) {
      case StreamHealthStatus.green:
        return 'Optimal buffer headroom and low network latency.';
      case StreamHealthStatus.yellow:
        return 'Moderate buffer headroom or elevated network latency.';
      case StreamHealthStatus.red:
        return 'Critically low buffer ahead or high network latency.';
    }
  }

  /// Icon associated with this health status.
  IconData get icon {
    switch (this) {
      case StreamHealthStatus.green:
        return Icons.check_circle_rounded;
      case StreamHealthStatus.yellow:
        return Icons.warning_amber_rounded;
      case StreamHealthStatus.red:
        return Icons.error_outline_rounded;
    }
  }

  bool get isGreen => this == StreamHealthStatus.green;
  bool get isYellow => this == StreamHealthStatus.yellow;
  bool get isRed => this == StreamHealthStatus.red;
}

// ============================================================================
// Model: StreamHealthData
// ============================================================================

/// Immutable snapshot of real-time stream diagnostic telemetry.
@immutable
class StreamHealthData {
  /// Current playback position.
  final Duration position;

  /// Current buffered position along the track timeline.
  final Duration bufferedPosition;

  /// Duration buffered ahead of current playback position (`bufferedPosition - position`).
  final Duration bufferAhead;

  /// Active stream audio bitrate in kilobits per second (e.g. 320 for 320 kbps).
  final int bitrateKbps;

  /// Measured network round-trip ping/latency in milliseconds (null if not yet measured).
  final int? latencyMs;

  /// Whether audio player is currently stalled or buffering packets.
  final bool isBuffering;

  /// Whether audio playback is actively playing.
  final bool isPlaying;

  /// Codec of the active stream (e.g. "AAC", "Opus", "FLAC", "MP3").
  final String codec;

  /// Container format (e.g. "m4a", "webm", "opus").
  final String container;

  /// Evaluated health status based on buffer ahead, latency, and buffering state.
  final StreamHealthStatus status;

  /// Timestamp when this diagnostic snapshot was recorded.
  final DateTime timestamp;

  /// Name of the streaming provider or CDN source (e.g. "saavn", "youtube_explode", "cached").
  final String providerName;

  const StreamHealthData({
    required this.position,
    required this.bufferedPosition,
    required this.bufferAhead,
    required this.bitrateKbps,
    this.latencyMs,
    this.isBuffering = false,
    this.isPlaying = true,
    this.codec = 'AAC',
    this.container = 'm4a',
    required this.status,
    required this.timestamp,
    this.providerName = 'Live CDN Stream',
  });

  /// Real-time formatted buffer ahead string (e.g., "+28s", "+0s").
  String get formattedBufferAhead {
    final seconds = bufferAhead.inSeconds;
    if (seconds <= 0) return '+0s';
    return '+${seconds}s';
  }

  /// Formatted bitrate string (e.g., "320 kbps").
  String get formattedBitrate => '$bitrateKbps kbps';

  /// Formatted latency string (e.g., "28 ms", "-- ms").
  String get formattedLatency => latencyMs != null ? '$latencyMs ms' : '-- ms';

  /// Convenience getter for the status color.
  Color get statusColor => status.color;

  /// Consolidated single-line summary string.
  String get summaryText =>
      '$formattedBufferAhead • $formattedBitrate • $formattedLatency';

  /// Ratio of current buffer ahead relative to an ideal 30-second target (clamped 0.0 to 1.0).
  double get bufferHealthRatio {
    const targetSeconds = 30.0;
    final ratio = bufferAhead.inSeconds / targetSeconds;
    return ratio.clamp(0.0, 1.0);
  }

  /// Calculates stream health telemetry and status from raw player and stream inputs.
  factory StreamHealthData.calculate({
    required Duration position,
    required Duration bufferedPosition,
    StreamInfo? streamInfo,
    int? latencyMs,
    bool isBuffering = false,
    bool isPlaying = true,
    int defaultBitrateKbps = 320,
    AudioQualityPreset qualityPreset = AudioQualityPreset.standard,
  }) {
    // 1. Calculate buffer ahead
    final Duration bufferAhead = bufferedPosition > position
        ? bufferedPosition - position
        : Duration.zero;

    // 2. Parse bitrate
    int bitrate = defaultBitrateKbps;
    if (streamInfo != null && streamInfo.bitrate > 0) {
      bitrate = (streamInfo.bitrate / 1000).round();
    } else {
      switch (qualityPreset) {
        case AudioQualityPreset.high:
          bitrate = 320;
          break;
        case AudioQualityPreset.standard:
          bitrate = 160;
          break;
        case AudioQualityPreset.low:
          bitrate = 64;
          break;
      }
    }

    // 3. Parse codec & container
    String codec = 'AAC';
    String container = 'm4a';
    String provider = 'Live CDN Stream';

    if (streamInfo != null) {
      final rawCodec = streamInfo.codec.toLowerCase();
      if (rawCodec.contains('flac')) {
        codec = 'FLAC';
      } else if (rawCodec.contains('opus')) {
        codec = 'Opus';
      } else if (rawCodec.contains('mp4a') || rawCodec.contains('aac')) {
        codec = 'AAC';
      } else if (rawCodec.contains('mp3')) {
        codec = 'MP3';
      } else if (streamInfo.codec.isNotEmpty) {
        codec = streamInfo.codec.toUpperCase();
      }

      if (streamInfo.container.isNotEmpty) {
        container = streamInfo.container.toLowerCase();
      }

      if (streamInfo.providerName.isNotEmpty) {
        provider = streamInfo.providerName;
      }
    }

    // 4. Determine Health Status:
    // Green: bufferAhead >= 15s AND (latency is null or < 200ms)
    // Yellow: bufferAhead >= 5s AND (latency is null or < 400ms)
    // Red: bufferAhead < 5s OR isBuffering with buffer < 4s OR latency >= 400ms
    final StreamHealthStatus status;
    if (isBuffering && bufferAhead.inSeconds < 4) {
      status = StreamHealthStatus.red;
    } else if (bufferAhead.inSeconds < 5 || (latencyMs != null && latencyMs >= 400)) {
      status = StreamHealthStatus.red;
    } else if (bufferAhead.inSeconds < 15 || (latencyMs != null && latencyMs >= 200)) {
      status = StreamHealthStatus.yellow;
    } else {
      status = StreamHealthStatus.green;
    }

    return StreamHealthData(
      position: position,
      bufferedPosition: bufferedPosition,
      bufferAhead: bufferAhead,
      bitrateKbps: bitrate,
      latencyMs: latencyMs,
      isBuffering: isBuffering,
      isPlaying: isPlaying,
      codec: codec,
      container: container,
      status: status,
      timestamp: DateTime.now(),
      providerName: provider,
    );
  }

  /// Sample mock data generator for previews and unit tests.
  factory StreamHealthData.sample({
    Duration position = const Duration(seconds: 45),
    Duration bufferAhead = const Duration(seconds: 28),
    int bitrateKbps = 320,
    int? latencyMs = 28,
    StreamHealthStatus status = StreamHealthStatus.green,
    bool isBuffering = false,
    bool isPlaying = true,
    String codec = 'AAC',
    String container = 'm4a',
    String providerName = 'Akamai CDN',
  }) {
    return StreamHealthData(
      position: position,
      bufferedPosition: position + bufferAhead,
      bufferAhead: bufferAhead,
      bitrateKbps: bitrateKbps,
      latencyMs: latencyMs,
      isBuffering: isBuffering,
      isPlaying: isPlaying,
      codec: codec,
      container: container,
      status: status,
      timestamp: DateTime.now(),
      providerName: providerName,
    );
  }

  StreamHealthData copyWith({
    Duration? position,
    Duration? bufferedPosition,
    Duration? bufferAhead,
    int? bitrateKbps,
    int? latencyMs,
    bool? isBuffering,
    bool? isPlaying,
    String? codec,
    String? container,
    StreamHealthStatus? status,
    DateTime? timestamp,
    String? providerName,
  }) {
    return StreamHealthData(
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      bufferAhead: bufferAhead ?? this.bufferAhead,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      latencyMs: latencyMs ?? this.latencyMs,
      isBuffering: isBuffering ?? this.isBuffering,
      isPlaying: isPlaying ?? this.isPlaying,
      codec: codec ?? this.codec,
      container: container ?? this.container,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      providerName: providerName ?? this.providerName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamHealthData &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          bufferedPosition == other.bufferedPosition &&
          bufferAhead == other.bufferAhead &&
          bitrateKbps == other.bitrateKbps &&
          latencyMs == other.latencyMs &&
          isBuffering == other.isBuffering &&
          isPlaying == other.isPlaying &&
          codec == other.codec &&
          container == other.container &&
          status == other.status &&
          providerName == other.providerName;

  @override
  int get hashCode => Object.hash(
        position,
        bufferedPosition,
        bufferAhead,
        bitrateKbps,
        latencyMs,
        isBuffering,
        isPlaying,
        codec,
        container,
        status,
        providerName,
      );

  @override
  String toString() =>
      'StreamHealthData(ahead: $formattedBufferAhead, bitrate: $formattedBitrate, latency: $formattedLatency, status: ${status.label})';
}

// ============================================================================
// Service: StreamLatencyProbe
// ============================================================================

typedef LatencyProbeFunction = Future<int?> Function([Uri? target]);

/// Lightweight diagnostic service to probe network roundtrip latency to streaming endpoints.
class StreamLatencyProbe {
  final LatencyProbeFunction? _probeOverride;
  final List<int> _history = [];

  StreamLatencyProbe({LatencyProbeFunction? probeFunction})
      : _probeOverride = probeFunction;

  /// Recent latency measurements in milliseconds.
  List<int> get history => List.unmodifiable(_history);

  /// Average latency over recent successful measurements.
  double get averageLatencyMs {
    if (_history.isEmpty) return 0.0;
    return _history.reduce((a, b) => a + b) / _history.length;
  }

  /// Measures network round-trip time in milliseconds against [targetUrl].
  Future<int?> measureLatency([Uri? targetUrl]) async {
    final probe = _probeOverride;
    if (probe != null) {
      final res = await probe(targetUrl);
      if (res != null) recordLatency(res);
      return res;
    }

    try {
      final target = targetUrl ?? Uri.parse('https://dns.google/resolve?name=example.com');
      final sw = Stopwatch()..start();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.headUrl(target);
      final res = await req.close();
      sw.stop();
      client.close();
      if (res.statusCode >= 200 && res.statusCode < 400) {
        final elapsed = sw.elapsedMilliseconds;
        recordLatency(elapsed);
        return elapsed;
      }
    } catch (_) {
      // Non-fatal probe failure
    }
    return null;
  }

  /// Manually records a measured latency.
  void recordLatency(int ms) {
    _history.add(ms);
    if (_history.length > 20) {
      _history.removeAt(0);
    }
  }

  /// Clears historical latency points.
  void clear() => _history.clear();
}

// ============================================================================
// Settings: StreamHealthSettings
// ============================================================================

@immutable
class StreamHealthSettings {
  final bool showLatency;
  final bool showBitrate;
  final bool showBufferAhead;
  final bool compact;

  const StreamHealthSettings({
    this.showLatency = true,
    this.showBitrate = true,
    this.showBufferAhead = true,
    this.compact = false,
  });

  StreamHealthSettings copyWith({
    bool? showLatency,
    bool? showBitrate,
    bool? showBufferAhead,
    bool? compact,
  }) {
    return StreamHealthSettings(
      showLatency: showLatency ?? this.showLatency,
      showBitrate: showBitrate ?? this.showBitrate,
      showBufferAhead: showBufferAhead ?? this.showBufferAhead,
      compact: compact ?? this.compact,
    );
  }
}

class StreamHealthSettingsNotifier extends StateNotifier<StreamHealthSettings> {
  StreamHealthSettingsNotifier() : super(const StreamHealthSettings());

  void toggleLatency() => state = state.copyWith(showLatency: !state.showLatency);
  void toggleBitrate() => state = state.copyWith(showBitrate: !state.showBitrate);
  void toggleBufferAhead() => state = state.copyWith(showBufferAhead: !state.showBufferAhead);
  void toggleCompact() => state = state.copyWith(compact: !state.compact);
  void update({bool? showLatency, bool? showBitrate, bool? showBufferAhead, bool? compact}) {
    state = state.copyWith(
      showLatency: showLatency,
      showBitrate: showBitrate,
      showBufferAhead: showBufferAhead,
      compact: compact,
    );
  }
}

// ============================================================================
// Riverpod State Providers
// ============================================================================

/// Latency measurement probe instance provider.
final streamLatencyProbeProvider = Provider<StreamLatencyProbe>((ref) {
  return StreamLatencyProbe();
});

/// Current measured network latency provider (in milliseconds).
final networkLatencyProvider = StateProvider<int?>((ref) => null);

/// Stream health pill display configuration provider.
final streamHealthSettingsProvider =
    StateNotifierProvider<StreamHealthSettingsNotifier, StreamHealthSettings>((ref) {
  return StreamHealthSettingsNotifier();
});

/// Reactive diagnostic data provider calculated from playback streams.
final streamHealthDataProvider = Provider<StreamHealthData>((ref) {
  final posAsync = ref.watch(positionStreamProvider);
  final bufAsync = ref.watch(bufferedPositionStreamProvider);
  final streamInfoAsync = ref.watch(currentStreamInfoProvider);
  final playbackStateAsync = ref.watch(playbackStateStreamProvider);
  final latency = ref.watch(networkLatencyProvider);
  final preset = ref.watch(audioQualityPresetProvider);

  final position = posAsync.value ?? Duration.zero;
  final buffered = bufAsync.value ?? Duration.zero;
  final streamInfo = streamInfoAsync.value;
  final isBuffering =
      playbackStateAsync.value?.processingState == AudioProcessingState.buffering;
  final isPlaying = playbackStateAsync.value?.playing ?? false;

  return StreamHealthData.calculate(
    position: position,
    bufferedPosition: buffered,
    streamInfo: streamInfo,
    latencyMs: latency,
    isBuffering: isBuffering,
    isPlaying: isPlaying,
    qualityPreset: preset,
  );
});

// ============================================================================
// Widget: StreamHealthStatusIndicator
// ============================================================================

/// Compact glowing status dot widget visually indicating Green, Yellow, or Red stream health.
class StreamHealthStatusIndicator extends StatefulWidget {
  final StreamHealthStatus status;
  final double size;
  final bool animate;

  const StreamHealthStatusIndicator({
    super.key,
    required this.status,
    this.size = 7.0,
    this.animate = true,
  });

  @override
  State<StreamHealthStatusIndicator> createState() =>
      _StreamHealthStatusIndicatorState();
}

class _StreamHealthStatusIndicatorState
    extends State<StreamHealthStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.animate) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StreamHealthStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _animController.repeat(reverse: true);
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.status.color;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowOpacity = widget.animate ? _glowAnimation.value : 0.4;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: glowOpacity),
                blurRadius: widget.size * 0.9,
                spreadRadius: 1.0,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Widget: StreamHealthPill
// ============================================================================

/// Real-time stream health and buffer diagnostic pill widget.
///
/// Displays:
/// - Status color dot (Green / Yellow / Red)
/// - Real-time buffer ahead duration (e.g. "+28s")
/// - Audio stream bitrate (e.g. "320 kbps")
/// - Network roundtrip latency (e.g. "28 ms")
///
/// Tapping opens the detailed [StreamHealthDetailDialog] diagnostic sheet.
class StreamHealthPill extends ConsumerWidget {
  final StreamHealthData? customData;
  final bool compact;
  final bool showLatency;
  final bool showBitrate;
  final bool showBufferAhead;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const StreamHealthPill({
    super.key,
    this.customData,
    this.compact = false,
    this.showLatency = true,
    this.showBitrate = true,
    this.showBufferAhead = true,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final StreamHealthData data = customData ?? ref.watch(streamHealthDataProvider);
    final statusColor = data.statusColor;

    final defaultPadding = EdgeInsets.symmetric(
      horizontal: compact ? 8.0 : 10.0,
      vertical: compact ? 3.0 : 5.0,
    );

    return BouncingScaleButton(
      scaleFactor: 0.96,
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          StreamHealthDetailDialog.show(context, data: data);
        }
      },
      child: Tooltip(
        message: 'Buffer: ${data.formattedBufferAhead} • Bitrate: ${data.formattedBitrate} • Latency: ${data.formattedLatency} (${data.status.label})\nTap for detailed diagnostics',
        waitDuration: const Duration(milliseconds: 600),
        child: Container(
          padding: padding ?? defaultPadding,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.38),
              width: 0.85,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Health Status Dot
              StreamHealthStatusIndicator(
                status: data.status,
                size: compact ? 6.0 : 7.0,
              ),

              // 2. Buffer Ahead Duration (+28s)
              if (showBufferAhead) ...[
                SizedBox(width: compact ? 5 : 6),
                Text(
                  data.formattedBufferAhead,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: compact ? 10.0 : 11.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],

              // 3. Bitrate (320 kbps)
              if (showBitrate) ...[
                _buildDotDivider(tokens),
                Text(
                  data.formattedBitrate,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: compact ? 10.0 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],

              // 4. Network Latency (e.g. 28 ms)
              if (showLatency) ...[
                _buildDotDivider(tokens),
                Icon(
                  Icons.wifi_rounded,
                  size: compact ? 11.0 : 12.5,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 3.5),
                Text(
                  data.formattedLatency,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: compact ? 10.0 : 11.5,
                    fontWeight: FontWeight.w500,
                    color: tokens.textSecondary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotDivider(AppTokens tokens) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4.5 : 6.0),
      child: Text(
        '•',
        style: TextStyle(
          color: tokens.textMuted.withValues(alpha: 0.7),
          fontSize: compact ? 9.0 : 11.0,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

// ============================================================================
// Widget: DiagnosticPill
// ============================================================================

/// Diagnostic pill widget showing real-time buffer ahead duration (+28s),
/// bitrate (320 kbps), and network latency.
///
/// Directly aliases and configures [StreamHealthPill] with full diagnostic display.
class DiagnosticPill extends StatelessWidget {
  final StreamHealthData? data;
  final bool compact;
  final VoidCallback? onTap;

  const DiagnosticPill({
    super.key,
    this.data,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamHealthPill(
      customData: data,
      compact: compact,
      showBufferAhead: true,
      showBitrate: true,
      showLatency: true,
      onTap: onTap,
    );
  }
}

// ============================================================================
// Dialog / Sheet: StreamHealthDetailDialog
// ============================================================================

/// Comprehensive modal dialog inspecting stream buffer health, codec parameters,
/// and network roundtrip ping.
class StreamHealthDetailDialog extends ConsumerStatefulWidget {
  final StreamHealthData? initialData;

  const StreamHealthDetailDialog({
    super.key,
    this.initialData,
  });

  static Future<void> show(BuildContext context, {StreamHealthData? data}) {
    return showDialog(
      context: context,
      builder: (ctx) => StreamHealthDetailDialog(initialData: data),
    );
  }

  @override
  ConsumerState<StreamHealthDetailDialog> createState() =>
      _StreamHealthDetailDialogState();
}

class _StreamHealthDetailDialogState
    extends ConsumerState<StreamHealthDetailDialog> {
  bool _isProbing = false;

  Future<void> _runPingProbe() async {
    setState(() => _isProbing = true);
    try {
      final probe = ref.read(streamLatencyProbeProvider);
      final latency = await probe.measureLatency();
      if (mounted) {
        ref.read(networkLatencyProvider.notifier).state = latency;
      }
    } finally {
      if (mounted) {
        setState(() => _isProbing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final StreamHealthData data = widget.initialData ?? ref.watch(streamHealthDataProvider);
    final status = data.status;

    return Dialog(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        side: BorderSide(
          color: tokens.glassBorder.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 20,
                      color: status.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stream Health & Buffer',
                          style: TextStyle(
                            fontFamily: AppTheme.fontPageTitle,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Real-time streaming telemetry',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: tokens.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Status Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.35),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(status.icon, color: status.color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${status.label}',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: status.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status.description,
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 11.5,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Buffer Health Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Buffer Headroom',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      Text(
                        '${data.formattedBufferAhead} ahead (Target: 30s)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: status.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    child: LinearProgressIndicator(
                      value: data.bufferHealthRatio,
                      backgroundColor: tokens.surfaceHighlight,
                      valueColor: AlwaysStoppedAnimation<Color>(status.color),
                      minHeight: 7.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2x2 Telemetry Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      tokens: tokens,
                      icon: Icons.hourglass_top_rounded,
                      label: 'Buffer Ahead',
                      value: data.formattedBufferAhead,
                      subtext: data.bufferAhead.inSeconds >= 15
                          ? 'Optimal capacity'
                          : 'Buffering soon',
                      accentColor: status.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      tokens: tokens,
                      icon: Icons.graphic_eq_rounded,
                      label: 'Stream Bitrate',
                      value: data.formattedBitrate,
                      subtext: '${data.codec} • ${data.container.toUpperCase()}',
                      accentColor: tokens.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      tokens: tokens,
                      icon: Icons.speed_rounded,
                      label: 'Network Latency',
                      value: data.formattedLatency,
                      subtext: data.latencyMs != null
                          ? (data.latencyMs! < 120 ? 'Fast connection' : 'High latency')
                          : 'Not probed yet',
                      accentColor: data.latencyMs != null && data.latencyMs! < 180
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEAB308),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      tokens: tokens,
                      icon: Icons.cloud_outlined,
                      label: 'Stream Source',
                      value: data.providerName,
                      subtext: data.isPlaying ? 'Live playback' : 'Paused',
                      accentColor: tokens.accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons: Ping & Close
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: tokens.glassBorder.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                      ),
                      onPressed: _isProbing ? null : _runPingProbe,
                      icon: _isProbing
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: tokens.accent,
                              ),
                            )
                          : const Icon(Icons.network_ping_rounded, size: 16),
                      label: Text(
                        _isProbing ? 'Testing Ping...' : 'Test Ping Latency',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.cardHover,
                      foregroundColor: tokens.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required AppTokens tokens,
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: tokens.glassBorder.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11,
                    color: tokens.textMuted,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 10.5,
              color: tokens.textSecondary,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
