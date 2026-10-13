import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';

/// 1-Click encrypted/portable backup and restore engine for Softify libraries.
/// Exports playlists, liked tracks, and settings to a standalone JSON file.
class LibraryBackupService {
  static const int currentBackupVersion = 1;

  /// Generates a complete JSON backup payload of user's library.
  static Future<String> generateBackupJson(AppDatabase db) async {
    // 1. Liked Tracks
    final likedTrackRows = await (db.select(db.tracks)
          ..where((t) => t.isLiked.equals(true)))
        .get();

    final likedTracksJson = likedTrackRows
        .map((t) => {
              'id': t.id,
              'sourceId': t.sourceId,
              'title': t.title,
              'artist': t.artist,
              'album': t.album,
              'durationMs': t.durationMs,
              'coverUrl': t.coverUrl,
            })
        .toList();

    // 2. Playlists & Tracks
    final playlistRows = await db.select(db.playlists).get();
    final List<Map<String, dynamic>> playlistsJson = [];

    for (final pRow in playlistRows) {
      final trackEntries = await (db.select(db.playlistTracks).join([
        leftOuterJoin(db.tracks, db.tracks.id.equalsExp(db.playlistTracks.trackId)),
      ])..where(db.playlistTracks.playlistId.equals(pRow.id))
        ..orderBy([OrderingTerm.asc(db.playlistTracks.position)]))
          .get();

      final tracksJson = trackEntries.map((row) {
        final pt = row.readTable(db.playlistTracks);
        final t = row.readTableOrNull(db.tracks);
        return {
          'position': pt.position,
          'originalTitle': pt.originalTitle,
          'originalArtist': pt.originalArtist,
          'matchStatus': pt.matchStatus,
          'track': t != null
              ? {
                  'id': t.id,
                  'sourceId': t.sourceId,
                  'title': t.title,
                  'artist': t.artist,
                  'album': t.album,
                  'durationMs': t.durationMs,
                  'coverUrl': t.coverUrl,
                }
              : null,
        };
      }).toList();

      playlistsJson.add({
        'id': pRow.id,
        'name': pRow.name,
        'description': pRow.description,
        'createdAt': pRow.createdAt,
        'tracks': tracksJson,
      });
    }

    // 3. User Settings
    final settingRows = await db.select(db.settings).get();
    final Map<String, String> settingsMap = {
      for (final s in settingRows) s.key: s.value
    };

    final payload = {
      'format': 'softify_backup',
      'version': currentBackupVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'likedTracks': likedTracksJson,
      'playlists': playlistsJson,
      'settings': settingsMap,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports backup to disk and returns the file path.
  static Future<String> exportBackupToFile(AppDatabase db, {String? targetDirectory}) async {
    final jsonStr = await generateBackupJson(db);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'softify_library_backup_$timestamp.json';

    String dirPath = targetDirectory ?? '';
    if (dirPath.isEmpty) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          final downloads = Directory(p.join(home, 'Downloads'));
          if (downloads.existsSync()) {
            dirPath = downloads.path;
          } else {
            dirPath = home;
          }
        }
      }
      if (dirPath.isEmpty) {
        dirPath = Directory.systemTemp.path;
      }
    }

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final file = File(p.join(dir.path, filename));
    await file.writeAsString(jsonStr, flush: true);
    return file.path;
  }

  /// Restores library from a backup JSON string.
  static Future<({int playlistsRestored, int likedRestored})> restoreFromJson(
    AppDatabase db,
    String jsonString,
  ) async {
    final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
    if (data['format'] != 'softify_backup') {
      throw const FormatException('Invalid Softify backup format');
    }

    int likedCount = 0;
    int playlistCount = 0;

    await db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Restore Liked Tracks
      final likedList = data['likedTracks'] as List<dynamic>? ?? [];
      for (final item in likedList) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String? ?? '';
          if (id.isEmpty) continue;
          await db.into(db.tracks).insertOnConflictUpdate(
                TracksCompanion(
                  id: Value(id),
                  sourceId: Value((item['sourceId'] as String?) ?? id),
                  title: Value((item['title'] as String?) ?? 'Unknown Title'),
                  artist: Value((item['artist'] as String?) ?? 'Unknown Artist'),
                  album: Value(item['album'] as String?),
                  durationMs: Value((item['durationMs'] as int?) ?? 180000),
                  coverUrl: Value(item['coverUrl'] as String?),
                  matchConfidence: const Value(1.0),
                  isLiked: const Value(true),
                  isUnavailable: const Value(false),
                  createdAt: Value(now),
                ),
              );
          likedCount++;
        }
      }

      // 2. Restore Playlists
      final playlistsList = data['playlists'] as List<dynamic>? ?? [];
      for (final pItem in playlistsList) {
        if (pItem is Map<String, dynamic>) {
          final pId = pItem['id'] as String? ?? 'pl_${DateTime.now().microsecondsSinceEpoch}';
          final name = pItem['name'] as String? ?? 'Restored Playlist';
          final desc = pItem['description'] as String?;
          final createdAt = (pItem['createdAt'] as int?) ?? now;

          await db.into(db.playlists).insertOnConflictUpdate(
                PlaylistsCompanion(
                  id: Value(pId),
                  name: Value(name),
                  description: Value(desc),
                  isImported: const Value(false),
                  createdAt: Value(createdAt),
                ),
              );

          final tracks = pItem['tracks'] as List<dynamic>? ?? [];
          for (final tItem in tracks) {
            if (tItem is Map<String, dynamic>) {
              final pos = (tItem['position'] as int?) ?? 0;
              final origTitle = (tItem['originalTitle'] as String?) ?? '';
              final origArtist = (tItem['originalArtist'] as String?) ?? '';
              final matchStatus = (tItem['matchStatus'] as String?) ?? 'matched';

              String? trackId;
              final tData = tItem['track'] as Map<String, dynamic>?;
              if (tData != null) {
                trackId = tData['id'] as String?;
                if (trackId != null && trackId.isNotEmpty) {
                  final existing = await (db.select(db.tracks)
                        ..where((t) => t.id.equals(trackId!)))
                      .getSingleOrNull();
                  final bool keepLiked = existing?.isLiked ?? false;

                  await db.into(db.tracks).insertOnConflictUpdate(
                        TracksCompanion(
                          id: Value(trackId),
                          sourceId: Value((tData['sourceId'] as String?) ?? trackId),
                          title: Value((tData['title'] as String?) ?? origTitle),
                          artist: Value((tData['artist'] as String?) ?? origArtist),
                          album: Value(tData['album'] as String?),
                          durationMs: Value((tData['durationMs'] as int?) ?? 180000),
                          coverUrl: Value(tData['coverUrl'] as String?),
                          matchConfidence: const Value(1.0),
                          isLiked: Value(keepLiked),
                          isUnavailable: const Value(false),
                          createdAt: Value(now),
                        ),
                      );
                }
              }

              await db.into(db.playlistTracks).insertOnConflictUpdate(
                    PlaylistTracksCompanion(
                      playlistId: Value(pId),
                      position: Value(pos),
                      trackId: Value(trackId),
                      originalTitle: Value(origTitle),
                      originalArtist: Value(origArtist),
                      matchStatus: Value(matchStatus),
                    ),
                  );
            }
          }
          playlistCount++;
        }
      }

      // 3. Restore Settings
      final settings = data['settings'] as Map<String, dynamic>? ?? {};
      for (final entry in settings.entries) {
        if (entry.value is String) {
          await db.into(db.settings).insertOnConflictUpdate(
                SettingRow(key: entry.key, value: entry.value as String),
              );
        }
      }
    });

    db.notifyUpdates({
      TableUpdate.onTable(db.tracks),
      TableUpdate.onTable(db.playlists),
      TableUpdate.onTable(db.playlistTracks),
      TableUpdate.onTable(db.settings),
    });

    return (playlistsRestored: playlistCount, likedRestored: likedCount);
  }
}
