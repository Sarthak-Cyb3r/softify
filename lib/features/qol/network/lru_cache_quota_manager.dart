// ============================================================================
// Softify Quality of Life (QoL) Feature 46:
// Configurable Disk Cache Size & Automated LRU Audio Chunk Purge Manager
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../presentation/theme/app_theme.dart';
import '../../../services/chunk_cache_service.dart';

// ============================================================================
// SharedPreferences Persistence Layer
// ============================================================================

/// Storage key for persisting the chosen disk cache quota limit.
const String kCacheQuotaLimitPrefKey = 'softify_disk_cache_quota_limit';

/// Lightweight, self-contained SharedPreferences persistence engine
/// matching the standard package:shared_preferences API contract.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Injects initial key-value mappings for test suites.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Clears singleton and test mock values.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Singleton accessor with asynchronous disk hydration.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;
    try {
      file = _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key.toString()] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // Graceful fallback to memory store
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_store);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  String? getString(String key) {
    final val = _store[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  int? getInt(String key) {
    final val = _store[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _store[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }
}

// ============================================================================
// Disk Cache Quota Limit Options
// ============================================================================

/// Configurable disk cache quota limits for Softify's audio chunk engine.
enum CacheQuotaLimit {
  mb500(
    id: '500mb',
    label: '500 MB',
    shortLabel: '500MB',
    bytes: 500 * 1024 * 1024, // 524,288,000 bytes
  ),
  gb1(
    id: '1gb',
    label: '1 GB',
    shortLabel: '1GB',
    bytes: 1024 * 1024 * 1024, // 1,073,741,824 bytes
  ),
  gb2(
    id: '2gb',
    label: '2 GB',
    shortLabel: '2GB',
    bytes: 2 * 1024 * 1024 * 1024, // 2,147,483,648 bytes
  ),
  gb5(
    id: '5gb',
    label: '5 GB',
    shortLabel: '5GB',
    bytes: 5 * 1024 * 1024 * 1024, // 5,368,709,120 bytes
  ),
  unlimited(
    id: 'unlimited',
    label: 'Unlimited',
    shortLabel: '∞',
    bytes: null,
  );

  final String id;
  final String label;
  final String shortLabel;
  final int? bytes;

  const CacheQuotaLimit({
    required this.id,
    required this.label,
    required this.shortLabel,
    this.bytes,
  });

  /// True if the cache has no upper size quota limit.
  bool get isUnlimited => bytes == null;

  /// Parse quota from unique ID string, falling back to 2 GB default.
  static CacheQuotaLimit fromId(String? id) {
    if (id == null) return CacheQuotaLimit.gb2;
    for (final limit in CacheQuotaLimit.values) {
      if (limit.id.toLowerCase() == id.trim().toLowerCase()) {
        return limit;
      }
    }
    return CacheQuotaLimit.gb2;
  }

  /// Parse quota from byte count.
  static CacheQuotaLimit fromBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return CacheQuotaLimit.unlimited;
    for (final limit in CacheQuotaLimit.values) {
      if (limit.bytes == bytes) return limit;
    }
    return CacheQuotaLimit.gb2;
  }
}

// ============================================================================
// Cache File Records & Purge Models
// ============================================================================

/// Metadata record for an individual cached file during LRU analysis.
@immutable
class CacheFileRecord {
  final File file;
  final String path;
  final int sizeBytes;
  final DateTime lastAccessed;

  const CacheFileRecord({
    required this.file,
    required this.path,
    required this.sizeBytes,
    required this.lastAccessed,
  });

  @override
  String toString() =>
      'CacheFileRecord(path: $path, size: $sizeBytes, lastAccessed: $lastAccessed)';
}

/// Disk cache usage overview.
@immutable
class CacheStorageUsage {
  final int totalBytes;
  final int fileCount;
  final DateTime scannedAt;

  const CacheStorageUsage({
    required this.totalBytes,
    required this.fileCount,
    required this.scannedAt,
  });

  double get sizeMb => totalBytes / (1024.0 * 1024.0);
  double get sizeGb => totalBytes / (1024.0 * 1024.0 * 1024.0);

  String get formattedSize {
    if (totalBytes >= 1024 * 1024 * 1024) {
      return '${sizeGb.toStringAsFixed(2)} GB';
    }
    return '${sizeMb.toStringAsFixed(2)} MB';
  }

  static final CacheStorageUsage zero = CacheStorageUsage(
    totalBytes: 0,
    fileCount: 0,
    scannedAt: _epochZero,
  );
}

final DateTime _epochZero = DateTime.fromMillisecondsSinceEpoch(0);

/// Detailed results of an executed LRU purge operation.
@immutable
class PurgeResult {
  final int purgedFilesCount;
  final int purgedBytes;
  final int remainingFilesCount;
  final int remainingSizeBytes;
  final int? targetBytes;
  final DateTime completedAt;
  final bool success;
  final String? errorMessage;
  final Duration duration;

  const PurgeResult({
    required this.purgedFilesCount,
    required this.purgedBytes,
    required this.remainingFilesCount,
    required this.remainingSizeBytes,
    this.targetBytes,
    required this.completedAt,
    this.success = true,
    this.errorMessage,
    this.duration = Duration.zero,
  });

  double get purgedMb => purgedBytes / (1024.0 * 1024.0);
  double get remainingMb => remainingSizeBytes / (1024.0 * 1024.0);
  String get formattedPurgedMb => '${purgedMb.toStringAsFixed(2)} MB';
  String get formattedRemainingMb => '${remainingMb.toStringAsFixed(2)} MB';

  PurgeResult copyWith({
    int? purgedFilesCount,
    int? purgedBytes,
    int? remainingFilesCount,
    int? remainingSizeBytes,
    int? targetBytes,
    DateTime? completedAt,
    bool? success,
    String? errorMessage,
    Duration? duration,
  }) {
    return PurgeResult(
      purgedFilesCount: purgedFilesCount ?? this.purgedFilesCount,
      purgedBytes: purgedBytes ?? this.purgedBytes,
      remainingFilesCount: remainingFilesCount ?? this.remainingFilesCount,
      remainingSizeBytes: remainingSizeBytes ?? this.remainingSizeBytes,
      targetBytes: targetBytes ?? this.targetBytes,
      completedAt: completedAt ?? this.completedAt,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      duration: duration ?? this.duration,
    );
  }
}

// ============================================================================
// Pure LRU Purge Algorithm Engine
// ============================================================================

/// High-performance file scanner and Least Recently Used (LRU) purge algorithm.
///
/// Trims oldest accessed chunks first when cache size exceeds configured quotas,
/// cleans up orphaned track directories, and reports detailed purge metrics.
class LruPurgeEngine {
  final Directory? customDirectory;

  const LruPurgeEngine({this.customDirectory});

  /// Resolves the effective chunk cache storage directory.
  Future<Directory> resolveCacheDirectory() async {
    if (customDirectory != null) {
      return customDirectory!;
    }

    try {
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isNotEmpty) {
          final linuxDir =
              Directory(p.join(home, '.cache', 'softify', 'Storage', 'chunks'));
          if (!await linuxDir.exists()) {
            await linuxDir.create(recursive: true);
          }
          return linuxDir;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final chunksDir = Directory(p.join(tempDir.path, 'chunks'));
      if (!await chunksDir.exists()) {
        await chunksDir.create(recursive: true);
      }
      return chunksDir;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Scans the cache directory and collects sorted file records.
  Future<List<CacheFileRecord>> scanFiles([Directory? targetDir]) async {
    final dir = targetDir ?? await resolveCacheDirectory();
    if (!await dir.exists()) return [];

    final records = <CacheFileRecord>[];
    try {
      final entities =
          await dir.list(recursive: true, followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            // In Softify, chunk access touches file modified timestamp
            final lastTime = stat.modified.isAfter(stat.accessed)
                ? stat.modified
                : stat.accessed;
            records.add(CacheFileRecord(
              file: entity,
              path: entity.path,
              sizeBytes: stat.size,
              lastAccessed: lastTime,
            ));
          } catch (_) {
            // File may have been removed concurrently
          }
        }
      }
    } catch (_) {}

    // Sort ascending by lastAccessed: oldest accessed first
    records.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
    return records;
  }

  /// Calculates current total cache byte size and chunk file count.
  Future<CacheStorageUsage> calculateUsage([Directory? targetDir]) async {
    final records = await scanFiles(targetDir);
    int totalBytes = 0;
    for (final record in records) {
      totalBytes += record.sizeBytes;
    }
    return CacheStorageUsage(
      totalBytes: totalBytes,
      fileCount: records.length,
      scannedAt: DateTime.now(),
    );
  }

  /// Trims least recently accessed chunk files until total size falls below [targetBytes].
  ///
  /// If [headroomRatio] is specified (e.g. 0.90), it purges down to 90% of [targetBytes]
  /// to provide headroom for incoming chunk writes.
  Future<PurgeResult> purgeToQuota({
    required int targetBytes,
    double headroomRatio = 1.0,
    Directory? targetDir,
  }) async {
    final stopwatch = Stopwatch()..start();
    final dir = targetDir ?? await resolveCacheDirectory();
    final records = await scanFiles(dir);

    int currentTotalBytes = 0;
    for (final r in records) {
      currentTotalBytes += r.sizeBytes;
    }

    final effectiveTarget = (targetBytes * headroomRatio).round();

    if (currentTotalBytes <= effectiveTarget) {
      stopwatch.stop();
      return PurgeResult(
        purgedFilesCount: 0,
        purgedBytes: 0,
        remainingFilesCount: records.length,
        remainingSizeBytes: currentTotalBytes,
        targetBytes: targetBytes,
        completedAt: DateTime.now(),
        duration: stopwatch.elapsed,
      );
    }

    int purgedCount = 0;
    int purgedBytes = 0;

    for (final record in records) {
      if (currentTotalBytes <= effectiveTarget) {
        break;
      }

      try {
        if (await record.file.exists()) {
          await record.file.delete();
          currentTotalBytes -= record.sizeBytes;
          purgedBytes += record.sizeBytes;
          purgedCount++;
        }
      } catch (_) {
        // Skip inaccessible files
      }
    }

    // Prune empty parent chunk directories
    await _pruneEmptyDirectories(dir);

    stopwatch.stop();
    return PurgeResult(
      purgedFilesCount: purgedCount,
      purgedBytes: purgedBytes,
      remainingFilesCount: records.length - purgedCount,
      remainingSizeBytes: currentTotalBytes,
      targetBytes: targetBytes,
      completedAt: DateTime.now(),
      duration: stopwatch.elapsed,
    );
  }

  /// Purges a specific fraction [ratio] (0.0 to 1.0) of oldest files.
  Future<PurgeResult> purgeOldestFraction({
    double ratio = 0.25,
    Directory? targetDir,
  }) async {
    final stopwatch = Stopwatch()..start();
    final dir = targetDir ?? await resolveCacheDirectory();
    final records = await scanFiles(dir);

    if (records.isEmpty) {
      stopwatch.stop();
      return PurgeResult(
        purgedFilesCount: 0,
        purgedBytes: 0,
        remainingFilesCount: 0,
        remainingSizeBytes: 0,
        completedAt: DateTime.now(),
        duration: stopwatch.elapsed,
      );
    }

    final countToPurge = (records.length * ratio).ceil().clamp(0, records.length);
    int currentTotalBytes = 0;
    for (final r in records) {
      currentTotalBytes += r.sizeBytes;
    }

    int purgedCount = 0;
    int purgedBytes = 0;

    for (int i = 0; i < countToPurge; i++) {
      final record = records[i];
      try {
        if (await record.file.exists()) {
          await record.file.delete();
          currentTotalBytes -= record.sizeBytes;
          purgedBytes += record.sizeBytes;
          purgedCount++;
        }
      } catch (_) {}
    }

    await _pruneEmptyDirectories(dir);

    stopwatch.stop();
    return PurgeResult(
      purgedFilesCount: purgedCount,
      purgedBytes: purgedBytes,
      remainingFilesCount: records.length - purgedCount,
      remainingSizeBytes: currentTotalBytes,
      completedAt: DateTime.now(),
      duration: stopwatch.elapsed,
    );
  }

  /// Completely empties all cached chunk files and directories.
  Future<PurgeResult> clearAll([Directory? targetDir]) async {
    final stopwatch = Stopwatch()..start();
    final dir = targetDir ?? await resolveCacheDirectory();
    final records = await scanFiles(dir);

    int purgedCount = 0;
    int purgedBytes = 0;

    for (final record in records) {
      try {
        if (await record.file.exists()) {
          await record.file.delete();
          purgedBytes += record.sizeBytes;
          purgedCount++;
        }
      } catch (_) {}
    }

    await _pruneEmptyDirectories(dir);

    stopwatch.stop();
    return PurgeResult(
      purgedFilesCount: purgedCount,
      purgedBytes: purgedBytes,
      remainingFilesCount: 0,
      remainingSizeBytes: 0,
      completedAt: DateTime.now(),
      duration: stopwatch.elapsed,
    );
  }

  /// Recursively deletes empty folders inside [dir].
  Future<void> _pruneEmptyDirectories(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      final entities =
          await dir.list(recursive: true, followLinks: false).toList();
      final subdirs = entities.whereType<Directory>().toList();

      // Deepest subdirectories first
      subdirs.sort((a, b) => b.path.length.compareTo(a.path.length));

      for (final subdir in subdirs) {
        if (await subdir.exists()) {
          final entries = await subdir.list(followLinks: false).toList();
          if (entries.isEmpty) {
            await subdir.delete();
          }
        }
      }
    } catch (_) {}
  }
}

// ============================================================================
// Riverpod State & Notifier
// ============================================================================

/// Immutable state representation for disk cache quota management.
@immutable
class LruCacheQuotaState {
  final CacheQuotaLimit quota;
  final int currentSizeBytes;
  final int fileCount;
  final bool isLoading;
  final bool isPurging;
  final PurgeResult? lastPurgeResult;
  final String? errorMessage;
  final String? cachePath;

  const LruCacheQuotaState({
    this.quota = CacheQuotaLimit.gb2,
    this.currentSizeBytes = 0,
    this.fileCount = 0,
    this.isLoading = false,
    this.isPurging = false,
    this.lastPurgeResult,
    this.errorMessage,
    this.cachePath,
  });

  /// Current size formatted strictly in MB.
  double get sizeMb => currentSizeBytes / (1024.0 * 1024.0);

  /// Current size formatted in GB.
  double get sizeGb => currentSizeBytes / (1024.0 * 1024.0 * 1024.0);

  /// Clean display string for current size.
  String get formattedCurrentSize {
    if (currentSizeBytes >= 1024 * 1024 * 1024) {
      return '${sizeGb.toStringAsFixed(2)} GB';
    }
    return '${sizeMb.toStringAsFixed(2)} MB';
  }

  /// Display string for the quota limit.
  String get formattedQuotaLimit => quota.label;

  /// Fraction of quota currently utilized (0.0 to 1.0, or 0.0 if unlimited).
  double get usageRatio {
    if (quota.isUnlimited || quota.bytes == null || quota.bytes! <= 0) {
      return 0.0;
    }
    return (currentSizeBytes / quota.bytes!).clamp(0.0, 1.0);
  }

  /// Utilization percentage (0.0% to 100.0%).
  double get usagePercentage => usageRatio * 100.0;

  /// True if current disk footprint is above 85% of allowed quota.
  bool get isNearQuota => !quota.isUnlimited && usageRatio >= 0.85;

  /// True if current disk footprint exceeds the allowed quota.
  bool get isOverQuota =>
      !quota.isUnlimited &&
      quota.bytes != null &&
      currentSizeBytes > quota.bytes!;

  /// Status string e.g., "120.50 MB of 2 GB used (5.8%)".
  String get statusDescription {
    if (quota.isUnlimited) {
      return '$formattedCurrentSize cached (Unlimited quota)';
    }
    return '$formattedCurrentSize of ${quota.label} used (${usagePercentage.toStringAsFixed(1)}%)';
  }

  LruCacheQuotaState copyWith({
    CacheQuotaLimit? quota,
    int? currentSizeBytes,
    int? fileCount,
    bool? isLoading,
    bool? isPurging,
    PurgeResult? lastPurgeResult,
    String? errorMessage,
    String? cachePath,
    bool clearError = false,
  }) {
    return LruCacheQuotaState(
      quota: quota ?? this.quota,
      currentSizeBytes: currentSizeBytes ?? this.currentSizeBytes,
      fileCount: fileCount ?? this.fileCount,
      isLoading: isLoading ?? this.isLoading,
      isPurging: isPurging ?? this.isPurging,
      lastPurgeResult: lastPurgeResult ?? this.lastPurgeResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      cachePath: cachePath ?? this.cachePath,
    );
  }
}

/// StateNotifier coordinating cache quota settings, real-time usage scanning,
/// and automated LRU purge execution.
class LruCacheQuotaNotifier extends StateNotifier<LruCacheQuotaState> {
  final LruPurgeEngine _engine;
  SharedPreferences? _prefs;

  LruCacheQuotaNotifier({
    LruPurgeEngine? engine,
    Directory? customCacheDirectory,
    SharedPreferences? prefs,
    CacheQuotaLimit initialQuota = CacheQuotaLimit.gb2,
  })  : _engine = engine ?? LruPurgeEngine(customDirectory: customCacheDirectory),
        _prefs = prefs,
        super(LruCacheQuotaState(quota: initialQuota)) {
    initialize();
  }

  /// Initializes persisted quota limit and calculates initial disk usage.
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedId = _prefs?.getString(kCacheQuotaLimitPrefKey);
      final activeQuota =
          savedId != null ? CacheQuotaLimit.fromId(savedId) : state.quota;

      // Sync with native ChunkCacheService
      _syncChunkCacheServiceLimit(activeQuota);

      final dir = await _engine.resolveCacheDirectory();
      final usage = await _engine.calculateUsage(dir);

      state = state.copyWith(
        quota: activeQuota,
        currentSizeBytes: usage.totalBytes,
        fileCount: usage.fileCount,
        cachePath: dir.path,
        isLoading: false,
      );

      // Auto-purge if current size exceeds active quota
      if (!activeQuota.isUnlimited &&
          activeQuota.bytes != null &&
          usage.totalBytes > activeQuota.bytes!) {
        await purgeToQuota();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize cache quota: $e',
      );
    }
  }

  /// Sets and persists a new disk cache quota limit.
  ///
  /// If the current cache usage exceeds the newly assigned quota,
  /// an immediate LRU purge is triggered.
  Future<void> setQuota(CacheQuotaLimit newQuota) async {
    state = state.copyWith(quota: newQuota);

    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(kCacheQuotaLimitPrefKey, newQuota.id);

      // Sync with ChunkCacheService
      _syncChunkCacheServiceLimit(newQuota);

      if (!newQuota.isUnlimited &&
          newQuota.bytes != null &&
          state.currentSizeBytes > newQuota.bytes!) {
        await purgeToQuota(targetBytes: newQuota.bytes!);
      } else {
        await refreshUsage();
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to update cache quota: $e',
      );
    }
  }

  /// Refreshes current cache byte footprint and chunk count from disk.
  Future<void> refreshUsage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dir = await _engine.resolveCacheDirectory();
      final usage = await _engine.calculateUsage(dir);
      state = state.copyWith(
        currentSizeBytes: usage.totalBytes,
        fileCount: usage.fileCount,
        cachePath: dir.path,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to calculate cache usage: $e',
      );
    }
  }

  /// Performs an LRU purge down to the current quota or optional [targetBytes].
  Future<PurgeResult> purgeToQuota({
    int? targetBytes,
    double headroomRatio = 0.90,
  }) async {
    state = state.copyWith(isPurging: true, clearError: true);

    try {
      final effectiveTarget = targetBytes ??
          (state.quota.isUnlimited
              ? state.currentSizeBytes
              : (state.quota.bytes ?? state.currentSizeBytes));

      final dir = await _engine.resolveCacheDirectory();
      final result = await _engine.purgeToQuota(
        targetBytes: effectiveTarget,
        headroomRatio: headroomRatio,
        targetDir: dir,
      );

      state = state.copyWith(
        isPurging: false,
        currentSizeBytes: result.remainingSizeBytes,
        fileCount: result.remainingFilesCount,
        lastPurgeResult: result,
      );

      return result;
    } catch (e) {
      final failure = PurgeResult(
        purgedFilesCount: 0,
        purgedBytes: 0,
        remainingFilesCount: state.fileCount,
        remainingSizeBytes: state.currentSizeBytes,
        completedAt: DateTime.now(),
        success: false,
        errorMessage: e.toString(),
      );
      state = state.copyWith(
        isPurging: false,
        lastPurgeResult: failure,
        errorMessage: 'Purge failed: $e',
      );
      return failure;
    }
  }

  /// Purges a fraction of the oldest chunks (e.g. 25%).
  Future<PurgeResult> purgeOldest({double ratio = 0.25}) async {
    state = state.copyWith(isPurging: true, clearError: true);
    try {
      final dir = await _engine.resolveCacheDirectory();
      final result = await _engine.purgeOldestFraction(
        ratio: ratio,
        targetDir: dir,
      );

      state = state.copyWith(
        isPurging: false,
        currentSizeBytes: result.remainingSizeBytes,
        fileCount: result.remainingFilesCount,
        lastPurgeResult: result,
      );

      return result;
    } catch (e) {
      final failure = PurgeResult(
        purgedFilesCount: 0,
        purgedBytes: 0,
        remainingFilesCount: state.fileCount,
        remainingSizeBytes: state.currentSizeBytes,
        completedAt: DateTime.now(),
        success: false,
        errorMessage: e.toString(),
      );
      state = state.copyWith(
        isPurging: false,
        lastPurgeResult: failure,
        errorMessage: 'Purge failed: $e',
      );
      return failure;
    }
  }

  /// Completely wipes all audio chunks in the cache directory.
  Future<PurgeResult> clearEntireCache() async {
    state = state.copyWith(isPurging: true, clearError: true);
    try {
      final dir = await _engine.resolveCacheDirectory();
      final result = await _engine.clearAll(dir);

      try {
        await ChunkCacheService.instance.clearAll();
      } catch (_) {}

      state = state.copyWith(
        isPurging: false,
        currentSizeBytes: 0,
        fileCount: 0,
        lastPurgeResult: result,
      );

      return result;
    } catch (e) {
      final failure = PurgeResult(
        purgedFilesCount: 0,
        purgedBytes: 0,
        remainingFilesCount: state.fileCount,
        remainingSizeBytes: state.currentSizeBytes,
        completedAt: DateTime.now(),
        success: false,
        errorMessage: e.toString(),
      );
      state = state.copyWith(
        isPurging: false,
        lastPurgeResult: failure,
        errorMessage: 'Clear failed: $e',
      );
      return failure;
    }
  }

  void _syncChunkCacheServiceLimit(CacheQuotaLimit limit) {
    try {
      if (limit.isUnlimited) {
        // Very large limit for unlimited (1 TB)
        ChunkCacheService.instance
            .setMaxCacheSize(1024 * 1024 * 1024 * 1024);
      } else if (limit.bytes != null) {
        ChunkCacheService.instance.setMaxCacheSize(limit.bytes!);
      }
    } catch (_) {}
  }
}

