import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/services/library_backup_service.dart';
import 'package:softify/data/services/local_audio_scanner.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('LibraryBackupService Test Suite', () {
    test('Exports and restores library without data loss', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Populate DB with a liked track and custom playlist
      await db.into(db.tracks).insert(
            TracksCompanion(
              id: const Value('t_1'),
              sourceId: const Value('src_1'),
              title: const Value('Starboy'),
              artist: const Value('The Weeknd'),
              album: const Value('Starboy Album'),
              durationMs: const Value(230000),
              isLiked: const Value(true),
              createdAt: Value(now),
            ),
          );

      await db.into(db.playlists).insert(
            PlaylistsCompanion(
              id: const Value('pl_1'),
              name: const Value('Night Drive'),
              description: const Value('Late night hits'),
              createdAt: Value(now),
            ),
          );

      await db.into(db.playlistTracks).insert(
            const PlaylistTracksCompanion(
              playlistId: Value('pl_1'),
              position: Value(0),
              trackId: Value('t_1'),
              originalTitle: Value('Starboy'),
              originalArtist: Value('The Weeknd'),
              matchStatus: Value('matched'),
            ),
          );

      // 2. Generate backup JSON
      final backupJson = await LibraryBackupService.generateBackupJson(db);
      expect(backupJson, isNotEmpty);
      expect(backupJson, contains('Starboy'));
      expect(backupJson, contains('Night Drive'));

      // 3. Clear database to test fresh restore
      await db.delete(db.playlistTracks).go();
      await db.delete(db.playlists).go();
      await db.delete(db.tracks).go();

      final emptyPlaylists = await db.select(db.playlists).get();
      expect(emptyPlaylists, isEmpty);

      // 4. Restore from JSON
      final result = await LibraryBackupService.restoreFromJson(db, backupJson);
      expect(result.playlistsRestored, equals(1));
      expect(result.likedRestored, equals(1));

      // 5. Verify restored data
      final restoredTracks = await db.select(db.tracks).get();
      expect(restoredTracks.length, equals(1));
      expect(restoredTracks.first.title, equals('Starboy'));
      expect(restoredTracks.first.isLiked, isTrue);

      final restoredPlaylists = await db.select(db.playlists).get();
      expect(restoredPlaylists.length, equals(1));
      expect(restoredPlaylists.first.name, equals('Night Drive'));
    });
  });

  group('LocalAudioScanner Test Suite', () {
    test('Discovers local audio files and indexes them into database', () async {
      // Create temporary mock directory with audio files
      final tempDir = Directory.systemTemp.createTempSync('softify_audio_test_');

      try {
        final dummyMusicBytes = List.filled(350 * 1024, 65); // 350 KB
        final songFile1 = File('${tempDir.path}/The Weeknd - Blinding Lights.mp3');
        songFile1.writeAsBytesSync(dummyMusicBytes);

        final songFile2 = File('${tempDir.path}/Kesariya.flac');
        songFile2.writeAsBytesSync(dummyMusicBytes);

        // Sound effect < 300 KB should be skipped
        final sfxFile = File('${tempDir.path}/beep.wav');
        sfxFile.writeAsBytesSync(List.filled(10 * 1024, 0));

        // File inside node_modules should be skipped
        final nodeDir = Directory('${tempDir.path}/node_modules/lib')..createSync(recursive: true);
        final nodeAudio = File('${nodeDir.path}/click.mp3');
        nodeAudio.writeAsBytesSync(dummyMusicBytes);

        final textFile = File('${tempDir.path}/notes.txt');
        textFile.writeAsStringSync('ignored text file');

        // Scan the directory
        final count = await LocalAudioScanner.scanAndIndex(
          db,
          customDirectories: [tempDir],
        );

        expect(count, equals(2));

        final indexedTracks = await db.select(db.tracks).get();
        expect(indexedTracks.length, equals(2));

        final blindingLights = indexedTracks.firstWhere((t) => t.title.contains('Blinding Lights'));
        expect(blindingLights.artist, equals('The Weeknd'));
        expect(blindingLights.id, startsWith('local_'));

        final kesariya = indexedTracks.firstWhere((t) => t.title.contains('Kesariya'));
        expect(kesariya.id, startsWith('local_'));

        // Delete one file and rescan -> should prune deleted track from DB
        songFile1.deleteSync();
        final countAfterDelete = await LocalAudioScanner.scanAndIndex(
          db,
          customDirectories: [tempDir],
        );
        expect(countAfterDelete, equals(1));
        final tracksAfterDelete = await db.select(db.tracks).get();
        expect(tracksAfterDelete.length, equals(1));
        expect(tracksAfterDelete.first.id, equals(kesariya.id));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
