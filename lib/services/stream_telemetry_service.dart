import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_clock_service.dart';

/// Local listening telemetry record directly modeled after Spotify's
/// `spotify.event_sender.proto.RawCoreStream` schema.
class RawCoreStreamRecord {
  final String trackId;
  final String title;
  final String artist;
  final int bitrate; // Target: 320,000 bps
  final String codec;
  final int durationListenedMs;
  final int totalDurationMs;
  final String completionReason; // 'finished', 'skipped', 'interrupted'
  final AudioOutputSinkCategory outputSink;
  final DateTime timestamp;

  const RawCoreStreamRecord({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.bitrate,
    required this.codec,
    required this.durationListenedMs,
    required this.totalDurationMs,
    required this.completionReason,
    required this.outputSink,
    required this.timestamp,
  });

  bool get isFullBitrateCompliant => bitrate >= 320000;

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'bitrate': bitrate,
        'isFullBitrateCompliant': isFullBitrateCompliant,
        'codec': codec,
        'durationListenedMs': durationListenedMs,
        'totalDurationMs': totalDurationMs,
        'completionReason': completionReason,
        'outputSink': outputSink.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RawCoreStreamRecord.fromJson(Map<String, dynamic> json) {
    return RawCoreStreamRecord(
      trackId: json['trackId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      bitrate: (json['bitrate'] as num?)?.toInt() ?? 320000,
      codec: json['codec'] as String? ?? 'aac',
      durationListenedMs: (json['durationListenedMs'] as num?)?.toInt() ?? 0,
      totalDurationMs: (json['totalDurationMs'] as num?)?.toInt() ?? 0,
      completionReason: json['completionReason'] as String? ?? 'finished',
      outputSink: AudioOutputSinkCategory.values.firstWhere(
        (e) => e.name == json['outputSink'],
        orElse: () => AudioOutputSinkCategory.internalSpeaker,
      ),
      timestamp: DateTime.parse(
          json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Offline-first listening telemetry and quality audit logger.
/// Emulates Spotify's EventSender/GABO telemetry purely locally on disk.
/// Tracks listening hours, 320 kbps fidelity compliance, and local Wrapped stats.
class StreamTelemetryService {
  static final StreamTelemetryService instance =
      StreamTelemetryService._internal();

  StreamTelemetryService._internal();

  File? _logFile;
  final List<RawCoreStreamRecord> _inMemoryBuffer = [];
  final _recordController =
      StreamController<RawCoreStreamRecord>.broadcast();

  Stream<RawCoreStreamRecord> get recordStream => _recordController.stream;

  /// Initializes the local telemetry file in application support directory.
  Future<void> initialize() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final teleDir = Directory(p.join(dir.path, 'telemetry'));
      if (!await teleDir.exists()) {
        await teleDir.create(recursive: true);
      }
      _logFile = File(p.join(teleDir.path, 'stream_events.jsonl'));
    } catch (_) {}
  }

  /// Logs a completed or skipped track playback event.
  Future<void> logStreamEvent({
    required String trackId,
    required String title,
    required String artist,
    required int bitrate,
    String codec = 'aac',
    required int durationListenedMs,
    required int totalDurationMs,
    required String completionReason,
    AudioOutputSinkCategory outputSink = AudioOutputSinkCategory.internalSpeaker,
  }) async {
    final record = RawCoreStreamRecord(
      trackId: trackId,
      title: title,
      artist: artist,
      bitrate: bitrate,
      codec: codec,
      durationListenedMs: durationListenedMs,
      totalDurationMs: totalDurationMs,
      completionReason: completionReason,
      outputSink: outputSink,
      timestamp: DateTime.now(),
    );

    _inMemoryBuffer.add(record);
    if (_inMemoryBuffer.length > 200) {
      _inMemoryBuffer.removeAt(0);
    }

    _recordController.add(record);

    // Append to local JSONL audit file
    if (_logFile != null) {
      try {
        final line = '${jsonEncode(record.toJson())}\n';
        await _logFile?.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (_) {}
    }
  }

  /// Calculates total listening time in seconds.
  int get totalListeningSeconds {
    final sumMs = _inMemoryBuffer.fold<int>(
        0, (acc, item) => acc + item.durationListenedMs);
    return sumMs ~/ 1000;
  }

  /// Calculates percentage of streams meeting the 320 kbps studio invariant.
  double get studioBitrateCompliancePercent {
    if (_inMemoryBuffer.isEmpty) return 100.0;
    final compliantCount =
        _inMemoryBuffer.where((r) => r.isFullBitrateCompliant).length;
    return (compliantCount / _inMemoryBuffer.length) * 100.0;
  }

  void dispose() {
    _recordController.close();
  }
}
