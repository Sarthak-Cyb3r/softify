import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/remote_config_repository.dart';
import '../../data/updater/github_release_update_checker.dart';
import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/ports/i_remote_config.dart';
import '../../domain/ports/i_update_checker.dart';
import 'player_providers.dart';

final remoteConfigRepositoryProvider = Provider<RemoteConfigRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RemoteConfigRepository(db: db);
});

final updateCheckerProvider = Provider<IUpdateChecker>((ref) {
  return GitHubReleaseUpdateChecker(repoOwner: 'Sarthak-Cyb3r', repoName: 'softify');
});

final pipedInstancesStreamProvider = StreamProvider<List<PipedInstanceRow>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.pipedInstances)
        ..orderBy([(t) => OrderingTerm.desc(t.isHealthy), (t) => OrderingTerm.asc(t.latencyMs)]))
      .watch();
});

final remoteConfigFutureProvider = FutureProvider<RemoteConfigData>((ref) {
  final repo = ref.watch(remoteConfigRepositoryProvider);
  return repo.fetchLatestConfig();
});

const String kAppVersion = '2.0.9';
final currentAppVersionProvider = Provider<String>((ref) => kAppVersion);

final updateCheckFutureProvider = FutureProvider<AppReleaseInfo?>((ref) {
  final checker = ref.watch(updateCheckerProvider);
  final currentVersion = ref.watch(currentAppVersionProvider);
  return checker.checkForUpdate(currentVersion);
});

// Audio Quality Setting Notifier
class AudioQualityNotifier extends StateNotifier<AudioQualityPreset> {
  final AppDatabase _db;

  AudioQualityNotifier(this._db) : super(AudioQualityPreset.standard) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    final row = await (_db.select(_db.settings)..where((t) => t.key.equals('audio_quality'))).getSingleOrNull();
    if (row != null) {
      final preset = row.value == 'high'
          ? AudioQualityPreset.high
          : (row.value == 'low' ? AudioQualityPreset.low : AudioQualityPreset.standard);
      state = preset;
    }
  }

  Future<void> setQuality(AudioQualityPreset preset) async {
    state = preset;
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingRow(
            key: 'audio_quality',
            value: preset.name,
          ),
        );
  }
}

final audioQualityPresetProvider =
    StateNotifierProvider<AudioQualityNotifier, AudioQualityPreset>((ref) {
  final db = ref.watch(databaseProvider);
  return AudioQualityNotifier(db);
});

// Crossfade Duration Setting Notifier (0s to 12s)
class CrossfadeDurationNotifier extends StateNotifier<int> {
  final AppDatabase _db;
  final Ref _ref;

  CrossfadeDurationNotifier(this._db, this._ref) : super(0) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals('crossfade_duration')))
          .getSingleOrNull();
      if (row != null) {
        final sec = int.tryParse(row.value) ?? 0;
        state = sec;
        _ref.read(audioHandlerProvider).setCrossfadeSeconds(sec);
      }
    } catch (_) {}
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    final clamped = seconds.clamp(0, 12);
    state = clamped;
    _ref.read(audioHandlerProvider).setCrossfadeSeconds(clamped);
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingRow(
            key: 'crossfade_duration',
            value: clamped.toString(),
          ),
        );
  }
}

final crossfadeDurationProvider =
    StateNotifierProvider<CrossfadeDurationNotifier, int>((ref) {
  final db = ref.watch(databaseProvider);
  return CrossfadeDurationNotifier(db, ref);
});

class StorageBreakdown {
  final int downloadedBytes;
  final int tempCacheBytes;
  final int lyricsCacheCount;
  final int lyricsEstimatedBytes;
  final int totalBytes;

  const StorageBreakdown({
    this.downloadedBytes = 0,
    this.tempCacheBytes = 0,
    this.lyricsCacheCount = 0,
    this.lyricsEstimatedBytes = 0,
    this.totalBytes = 0,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// Cache Cleaning Utilities
class CacheManager {
  final AppDatabase _db;

  CacheManager(this._db);

  Future<StorageBreakdown> getStorageBreakdown() async {
    int downloadedBytes = 0;
    int tempCacheBytes = 0;
    int lyricsCount = 0;
    int lyricsBytes = 0;

    // 1. Scan offline downloads directory
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final tracksDir = Directory('${docsDir.path}/tracks');
      if (await tracksDir.exists()) {
        final files = tracksDir.listSync(recursive: true);
        for (final f in files) {
          if (f is File) {
            downloadedBytes += f.lengthSync();
          }
        }
      }
    } catch (_) {}

    // 2. Scan temporary cache directory
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entries = tempDir.listSync(recursive: true);
        for (final entry in entries) {
          if (entry is File) {
            tempCacheBytes += entry.lengthSync();
          }
        }
      }
    } catch (_) {}

    // 3. Query lyrics cache database count & size
    try {
      final lyricsRows = await _db.select(_db.cachedLyrics).get();
      lyricsCount = lyricsRows.length;
      for (final row in lyricsRows) {
        lyricsBytes += row.plainText?.length ?? 0;
        lyricsBytes += row.syncedLrc?.length ?? 0;
      }
      lyricsBytes += lyricsCount * 512;
    } catch (_) {}

    final totalBytes = downloadedBytes + tempCacheBytes + lyricsBytes;
    return StorageBreakdown(
      downloadedBytes: downloadedBytes,
      tempCacheBytes: tempCacheBytes,
      lyricsCacheCount: lyricsCount,
      lyricsEstimatedBytes: lyricsBytes,
      totalBytes: totalBytes,
    );
  }

