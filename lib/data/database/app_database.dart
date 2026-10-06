import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// 1. Tracks Table
@DataClassName('TrackRow')
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  IntColumn get durationMs => integer()();
  TextColumn get coverUrl => text().nullable()();
  RealColumn get matchConfidence => real().nullable()();
  BoolColumn get isLiked => boolean().withDefault(const Constant(false))();
  BoolColumn get isUnavailable => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {sourceId}
      ];
}

// 2. Playlists Table
@DataClassName('PlaylistRow')
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isImported => boolean().withDefault(const Constant(false))();
  TextColumn get sourceUrl => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Playlist Tracks Junction Table
@DataClassName('PlaylistTrackRow')
class PlaylistTracks extends Table {
  TextColumn get playlistId =>
      text().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get trackId =>
      text().nullable().references(Tracks, #id, onDelete: KeyAction.setNull)();
  TextColumn get originalTitle => text()();
  TextColumn get originalArtist => text()();
  TextColumn get matchStatus => text()(); // 'matched', 'unmatched', 'pending'

  @override
  Set<Column> get primaryKey => {playlistId, position};
}

// 4. Active Playback Queue Items Table
@DataClassName('QueueItemRow')
class QueueItems extends Table {
  IntColumn get position => integer()();
  TextColumn get trackId =>
      text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get addedAt => integer()();

  @override
  Set<Column> get primaryKey => {position};
}

// 5. Playback State Table (single row holding active index and position)
@DataClassName('PlaybackStateRow')
class PlaybackStates extends Table {
  IntColumn get id => integer()();
  IntColumn get currentQueueIndex =>
      integer().withDefault(const Constant(0))();
  IntColumn get currentPositionMs =>
      integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// 6. Play History Table
@DataClassName('PlayHistoryRow')
class PlayHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId =>
      text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get playedAt => integer()();
  RealColumn get completedRatio => real()();
}

// 7. Downloads Table
@DataClassName('DownloadRow')
class Downloads extends Table {
  TextColumn get trackId =>
      text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get relativePath => text()();
  TextColumn get containerFormat =>
      text().withDefault(const Constant('m4a'))();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get bytesDownloaded =>
      integer().withDefault(const Constant(0))();
  TextColumn get status => text()(); // 'queued', 'downloading', 'completed', 'failed', 'paused'
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {trackId};
}

// 8. Cached Lyrics Table
@DataClassName('CachedLyricRow')
class CachedLyrics extends Table {
  TextColumn get trackId =>
      text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get syncedLrc => text().nullable()();
  TextColumn get plainText => text().nullable()();
  BoolColumn get isNotFound =>
      boolean().withDefault(const Constant(false))();
  IntColumn get cachedAt => integer()();

  @override
  Set<Column> get primaryKey => {trackId};
}

// 9. App Settings Table
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// 10. Piped Instances Table
@DataClassName('PipedInstanceRow')
class PipedInstances extends Table {
  TextColumn get url => text()();
  IntColumn get latencyMs => integer().nullable()();
  BoolColumn get isHealthy => boolean().withDefault(const Constant(true))();
  IntColumn get lastChecked => integer()();

  @override
  Set<Column> get primaryKey => {url};
}

LazyDatabase openDefaultConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'softify.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [
  Tracks,
  Playlists,
  PlaylistTracks,
  QueueItems,
  PlaybackStates,
  PlayHistories,
  Downloads,
  CachedLyrics,
  Settings,
  PipedInstances,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? openDefaultConnection());

  @override
  int get schemaVersion => 1;
}
