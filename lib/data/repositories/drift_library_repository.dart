import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/entities/history_item.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist_entry.dart';
import '../../domain/entities/queue_state.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_library_repository.dart';
import '../database/app_database.dart';

class DriftLibraryRepository implements ILibraryRepository {
  final AppDatabase _db;
  final Random _random = Random();

  DriftLibraryRepository(this._db);

  String _newUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFFFF);
    return 'softify_${now}_$rand';
  }

  Track _trackFromRow(TrackRow row) {
    return Track(
      id: row.id,
      sourceId: row.sourceId,
      title: row.title,
      artist: row.artist,
      album: row.album,
      duration: Duration(milliseconds: row.durationMs),
      coverUrl: row.coverUrl,
      matchConfidence: row.matchConfidence,
      isLiked: row.isLiked,
      isUnavailable: row.isUnavailable,
    );
  }

  // ==========================================
  // Track Operations
  // ==========================================

  @override
  Future<void> upsertTrack(Track track) async {
    await _db.into(_db.tracks).insertOnConflictUpdate(
          TracksCompanion(
            id: Value(track.id),
            sourceId: Value(track.sourceId),
            title: Value(track.title),
            artist: Value(track.artist),
            album: Value(track.album),
            durationMs: Value(track.duration.inMilliseconds),
            coverUrl: Value(track.coverUrl),
            matchConfidence: Value(track.matchConfidence),
            isLiked: Value(track.isLiked),
            isUnavailable: Value(track.isUnavailable),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<Track?> getTrackById(String id) async {
    final row = await (_db.select(_db.tracks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _trackFromRow(row) : null;
  }

  @override
  Future<Track?> getTrackBySourceId(String sourceId) async {
    final row = await (_db.select(_db.tracks)
          ..where((t) => t.sourceId.equals(sourceId)))
        .getSingleOrNull();
    return row != null ? _trackFromRow(row) : null;
  }

  @override
  Future<void> markTrackUnavailable(String id, bool isUnavailable) async {
    await (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(isUnavailable: Value(isUnavailable)),
    );
  }

  @override
  Future<List<Track>> searchLocalTracks(String query, {int limit = 20}) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final pattern = '%$clean%';
    final rows = await (_db.select(_db.tracks)
          ..where((t) =>
              t.title.lower().like(pattern) |
              t.artist.lower().like(pattern) |
              t.album.lower().like(pattern))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isLiked),
            (t) => OrderingTerm.desc(t.createdAt),
          ])
          ..limit(limit))
        .get();

    return rows.map(_trackFromRow).toList();
  }

  // ==========================================
  // Favorites / Liked Tracks
  // ==========================================

  @override
  Future<void> setLiked(String trackId, bool isLiked, {Track? track}) async {
    if (track != null) {
      await _db.into(_db.tracks).insertOnConflictUpdate(
            TracksCompanion(
              id: Value(track.id),
              sourceId: Value(track.sourceId),
              title: Value(track.title),
              artist: Value(track.artist),
              album: Value(track.album),
              durationMs: Value(track.duration.inMilliseconds),
              coverUrl: Value(track.coverUrl),
              matchConfidence: Value(track.matchConfidence),
              isLiked: Value(isLiked),
              isUnavailable: Value(track.isUnavailable),
              createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
      return;
    }
    await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(isLiked: Value(isLiked)),
    );
  }

  @override
  Future<bool> isLiked(String trackId) async {
    final row = await (_db.select(_db.tracks)
          ..where((t) => t.id.equals(trackId)))
        .getSingleOrNull();
    return row?.isLiked ?? false;
  }

  @override
  Stream<List<Track>> watchLikedTracks() {
    return (_db.select(_db.tracks)
          ..where((t) => t.isLiked.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_trackFromRow).toList());
  }

  @override
  Future<List<Track>> getLikedTracks() async {
    final rows = await (_db.select(_db.tracks)
          ..where((t) => t.isLiked.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_trackFromRow).toList();
  }

  // ==========================================
  // Playlists
  // ==========================================

  @override
  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    bool isImported = false,
    String? sourceUrl,
  }) async {
    final id = _newUuid();
    final now = DateTime.now();
    await _db.into(_db.playlists).insert(
          PlaylistsCompanion.insert(
            id: id,
            name: name,
            description: Value(description),
            isImported: Value(isImported),
            sourceUrl: Value(sourceUrl),
            createdAt: now.millisecondsSinceEpoch,
          ),
        );
    _db.notifyUpdates({
      TableUpdate.onTable(_db.playlists),
      TableUpdate.onTable(_db.playlistTracks),
    });
    return Playlist(
      id: id,
      name: name,
      description: description,
      isImported: isImported,
      sourceUrl: sourceUrl,
      createdAt: now,
      trackCount: 0,
    );
  }

  @override
  Future<void> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
  }) async {
    await (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
        .write(
      PlaylistsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description:
            description != null ? Value(description) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await (_db.delete(_db.playlists)..where((p) => p.id.equals(playlistId)))
        .go();
    _db.notifyUpdates({
      TableUpdate.onTable(_db.playlists),
      TableUpdate.onTable(_db.playlistTracks),
    });
  }

  @override
  Stream<List<Playlist>> watchPlaylists() {
    final countExp = _db.playlistTracks.position.count();
    final query = _db.select(_db.playlists).join([
      leftOuterJoin(
        _db.playlistTracks,
        _db.playlistTracks.playlistId.equalsExp(_db.playlists.id),
      ),
    ])
      ..groupBy([
        _db.playlists.id,
        _db.playlists.name,
        _db.playlists.description,
        _db.playlists.isImported,
        _db.playlists.sourceUrl,
        _db.playlists.createdAt,
      ])
      ..addColumns([countExp])
      ..orderBy([OrderingTerm.desc(_db.playlists.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((r) {
        final p = r.readTable(_db.playlists);
        final count = r.read(countExp) ?? 0;
        return Playlist(
          id: p.id,
          name: p.name,
          description: p.description,
          isImported: p.isImported,
          sourceUrl: p.sourceUrl,
          createdAt: DateTime.fromMillisecondsSinceEpoch(p.createdAt),
          trackCount: count,
        );
      }).toList();
    });
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final countExp = _db.playlistTracks.position.count();
    final query = _db.select(_db.playlists).join([
      leftOuterJoin(
        _db.playlistTracks,
        _db.playlistTracks.playlistId.equalsExp(_db.playlists.id),
      ),
    ])
      ..groupBy([
        _db.playlists.id,
        _db.playlists.name,
        _db.playlists.description,
        _db.playlists.isImported,
        _db.playlists.sourceUrl,
        _db.playlists.createdAt,
      ])
      ..addColumns([countExp])
      ..orderBy([OrderingTerm.desc(_db.playlists.createdAt)]);

    final rows = await query.get();
    return rows.map((r) {
      final p = r.readTable(_db.playlists);
      final count = r.read(countExp) ?? 0;
      return Playlist(
        id: p.id,
        name: p.name,
        description: p.description,
        isImported: p.isImported,
        sourceUrl: p.sourceUrl,
        createdAt: DateTime.fromMillisecondsSinceEpoch(p.createdAt),
        trackCount: count,
      );
    }).toList();
  }

  @override
  Stream<PlaylistWithTracks?> watchPlaylistWithTracks(String playlistId) {
    final query = _db.select(_db.playlists).join([
      leftOuterJoin(
        _db.playlistTracks,
        _db.playlistTracks.playlistId.equalsExp(_db.playlists.id),
      ),
    ])..where(_db.playlists.id.equals(playlistId));

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      final pRow = rows.first.readTable(_db.playlists);
      return _loadPlaylistWithTracks(pRow);
    });
  }

  @override
  Future<PlaylistWithTracks?> getPlaylistWithTracks(String playlistId) async {
    final pRow = await (_db.select(_db.playlists)
          ..where((p) => p.id.equals(playlistId)))
        .getSingleOrNull();
    if (pRow == null) return null;
    return _loadPlaylistWithTracks(pRow);
  }

  Future<PlaylistWithTracks> _loadPlaylistWithTracks(PlaylistRow pRow) async {
    final ptQuery = _db.select(_db.playlistTracks).join([
      leftOuterJoin(
        _db.tracks,
        _db.tracks.id.equalsExp(_db.playlistTracks.trackId),
      ),
    ])
      ..where(_db.playlistTracks.playlistId.equals(pRow.id))
      ..orderBy([OrderingTerm.asc(_db.playlistTracks.position)]);

    final rows = await ptQuery.get();
    final entries = <PlaylistEntry>[];

    for (final r in rows) {
      final pt = r.readTable(_db.playlistTracks);
      final t = r.readTableOrNull(_db.tracks);

      entries.add(PlaylistEntry(
        playlistId: pt.playlistId,
        position: pt.position,
        trackId: pt.trackId,
        track: t != null ? _trackFromRow(t) : null,
        originalTitle: pt.originalTitle,
        originalArtist: pt.originalArtist,
        matchStatus: MatchStatus.fromString(pt.matchStatus),
      ));
    }

    final playlist = Playlist(
      id: pRow.id,
      name: pRow.name,
      description: pRow.description,
      isImported: pRow.isImported,
      sourceUrl: pRow.sourceUrl,
      createdAt: DateTime.fromMillisecondsSinceEpoch(pRow.createdAt),
      trackCount: entries.length,
    );

    return PlaylistWithTracks(playlist: playlist, entries: entries);
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await upsertTrack(track);

    // Determine max position
    final maxPosExp = _db.playlistTracks.position.max();
    final query = _db.selectOnly(_db.playlistTracks)
      ..addColumns([maxPosExp])
      ..where(_db.playlistTracks.playlistId.equals(playlistId));
    final maxPos = await query.map((row) => row.read(maxPosExp)).getSingleOrNull();
    final nextPos = (maxPos ?? -1) + 1;

    await _db.into(_db.playlistTracks).insert(
          PlaylistTracksCompanion.insert(
            playlistId: playlistId,
            position: nextPos,
            trackId: Value(track.id),
            originalTitle: track.title,
            originalArtist: track.artist,
            matchStatus: MatchStatus.matched.toDbString(),
          ),
        );

    _db.notifyUpdates({
      TableUpdate.onTable(_db.playlists),
      TableUpdate.onTable(_db.playlistTracks),
    });
  }

  @override
  Future<void> addTracksToPlaylist(String playlistId, List<Track> tracks) async {
    if (tracks.isEmpty) return;

    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final track in tracks) {
        await _db.into(_db.tracks).insertOnConflictUpdate(
              TracksCompanion(
                id: Value(track.id),
                sourceId: Value(track.sourceId),
                title: Value(track.title),
                artist: Value(track.artist),
                album: Value(track.album),
                durationMs: Value(track.duration.inMilliseconds),
                coverUrl: Value(track.coverUrl),
                matchConfidence: Value(track.matchConfidence),
                isLiked: Value(track.isLiked),
                isUnavailable: Value(track.isUnavailable),
                createdAt: Value(now),
              ),
            );
      }

      final maxPosExp = _db.playlistTracks.position.max();
      final query = _db.selectOnly(_db.playlistTracks)
        ..addColumns([maxPosExp])
        ..where(_db.playlistTracks.playlistId.equals(playlistId));
      final maxPos = await query.map((row) => row.read(maxPosExp)).getSingleOrNull();
      int currentPos = (maxPos ?? -1) + 1;

      for (final track in tracks) {
        await _db.into(_db.playlistTracks).insert(
              PlaylistTracksCompanion.insert(
                playlistId: playlistId,
                position: currentPos++,
                trackId: Value(track.id),
                originalTitle: track.title,
                originalArtist: track.artist,
                matchStatus: MatchStatus.matched.toDbString(),
              ),
            );
      }
    });

    _db.notifyUpdates({
      TableUpdate.onTable(_db.playlists),
      TableUpdate.onTable(_db.playlistTracks),
    });
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, int position) async {
    await _db.transaction(() async {
      await (_db.delete(_db.playlistTracks)
            ..where((pt) =>
                pt.playlistId.equals(playlistId) &
                pt.position.equals(position)))
          .go();

      // Shift subsequent entries down by 1
      final subsequent = await (_db.select(_db.playlistTracks)
            ..where((pt) =>
                pt.playlistId.equals(playlistId) &
                pt.position.isBiggerThanValue(position))
            ..orderBy([(pt) => OrderingTerm.asc(pt.position)]))
          .get();

      for (final row in subsequent) {
        await (_db.update(_db.playlistTracks)
              ..where((pt) =>
                  pt.playlistId.equals(playlistId) &
                  pt.position.equals(row.position)))
            .write(PlaylistTracksCompanion(
          position: Value(row.position - 1),
        ));
      }
    });

    _db.notifyUpdates({
      TableUpdate.onTable(_db.playlists),
      TableUpdate.onTable(_db.playlistTracks),
    });
  }

  @override
  Future<void> reorderPlaylistTrack(
    String playlistId,
    int oldPosition,
    int newPosition,
  ) async {
    if (oldPosition == newPosition) return;

    await _db.transaction(() async {
      final entries = await (_db.select(_db.playlistTracks)
            ..where((pt) => pt.playlistId.equals(playlistId))
            ..orderBy([(pt) => OrderingTerm.asc(pt.position)]))
          .get();

      if (oldPosition < 0 ||
          oldPosition >= entries.length ||
          newPosition < 0 ||
          newPosition >= entries.length) {
        return;
      }

      final item = entries.removeAt(oldPosition);
      entries.insert(newPosition, item);

      // Reassign all positions
      for (int i = 0; i < entries.length; i++) {
        await (_db.update(_db.playlistTracks)
              ..where((pt) =>
                  pt.playlistId.equals(playlistId) &
                  pt.position.equals(entries[i].position)))
            .write(PlaylistTracksCompanion(
          position: Value(-1000 - i), // Temporary intermediate value to avoid PK collision
        ));
      }

      for (int i = 0; i < entries.length; i++) {
        await (_db.update(_db.playlistTracks)
              ..where((pt) =>
                  pt.playlistId.equals(playlistId) &
                  pt.position.equals(-1000 - i)))
            .write(PlaylistTracksCompanion(
          position: Value(i),
        ));
      }
    });

    _db.notifyUpdates({
      TableUpdate.onTable(_db.playlists),
      TableUpdate.onTable(_db.playlistTracks),
    });
  }

  // ==========================================
  // Play History
  // ==========================================

  @override
  Future<void> recordPlayHistory(Track track, double completedRatio) async {
    await upsertTrack(track);

    final normTitle = track.title.toLowerCase().trim();
    final normArtist = track.artist.toLowerCase().trim();

    final matchingRows = await (_db.select(_db.tracks)
          ..where((t) =>
              t.id.equals(track.id) |
              (t.title.lower().equals(normTitle) &
                  t.artist.lower().equals(normArtist))))
        .get();

    final trackIds = matchingRows.map((t) => t.id).toSet()..add(track.id);

    await (_db.delete(_db.playHistories)
          ..where((ph) => ph.trackId.isIn(trackIds)))
        .go();

    await _db.into(_db.playHistories).insert(
          PlayHistoriesCompanion.insert(
            trackId: track.id,
            playedAt: DateTime.now().millisecondsSinceEpoch,
            completedRatio: completedRatio,
          ),
        );
  }

  @override
  Stream<List<HistoryItem>> watchPlayHistory({int limit = 50}) {
    final query = _db.select(_db.playHistories).join([
      innerJoin(
        _db.tracks,
        _db.tracks.id.equalsExp(_db.playHistories.trackId),
      ),
    ])
      ..orderBy([
        OrderingTerm.desc(_db.playHistories.playedAt),
        OrderingTerm.desc(_db.playHistories.id),
      ])
      ..limit(limit * 4);

    return query.watch().map((rows) {
      final seenTrackKeys = <String>{};
      final items = <HistoryItem>[];
      for (final r in rows) {
        final ph = r.readTable(_db.playHistories);
        final t = r.readTable(_db.tracks);
        final track = _trackFromRow(t);
        final key = '${track.title.toLowerCase().trim()}_${track.artist.toLowerCase().trim()}';
        if (seenTrackKeys.add(key) && seenTrackKeys.add(track.id)) {
          items.add(
            HistoryItem(
              id: ph.id,
              track: track,
              playedAt: DateTime.fromMillisecondsSinceEpoch(ph.playedAt),
              completedRatio: ph.completedRatio,
            ),
          );
          if (items.length >= limit) break;
        }
      }
      return items;
    });
  }

  @override
  Future<void> clearPlayHistory() async {
    await _db.delete(_db.playHistories).go();
  }

  // ==========================================
  // Queue State Persistence
  // ==========================================

  @override
  Future<void> saveQueueState(
    List<Track> queue,
    int currentIndex,
    Duration position,
  ) async {
    await _db.transaction(() async {
      // Upsert all tracks first
      for (final t in queue) {
        await upsertTrack(t);
      }

      // Replace queue items
      await _db.delete(_db.queueItems).go();

      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < queue.length; i++) {
        await _db.into(_db.queueItems).insert(
              QueueItemsCompanion.insert(
                position: Value(i),
                trackId: queue[i].id,
                addedAt: now,
              ),
            );
      }

      // Upsert playback state
      await _db.into(_db.playbackStates).insertOnConflictUpdate(
            PlaybackStatesCompanion.insert(
              id: const Value(1),
              currentQueueIndex: Value(currentIndex),
              currentPositionMs: Value(position.inMilliseconds),
              updatedAt: now,
            ),
          );
    });
  }

  @override
  Future<QueueState> getQueueState() async {
    final stateRow = await (_db.select(_db.playbackStates)
          ..where((s) => s.id.equals(1)))
        .getSingleOrNull();

    final query = _db.select(_db.queueItems).join([
      innerJoin(
        _db.tracks,
        _db.tracks.id.equalsExp(_db.queueItems.trackId),
      ),
    ])..orderBy([OrderingTerm.asc(_db.queueItems.position)]);

    final rows = await query.get();
    final tracks = rows.map((r) => _trackFromRow(r.readTable(_db.tracks))).toList();

    return QueueState(
      tracks: tracks,
      currentIndex: stateRow?.currentQueueIndex ?? 0,
      position: Duration(milliseconds: stateRow?.currentPositionMs ?? 0),
    );
  }

  @override
  Future<void> clearQueueState() async {
    await _db.transaction(() async {
      await _db.delete(_db.queueItems).go();
      await (_db.delete(_db.playbackStates)..where((s) => s.id.equals(1))).go();
    });
  }

  // ==========================================
  // Lyrics Cache
  // ==========================================

  @override
  Future<void> cacheLyrics(
    String trackId, {
    String? syncedLrc,
    String? plainText,
    bool isNotFound = false,
  }) async {
    await _db.into(_db.cachedLyrics).insertOnConflictUpdate(
          CachedLyricsCompanion.insert(
            trackId: trackId,
            syncedLrc: Value(syncedLrc),
            plainText: Value(plainText),
            isNotFound: Value(isNotFound),
            cachedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<({String? syncedLrc, String? plainText, bool isNotFound})?> getCachedLyrics(
    String trackId,
  ) async {
    final row = await (_db.select(_db.cachedLyrics)
          ..where((c) => c.trackId.equals(trackId)))
        .getSingleOrNull();

    if (row == null) return null;
    return (
      syncedLrc: row.syncedLrc,
      plainText: row.plainText,
      isNotFound: row.isNotFound,
    );
  }
}
