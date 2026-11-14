import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/track.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_toast.dart';

/// Riverpod provider for [PlaylistM3uExporter].
final playlistM3uExporterProvider = Provider<PlaylistM3uExporter>((ref) {
  return const PlaylistM3uExporter();
});

/// Quality-of-life utility to export Softify playlists into universal formats
/// (.m3u8 extended playlist or .csv spreadsheet).
///
/// Supports saving directly to the user's Music or Documents directory across
/// Linux, macOS, Windows, and Android.
class PlaylistM3uExporter {
  const PlaylistM3uExporter();

  /// Generates an extended M3U8 playlist formatted string with:
  /// - `#EXTM3U` header on the first line
  /// - `#PLAYLIST:<playlistName>` header (if non-empty)
  /// - `#EXTINF:duration,Artist - Title` for each track
  /// - URI / file path on the following line
  static String generateM3u8(String playlistName, List<Track> tracks) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');

    final trimmedName = playlistName.trim();
    if (trimmedName.isNotEmpty) {
      buffer.writeln('#PLAYLIST:$trimmedName');
    }

    for (final track in tracks) {
      final durationSec =
          track.duration.inSeconds >= 0 ? track.duration.inSeconds : 0;
      final artist =
          track.artist.trim().isEmpty ? 'Unknown Artist' : track.artist.trim();
      final title =
          track.title.trim().isEmpty ? 'Unknown Title' : track.title.trim();

      buffer.writeln('#EXTINF:$durationSec,$artist - $title');
      buffer.writeln(resolveTrackUri(track));
    }

