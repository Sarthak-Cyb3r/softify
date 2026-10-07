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

// 11. Search Events Table (Local-only serving log)
@DataClassName('SearchEventRow')
class SearchEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get query => text()();
  TextColumn get resultIdsJson => text()(); // List<String> encoded
  IntColumn get shownCount => integer()();
  TextColumn get clickedId => text().nullable()();
  IntColumn get clickedPosition => integer().nullable()();
  IntColumn get msToClick => integer().nullable()();
  TextColumn get rankerVersion => text()();
}

// 12. Play Events Table (Local-only stream vs early skip log)
@DataClassName('PlayEventRow')
class PlayEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get trackId => text()();
  TextColumn get source => text()(); // 'search' | 'shelf:<name>' | 'autoplay' | 'library' | 'radio'
  IntColumn get listenedMs => integer()();
  IntColumn get durationMs => integer()();
  BoolColumn get skippedEarly => boolean()(); // listenedMs < 30000
  BoolColumn get saved => boolean()();
  BoolColumn get addedToPlaylist => boolean()();
  TextColumn get rankerVersion => text()();
  TextColumn get featuresJson => text().nullable()(); // Snapshot of features at serving time
}

// 13. Impressions Table (Local-only impression log)
@DataClassName('ImpressionRow')
class Impressions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get surface => text()(); // 'home_shelf' | 'search_result'
  TextColumn get itemId => text()();
  IntColumn get position => integer()();
}

// 14. Taste Profile Table (Dual-Band Half-Life Decay)
@DataClassName('TasteProfileRow')
class TasteProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'artist' | 'genre' | 'language'
  TextColumn get entityId => text()();
  RealColumn get slowWeight => real().withDefault(const Constant(0.0))(); // Half-life: 14 days
  RealColumn get fastWeight => real().withDefault(const Constant(0.0))(); // Half-life: 4 hours
  IntColumn get updatedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {entityType, entityId}
      ];
}

// 15. Track Co-occurrences Table (Pointwise Mutual Information PMI)
@DataClassName('CooccurrenceRow')
class Cooccurrences extends Table {
  TextColumn get trackA => text()();
  TextColumn get trackB => text()();
  RealColumn get score => real()(); // Pointwise Mutual Information (PMI)
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {trackA, trackB};
}

// 16. Query Completions Table (Autocomplete Suggestions)
@DataClassName('QueryCompletionRow')
class QueryCompletions extends Table {
  TextColumn get query => text()();
  TextColumn get normalizedPrefix => text()();
  IntColumn get streamCount => integer().withDefault(const Constant(0))();
  IntColumn get lastUsedTs => integer()();

  @override
  Set<Column> get primaryKey => {query};
}

// 17. Bandit States Table (Explore/Exploit Novelty Ratios)
@DataClassName('BanditStateRow')
class BanditStates extends Table {
  TextColumn get shelfId => text()();
  RealColumn get epsilon => real().withDefault(const Constant(0.1))();
  IntColumn get pullCount => integer().withDefault(const Constant(0))();
  RealColumn get cumulativeReward => real().withDefault(const Constant(0.0))();
  RealColumn get currentNoveltyRatio => real().withDefault(const Constant(0.2))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {shelfId};
}

// 18. Artist Snoozes Table (Diversity & Agency Controls)
@DataClassName('ArtistSnoozeRow')
class ArtistSnoozes extends Table {
  TextColumn get artistId => text()();
  IntColumn get snoozedUntil => integer()(); // Milliseconds timestamp (now + 30 days)

  @override
  Set<Column> get primaryKey => {artistId};
}

// 19. Interleave Outcomes Table (Team-Draft Interleaving A/B Evaluation)
@DataClassName('InterleaveOutcomeRow')
class InterleaveOutcomes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get queryOrContext => text()();
  TextColumn get modelAId => text()();
  TextColumn get modelBId => text()();
  TextColumn get winningModelId => text().nullable()();
  IntColumn get ts => integer()();
}

// 20. Track Embeddings Table (On-Device Semantic Vector Search)
@DataClassName('TrackEmbeddingRow')
class TrackEmbeddings extends Table {
  TextColumn get trackId => text()();
  BlobColumn get vector => blob()(); // 128-dimensional float32 byte buffer
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {trackId};
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
  SearchEvents,
  PlayEvents,
  Impressions,
  TasteProfiles,
  Cooccurrences,
  QueryCompletions,
  BanditStates,
  ArtistSnoozes,
  InterleaveOutcomes,
  TrackEmbeddings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? openDefaultConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS track_fts USING fts5(
              track_id UNINDEXED,
              title,
              artist,
              album,
              tokenize = 'unicode61 remove_diacritics 2'
            );
          ''');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(searchEvents);
            await m.createTable(playEvents);
            await m.createTable(impressions);
          }
          if (from < 3) {
            await customStatement('''
              CREATE VIRTUAL TABLE IF NOT EXISTS track_fts USING fts5(
                track_id UNINDEXED,
                title,
                artist,
                album,
                tokenize = 'unicode61 remove_diacritics 2'
              );
            ''');
          }
          if (from < 4) {
            await m.createTable(tasteProfiles);
            await m.createTable(cooccurrences);
          }
          if (from < 5) {
            await m.createTable(queryCompletions);
          }
          if (from < 6) {
            await m.createTable(banditStates);
          }
          if (from < 7) {
            await m.createTable(artistSnoozes);
          }
          if (from < 8) {
            await m.createTable(interleaveOutcomes);
          }
          if (from < 9) {
            await m.createTable(trackEmbeddings);
          }
        },
      );
}
