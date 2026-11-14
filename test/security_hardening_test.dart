import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/repositories/background_download_repository.dart';
import 'package:softify/data/services/library_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security Hardening & Vulnerability Remediation Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Path Traversal Prevention in BackgroundDownloadRepository', () {
      expect(
        BackgroundDownloadRepository.sanitizeTrackId('../../etc/passwd'),
        '______etc_passwd',
      );
      expect(
        BackgroundDownloadRepository.sanitizeTrackId(r'..\..\Windows\System32\cmd.exe'),
        '______Windows_System32_cmd_exe',
      );
      expect(
        BackgroundDownloadRepository.sanitizeTrackId('track/with/slash:and*wildcards?'),
        'track_with_slash_and_wildcards_',
      );

      // Path containment check
      expect(
        BackgroundDownloadRepository.isPathContained('/app/tracks', '/app/tracks/song1.m4a'),
        isTrue,
      );
      expect(
        BackgroundDownloadRepository.isPathContained('/app/tracks', '/app/tracks/../etc/passwd'),
        isFalse,
      );
      expect(
        BackgroundDownloadRepository.isPathContained('/app/tracks', '/etc/shadow'),
        isFalse,
      );
    });

    test('Sensitive Credential Leakage Prevention in LibraryBackupService Export', () async {
      // Seed regular and sensitive settings
      await db.into(db.settings).insert(
            const SettingRow(key: 'audio_quality', value: 'high'),
          );
      await db.into(db.settings).insert(
            const SettingRow(key: 'user_name', value: 'Alice'),
          );
      await db.into(db.settings).insert(
            const SettingRow(key: 'spotify_user_token', value: 'super_secret_oauth_token'),
          );
      await db.into(db.settings).insert(
            const SettingRow(key: 'spotify_refresh_token', value: 'secret_refresh_token_xyz'),
          );
      await db.into(db.settings).insert(
            const SettingRow(key: 'spotify_lyrics_token', value: 'secret_lyrics_token'),
          );
      await db.into(db.settings).insert(
            const SettingRow(key: 'navidrome_token', value: 'secret_navidrome_token'),
          );

      final jsonString = await LibraryBackupService.generateBackupJson(db);
      final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
      final settings = data['settings'] as Map<String, dynamic>;

      // Safe settings should be exported
      expect(settings['audio_quality'], 'high');
      expect(settings['user_name'], 'Alice');

      // Sensitive credentials MUST NOT be leaked in the backup
      expect(settings.containsKey('spotify_user_token'), isFalse);
      expect(settings.containsKey('spotify_refresh_token'), isFalse);
      expect(settings.containsKey('spotify_lyrics_token'), isFalse);
      expect(settings.containsKey('navidrome_token'), isFalse);
      expect(jsonString.contains('super_secret_oauth_token'), isFalse);
      expect(jsonString.contains('secret_refresh_token_xyz'), isFalse);
    });

    test('Malicious Credential Injection Prevention in LibraryBackupService Restore', () async {
      const maliciousPayload = '''
{
  "format": "softify_backup",
  "version": 1,
  "likedTracks": [],
  "playlists": [],
  "settings": {
    "audio_quality": "standard",
    "spotify_user_token": "injected_attacker_token",
    "spotify_refresh_token": "injected_refresh_token",
    "navidrome_password": "injected_password"
  }
}
''';

      await LibraryBackupService.restoreFromJson(db, maliciousPayload);

      final qualityRow = await (db.select(db.settings)
            ..where((t) => t.key.equals('audio_quality')))
          .getSingleOrNull();
      final tokenRow = await (db.select(db.settings)
            ..where((t) => t.key.equals('spotify_user_token')))
          .getSingleOrNull();
      final refreshRow = await (db.select(db.settings)
            ..where((t) => t.key.equals('spotify_refresh_token')))
          .getSingleOrNull();

      expect(qualityRow?.value, 'standard');
      expect(tokenRow, isNull);
      expect(refreshRow, isNull);
    });

    test('FileProvider file_paths.xml does not contain root-path', () {
      final filePathsXml = File('android/app/src/main/res/xml/file_paths.xml');
      expect(filePathsXml.existsSync(), isTrue);
      final content = filePathsXml.readAsStringSync();
      expect(content.contains('<root-path'), isFalse);
    });
  });
}
