import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/repositories/background_download_repository.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/download_item.dart';
import 'package:softify/domain/entities/stream_info.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_stream_resolver.dart';

class MockStreamResolver implements IStreamResolver {
  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    return StreamInfo(
      url: Uri.parse('https://example.com/audio.m4a'),
      container: 'm4a',
      bitrate: 128000,
      codec: 'mp4a.40.2',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      providerName: 'mock',
    );
  }

  @override
  Future<void> prefetch(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftLibraryRepository libraryRepo;
  late MockStreamResolver streamResolver;
  late Directory tempDir;
  late StreamController<TaskUpdate> updatesController;
  late BackgroundDownloadRepository downloadRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    libraryRepo = DriftLibraryRepository(db);
    streamResolver = MockStreamResolver();
    tempDir = Directory.systemTemp.createTempSync('softify_dl_test');
    updatesController = StreamController<TaskUpdate>.broadcast();

    downloadRepo = BackgroundDownloadRepository(
      db: db,
      streamResolver: streamResolver,
      libraryRepo: libraryRepo,
      updatesStream: updatesController.stream,
      docsDirProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await downloadRepo.dispose();
    await updatesController.close();
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  const testTrack = Track(
    id: 'test-track-1',
    sourceId: 'src-1',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    duration: Duration(seconds: 200),
  );

  test('Missing download file handling: prunes DB record and returns null', () async {
    await libraryRepo.upsertTrack(testTrack);

    // Directly insert a completed download record whose file does not exist on disk
    await db.into(db.downloads).insert(
          DownloadsCompanion.insert(
            trackId: testTrack.id,
            relativePath: 'tracks/test-track-1.m4a',
            status: DownloadStatus.completed.toDbString(),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // Physical file does not exist
    final filePath = await downloadRepo.getDownloadedFilePath(testTrack.id);
    expect(filePath, isNull);

    // Record should have been pruned from DB
    final downloadRow = await (db.select(db.downloads)
          ..where((d) => d.trackId.equals(testTrack.id)))
        .getSingleOrNull();
    expect(downloadRow, isNull);
    expect(await downloadRepo.isDownloaded(testTrack.id), isFalse);
  });

  test('Disk-first deletion: physical file deleted from disk before DB record pruned', () async {
    await libraryRepo.upsertTrack(testTrack);

    // Create physical dummy file
    final tracksDir = Directory(p.join(tempDir.path, 'tracks'))..createSync(recursive: true);
    final file = File(p.join(tracksDir.path, '${testTrack.id}.m4a'))..writeAsStringSync('audio-data');

    expect(file.existsSync(), isTrue);

    // Insert completed record
    await db.into(db.downloads).insert(
          DownloadsCompanion.insert(
            trackId: testTrack.id,
            relativePath: 'tracks/${testTrack.id}.m4a',
            status: DownloadStatus.completed.toDbString(),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    expect(await downloadRepo.isDownloaded(testTrack.id), isTrue);

    // Execute delete
    await downloadRepo.deleteDownload(testTrack.id);

    // Verify disk file is gone
    expect(file.existsSync(), isFalse);

    // Verify DB record is gone
    final row = await (db.select(db.downloads)
          ..where((d) => d.trackId.equals(testTrack.id)))
        .getSingleOrNull();
    expect(row, isNull);
  });
}
