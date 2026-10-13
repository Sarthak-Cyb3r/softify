import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/track.dart';
import '../database/app_database.dart';

/// Scanner that crawls local device storage for music files and indexes them
/// into Softify's offline SQLite database for zero-network local playback.
class LocalAudioScanner {
  static const Set<String> supportedExtensions = {
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.ogg',
    '.aac',
  };

  /// Minimum file size (300 KB) to filter out UI sounds, clicks, beeps, and short voice memos.
  static const int minFileSizeBytes = 300 * 1024;

  /// Folders excluded from crawl to prevent indexing sound effects, code assets, and cache.
  static const Set<String> excludedFolderNames = {
    'node_modules',
    'build',
    'dist',
    'out',
    'target',
    'vendor',
    'bin',
    'obj',
    'src',
    'assets',
    'public',
    'temp',
    'tmp',
    'cache',
    'Android',
    '.Trash',
    'WhatsApp',
    'WhatsApp Audio',
    'Voice Notes',
    'Ringtones',
    'Notifications',
    'Alarms',
    'Call Recordings',
    '.venv',
    '.git',
    '.idea',
    '.vscode',
  };

  /// Checks if any segment of a file path is in an excluded or hidden directory.
  static bool isExcludedPath(String filePath) {
    final segments = p.split(filePath);
    for (final seg in segments) {
      if (seg.isEmpty) continue;
      if (seg.startsWith('.') && seg != '.' && seg != '..') return true;
      if (excludedFolderNames.contains(seg)) return true;
    }
    return false;
  }

  /// Discovers standard music directories on Android, Linux, and macOS.
  static Future<List<Directory>> getTargetDirectories() async {
    final dirs = <Directory>[];

    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final musicDir = Directory(p.join(home, 'Music'));
          if (musicDir.existsSync()) dirs.add(musicDir);

          final downloadsDir = Directory(p.join(home, 'Downloads'));
          if (downloadsDir.existsSync()) dirs.add(downloadsDir);
        }
      } else if (Platform.isAndroid) {
        final candidatePaths = [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Audiobooks',
          '/storage/emulated/0/Podcasts',
        ];
        for (final path in candidatePaths) {
          final dir = Directory(path);
          if (dir.existsSync()) dirs.add(dir);
        }

        try {
          final appMusic = await getExternalStorageDirectories(
              type: StorageDirectory.music);
          if (appMusic != null) {
            for (final d in appMusic) {
              if (d.existsSync()) dirs.add(d);
            }
          }
          final appDownloads = await getExternalStorageDirectories(
              type: StorageDirectory.downloads);
          if (appDownloads != null) {
            for (final d in appDownloads) {
              if (d.existsSync()) dirs.add(d);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return dirs;
  }

  /// Scans directories safely for genuine audio music files.
  static Future<List<Track>> scanDirectories({
    List<Directory>? customDirectories,
  }) async {
    final targets = customDirectories ?? await getTargetDirectories();
    final List<Track> discovered = [];
    final Set<String> seenPaths = {};

    for (final dir in targets) {
      if (!dir.existsSync()) continue;
      // In Downloads, limit crawl depth to 2 to avoid descending into arbitrary project workspaces
      final isDownloads = p.basename(dir.path).toLowerCase() == 'downloads' ||
          p.basename(dir.path).toLowerCase() == 'download';
      final maxDepth = isDownloads ? 2 : 4;

      await _walkDirectory(
        dir: dir,
        currentDepth: 0,
        maxDepth: maxDepth,
        seenPaths: seenPaths,
        discovered: discovered,
      );
    }

    return discovered;
  }

  static Future<void> _walkDirectory({
    required Directory dir,
    required int currentDepth,
    required int maxDepth,
    required Set<String> seenPaths,
    required List<Track> discovered,
  }) async {
    if (currentDepth > maxDepth || !dir.existsSync()) return;

    try {
      // Respect .nomedia marker
      final noMedia = File(p.join(dir.path, '.nomedia'));
      if (noMedia.existsSync()) return;

      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (name.startsWith('.') || excludedFolderNames.contains(name)) {
          continue;
        }

        if (entity is Directory) {
          await _walkDirectory(
            dir: entity,
            currentDepth: currentDepth + 1,
            maxDepth: maxDepth,
            seenPaths: seenPaths,
            discovered: discovered,
          );
        } else if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext) && !seenPaths.contains(entity.path)) {
            try {
              if (entity.lengthSync() < minFileSizeBytes) continue;
            } catch (_) {
              continue;
            }

            seenPaths.add(entity.path);
            final track = _fileToTrack(entity);
            if (track != null) {
              discovered.add(track);
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Scans device, purges missing files, and indexes genuine tracks into Drift database.
  static Future<int> scanAndIndex(AppDatabase db, {List<Directory>? customDirectories}) async {
    // 1. Purge deleted, non-existent, or excluded tracks from SQLite
    try {
      final existingLocal = await (db.select(db.tracks)
            ..where((t) => t.id.like('local_%') | t.sourceId.like('local_%')))
          .get();

      for (final row in existingLocal) {
        final file = File(row.sourceId);
        if (!file.existsSync() ||
            file.lengthSync() < minFileSizeBytes ||
            isExcludedPath(row.sourceId)) {
          await (db.delete(db.tracks)..where((t) => t.id.equals(row.id))).go();
        }
      }
    } catch (_) {}

    // 2. Discover active tracks
    final tracks = await scanDirectories(customDirectories: customDirectories);
    if (tracks.isEmpty) return 0;

    await db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final t in tracks) {
        await db.into(db.tracks).insertOnConflictUpdate(
              TracksCompanion(
                id: Value(t.id),
                sourceId: Value(t.sourceId),
                title: Value(t.title),
                artist: Value(t.artist),
                album: Value(t.album),
                durationMs: Value(t.duration.inMilliseconds),
                coverUrl: Value(t.coverUrl),
                matchConfidence: const Value(1.0),
                isLiked: const Value(false),
                isUnavailable: const Value(false),
                createdAt: Value(now),
              ),
            );
      }
    });

    return tracks.length;
  }

  /// Maps a local audio file on disk to a Softify [Track] entity.
  static Track? _fileToTrack(File file) {
    try {
      final filename = p.basenameWithoutExtension(file.path);
      String artist = 'Local Artist';
      String title = filename;

      // Parse common "Artist - Title" filename patterns
      if (filename.contains(' - ')) {
        final parts = filename.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      // Clean up common web download suffixes
      title = title
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'\(.*?Official.*?\)', caseSensitive: false), '')
          .trim();

      if (title.isEmpty) title = filename;

      final pathHash = md5.convert(utf8.encode(file.path)).toString().substring(0, 16);
      final id = 'local_$pathHash';

      return Track(
        id: id,
        sourceId: file.path,
        title: title,
        artist: artist.isNotEmpty ? artist : 'Local Music',
        album: null,
        duration: const Duration(minutes: 3), // Initial estimate, updated on playback
        matchConfidence: 1.0,
      );
    } catch (_) {
      return null;
    }
  }
}