  Future<int> clearLyricsCache() async {
    return _db.delete(_db.cachedLyrics).go();
  }

  Future<void> clearTemporaryCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entries = tempDir.listSync(recursive: true);
        for (final entry in entries) {
          try {
            if (entry is File) {
              await entry.delete();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

final cacheManagerProvider = Provider<CacheManager>((ref) {
  final db = ref.watch(databaseProvider);
  return CacheManager(db);
});

final storageBreakdownProvider =
    FutureProvider.autoDispose<StorageBreakdown>((ref) async {
  final manager = ref.watch(cacheManagerProvider);
  return manager.getStorageBreakdown();
});

// ==========================================
// User Name & Onboarding Settings
// ==========================================

class UserNameNotifier extends StateNotifier<String?> {
  final AppDatabase _db;
  bool _isExplicitlySet = false;

  UserNameNotifier(this._db) : super(null) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final row = await (_db.select(_db.settings)..where((t) => t.key.equals('user_name'))).getSingleOrNull();
      if (!_isExplicitlySet) {
        state = row?.value;
      }
    } catch (_) {}
  }

  Future<void> setUserName(String name) async {
    _isExplicitlySet = true;
    final clean = name.trim();
    state = clean.isEmpty ? null : clean;
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingRow(
            key: 'user_name',
            value: clean,
          ),
        );
    await _db.into(_db.settings).insertOnConflictUpdate(
          const SettingRow(
            key: 'has_completed_name_prompt',
            value: 'true',
          ),
        );
  }

  Future<void> markPromptCompleted() async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          const SettingRow(
            key: 'has_completed_name_prompt',
            value: 'true',
          ),
        );
  }
}

final userNameProvider = StateNotifierProvider<UserNameNotifier, String?>((ref) {
  final db = ref.watch(databaseProvider);
  return UserNameNotifier(db);
});

final hasCompletedNamePromptProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  final row = await (db.select(db.settings)..where((t) => t.key.equals('has_completed_name_prompt'))).getSingleOrNull();
  return row?.value == 'true';
});

// ==========================================
// Spotify Color-Lyrics Configuration
// ==========================================

class SpotifyLyricsConfig {
  final String? token;
  final String? endpoint;

  const SpotifyLyricsConfig({this.token, this.endpoint});

  bool get isConfigured =>
      (token != null && token!.trim().isNotEmpty) ||
      (endpoint != null && endpoint!.trim().isNotEmpty);
}

class SpotifyLyricsConfigNotifier extends StateNotifier<SpotifyLyricsConfig> {
  final AppDatabase _db;

  SpotifyLyricsConfigNotifier(this._db) : super(const SpotifyLyricsConfig()) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final tokenRow = await (_db.select(_db.settings)
            ..where((t) => t.key.equals('spotify_lyrics_token')))
          .getSingleOrNull();
      final endpointRow = await (_db.select(_db.settings)
            ..where((t) => t.key.equals('spotify_lyrics_endpoint')))
          .getSingleOrNull();

      final tokenVal = tokenRow?.value.trim();
      final endpointVal = endpointRow?.value.trim();

      state = SpotifyLyricsConfig(
        token: (tokenVal != null && tokenVal.isNotEmpty) ? tokenVal : null,
        endpoint: (endpointVal != null && endpointVal.isNotEmpty) ? endpointVal : null,
      );
    } catch (_) {}
  }

  Future<void> setToken(String? token) async {
    final clean = token?.trim();
    state = SpotifyLyricsConfig(
      token: (clean != null && clean.isNotEmpty) ? clean : null,
      endpoint: state.endpoint,
    );
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingRow(
            key: 'spotify_lyrics_token',
            value: clean ?? '',
          ),
        );
  }

  Future<void> setEndpoint(String? endpoint) async {
    final clean = endpoint?.trim();
    state = SpotifyLyricsConfig(
      token: state.token,
      endpoint: (clean != null && clean.isNotEmpty) ? clean : null,
    );
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingRow(
            key: 'spotify_lyrics_endpoint',
            value: clean ?? '',
          ),
        );
  }
}

final spotifyLyricsConfigProvider =
    StateNotifierProvider<SpotifyLyricsConfigNotifier, SpotifyLyricsConfig>((ref) {
  final db = ref.watch(databaseProvider);
  return SpotifyLyricsConfigNotifier(db);
});

