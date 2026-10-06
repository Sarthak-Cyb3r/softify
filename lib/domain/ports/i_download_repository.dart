import '../entities/audio_quality_preset.dart';
import '../entities/download_item.dart';
import '../entities/track.dart';

abstract class IDownloadRepository {
  /// Enqueues a track for background downloading.
  Future<void> queueDownload(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  });

  /// Pauses an active download.
  Future<void> pauseDownload(String trackId);

  /// Resumes a paused or failed download.
  Future<void> resumeDownload(String trackId);

  /// Cancels an active download and cleans up any partial temporary files.
  Future<void> cancelDownload(String trackId);

  /// Deletes a download.
  /// Rule: Deletes local file from disk FIRST; only after filesystem removal
  /// succeeds, prunes the record from the database.
  Future<void> deleteDownload(String trackId);

  /// Watches all downloads with real-time progress updates.
  Stream<List<DownloadItem>> watchDownloads();

  /// Watches a specific track's download status.
  Stream<DownloadItem?> watchDownload(String trackId);

  /// Retrieves a specific download item.
  Future<DownloadItem?> getDownload(String trackId);

  /// Checks if a track has a completed download whose file physically exists on disk.
  Future<bool> isDownloaded(String trackId);

  /// Returns the absolute path of the downloaded file if it physically exists.
  /// If missing or corrupt, returns null and cleans up stale records.
  Future<String?> getDownloadedFilePath(String trackId);

  /// Disposes background download listeners and resources.
  Future<void> dispose();
}
