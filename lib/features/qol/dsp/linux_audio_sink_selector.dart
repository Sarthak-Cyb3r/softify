import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// Enums & Models
// ============================================================================

/// Audio subsystem backend types on Linux.
enum LinuxAudioBackend {
  pipeWire('PipeWire'),
  pulseAudio('PulseAudio'),
  alsa('ALSA'),
  generic('Linux Audio');

  final String displayName;
  const LinuxAudioBackend(this.displayName);
}

/// Output sink model representing a Linux audio device.
@immutable
class LinuxAudioSink {
  final String id;
  final String deviceName;
  final String? description;
  final String? port;
  final List<String> availablePorts;
  final bool isDefault;
  final LinuxAudioBackend backend;
  final double volume; // 0.0 to 1.0
  final bool isMuted;
  final Map<String, dynamic> properties;

  const LinuxAudioSink({
    required this.id,
    required this.deviceName,
    this.description,
    this.port,
    this.availablePorts = const [],
    this.isDefault = false,
    this.backend = LinuxAudioBackend.pipeWire,
    this.volume = 1.0,
    this.isMuted = false,
    this.properties = const {},
  });

  /// User-facing display title for the sink.
  String get name {
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    return deviceName.trim();
  }

  /// Contextual icon representing device type based on name and port.
  IconData get icon {
    final lower = '${name.toLowerCase()} ${port?.toLowerCase() ?? ""}';
    if (lower.contains('headphone') || lower.contains('headset')) {
      return Icons.headphones_rounded;
    } else if (lower.contains('hdmi') ||
        lower.contains('displayport') ||
        lower.contains('tv')) {
      return Icons.tv_rounded;
    } else if (lower.contains('usb') || lower.contains('dac')) {
      return Icons.usb_rounded;
    } else if (lower.contains('bluetooth') || lower.contains('bluez')) {
      return Icons.bluetooth_audio_rounded;
    } else {
      return Icons.speaker_rounded;
    }
  }

