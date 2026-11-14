import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Chunk size modeled after Spotify's native storage chunk cache (128 KB).
const int kAudioChunkSize = 128 * 1024; // 131,072 bytes

/// High-performance chunk-based sparse audio disk cache.
/// Preserves strict 320 kbps bit-exact audio streams with zero re-encoding
/// and enforces automated LRU disk quota cleanup.
class ChunkCacheService {
  static final ChunkCacheService instance = ChunkCacheService._internal();

  ChunkCacheService._internal();

  Directory? _cacheDir;
  int _maxCacheSizeBytes = 2 * 1024 * 1024 * 1024; // 2 GB default limit

  int get maxCacheSizeBytes => _maxCacheSizeBytes;

  void setMaxCacheSize(int bytes) {
    _maxCacheSizeBytes = bytes;
  }

  /// Initializes the cache directory on host OS.
  Future<void> initialize() async {
    try {
      Directory baseDir;
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        baseDir = Directory(p.join(home, '.cache', 'softify', 'Storage'));
      } else {
        baseDir = await getTemporaryDirectory();
      }

      _cacheDir = Directory(p.join(baseDir.path, 'chunks'));
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }

  /// Generates the directory path for a track's sparse chunks.
  Directory? _trackChunkDir(String trackId) {
    if (_cacheDir == null) return null;
    return Directory(p.join(_cacheDir!.path, trackId));
  }

  /// Writes a 128 KB chunk of 320 kbps audio data to disk.
  Future<void> writeChunk({
    required String trackId,
    required int chunkIndex,
    required Uint8List data,
  }) async {
    final trackDir = _trackChunkDir(trackId);
    if (trackDir == null) return;

    if (!await trackDir.exists()) {
      await trackDir.create(recursive: true);
    }

    final chunkFile = File(p.join(trackDir.path, 'chunk_$chunkIndex.bin'));
    await chunkFile.writeAsBytes(data, flush: true);

    // Check disk usage after writes
    _evictLruIfNecessary();
  }

  /// Reads a 128 KB chunk from disk if present.
  Future<Uint8List?> readChunk({
    required String trackId,
    required int chunkIndex,
  }) async {
    final trackDir = _trackChunkDir(trackId);
    if (trackDir == null) return null;

    final chunkFile = File(p.join(trackDir.path, 'chunk_$chunkIndex.bin'));
    if (await chunkFile.exists()) {
      // Touch file to update access time for LRU
      await chunkFile.setLastModified(DateTime.now());
      return await chunkFile.readAsBytes();
    }
    return null;
  }

  /// Checks if all chunks for a given track duration/size are available offline.
  Future<bool> isTrackFullyCached(String trackId, int expectedTotalBytes) async {
    final trackDir = _trackChunkDir(trackId);
    if (trackDir == null || !await trackDir.exists()) return false;

    final totalChunks = (expectedTotalBytes / kAudioChunkSize).ceil();
    for (int i = 0; i < totalChunks; i++) {
      final chunkFile = File(p.join(trackDir.path, 'chunk_$i.bin'));
      if (!await chunkFile.exists()) return false;
    }
    return true;
  }

  /// Enforces LRU eviction if cache directory exceeds max size quota.
  Future<void> _evictLruIfNecessary() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) return;

    try {
      final files = await _cacheDir!
          .list(recursive: true, followLinks: false)
          .where((f) => f is File)
          .cast<File>()
          .toList();

      int totalSize = 0;
      final fileStats = <File, DateTime>{};

      for (final file in files) {
        final stat = await file.stat();
        totalSize += stat.size;
        fileStats[file] = stat.modified;
      }

      if (totalSize > _maxCacheSizeBytes) {
        // Sort oldest modified first
        files.sort((a, b) =>
            (fileStats[a] ?? DateTime(0)).compareTo(fileStats[b] ?? DateTime(0)));

        for (final file in files) {
          if (totalSize <= (_maxCacheSizeBytes * 0.85)) break; // Evict down to 85%
          final stat = await file.stat();
          await file.delete();
          totalSize -= stat.size;
        }
      }
    } catch (_) {}
  }

  /// Clears all cached audio chunks.
  Future<void> clearAll() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }
  }
}
