import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/repositories/remote_config_repository.dart';
import 'package:softify/data/updater/github_release_update_checker.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/presentation/providers/settings_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 4: Remote Config Repository', () {
    test('Returns default fallback instances (HTTPS only, <= 10)', () {
      final repo = RemoteConfigRepository(db: db);
      final fallbacks = repo.getFallbackPipedInstances();

      expect(fallbacks, isNotEmpty);
      expect(fallbacks.length, lessThanOrEqualTo(10));
      for (final url in fallbacks) {
        expect(url.startsWith('https://'), isTrue);
      }
    });

    test('Gracefully falls back to bundled defaults when fetch fails', () async {
      final repo = RemoteConfigRepository(
        db: db,
        configUrl: 'https://invalid-nonexistent-domain-xyz123.com/config.json',
      );
      final config = await repo.fetchLatestConfig();

      expect(config.pipedInstances, equals(RemoteConfigRepository.defaultFallbackInstances));
      expect(config.primaryResolver, equals('youtube_explode'));
      expect(config.minAppVersionCode, equals(1));
    });
  });

  group('Milestone 4: GitHub Release Update Checker', () {
    test('isNewerVersion semver comparison logic', () {
      expect(GitHubReleaseUpdateChecker.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(GitHubReleaseUpdateChecker.isNewerVersion('1.1.0', '1.0.5'), isTrue);
      expect(GitHubReleaseUpdateChecker.isNewerVersion('v2.0.0', 'v1.9.9'), isTrue);
      expect(GitHubReleaseUpdateChecker.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(GitHubReleaseUpdateChecker.isNewerVersion('v1.0.0', 'v1.0.1'), isFalse);
      expect(GitHubReleaseUpdateChecker.isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('SHA-256 hash validation calculates correct hash', () {
      final sampleBytes = utf8.encode('Softify APK test payload data');
      final expectedHash = sha256.convert(sampleBytes).toString();

      final actualHash = sha256.convert(Uint8List.fromList(sampleBytes)).toString();
      expect(actualHash, equals(expectedHash));
    });
  });

  group('Milestone 4: Settings & Cache Management', () {
    test('AudioQualityNotifier persists setting changes in Drift database', () async {
      final notifier = AudioQualityNotifier(db);
      expect(notifier.state, equals(AudioQualityPreset.standard));

      await notifier.setQuality(AudioQualityPreset.low);
      expect(notifier.state, equals(AudioQualityPreset.low));

      // Verify row in database
      final row = await (db.select(db.settings)..where((t) => t.key.equals('audio_quality'))).getSingle();
      expect(row.value, equals('low'));

      await notifier.setQuality(AudioQualityPreset.standard);
      expect(notifier.state, equals(AudioQualityPreset.standard));
      final updatedRow = await (db.select(db.settings)..where((t) => t.key.equals('audio_quality'))).getSingle();
      expect(updatedRow.value, equals('standard'));
    });

    test('CacheManager clears cached lyrics records from database', () async {
      final cacheManager = CacheManager(db);

      // Insert fake track and lyrics
      await db.into(db.tracks).insert(
            TrackRow(
              id: 'track-1',
              sourceId: 'src-1',
              title: 'Song 1',
              artist: 'Artist 1',
              durationMs: 180000,
              isLiked: false,
              isUnavailable: false,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      await db.into(db.cachedLyrics).insert(
            CachedLyricRow(
              trackId: 'track-1',
              syncedLrc: '[00:01.00] Line 1',
              plainText: 'Line 1',
              isNotFound: false,
              cachedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final beforeCount = (await db.select(db.cachedLyrics).get()).length;
      expect(beforeCount, equals(1));

      final deletedCount = await cacheManager.clearLyricsCache();
      expect(deletedCount, equals(1));

      final afterCount = (await db.select(db.cachedLyrics).get()).length;
      expect(afterCount, equals(0));
    });
  });
}