  LinuxAudioSink copyWith({
    String? id,
    String? deviceName,
    String? description,
    String? port,
    List<String>? availablePorts,
    bool? isDefault,
    LinuxAudioBackend? backend,
    double? volume,
    bool? isMuted,
    Map<String, dynamic>? properties,
  }) {
    return LinuxAudioSink(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      description: description ?? this.description,
      port: port ?? this.port,
      availablePorts: availablePorts ?? this.availablePorts,
      isDefault: isDefault ?? this.isDefault,
      backend: backend ?? this.backend,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      properties: properties ?? this.properties,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceName': deviceName,
        'description': description,
        'port': port,
        'availablePorts': availablePorts,
        'isDefault': isDefault,
        'backend': backend.name,
        'volume': volume,
        'isMuted': isMuted,
        'properties': properties,
      };

  factory LinuxAudioSink.fromJson(Map<String, dynamic> json) {
    return LinuxAudioSink(
      id: json['id'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Audio Sink',
      description: json['description'] as String?,
      port: json['port'] as String?,
      availablePorts: (json['availablePorts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isDefault: json['isDefault'] as bool? ?? false,
      backend: LinuxAudioBackend.values.firstWhere(
        (b) => b.name == json['backend'],
        orElse: () => LinuxAudioBackend.generic,
      ),
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      isMuted: json['isMuted'] as bool? ?? false,
      properties: json['properties'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinuxAudioSink &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          deviceName == other.deviceName &&
          port == other.port &&
          isDefault == other.isDefault &&
          backend == other.backend;

  @override
  int get hashCode => Object.hash(id, deviceName, port, isDefault, backend);

  @override
  String toString() =>
      'LinuxAudioSink(id: $id, deviceName: "$deviceName", port: "$port", isDefault: $isDefault, backend: ${backend.displayName})';
}

// ============================================================================
// Linux Command & Audio Parsers
// ============================================================================

/// Result of querying audio output sinks on the system.
@immutable
class LinuxAudioDetectionResult {
  final LinuxAudioBackend backend;
  final List<LinuxAudioSink> sinks;

  const LinuxAudioDetectionResult({
    required this.backend,
    required this.sinks,
  });
}

/// Parses PipeWire output from `wpctl status`.
List<LinuxAudioSink> parseWpctlStatus(String output) {
  final sinks = <LinuxAudioSink>[];
  final lines = output.split('\n');

  bool inAudioSection = false;
  bool inSinksSection = false;

  for (final rawLine in lines) {
    final line = rawLine.replaceAll('│', '').replaceAll('├', '').replaceAll('─', '').replaceAll('└', '').trim();

    if (rawLine.contains('Audio')) {
      inAudioSection = true;
      continue;
    }

    if (inAudioSection) {
      if (rawLine.contains('Sinks:')) {
        inSinksSection = true;
        continue;
      }

      if (inSinksSection &&
          (rawLine.contains('Sources:') ||
              rawLine.contains('Filters:') ||
              rawLine.contains('Streams:') ||
              rawLine.contains('Video') ||
              rawLine.contains('Settings'))) {
        inSinksSection = false;
        break;
      }

      if (inSinksSection && line.isNotEmpty) {
        final isDefault = line.startsWith('*');
        final cleaned = isDefault ? line.substring(1).trim() : line;

        // Match: "48. Built-in Audio Digital Stereo (IEC958) [vol: 1.00]"
        final match = RegExp(
          r'^(\d+)\.\s+(.*?)(?:\s+\[vol:\s*([0-9.]+)\])?(?:\s+\[MUTED\])?$',
        ).firstMatch(cleaned);

        if (match != null) {
          final id = match.group(1)!;
          final fullName = match.group(2)!.trim();
          final volString = match.group(3);
          final volume = volString != null ? (double.tryParse(volString) ?? 1.0) : 1.0;
          final isMuted = cleaned.contains('[MUTED]');

          // Extract port if contained in parentheses, e.g. (IEC958)
          String? port;
          final portMatch = RegExp(r'\(([^)]+)\)$').firstMatch(fullName);
          if (portMatch != null) {
            port = portMatch.group(1);
          }

          sinks.add(
            LinuxAudioSink(
              id: id,
              deviceName: fullName,
              description: fullName,
              port: port,
              isDefault: isDefault,
              backend: LinuxAudioBackend.pipeWire,
              volume: volume,
              isMuted: isMuted,
            ),
          );
        }
      }
    }
  }

  return sinks;
}

/// Parses PulseAudio output from `pactl list sinks`.
List<LinuxAudioSink> parsePactlSinks(
  String output, {
  String? defaultSinkName,
}) {
  final sinks = <LinuxAudioSink>[];
  if (output.trim().isEmpty) return sinks;

  final blocks = output.split(RegExp(r'(?=Sink\s*#\d+)'));

  for (final block in blocks) {
    if (!block.trim().startsWith('Sink')) continue;

    final idMatch = RegExp(r'Sink\s*#(\d+)').firstMatch(block);
    final id = idMatch?.group(1) ?? '';

    final nameMatch = RegExp(r'Name:\s*([^\n\r]+)').firstMatch(block);
    final deviceName = nameMatch?.group(1)?.trim() ?? '';
    if (deviceName.isEmpty) continue;

    final descMatch = RegExp(r'Description:\s*([^\n\r]+)').firstMatch(block);
    final description = descMatch?.group(1)?.trim();

    final portMatch = RegExp(r'Active Port:\s*([^\n\r]+)').firstMatch(block);
    final port = portMatch?.group(1)?.trim();

    // Available ports
    final availablePorts = <String>[];
    final portsSection = RegExp(r'Ports:\s*\n((?:\s+[^\n]+\n)+)').firstMatch(block);
    if (portsSection != null) {
      final portLines = portsSection.group(1)!.split('\n');
      for (final pLine in portLines) {
        final pMatch = RegExp(r'^\s*([a-zA-Z0-9_\-]+):').firstMatch(pLine);
        if (pMatch != null) {
          availablePorts.add(pMatch.group(1)!);
        }
      }
    }

    final isMuted = RegExp(r'Mute:\s*yes', caseSensitive: false).hasMatch(block);

    // Volume percentage
    double volume = 1.0;
    final volMatch = RegExp(r'(\d+)%').firstMatch(block);
    if (volMatch != null) {
      final pct = int.tryParse(volMatch.group(1) ?? '100') ?? 100;
      volume = (pct / 100.0).clamp(0.0, 1.5);
    }

    final isDefault = (defaultSinkName != null &&
        (defaultSinkName.trim() == deviceName.trim() ||
            defaultSinkName.trim() == id.trim()));

    sinks.add(
      LinuxAudioSink(
        id: id.isNotEmpty ? id : deviceName,
        deviceName: deviceName,
        description: description,
        port: port,
        availablePorts: availablePorts,
        isDefault: isDefault,
        backend: LinuxAudioBackend.pulseAudio,
        volume: volume,
        isMuted: isMuted,
      ),
    );
  }

  return sinks;
}

/// Parses ALSA hardware output from `aplay -l`.
List<LinuxAudioSink> parseAplayDevices(String output) {
  final sinks = <LinuxAudioSink>[];
  final lines = output.split('\n');

  // card 0: PCH [HDA Intel PCH], device 0: ALC887-VD Analog [ALC887-VD Analog]
  final regex = RegExp(
    r'card\s+(\d+):\s+([^,]+),\s+device\s+(\d+):\s+([^\[]+)(?:\[(.*?)\])?',
  );

  bool first = true;
  for (final line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      final cardNum = match.group(1)!;
      final cardName = match.group(2)!.trim();
      final deviceNum = match.group(3)!;
      final devDesc = (match.group(5) ?? match.group(4)!).trim();

      sinks.add(
        LinuxAudioSink(
          id: 'hw:$cardNum,$deviceNum',
          deviceName: devDesc,
          description: '$cardName - $devDesc',
          port: 'Card $cardNum, Device $deviceNum',
          isDefault: first,
          backend: LinuxAudioBackend.alsa,
        ),
      );
      first = false;
    }
  }

  return sinks;
}

// ============================================================================
// Command Runner & Audio Service
// ============================================================================

/// Abstract runner for native Linux audio commands.
abstract class LinuxAudioCommandRunner {
  Future<ProcessResult> run(String executable, List<String> arguments);
}

/// Default system implementation invoking [Process.run].
class SystemLinuxAudioCommandRunner implements LinuxAudioCommandRunner {
  @override
  Future<ProcessResult> run(String executable, List<String> arguments) {
    return Process.run(executable, arguments);
  }
}

/// Linux audio device service interfacing with PipeWire, PulseAudio, and ALSA.
class LinuxAudioService {
  final LinuxAudioCommandRunner _runner;

  LinuxAudioService({LinuxAudioCommandRunner? runner})
      : _runner = runner ?? SystemLinuxAudioCommandRunner();

  /// Detects audio sinks across Linux sound servers in order of preference.
  Future<LinuxAudioDetectionResult> detectSinks() async {
    // 1. Try PipeWire (wpctl status)
    try {
      final res = await _runner.run('wpctl', ['status']);
      if (res.exitCode == 0 && res.stdout.toString().contains('Sinks:')) {
        final sinks = parseWpctlStatus(res.stdout.toString());
        if (sinks.isNotEmpty) {
          return LinuxAudioDetectionResult(
            backend: LinuxAudioBackend.pipeWire,
            sinks: sinks,
          );
        }
      }
    } catch (_) {}

    // 2. Try PulseAudio (pactl list sinks)
    try {
      final res = await _runner.run('pactl', ['list', 'sinks']);
      if (res.exitCode == 0 && res.stdout.toString().contains('Sink #')) {
        String? defaultSinkName;
        try {
          final defRes = await _runner.run('pactl', ['get-default-sink']);
          if (defRes.exitCode == 0) {
            defaultSinkName = defRes.stdout.toString().trim();
          }
        } catch (_) {}

        final sinks = parsePactlSinks(
          res.stdout.toString(),
          defaultSinkName: defaultSinkName,
        );
        if (sinks.isNotEmpty) {
          return LinuxAudioDetectionResult(
            backend: LinuxAudioBackend.pulseAudio,
            sinks: sinks,
          );
        }
      }
    } catch (_) {}

    // 3. Try ALSA (aplay -l)
    try {
      final res = await _runner.run('aplay', ['-l']);
      if (res.exitCode == 0 && res.stdout.toString().contains('card ')) {
        final sinks = parseAplayDevices(res.stdout.toString());
        if (sinks.isNotEmpty) {
          return LinuxAudioDetectionResult(
            backend: LinuxAudioBackend.alsa,
            sinks: sinks,
          );
        }
      }
    } catch (_) {}

    // 4. Fallback Default
    return const LinuxAudioDetectionResult(
      backend: LinuxAudioBackend.generic,
      sinks: [
        LinuxAudioSink(
          id: 'default',
          deviceName: 'System Default Audio Output',
          description: 'Default Linux Audio Output',
          port: 'Standard Out',
          isDefault: true,
          backend: LinuxAudioBackend.generic,
        ),
      ],
    );
  }

  /// Sets the active system default sink.
  Future<bool> setDefaultSink(LinuxAudioSink sink) async {
    try {
      switch (sink.backend) {
        case LinuxAudioBackend.pipeWire:
          final cleanId = sink.id.replaceAll(RegExp(r'[^0-9]'), '');
          final target = cleanId.isNotEmpty ? cleanId : sink.id;
          final res = await _runner.run('wpctl', ['set-default', target]);
          return res.exitCode == 0;
        case LinuxAudioBackend.pulseAudio:
          final res = await _runner.run('pactl', ['set-default-sink', sink.deviceName]);
          return res.exitCode == 0;
        case LinuxAudioBackend.alsa:
        case LinuxAudioBackend.generic:
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  /// Plays a short test tone on the system to verify output routing.
  Future<bool> playTestTone(LinuxAudioSink sink) async {
    // 1. speaker-test (standard on ALSA/PipeWire/PulseAudio)
    try {
      final res = await _runner.run(
        'speaker-test',
        ['-t', 'sine', '-f', '440', '-l', '1'],
      );
      if (res.exitCode == 0) return true;
    } catch (_) {}

    // 2. canberra-gtk-play (standard GNOME/GTK sound event)
    try {
      final res = await _runner.run('canberra-gtk-play', ['-i', 'bell']);
      if (res.exitCode == 0) return true;
    } catch (_) {}

    // 3. pw-play or aplay test sound
    try {
      final res = await _runner.run(
        'aplay',
        ['/usr/share/sounds/alsa/Front_Center.wav'],
      );
      if (res.exitCode == 0) return true;
    } catch (_) {}

    return false;
  }
}

// ============================================================================
// State & Riverpod StateNotifier
// ============================================================================

/// Immutable state holding detected Linux audio output sinks.
@immutable
class LinuxAudioSinkState {
  final List<LinuxAudioSink> sinks;
  final LinuxAudioSink? activeSink;
  final LinuxAudioBackend activeBackend;
  final bool isLoading;
  final String? error;
  final bool isPlayingTestTone;
  final String? playingToneSinkId;

  const LinuxAudioSinkState({
    this.sinks = const [],
    this.activeSink,
    this.activeBackend = LinuxAudioBackend.pipeWire,
    this.isLoading = false,
    this.error,
    this.isPlayingTestTone = false,
    this.playingToneSinkId,
  });

  bool get hasSinks => sinks.isNotEmpty;

  LinuxAudioSinkState copyWith({
    List<LinuxAudioSink>? sinks,
    LinuxAudioSink? activeSink,
    bool clearActiveSink = false,
    LinuxAudioBackend? activeBackend,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isPlayingTestTone,
    String? playingToneSinkId,
    bool clearPlayingToneSinkId = false,
  }) {
    return LinuxAudioSinkState(
      sinks: sinks ?? this.sinks,
      activeSink: clearActiveSink ? null : (activeSink ?? this.activeSink),
      activeBackend: activeBackend ?? this.activeBackend,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isPlayingTestTone: isPlayingTestTone ?? this.isPlayingTestTone,
      playingToneSinkId: clearPlayingToneSinkId
          ? null
          : (playingToneSinkId ?? this.playingToneSinkId),
    );
  }
}

/// Riverpod StateNotifier managing audio sinks query, selection, and test tone.
class LinuxAudioSinkNotifier extends StateNotifier<LinuxAudioSinkState> {
  final LinuxAudioService _service;
  Timer? _testToneTimer;

  LinuxAudioSinkNotifier({
    LinuxAudioService? service,
    bool autoLoad = true,
  })  : _service = service ?? LinuxAudioService(),
        super(const LinuxAudioSinkState(isLoading: true)) {
    if (autoLoad) {
      refreshSinks();
    }
  }

  /// Scans Linux audio backend and refreshes sinks list.
  Future<void> refreshSinks() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detection = await _service.detectSinks();
      final sinks = detection.sinks;

      LinuxAudioSink? defaultSink;
      try {
        defaultSink = sinks.firstWhere((s) => s.isDefault);
      } catch (_) {
        if (sinks.isNotEmpty) {
          defaultSink = sinks.first.copyWith(isDefault: true);
        }
      }

      state = state.copyWith(
        sinks: sinks,
        activeSink: defaultSink,
        activeBackend: detection.backend,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to discover Linux audio sinks: $e',
      );
    }
  }

  /// Selects a sink as active default and updates Linux sound server.
  Future<bool> selectSink(LinuxAudioSink sink) async {
    final prevSink = state.activeSink;

    // Optimistically update default status
    final updatedList = state.sinks.map((s) {
      return s.copyWith(isDefault: s.id == sink.id);
    }).toList();

    state = state.copyWith(
      activeSink: sink.copyWith(isDefault: true),
      sinks: updatedList,
      clearError: true,
    );

    final success = await _service.setDefaultSink(sink);
    if (!success) {
      // Revert if system command failed
      if (prevSink != null) {
        state = state.copyWith(
          activeSink: prevSink,
          sinks: state.sinks
              .map((s) => s.copyWith(isDefault: s.id == prevSink.id))
              .toList(),
          error: 'Failed to switch output to ${sink.name}',
        );
      }
      return false;
    }
    return true;
  }

  /// Plays a short test tone on the specified sink or currently active sink.
  Future<void> playTestTone([LinuxAudioSink? sink]) async {
    final targetSink = sink ?? state.activeSink;
    if (targetSink == null) return;

    _testToneTimer?.cancel();
    state = state.copyWith(
      isPlayingTestTone: true,
      playingToneSinkId: targetSink.id,
    );

    unawaited(_service.playTestTone(targetSink));

    _testToneTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        state = state.copyWith(
          isPlayingTestTone: false,
          clearPlayingToneSinkId: true,
        );
      }
    });
  }

  /// Immediately stops test tone playback indicator.
  void stopTestTone() {
    _testToneTimer?.cancel();
    state = state.copyWith(
      isPlayingTestTone: false,
      clearPlayingToneSinkId: true,
    );
  }

  @override
  void dispose() {
    _testToneTimer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

final linuxAudioCommandRunnerProvider =
    Provider<LinuxAudioCommandRunner>((ref) {
  return SystemLinuxAudioCommandRunner();
});

final linuxAudioServiceProvider = Provider<LinuxAudioService>((ref) {
  final runner = ref.watch(linuxAudioCommandRunnerProvider);
  return LinuxAudioService(runner: runner);
});

final linuxAudioSinkNotifierProvider =
    StateNotifierProvider<LinuxAudioSinkNotifier, LinuxAudioSinkState>((ref) {
  final service = ref.watch(linuxAudioServiceProvider);
  return LinuxAudioSinkNotifier(service: service);
});

final activeAudioSinkProvider = Provider<LinuxAudioSink?>((ref) {
  return ref.watch(linuxAudioSinkNotifierProvider).activeSink;
});

final availableAudioSinksProvider = Provider<List<LinuxAudioSink>>((ref) {
  return ref.watch(linuxAudioSinkNotifierProvider).sinks;
});

// ============================================================================
// UI: AudioSinkSelectorSheet Widget
// ============================================================================

/// Bottom sheet dialog allowing users to browse, select, and test Linux audio output sinks.
class AudioSinkSelectorSheet extends ConsumerWidget {
  const AudioSinkSelectorSheet({super.key});

  /// Displays the [AudioSinkSelectorSheet] modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const AudioSinkSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(linuxAudioSinkNotifierProvider);
    final notifier = ref.read(linuxAudioSinkNotifierProvider.notifier);
    final tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: tokens.divider.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.speaker_group_rounded,
                        color: tokens.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Audio Output Device',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.glassSurface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  state.activeBackend.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.accentCyan,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${state.sinks.length} sink${state.sinks.length == 1 ? '' : 's'} found',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('refresh_sinks_button'),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh devices',
                      onPressed: state.isLoading ? null : notifier.refreshSinks,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Error Banner (if any)
                if (state.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: tokens.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tokens.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: tokens.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 4. Device Tiles List
                if (state.isLoading && state.sinks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Scanning audio devices...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (state.sinks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.speaker_notes_off_rounded,
                            size: 40,
                            color: tokens.textMuted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No audio devices found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ensure PipeWire, PulseAudio, or ALSA is running.',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: notifier.refreshSinks,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry Scan'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: state.sinks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final sink = state.sinks[index];
                        final isSelected = sink.isDefault ||
                            (state.activeSink != null &&
                                state.activeSink!.id == sink.id);
                        final isPlayingThis = state.isPlayingTestTone &&
                            state.playingToneSinkId == sink.id;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('sink_tile_${sink.id}'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => notifier.selectSink(sink),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? tokens.accent.withValues(alpha: 0.12)
                                    : tokens.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? tokens.accent
                                      : tokens.glassBorder,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Leading Device Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? tokens.accent.withValues(alpha: 0.2)
                                          : tokens.surfaceElevated,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      sink.icon,
                                      size: 20,
                                      color: isSelected
                                          ? tokens.accent
                                          : tokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Sink Information
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sink.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: tokens.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          sink.deviceName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: tokens.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (sink.port != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tokens.surfaceHighlight,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Port: ${sink.port}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: tokens.textMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Test Tone Button for this Sink
                                  IconButton(
                                    key: ValueKey('test_tone_btn_${sink.id}'),
                                    tooltip: 'Play test tone on this device',
                                    icon: isPlayingThis
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                tokens.accent,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.volume_up_rounded,
                                            size: 20,
                                            color: tokens.textSecondary,
                                          ),
                                    onPressed: () => notifier.playTestTone(sink),
                                  ),

                                  // Radio / Selection Checkmark
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? tokens.accent
                                        : tokens.textMuted,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // 5. Global Test Tone Button
                FilledButton.icon(
                  key: const ValueKey('play_test_tone_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: state.isPlayingTestTone
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.hearing_rounded, size: 20),
                  label: Text(
                    state.isPlayingTestTone
                        ? 'Playing Test Tone (440Hz)...'
                        : 'Test Audio Output',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: state.sinks.isEmpty
                      ? null
                      : () {
                          if (state.isPlayingTestTone) {
                            notifier.stopTestTone();
                          } else {
                            notifier.playTestTone();
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