// ============================================================================
// Providers
// ============================================================================

/// Primary StateNotifierProvider for cache quota settings and LRU purge management.
final lruCacheQuotaNotifierProvider =
    StateNotifierProvider<LruCacheQuotaNotifier, LruCacheQuotaState>((ref) {
  return LruCacheQuotaNotifier();
});

/// Readable state provider for the cache quota state.
final lruCacheQuotaProvider = Provider<LruCacheQuotaState>((ref) {
  return ref.watch(lruCacheQuotaNotifierProvider);
});

/// Quick provider for the currently selected quota limit.
final currentCacheQuotaLimitProvider = Provider<CacheQuotaLimit>((ref) {
  return ref.watch(lruCacheQuotaProvider).quota;
});

// ============================================================================
// UI Component: CacheQuotaSelectorCard
// ============================================================================

/// Production-grade Material 3 card widget providing interactive disk cache
/// quota configuration, storage capacity visualization, and LRU chunk trimming.
class CacheQuotaSelectorCard extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool showHeader;
  final bool showPurgeActions;
  final VoidCallback? onPurgeCompleted;

  const CacheQuotaSelectorCard({
    super.key,
    this.margin,
    this.padding,
    this.showHeader = true,
    this.showPurgeActions = true,
    this.onPurgeCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(lruCacheQuotaNotifierProvider);
    final notifier = ref.read(lruCacheQuotaNotifierProvider.notifier);

    final indicatorColor = state.quota.isUnlimited
        ? tokens.accentCyan
        : (state.isOverQuota
            ? tokens.error
            : (state.isNearQuota ? Colors.amber : tokens.accent));

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
          width: 1.0,
        ),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Section
          if (showHeader) ...[
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(
                    Icons.disc_full_rounded,
                    size: 20,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disk Cache Quota',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Automatic LRU eviction of cached audio chunks',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quota badge pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(
                      color: tokens.divider,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    state.quota.label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // 2. Capacity Progress Bar & Utilization Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.formattedCurrentSize,
                style: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                state.quota.isUnlimited
                    ? 'Unlimited Quota'
                    : 'Limit: ${state.quota.label} (${state.usagePercentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar track
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: state.quota.isUnlimited ? 0.0 : state.usageRatio,
                backgroundColor: tokens.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // File count and cache directory info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.fileCount} audio chunks cached',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  color: tokens.textMuted,
                ),
              ),
              if (state.isLoading || state.isPurging)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(tokens.accent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isPurging ? 'Purging LRU...' : 'Scanning...',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 11,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Quota Selection Limit Options
          Text(
            'SELECT QUOTA LIMIT',
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CacheQuotaLimit.values.map((limit) {
              final isSelected = state.quota == limit;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('quota_option_${limit.id}'),
                  onTap: () => notifier.setQuota(limit),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: AnimatedContainer(
                    duration: tokens.motionQuick,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.accent
                          : tokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: isSelected
                            ? tokens.accent
                            : tokens.divider,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      limit.label,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.black : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // 4. Purge Result Feedback Banner
          if (state.lastPurgeResult != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('purge_result_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: tokens.divider,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.lastPurgeResult!.success
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    size: 16,
                    color: state.lastPurgeResult!.success
                        ? tokens.accentCyan
                        : Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.lastPurgeResult!.purgedFilesCount > 0
                          ? 'Purged ${state.lastPurgeResult!.purgedFilesCount} files (${state.lastPurgeResult!.formattedPurgedMb} freed)'
                          : 'Cache is within target limits. No files purged.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Purge Actions
          if (showPurgeActions) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 12),
            Row(
              children: [
                // Purge LRU Button
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_purge_lru'),
                    onPressed: state.isPurging || state.isLoading
                        ? null
                        : () async {
                            await notifier.purgeToQuota();
                            onPurgeCompleted?.call();
                          },
                    icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                    label: const Text(
                      'Purge LRU Now',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.accent,
                      side: BorderSide(
                        color: tokens.accent.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Clear All Cache Button
                TextButton.icon(
                  key: const Key('btn_clear_cache'),
                  onPressed: state.isPurging || state.isLoading
                      ? null
                      : () async {
                          await notifier.clearEntireCache();
                          onPurgeCompleted?.call();
                        },
                  icon: Icon(Icons.delete_sweep_rounded,
                      size: 16, color: tokens.error),
                  label: Text(
                    'Clear All',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.error,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Refresh Usage Icon
                IconButton(
                  key: const Key('btn_refresh_quota'),
                  tooltip: 'Refresh Cache Usage',
                  onPressed: state.isPurging || state.isLoading
                      ? null
                      : () => notifier.refreshUsage(),
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
