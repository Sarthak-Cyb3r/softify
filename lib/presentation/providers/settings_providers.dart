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
  return GitHubReleaseUpdateChecker();
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

final currentAppVersionProvider = Provider<String>((ref) => '1.0.0');

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
      final preset = row.value == 'low' ? AudioQualityPreset.low : AudioQualityPreset.standard;
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

// Cache Cleaning Utilities
class CacheManager {
  final AppDatabase _db;

  CacheManager(this._db);

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