    return buffer.toString();
  }

  /// Generates an RFC 4180-compliant CSV string representing playlist tracks.
  ///
  /// Columns:
  /// - `Index`
  /// - `Title`
  /// - `Artist`
  /// - `Album`
  /// - `Duration` (formatted mm:ss or hh:mm:ss)
  /// - `DurationSeconds`
  /// - `SourceId`
  static String generateCsv(String playlistName, List<Track> tracks) {
    final buffer = StringBuffer();
    buffer.writeln(
        'Index,Title,Artist,Album,Duration,DurationSeconds,SourceId');

    for (int i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      final index = i + 1;
      final title = escapeCsvField(t.title);
      final artist = escapeCsvField(t.artist);
      final album = escapeCsvField(t.album ?? '');
      final durationFormatted = escapeCsvField(formatDuration(t.duration));
      final durationSeconds =
          t.duration.inSeconds >= 0 ? t.duration.inSeconds : 0;
      final sourceId = escapeCsvField(t.sourceId);

      buffer.writeln(
          '$index,$title,$artist,$album,$durationFormatted,$durationSeconds,$sourceId');
    }

    return buffer.toString();
  }

  /// Resolves the stream URI or local file path for [track].
  static String resolveTrackUri(Track track) {
    final source = track.sourceId.trim();
    if (source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('file://')) {
      return source;
    }
    if (source.startsWith('/') || source.contains(Platform.pathSeparator)) {
      return source;
    }
    if (source.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=$source';
    }
    final cleanArtist = sanitizeFileName(track.artist);
    final cleanTitle = sanitizeFileName(track.title);
    return '$cleanArtist - $cleanTitle.mp3';
  }

  /// Sanitizes playlist or track names for cross-platform filesystem safety.
  static String sanitizeFileName(String name) {
    var clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    clean = clean.replaceAll(RegExp(r'[. ]+$'), '');
    return clean.isEmpty ? 'playlist' : clean;
  }

  /// Escapes CSV values according to RFC 4180.
  static String escapeCsvField(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Formats [Duration] into `MM:SS` or `HH:MM:SS`.
  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Resolves the destination directory for saving exported playlists:
  /// Prioritizes user's standard Music directory, then Documents directory, then Downloads.
  static Future<Directory> resolveExportDirectory() async {
    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final home =
            Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null && home.isNotEmpty) {
          final musicDir = Directory(p.join(home, 'Music'));
          if (musicDir.existsSync()) return musicDir;

          final docsDir = Directory(p.join(home, 'Documents'));
          if (docsDir.existsSync()) return docsDir;

          final downloadsDir = Directory(p.join(home, 'Downloads'));
          if (downloadsDir.existsSync()) return downloadsDir;

          try {
            if (!musicDir.existsSync()) {
              musicDir.createSync(recursive: true);
              return musicDir;
            }
          } catch (_) {}
        }
      } else if (Platform.isAndroid) {
        final candidatePaths = [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/Download',
        ];
        for (final path in candidatePaths) {
          final dir = Directory(path);
          if (dir.existsSync()) return dir;
        }
      }
    } catch (_) {}

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      if (appDocs.existsSync()) return appDocs;
    } catch (_) {}

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && downloads.existsSync()) return downloads;
    } catch (_) {}

    return Directory.systemTemp;
  }

  /// Exports [tracks] as M3U8 or CSV to user Documents / Music directory.
  ///
  /// Displays a floating confirmation toast upon success or error.
  /// Returns the saved file's absolute path, or `null` if the export failed.
  static Future<String?> exportToFile(
    BuildContext context,
    String playlistName,
    List<Track> tracks, {
    bool isCsv = false,
    Directory? customDirectory,
    String? customFileName,
  }) async {
    try {
      final ext = isCsv ? 'csv' : 'm3u8';
      final content = isCsv
          ? generateCsv(playlistName, tracks)
          : generateM3u8(playlistName, tracks);

      final baseName = customFileName != null && customFileName.trim().isNotEmpty
          ? sanitizeFileName(customFileName)
          : sanitizeFileName(playlistName);

      final targetDir = customDirectory ?? await resolveExportDirectory();
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      final targetFile = File(p.join(targetDir.path, '$baseName.$ext'));
      await targetFile.writeAsString(content, flush: true);

      if (context.mounted) {
        AppToast.showSuccess(
          context,
          message:
              'Exported "$playlistName" to ${p.basename(targetFile.path)} (${p.basename(targetDir.path)})',
        );
      }

      return targetFile.path;
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(
          context,
          message: 'Export failed: ${e.toString()}',
        );
      }
      return null;
    }
  }

  /// Displays an interactive modal bottom sheet allowing the user to choose
  /// between exporting as M3U8 (media players) or CSV (spreadsheets/backup).
  static Future<String?> showExportBottomSheet(
    BuildContext context, {
    required String playlistName,
    required List<Track> tracks,
    Directory? customDirectory,
  }) {
    final tokens = context.tokens;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Material(
          color: tokens.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spaceMd,
                vertical: tokens.spaceSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36.0,
                      height: 4.0,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      decoration: BoxDecoration(
                        color: tokens.divider,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(tokens.spaceSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Playlist',
                          style: TextStyle(
                            fontFamily: AppTheme.fontPageTitle,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '$playlistName (${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'})',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 13.0,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1.0),
                  ListTile(
                    leading: Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: tokens.accent,
                        size: 22.0,
                      ),
                    ),
                    title: Text(
                      'M3U8 Playlist (.m3u8)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Standard audio playlist compatible with VLC, Apple Music, and offline players',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12.0,
                        color: tokens.textSecondary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      HapticFeedback.selectionClick();
                      await exportToFile(
                        context,
                        playlistName,
                        tracks,
                        isCsv: false,
                        customDirectory: customDirectory,
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: tokens.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Icon(
                        Icons.table_chart_rounded,
                        color: tokens.accentCyan,
                        size: 22.0,
                      ),
                    ),
                    title: Text(
                      'CSV Spreadsheet (.csv)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Universal spreadsheet for Excel, Google Sheets, Spotify migration, or backup',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12.0,
                        color: tokens.textSecondary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      HapticFeedback.selectionClick();
                      await exportToFile(
                        context,
                        playlistName,
                        tracks,
                        isCsv: true,
                        customDirectory: customDirectory,
                      );
                    },
                  ),
                  SizedBox(height: tokens.spaceMd),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Extension enabling instance method calls on [PlaylistM3uExporter].
extension PlaylistM3uExporterInstanceExtension on PlaylistM3uExporter {
  String generateM3u8(String playlistName, List<Track> tracks) =>
      PlaylistM3uExporter.generateM3u8(playlistName, tracks);

  String generateCsv(String playlistName, List<Track> tracks) =>
      PlaylistM3uExporter.generateCsv(playlistName, tracks);

  String resolveTrackUri(Track track) =>
      PlaylistM3uExporter.resolveTrackUri(track);

  String sanitizeFileName(String name) =>
      PlaylistM3uExporter.sanitizeFileName(name);

  Future<String?> exportToFile(
    BuildContext context,
    String playlistName,
    List<Track> tracks, {
    bool isCsv = false,
    Directory? customDirectory,
    String? customFileName,
  }) =>
      PlaylistM3uExporter.exportToFile(
        context,
        playlistName,
        tracks,
        isCsv: isCsv,
        customDirectory: customDirectory,
        customFileName: customFileName,
      );

  Future<String?> showExportBottomSheet(
    BuildContext context, {
    required String playlistName,
    required List<Track> tracks,
    Directory? customDirectory,
  }) =>
      PlaylistM3uExporter.showExportBottomSheet(
        context,
        playlistName: playlistName,
        tracks: tracks,
        customDirectory: customDirectory,
      );
}
