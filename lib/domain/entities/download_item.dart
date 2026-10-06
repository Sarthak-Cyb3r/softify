import 'track.dart';

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  paused;

  static DownloadStatus fromString(String status) {
    return switch (status.toLowerCase()) {
      'downloading' => DownloadStatus.downloading,
      'completed' => DownloadStatus.completed,
      'failed' => DownloadStatus.failed,
      'paused' => DownloadStatus.paused,
      _ => DownloadStatus.queued,
    };
  }

  String toDbString() => name;
}

class DownloadItem {
  final String trackId;
  final Track? track;
  final String relativePath;
  final String containerFormat;
  final int fileSizeBytes;
  final int bytesDownloaded;
  final DownloadStatus status;
  final DateTime createdAt;

  const DownloadItem({
    required this.trackId,
    this.track,
    required this.relativePath,
    this.containerFormat = 'm4a',
    this.fileSizeBytes = 0,
    this.bytesDownloaded = 0,
    required this.status,
    required this.createdAt,
  });

  double get progress =>
      fileSizeBytes > 0 ? (bytesDownloaded / fileSizeBytes).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => status == DownloadStatus.completed;

  DownloadItem copyWith({
    String? trackId,
    Track? track,
    String? relativePath,
    String? containerFormat,
    int? fileSizeBytes,
    int? bytesDownloaded,
    DownloadStatus? status,
    DateTime? createdAt,
  }) {
    return DownloadItem(
      trackId: trackId ?? this.trackId,
      track: track ?? this.track,
      relativePath: relativePath ?? this.relativePath,
      containerFormat: containerFormat ?? this.containerFormat,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItem &&
          runtimeType == other.runtimeType &&
          trackId == other.trackId &&
          status == other.status &&
          bytesDownloaded == other.bytesDownloaded;

  @override
  int get hashCode => trackId.hashCode ^ status.hashCode;
}
